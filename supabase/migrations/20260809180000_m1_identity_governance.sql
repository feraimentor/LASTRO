-- M1 hardening: transactional profile/onboarding, link lifecycle, recent-auth and RBAC mutations.

create or replace function private.session_is_recent(p_max_age interval default interval '15 minutes')
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1
      from auth.sessions s
     where s.user_id = auth.uid()
       and s.id = nullif(
         coalesce(
           current_setting('request.jwt.claim.session_id', true),
           nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'session_id'
         ), ''
       )::uuid
       and s.created_at >= now() - p_max_age
       and (s.not_after is null or s.not_after > now())
  );
$$;

create or replace function private.require_recent_auth()
returns void
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not private.session_is_recent(interval '15 minutes') then
    raise exception 'recent_authentication_required';
  end if;
end;
$$;

create or replace function public.current_session_is_recent()
returns boolean
language sql stable security invoker
set search_path = ''
as $$ select private.session_is_recent(interval '15 minutes'); $$;

create or replace function private.save_profile(
  p_first_name text,
  p_last_name text,
  p_display_name text,
  p_identity public.identity_mode,
  p_relation text,
  p_currently_resides boolean,
  p_whatsapp text default null
)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_email text;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  if char_length(btrim(p_first_name)) not between 2 and 80
     or char_length(btrim(p_last_name)) not between 2 and 80
     or char_length(btrim(p_display_name)) not between 2 and 100 then
    raise exception 'invalid_profile';
  end if;
  if p_relation not in ('resident_owner','nonresident_owner','tenant','authorized_resident','owner_representative') then
    raise exception 'invalid_relation';
  end if;
  select email into v_email from auth.users where id = v_user;
  if v_email is null then raise exception 'google_email_required'; end if;

  insert into public.profiles(
    id, first_name, last_name, display_name, public_identity_preference,
    relation_to_condo, currently_resides, access_state
  ) values (
    v_user, btrim(p_first_name), btrim(p_last_name), btrim(p_display_name), p_identity,
    p_relation, p_currently_resides, 'onboarding'
  )
  on conflict (id) do update set
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    display_name = excluded.display_name,
    public_identity_preference = excluded.public_identity_preference,
    relation_to_condo = excluded.relation_to_condo,
    currently_resides = excluded.currently_resides;

  insert into private.user_private_data(user_id, google_email, whatsapp)
  values (v_user, lower(v_email), nullif(btrim(p_whatsapp), ''))
  on conflict (user_id) do update set
    google_email = excluded.google_email,
    whatsapp = excluded.whatsapp,
    updated_at = now();
end;
$$;

create or replace function public.save_profile(
  p_first_name text,
  p_last_name text,
  p_display_name text,
  p_identity public.identity_mode,
  p_relation text,
  p_currently_resides boolean,
  p_whatsapp text default null
)
returns void
language sql volatile security invoker
set search_path = ''
as $$
  select private.save_profile(
    p_first_name, p_last_name, p_display_name, p_identity, p_relation,
    p_currently_resides, p_whatsapp
  );
$$;

create or replace function private.submit_verification_request(
  p_block_id smallint,
  p_unit_id uuid,
  p_requested_unit text,
  p_currently_resides boolean
)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
  v_relation text;
begin
  if v_user is null or not private.has_current_legal_acceptances() then
    raise exception 'onboarding_access_required';
  end if;
  select relation_to_condo into v_relation from public.profiles p where p.id = v_user;
  if v_relation is null then
    raise exception 'profile_required';
  end if;
  if v_relation not in ('resident_owner','nonresident_owner','tenant','authorized_resident','owner_representative') then
    raise exception 'invalid_relation';
  end if;
  if p_block_id not between 1 and 14 then raise exception 'invalid_block'; end if;
  if p_unit_id is null and char_length(btrim(coalesce(p_requested_unit, ''))) not between 1 and 30 then
    raise exception 'unit_required';
  end if;
  if p_unit_id is not null and not exists (
    select 1 from public.condo_units u
     where u.id = p_unit_id and u.block_id = p_block_id and u.archived_at is null
  ) then raise exception 'invalid_unit'; end if;
  if exists (
    select 1 from public.verification_requests r
     where r.user_id = v_user and r.state = 'pending'
  ) then raise exception 'verification_already_pending'; end if;

  select id into v_id
    from public.verification_requests
   where user_id = v_user and state = 'needs_information'
   order by created_at desc limit 1 for update;

  if v_id is null then
    insert into public.verification_requests(
      user_id, requested_unit_id, requested_block_id, requested_unit_label,
      relation_type, currently_resides, state
    ) values (
      v_user, p_unit_id, p_block_id,
      case when p_unit_id is null then btrim(p_requested_unit) else null end,
      v_relation, p_currently_resides, 'pending'
    ) returning id into v_id;
  else
    update public.verification_requests set
      requested_unit_id = p_unit_id,
      requested_block_id = p_block_id,
      requested_unit_label = case when p_unit_id is null then btrim(p_requested_unit) else null end,
      relation_type = v_relation,
      currently_resides = p_currently_resides,
      state = 'pending', reviewer_id = null, reviewed_at = null, decision_reason = null
    where id = v_id;
  end if;
  return v_id;
end;
$$;

create or replace function public.submit_verification_request(
  p_block_id smallint,
  p_unit_id uuid default null,
  p_requested_unit text default null,
  p_currently_resides boolean default true
)
returns uuid
language sql volatile security invoker
set search_path = ''
as $$
  select private.submit_verification_request(
    p_block_id, p_unit_id, p_requested_unit, p_currently_resides
  );
$$;

create or replace function private.end_resident_link(p_link_id uuid, p_reason text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_link public.resident_unit_links%rowtype;
begin
  if not (private.has_permission('residents.verify') or private.has_permission('residents.suspend')) then
    raise exception 'permission_denied';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 5 then raise exception 'reason_required'; end if;
  select * into v_link from public.resident_unit_links where id = p_link_id for update;
  if v_link.id is null or v_link.ended_at is not null then raise exception 'active_link_required'; end if;
  update public.resident_unit_links set
    ends_at = coalesce(ends_at, current_date), ended_by = auth.uid(), ended_at = now()
  where id = p_link_id;
  if not exists (
    select 1 from public.resident_unit_links l
     where l.user_id = v_link.user_id and l.verification_status = 'approved' and l.ended_at is null
  ) then
    update public.profiles set access_state = 'link_ended' where id = v_link.user_id;
  end if;
  insert into public.audit_logs(actor_user_id, action, target_type, target_id, old_values, new_values, reason)
  values (
    auth.uid(), 'resident_link.ended', 'resident_unit_link', p_link_id,
    jsonb_build_object('user_id', v_link.user_id, 'unit_id', v_link.unit_id, 'ended_at', v_link.ended_at),
    jsonb_build_object('ended_at', now()), btrim(p_reason)
  );
end;
$$;

create or replace function public.end_resident_link(p_link_id uuid, p_reason text)
returns void language sql volatile security invoker set search_path = ''
as $$ select private.end_resident_link(p_link_id, p_reason); $$;

create or replace function private.set_user_suspension(
  p_target_user_id uuid, p_suspend boolean, p_reason text
)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_old public.profiles%rowtype; v_next public.access_state;
begin
  if not private.has_permission('residents.suspend') then raise exception 'permission_denied'; end if;
  perform private.require_recent_auth();
  if p_target_user_id = auth.uid() then raise exception 'self_suspension_change_forbidden'; end if;
  if char_length(btrim(coalesce(p_reason,''))) < 5 then raise exception 'reason_required'; end if;
  select * into v_old from public.profiles where id=p_target_user_id for update;
  if v_old.id is null then raise exception 'profile_not_found'; end if;
  if p_suspend then
    update public.profiles set access_state='suspended',suspended_at=now(),suspension_reason=btrim(p_reason)
     where id=p_target_user_id;
  else
    if exists(select 1 from public.resident_unit_links l where l.user_id=p_target_user_id and l.verification_status='approved' and l.ended_at is null) then
      v_next := 'active';
    elsif exists(select 1 from public.resident_unit_links l where l.user_id=p_target_user_id and l.ended_at is not null) then
      v_next := 'link_ended';
    else
      v_next := 'pending_verification';
    end if;
    update public.profiles set access_state=v_next,suspended_at=null,suspension_reason=null where id=p_target_user_id;
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,old_values,new_values,reason)
  values(auth.uid(),case when p_suspend then 'access.suspended' else 'access.restored' end,
         'user',p_target_user_id,
         jsonb_build_object('access_state',v_old.access_state,'suspended_at',v_old.suspended_at),
         jsonb_build_object('suspended',p_suspend),btrim(p_reason));
end;
$$;

create or replace function public.set_user_suspension(
  p_target_user_id uuid, p_suspend boolean, p_reason text
)
returns void language sql volatile security invoker set search_path = ''
as $$ select private.set_user_suspension(p_target_user_id,p_suspend,p_reason); $$;

create or replace function private.set_user_role(
  p_target_user_id uuid,
  p_role_slug text,
  p_action text,
  p_reason text
)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.roles%rowtype;
  v_actor_level integer;
  v_actor_master boolean;
  v_assignment uuid;
begin
  if not private.has_permission('admins.manage') then raise exception 'permission_denied'; end if;
  perform private.require_recent_auth();
  if p_target_user_id = v_actor then raise exception 'self_role_change_forbidden'; end if;
  if p_action not in ('grant','revoke') then raise exception 'invalid_action'; end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 5 then raise exception 'reason_required'; end if;
  if not exists (select 1 from auth.users where id = p_target_user_id) then raise exception 'user_not_found'; end if;
  select * into v_role from public.roles where slug = p_role_slug;
  if v_role.id is null then raise exception 'role_not_found'; end if;
  select coalesce(max(r.level), 0), coalesce(bool_or(r.slug = 'master'), false)
    into v_actor_level, v_actor_master
    from public.user_roles ur join public.roles r on r.id = ur.role_id
   where ur.user_id = v_actor and ur.revoked_at is null;
  if (v_role.slug = 'master' and not v_actor_master)
     or (not v_actor_master and v_role.level >= v_actor_level) then
    raise exception 'role_hierarchy_violation';
  end if;

  if p_action = 'grant' then
    select id into v_assignment from public.user_roles
     where user_id = p_target_user_id and role_id = v_role.id and revoked_at is null;
    if v_assignment is null then
      insert into public.user_roles(user_id, role_id, granted_by)
      values (p_target_user_id, v_role.id, v_actor) returning id into v_assignment;
    end if;
  else
    select id into v_assignment from public.user_roles
     where user_id = p_target_user_id and role_id = v_role.id and revoked_at is null for update;
    if v_assignment is null then raise exception 'active_role_required'; end if;
    update public.user_roles set revoked_by = v_actor, revoked_at = now(), revocation_reason = btrim(p_reason)
     where id = v_assignment;
  end if;
  insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values, reason)
  values (v_actor, 'rbac.role_' || p_action, 'user', p_target_user_id,
          jsonb_build_object('role', p_role_slug, 'assignment_id', v_assignment), btrim(p_reason));
  return v_assignment;
end;
$$;

create or replace function public.set_user_role(
  p_target_user_id uuid, p_role_slug text, p_action text, p_reason text
)
returns uuid language sql volatile security invoker set search_path = ''
as $$ select private.set_user_role(p_target_user_id, p_role_slug, p_action, p_reason); $$;

create or replace function private.set_permission_override(
  p_target_user_id uuid,
  p_permission_slug text,
  p_effect text,
  p_reason text
)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_permission uuid;
  v_id uuid;
  v_actor_level integer;
  v_target_level integer;
  v_actor_master boolean;
begin
  if not private.has_permission('admins.manage') then raise exception 'permission_denied'; end if;
  perform private.require_recent_auth();
  if p_target_user_id = v_actor then raise exception 'self_permission_change_forbidden'; end if;
  if p_effect not in ('grant','deny','revoke') then raise exception 'invalid_effect'; end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 5 then raise exception 'reason_required'; end if;
  select id into v_permission from public.permissions where slug = p_permission_slug;
  if v_permission is null then raise exception 'permission_not_found'; end if;
  select coalesce(max(r.level),0), coalesce(bool_or(r.slug='master'),false)
    into v_actor_level, v_actor_master
    from public.user_roles ur join public.roles r on r.id=ur.role_id
   where ur.user_id=v_actor and ur.revoked_at is null;
  select coalesce(max(r.level),0) into v_target_level
    from public.user_roles ur join public.roles r on r.id=ur.role_id
   where ur.user_id=p_target_user_id and ur.revoked_at is null;
  if not v_actor_master and v_target_level >= v_actor_level then raise exception 'role_hierarchy_violation'; end if;

  select id into v_id from public.user_permission_overrides
   where user_id=p_target_user_id and permission_id=v_permission and revoked_at is null for update;
  if v_id is not null then
    update public.user_permission_overrides set revoked_by=v_actor, revoked_at=now() where id=v_id;
  end if;
  if p_effect <> 'revoke' then
    insert into public.user_permission_overrides(user_id,permission_id,effect,granted_by,reason)
    values(p_target_user_id,v_permission,p_effect,v_actor,btrim(p_reason)) returning id into v_id;
  elsif v_id is null then
    raise exception 'active_override_required';
  end if;
  insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values, reason)
  values(v_actor,'rbac.permission_'||p_effect,'user',p_target_user_id,
         jsonb_build_object('permission',p_permission_slug,'override_id',v_id),btrim(p_reason));
  return v_id;
end;
$$;

create or replace function public.set_permission_override(
  p_target_user_id uuid, p_permission_slug text, p_effect text, p_reason text
)
returns uuid language sql volatile security invoker set search_path = ''
as $$ select private.set_permission_override(p_target_user_id,p_permission_slug,p_effect,p_reason); $$;

create or replace function private.create_legal_draft(
  p_document_key text,
  p_version text,
  p_content_markdown text,
  p_content_hash_sha256 text,
  p_requires_reacceptance boolean,
  p_download_path text default null
)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_document uuid; v_version_id uuid;
begin
  if not private.has_permission('legal_documents.manage') then raise exception 'permission_denied'; end if;
  if char_length(btrim(coalesce(p_version,''))) not between 1 and 30
     or char_length(btrim(coalesce(p_content_markdown,''))) < 100
     or p_content_hash_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_legal_draft';
  end if;
  select id into v_document from public.legal_documents where key=p_document_key;
  if v_document is null then raise exception 'legal_document_not_found'; end if;
  insert into public.legal_document_versions(
    document_id,version,state,content_markdown,content_hash_sha256,
    requires_reacceptance,is_current,download_path,created_by
  ) values(
    v_document,btrim(p_version),'draft',p_content_markdown,p_content_hash_sha256,
    p_requires_reacceptance,false,nullif(btrim(p_download_path),''),auth.uid()
  ) returning id into v_version_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'legal.draft_created','legal_document_version',v_version_id,
         jsonb_build_object('document_key',p_document_key,'version',btrim(p_version),
                            'requires_reacceptance',p_requires_reacceptance,'hash',p_content_hash_sha256));
  return v_version_id;
end;
$$;

create or replace function public.create_legal_draft(
  p_document_key text,p_version text,p_content_markdown text,p_content_hash_sha256 text,
  p_requires_reacceptance boolean,p_download_path text default null
)
returns uuid language sql volatile security invoker set search_path = ''
as $$ select private.create_legal_draft(p_document_key,p_version,p_content_markdown,p_content_hash_sha256,p_requires_reacceptance,p_download_path); $$;

create or replace function private.publish_legal_version(
  p_version_id uuid,p_effective_at timestamptz,p_download_path text
)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_version public.legal_document_versions%rowtype;
begin
  if not private.has_permission('legal_documents.manage') then raise exception 'permission_denied'; end if;
  perform private.require_recent_auth();
  select * into v_version from public.legal_document_versions where id=p_version_id for update;
  if v_version.id is null or v_version.state<>'draft' then raise exception 'draft_required'; end if;
  if p_effective_at is null or char_length(btrim(coalesce(p_download_path,'')))<3 then
    raise exception 'publication_metadata_required';
  end if;
  update public.legal_document_versions set is_current=false
   where document_id=v_version.document_id and state='published' and is_current;
  update public.legal_document_versions set
    state='published',published_at=now(),effective_at=p_effective_at,
    download_path=btrim(p_download_path),is_current=true
   where id=p_version_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values,reason)
  values(auth.uid(),'legal.version_published','legal_document_version',p_version_id,
         jsonb_build_object('effective_at',p_effective_at,'hash',v_version.content_hash_sha256,
                            'requires_reacceptance',v_version.requires_reacceptance),
         'Publicação após autenticação recente');
end;
$$;

create or replace function public.publish_legal_version(
  p_version_id uuid,p_effective_at timestamptz,p_download_path text
)
returns void language sql volatile security invoker set search_path = ''
as $$ select private.publish_legal_version(p_version_id,p_effective_at,p_download_path); $$;

create or replace function private.guard_last_master_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_other_active integer;
begin
  if (new.access_state = 'suspended' or new.suspended_at is not null)
     and not (old.access_state = 'suspended' or old.suspended_at is not null)
     and exists (
       select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id
        where ur.user_id=old.id and ur.revoked_at is null and r.slug='master'
     ) then
    select count(*) into v_other_active
      from public.user_roles ur
      join public.roles r on r.id=ur.role_id
      left join public.profiles p on p.id=ur.user_id
     where r.slug='master' and ur.revoked_at is null and ur.user_id<>old.id
       and (p.id is null or (p.access_state<>'suspended' and p.suspended_at is null));
    if v_other_active=0 then raise exception 'last_active_master_cannot_be_suspended'; end if;
  end if;
  return new;
end;
$$;

create trigger last_master_profile_guard before update on public.profiles
for each row execute function private.guard_last_master_profile();

-- Published snapshots remain immutable; only the current pointer may move forward.
create or replace function private.prevent_published_legal_mutation()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'DELETE' and old.state = 'published' then
    raise exception 'published_legal_version_is_immutable';
  end if;
  if tg_op = 'UPDATE' and old.state = 'published' then
    if old.is_current and not new.is_current
       and (to_jsonb(new) - 'is_current') = (to_jsonb(old) - 'is_current') then
      return new;
    end if;
    raise exception 'published_legal_version_is_immutable';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create policy legal_versions_admin_read on public.legal_document_versions
for select to authenticated using (private.has_permission('legal_documents.manage'));

revoke insert, update on public.profiles from authenticated;
revoke insert, update on public.verification_requests from authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function public.next_report_protocol(public.source_origin,timestamptz) to authenticated;
grant execute on function public.create_report(jsonb) to authenticated;
grant execute on function public.current_user_has_permission(text) to authenticated;
grant execute on function public.accept_current_legal_documents() to authenticated;
grant execute on function public.review_verification_request(uuid,text,text) to authenticated;
grant execute on function public.create_condo_unit(smallint,text) to authenticated;
grant execute on function public.current_session_is_recent() to authenticated;
grant execute on function public.save_profile(text,text,text,public.identity_mode,text,boolean,text) to authenticated;
grant execute on function public.submit_verification_request(smallint,uuid,text,boolean) to authenticated;
grant execute on function public.end_resident_link(uuid,text) to authenticated;
grant execute on function public.set_user_suspension(uuid,boolean,text) to authenticated;
grant execute on function public.set_user_role(uuid,text,text,text) to authenticated;
grant execute on function public.set_permission_override(uuid,text,text,text) to authenticated;
grant execute on function public.create_legal_draft(text,text,text,text,boolean,text) to authenticated;
grant execute on function public.publish_legal_version(uuid,timestamptz,text) to authenticated;

grant execute on function private.session_is_recent(interval), private.require_recent_auth(),
  private.save_profile(text,text,text,public.identity_mode,text,boolean,text),
  private.submit_verification_request(smallint,uuid,text,boolean),
  private.end_resident_link(uuid,text), private.set_user_suspension(uuid,boolean,text),
  private.set_user_role(uuid,text,text,text), private.set_permission_override(uuid,text,text,text),
  private.create_legal_draft(text,text,text,text,boolean,text),
  private.publish_legal_version(uuid,timestamptz,text) to authenticated;
revoke all on all functions in schema private from public, anon;
