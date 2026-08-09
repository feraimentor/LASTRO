-- M3: official/external responses, case invitations, commitments and private evidence lifecycle.
create extension if not exists pgcrypto with schema extensions;

alter table public.access_invitations add column metadata jsonb not null default '{}'::jsonb;
alter table public.attachments add column upload_status text not null default 'reserved'
  check(upload_status in('reserved','ready','failed'));

create table public.official_status_updates(
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  status text not null check(status in('received','under_analysis','forwarded','in_execution','awaiting_third_party','service_reported_completed','closed_by_management')),
  note text,
  official_representation_id uuid not null references public.official_representations(id) on delete restrict,
  recorded_by uuid not null references auth.users(id) on delete restrict,
  recorded_at timestamptz not null default now()
);
alter table public.official_status_updates enable row level security;

create or replace function private.has_valid_official_representation(p_representation_id uuid,p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=''
as $$
  select exists(
    select 1 from public.official_representations o
     where o.id=p_representation_id and o.user_id=p_user_id and o.status='active'
       and o.starts_at<=now() and (o.ends_at is null or o.ends_at>now())
  );
$$;

create or replace function private.can_access_report(p_report_id uuid)
returns boolean
language sql stable security definer
set search_path=''
as $$
  select auth.uid() is not null and exists(
    select 1 from public.reports r where r.id=p_report_id and (
      r.author_user_id=auth.uid()
      or private.has_permission_for_user('sensitive_content.view',auth.uid())
      or (
        r.visibility='community' and r.hidden_at is null
        and private.has_current_legal_acceptances_for_user(auth.uid())
        and (
          private.is_verified_resident_for_user(auth.uid())
          or exists(select 1 from public.official_representations o where o.user_id=auth.uid() and o.status='active' and o.starts_at<=now() and (o.ends_at is null or o.ends_at>now()))
        )
      )
      or (
        private.has_current_legal_acceptances_for_user(auth.uid())
        and exists(select 1 from public.case_access_grants g where g.report_id=r.id and g.user_id=auth.uid() and g.revoked_at is null and (g.expires_at is null or g.expires_at>now()))
      )
    )
  );
$$;

create or replace function private.set_official_status(
  p_report_id uuid,p_representation_id uuid,p_status text,p_note text default null
)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid; v_issue uuid;
begin
  if not private.has_valid_official_representation(p_representation_id,auth.uid()) then raise exception 'valid_official_representation_required'; end if;
  if p_status not in('received','under_analysis','forwarded','in_execution','awaiting_third_party','service_reported_completed','closed_by_management') then raise exception 'invalid_official_status'; end if;
  select issue_id into v_issue from public.reports where id=p_report_id and private.can_access_report(id);
  if v_issue is null then raise exception 'report_access_required'; end if;
  insert into public.official_status_updates(report_id,status,note,official_representation_id,recorded_by)
  values(p_report_id,p_status,nullif(btrim(p_note),''),p_representation_id,auth.uid()) returning id into v_id;
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
  values(v_issue,p_report_id,auth.uid(),'official.status_changed','official_status_update',v_id,
         'Status operacional oficial atualizado',jsonb_build_object('status',p_status));
  return v_id;
end;
$$;

create or replace function public.set_official_status(p_report_id uuid,p_representation_id uuid,p_status text,p_note text default null)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.set_official_status(p_report_id,p_representation_id,p_status,p_note); $$;

create or replace view public.official_status_current with(security_invoker=true) as
select distinct on(u.report_id) u.id,u.report_id,u.status,u.note,u.official_representation_id,u.recorded_at
from public.official_status_updates u order by u.report_id,u.recorded_at desc,u.id desc;

create or replace function private.create_commitment_from_response(
  p_report_id uuid,p_response_id uuid,p_source_label text,p_assigned_to text,p_description text,
  p_assumed_at timestamptz,p_due_at timestamptz
)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid; v_issue uuid;
begin
  if char_length(btrim(coalesce(p_source_label,'')))<2 or char_length(btrim(coalesce(p_description,'')))<5 then raise exception 'invalid_commitment'; end if;
  select issue_id into v_issue from public.reports where id=p_report_id;
  insert into public.commitments(report_id,issue_id,response_id,source_label,assigned_to,recorded_by,description,assumed_at,original_due_at,current_due_at,status)
  values(p_report_id,v_issue,p_response_id,btrim(p_source_label),nullif(btrim(p_assigned_to),''),auth.uid(),btrim(p_description),p_assumed_at,p_due_at,p_due_at,'active')
  returning id into v_id;
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,occurred_at,display_text,metadata)
  values(v_issue,p_report_id,auth.uid(),'commitment.created','commitment',v_id,p_assumed_at,'Compromisso registrado',jsonb_build_object('due_at',p_due_at,'source',btrim(p_source_label)));
  return v_id;
end;
$$;

create or replace function private.record_response(
  p_report_id uuid,p_response_type text,p_attributed_to text,p_channel text,p_occurred_at timestamptz,
  p_body text,p_action_informed text,p_official_representation_id uuid default null,
  p_case_grant_id uuid default null,p_commitment jsonb default null
)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid; v_issue uuid; v_label text;
begin
  if p_response_type not in('external_recorded','official','party_statement') or char_length(btrim(coalesce(p_body,'')))<5 then raise exception 'invalid_response'; end if;
  select issue_id into v_issue from public.reports where id=p_report_id;
  if v_issue is null or not private.can_access_report(p_report_id) then raise exception 'report_access_required'; end if;
  if p_response_type='external_recorded' then
    if not private.is_report_author(p_report_id) then raise exception 'report_author_required'; end if;
    if char_length(btrim(coalesce(p_attributed_to,'')))<2 or char_length(btrim(coalesce(p_channel,'')))<2 then raise exception 'external_attribution_required'; end if;
    p_official_representation_id:=null;p_case_grant_id:=null;
    v_label:='Retorno externo registrado pelo usuário; autoria externa não verificada diretamente pela plataforma';
  elsif p_response_type='official' then
    if not private.has_valid_official_representation(p_official_representation_id,auth.uid()) then raise exception 'valid_official_representation_required'; end if;
    p_case_grant_id:=null;v_label:='Resposta oficial publicada na plataforma';
  else
    if not exists(select 1 from public.case_access_grants g where g.id=p_case_grant_id and g.report_id=p_report_id and g.user_id=auth.uid() and g.revoked_at is null and (g.expires_at is null or g.expires_at>now())) then raise exception 'valid_case_grant_required'; end if;
    p_official_representation_id:=null;v_label:='Manifestação de parte citada';
  end if;
  insert into public.responses(report_id,response_type,attributed_to,channel,occurred_at,body,action_informed,recorded_by,official_representation_id,case_grant_id)
  values(p_report_id,p_response_type,nullif(btrim(p_attributed_to),''),nullif(btrim(p_channel),''),p_occurred_at,btrim(p_body),nullif(btrim(p_action_informed),''),auth.uid(),p_official_representation_id,p_case_grant_id)
  returning id into v_id;
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,occurred_at,display_text,metadata)
  values(v_issue,p_report_id,auth.uid(),'response.'||p_response_type,'response',v_id,p_occurred_at,v_label,jsonb_build_object('response_type',p_response_type));
  if p_commitment is not null then
    perform private.create_commitment_from_response(
      p_report_id,v_id,p_commitment->>'source_label',p_commitment->>'assigned_to',p_commitment->>'description',
      coalesce(nullif(p_commitment->>'assumed_at','')::timestamptz,p_occurred_at),nullif(p_commitment->>'due_at','')::timestamptz
    );
  end if;
  return v_id;
end;
$$;

create or replace function public.record_response(
  p_report_id uuid,p_response_type text,p_attributed_to text,p_channel text,p_occurred_at timestamptz,
  p_body text,p_action_informed text,p_official_representation_id uuid default null,
  p_case_grant_id uuid default null,p_commitment jsonb default null
)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.record_response(p_report_id,p_response_type,p_attributed_to,p_channel,p_occurred_at,p_body,p_action_informed,p_official_representation_id,p_case_grant_id,p_commitment); $$;

create or replace function private.reschedule_commitment(p_commitment_id uuid,p_new_due_at timestamptz,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$
declare v public.commitments%rowtype; v_issue uuid;
begin
  select * into v from public.commitments where id=p_commitment_id for update;
  if v.id is null or (v.recorded_by<>auth.uid() and not private.has_permission('settings.manage')) then raise exception 'commitment_owner_required'; end if;
  if p_new_due_at is null or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_reschedule'; end if;
  insert into public.commitment_deadline_history(commitment_id,previous_due_at,new_due_at,reason,changed_by)
  values(v.id,v.current_due_at,p_new_due_at,btrim(p_reason),auth.uid());
  update public.commitments set current_due_at=p_new_due_at,status='active',justification=btrim(p_reason) where id=v.id;
  v_issue:=coalesce(v.issue_id,(select issue_id from public.reports where id=v.report_id));
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
  values(v_issue,v.report_id,auth.uid(),'commitment.deadline_changed','commitment',v.id,'Prazo de compromisso reprogramado',jsonb_build_object('previous_due_at',v.current_due_at,'new_due_at',p_new_due_at));
end;
$$;

create or replace function public.reschedule_commitment(p_commitment_id uuid,p_new_due_at timestamptz,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.reschedule_commitment(p_commitment_id,p_new_due_at,p_reason); $$;

create or replace function private.mark_overdue_commitments()
returns integer language plpgsql volatile security definer set search_path=''
as $$
declare v record; v_count integer:=0; v_issue uuid;
begin
  for v in select * from public.commitments where status in('active','awaiting_confirmation') and current_due_at is not null and current_due_at<now() for update skip locked loop
    update public.commitments set status='overdue' where id=v.id;
    v_issue:=coalesce(v.issue_id,(select issue_id from public.reports where id=v.report_id));
    insert into public.timeline_events(issue_id,report_id,event_type,entity_type,entity_id,display_text,metadata)
    values(v_issue,v.report_id,'commitment.overdue','commitment',v.id,'Prazo de compromisso vencido',jsonb_build_object('due_at',v.current_due_at));
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.mark_overdue_commitments()
returns integer language sql volatile security invoker set search_path=''
as $$ select private.mark_overdue_commitments(); $$;

create or replace function private.verify_official_representation(
  p_user_id uuid,p_role_type text,p_organization text,p_starts_at timestamptz,p_ends_at timestamptz,p_reason text
)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid;
begin
  if not private.has_permission('official_accounts.verify') then raise exception 'permission_denied'; end if;
  perform private.require_recent_auth();
  if p_role_type not in('manager','deputy_manager','council','administrator','authorized_representative','authorized_provider') or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_representation'; end if;
  insert into public.official_representations(user_id,role_type,organization,starts_at,ends_at,status,verified_by,verified_at)
  values(p_user_id,p_role_type,nullif(btrim(p_organization),''),p_starts_at,p_ends_at,'active',auth.uid(),now()) returning id into v_id;
  update public.profiles set access_state='official' where id=p_user_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values,reason)
  values(auth.uid(),'official_representation.verified','official_representation',v_id,jsonb_build_object('user_id',p_user_id,'role_type',p_role_type,'starts_at',p_starts_at,'ends_at',p_ends_at),btrim(p_reason));
  return v_id;
end;
$$;

create or replace function public.verify_official_representation(p_user_id uuid,p_role_type text,p_organization text,p_starts_at timestamptz,p_ends_at timestamptz,p_reason text)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.verify_official_representation(p_user_id,p_role_type,p_organization,p_starts_at,p_ends_at,p_reason); $$;

create or replace function private.create_access_invitation(
  p_email_hash text,p_token_hash text,p_invitation_type text,p_report_id uuid,p_expires_at timestamptz,p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid;
begin
  perform private.enforce_rate_limit('invitation.create',20);
  if p_email_hash!~'^[0-9a-f]{64}$' or p_token_hash!~'^[0-9a-f]{64}$' or p_expires_at<=now() or p_expires_at>now()+interval '30 days' then raise exception 'invalid_invitation'; end if;
  if p_invitation_type='case_participant' then
    if p_report_id is null or not (private.is_report_author(p_report_id) or private.has_permission('moderation.review')) then raise exception 'invitation_permission_denied'; end if;
  elsif p_invitation_type='official_representative' then
    if not private.has_permission('official_accounts.verify') then raise exception 'invitation_permission_denied'; end if;
  elsif p_invitation_type='admin' then
    if not exists(select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=auth.uid() and ur.revoked_at is null and r.slug='master') then raise exception 'master_required'; end if;
  else raise exception 'invalid_invitation_type'; end if;
  insert into public.access_invitations(invitation_type,email_hash_sha256,token_hash_sha256,report_id,expires_at,created_by,metadata)
  values(p_invitation_type,p_email_hash,p_token_hash,p_report_id,p_expires_at,auth.uid(),coalesce(p_metadata,'{}'::jsonb)) returning id into v_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'access_invitation.created','access_invitation',v_id,jsonb_build_object('type',p_invitation_type,'report_id',p_report_id,'expires_at',p_expires_at));
  return v_id;
end;
$$;

create or replace function public.current_user_is_report_author(p_report_id uuid)
returns boolean language sql stable security invoker set search_path=''
as $$ select private.is_report_author(p_report_id); $$;

create or replace function public.create_access_invitation(p_email_hash text,p_token_hash text,p_invitation_type text,p_report_id uuid,p_expires_at timestamptz,p_metadata jsonb default '{}'::jsonb)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.create_access_invitation(p_email_hash,p_token_hash,p_invitation_type,p_report_id,p_expires_at,p_metadata); $$;

create or replace function private.consume_access_invitation(p_token text)
returns table(invitation_type text,report_id uuid)
language plpgsql volatile security definer set search_path=''
as $$
declare v public.access_invitations%rowtype; v_email text; v_role uuid;
begin
  if auth.uid() is null or not private.has_current_legal_acceptances() then raise exception 'legal_acceptance_required'; end if;
  select email into v_email from auth.users where id=auth.uid();
  select * into v from public.access_invitations
   where token_hash_sha256=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex') for update;
  if v.id is null or v.revoked_at is not null or v.consumed_at is not null or v.expires_at<=now() then raise exception 'invalid_or_expired_invitation'; end if;
  if v.email_hash_sha256<>encode(extensions.digest(convert_to(lower(v_email),'UTF8'),'sha256'),'hex') then raise exception 'invitation_email_mismatch'; end if;
  update public.access_invitations set consumed_by=auth.uid(),consumed_at=now() where id=v.id;
  if v.invitation_type='case_participant' then
    insert into public.case_access_grants(report_id,user_id,invitation_id,granted_by,expires_at)
    values(v.report_id,auth.uid(),v.id,v.created_by,v.expires_at);
    insert into public.profiles(id,access_state) values(auth.uid(),'case_restricted') on conflict(id) do update set access_state='case_restricted';
  elsif v.invitation_type='official_representative' then
    insert into public.official_representations(user_id,role_type,organization,starts_at,ends_at,status,verified_by,verified_at)
    values(auth.uid(),v.metadata->>'role_type',v.metadata->>'organization',coalesce(nullif(v.metadata->>'starts_at','')::timestamptz,now()),nullif(v.metadata->>'ends_at','')::timestamptz,'active',v.created_by,now());
    insert into public.profiles(id,access_state) values(auth.uid(),'official') on conflict(id) do update set access_state='official';
  else
    select id into v_role from public.roles where slug=coalesce(v.metadata->>'role_slug','administrator');
    insert into public.user_roles(user_id,role_id,granted_by) values(auth.uid(),v_role,v.created_by);
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'access_invitation.consumed','access_invitation',v.id,jsonb_build_object('type',v.invitation_type,'report_id',v.report_id));
  return query select v.invitation_type,v.report_id;
end;
$$;

create or replace function public.consume_access_invitation(p_token text)
returns table(invitation_type text,report_id uuid) language sql volatile security invoker set search_path=''
as $$ select * from private.consume_access_invitation(p_token); $$;

create or replace function private.reserve_report_attachment(
  p_report_id uuid,p_original_filename text,p_mime_type text,p_size_bytes bigint,p_sha256 text,p_description text,p_sensitivity text
)
returns table(attachment_id uuid,storage_path text)
language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid:=gen_random_uuid(); v_ext text; v_path text; v_limit bigint;
begin
  if not private.can_access_report(p_report_id) or not (
    private.is_report_author(p_report_id)
    or exists(select 1 from public.case_access_grants g where g.report_id=p_report_id and g.user_id=auth.uid() and g.revoked_at is null and (g.expires_at is null or g.expires_at>now()))
    or exists(select 1 from public.official_representations o where o.user_id=auth.uid() and o.status='active' and o.starts_at<=now() and (o.ends_at is null or o.ends_at>now()))
  ) then raise exception 'attachment_permission_denied'; end if;
  perform private.enforce_rate_limit('attachment.reserve',50);
  select (value#>>'{}')::bigint into v_limit from public.app_settings where key='max_upload_bytes';
  v_limit:=coalesce(v_limit,52428800);v_ext:=lower(regexp_replace(p_original_filename,'^.*\.','','g'));
  if p_size_bytes<=0 or p_size_bytes>v_limit or p_sha256!~'^[0-9a-f]{64}$' then raise exception 'invalid_attachment_metadata'; end if;
  if not ((p_mime_type='image/jpeg' and v_ext in('jpg','jpeg')) or (p_mime_type='image/png' and v_ext='png') or (p_mime_type='image/webp' and v_ext='webp') or (p_mime_type='application/pdf' and v_ext='pdf') or (p_mime_type='audio/mpeg' and v_ext='mp3') or (p_mime_type='audio/mp4' and v_ext in('m4a','mp4')) or (p_mime_type='video/mp4' and v_ext='mp4') or (p_mime_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document' and v_ext='docx') or (p_mime_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' and v_ext='xlsx')) then raise exception 'mime_extension_mismatch'; end if;
  v_path:=auth.uid()::text||'/'||p_report_id::text||'/'||v_id::text||'.'||v_ext;
  insert into public.attachments(id,report_id,uploader_user_id,bucket_id,storage_path,original_filename,mime_type,size_bytes,sha256,description,sensitivity,upload_status)
  values(v_id,p_report_id,auth.uid(),'evidence',v_path,p_original_filename,p_mime_type,p_size_bytes,p_sha256,nullif(btrim(p_description),''),coalesce(nullif(p_sensitivity,''),'normal'),'reserved');
  return query select v_id,v_path;
end;
$$;

create or replace function public.reserve_report_attachment(p_report_id uuid,p_original_filename text,p_mime_type text,p_size_bytes bigint,p_sha256 text,p_description text,p_sensitivity text)
returns table(attachment_id uuid,storage_path text) language sql volatile security invoker set search_path=''
as $$ select * from private.reserve_report_attachment(p_report_id,p_original_filename,p_mime_type,p_size_bytes,p_sha256,p_description,p_sensitivity); $$;

create or replace function private.can_upload_attachment_path(p_path text)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.attachments a where a.storage_path=p_path and a.uploader_user_id=auth.uid() and a.upload_status='reserved' and private.can_access_report(a.report_id)); $$;

create or replace function private.finalize_report_attachment(p_attachment_id uuid)
returns void language plpgsql volatile security definer set search_path=''
as $$
declare v public.attachments%rowtype; v_issue uuid;
begin
  select * into v from public.attachments where id=p_attachment_id for update;
  if v.id is null or v.uploader_user_id<>auth.uid() or v.upload_status<>'reserved' then raise exception 'reserved_attachment_required'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id=v.bucket_id and o.name=v.storage_path) then raise exception 'storage_object_missing'; end if;
  update public.attachments set upload_status='ready' where id=v.id;
  select issue_id into v_issue from public.reports where id=v.report_id;
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
  values(v_issue,v.report_id,auth.uid(),'attachment.added','attachment',v.id,'Evidência adicionada',jsonb_build_object('mime_type',v.mime_type,'size_bytes',v.size_bytes,'sha256',v.sha256));
end;
$$;

create or replace function public.finalize_report_attachment(p_attachment_id uuid)
returns void language sql volatile security invoker set search_path=''
as $$ select private.finalize_report_attachment(p_attachment_id); $$;

create policy official_representation_self_or_admin_read on public.official_representations for select to authenticated
using(user_id=auth.uid() or private.has_permission('official_accounts.verify'));
create policy official_status_authorized_read on public.official_status_updates for select to authenticated using(private.can_access_report(report_id));
create policy case_grants_self_read on public.case_access_grants for select to authenticated using(user_id=auth.uid());
create policy deadline_history_authorized_read on public.commitment_deadline_history for select to authenticated using(exists(select 1 from public.commitments c where c.id=commitment_id and ((c.report_id is not null and private.can_access_report(c.report_id)) or private.is_verified_resident())));

drop policy if exists responses_authorized_insert on public.responses;
drop policy if exists attachments_own_insert on public.attachments;
revoke insert on public.responses,public.attachments from authenticated;
grant select on public.official_representations,public.official_status_updates,public.official_status_current,public.case_access_grants,public.commitment_deadline_history to authenticated;

drop policy if exists evidence_insert_own_path on storage.objects;
create policy evidence_insert_reserved on storage.objects for insert to authenticated with check(bucket_id='evidence' and private.can_upload_attachment_path(name));

revoke all on all functions in schema public from public,anon,authenticated;
grant execute on function public.next_report_protocol(public.source_origin,timestamptz),public.create_report(jsonb),public.current_user_has_permission(text),public.accept_current_legal_documents(),public.review_verification_request(uuid,text,text),public.create_condo_unit(smallint,text),public.current_session_is_recent(),public.save_profile(text,text,text,public.identity_mode,text,boolean,text),public.submit_verification_request(smallint,uuid,text,boolean),public.end_resident_link(uuid,text),public.set_user_suspension(uuid,boolean,text),public.set_user_role(uuid,text,text,text),public.set_permission_override(uuid,text,text,text),public.create_legal_draft(text,text,text,text,boolean,text),public.publish_legal_version(uuid,timestamptz,text),public.search_community_reports(text,integer),public.set_issue_affected(uuid,boolean,uuid),public.set_issue_following(uuid,boolean),public.current_issue_relationships(uuid),public.set_report_status(uuid,text,text),public.set_official_status(uuid,uuid,text,text),public.record_response(uuid,text,text,text,timestamptz,text,text,uuid,uuid,jsonb),public.reschedule_commitment(uuid,timestamptz,text),public.verify_official_representation(uuid,text,text,timestamptz,timestamptz,text),public.create_access_invitation(text,text,text,uuid,timestamptz,jsonb),public.consume_access_invitation(text),public.reserve_report_attachment(uuid,text,text,bigint,text,text,text),public.finalize_report_attachment(uuid) to authenticated;
grant execute on function public.current_user_is_report_author(uuid) to authenticated;
grant execute on function public.mark_overdue_commitments() to service_role;

grant execute on function private.has_valid_official_representation(uuid,uuid),private.set_official_status(uuid,uuid,text,text),private.create_commitment_from_response(uuid,uuid,text,text,text,timestamptz,timestamptz),private.record_response(uuid,text,text,text,timestamptz,text,text,uuid,uuid,jsonb),private.reschedule_commitment(uuid,timestamptz,text),private.verify_official_representation(uuid,text,text,timestamptz,timestamptz,text),private.create_access_invitation(text,text,text,uuid,timestamptz,jsonb),private.consume_access_invitation(text),private.reserve_report_attachment(uuid,text,text,bigint,text,text,text),private.can_upload_attachment_path(text),private.finalize_report_attachment(uuid) to authenticated;
grant execute on function private.mark_overdue_commitments() to service_role;
revoke all on all functions in schema private from public,anon;
