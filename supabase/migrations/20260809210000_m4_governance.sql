-- M4: reversible issue curation, moderation/review, privacy decisions and configurable taxonomy.

alter table public.report_issue_history
  add column merge_id uuid references public.issue_merges(id) on delete restrict,
  add column undone_by uuid references auth.users(id) on delete restrict,
  add column undone_at timestamptz,
  add column undo_reason text;

create table public.issue_splits(
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  source_issue_id uuid not null references public.issues(id) on delete restrict,
  new_issue_id uuid not null references public.issues(id) on delete restrict,
  reason text not null,
  split_by uuid not null references auth.users(id) on delete restrict,
  split_at timestamptz not null default now(),
  undone_by uuid references auth.users(id) on delete restrict,
  undone_at timestamptz,
  undo_reason text
);
alter table public.issue_splits enable row level security;

alter table public.content_flags add constraint content_flag_one_target
check((report_id is not null)::int+(response_id is not null)::int+(attachment_id is not null)::int=1) not valid;

create or replace function private.merge_issues(p_source_issue_id uuid,p_target_issue_id uuid,p_reason text)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_merge uuid; v_report record;
begin
  if not private.has_permission('issues.merge') then raise exception 'permission_denied'; end if;
  if p_source_issue_id=p_target_issue_id or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_merge'; end if;
  perform 1 from public.issues where id in(p_source_issue_id,p_target_issue_id) order by id for update;
  if (select count(*) from public.issues where id in(p_source_issue_id,p_target_issue_id) and archived_at is null)<>2 then raise exception 'active_issues_required'; end if;
  insert into public.issue_merges(source_issue_id,target_issue_id,reason,merged_by)
  values(p_source_issue_id,p_target_issue_id,btrim(p_reason),auth.uid()) returning id into v_merge;
  for v_report in select id from public.reports where issue_id=p_source_issue_id and archived_at is null for update loop
    update public.reports set issue_id=p_target_issue_id where id=v_report.id;
    insert into public.report_issue_history(report_id,from_issue_id,to_issue_id,reason,changed_by,merge_id)
    values(v_report.id,p_source_issue_id,p_target_issue_id,btrim(p_reason),auth.uid(),v_merge);
  end loop;
  insert into public.issue_locations(issue_id,location_id)
    select p_target_issue_id,location_id from public.issue_locations where issue_id=p_source_issue_id on conflict do nothing;
  update public.issues set archived_at=now(),derived_status='archived' where id=p_source_issue_id;
  perform private.recalculate_issue_status(p_target_issue_id);
  insert into public.timeline_events(issue_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
  values(p_target_issue_id,auth.uid(),'issue.merged','issue_merge',v_merge,'Problemas coletivos mesclados',jsonb_build_object('source_issue_id',p_source_issue_id,'target_issue_id',p_target_issue_id));
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values,reason)
  values(auth.uid(),'issue.merged','issue_merge',v_merge,jsonb_build_object('source_issue_id',p_source_issue_id,'target_issue_id',p_target_issue_id),btrim(p_reason));
  return v_merge;
end;
$$;

create or replace function public.merge_issues(p_source_issue_id uuid,p_target_issue_id uuid,p_reason text)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.merge_issues(p_source_issue_id,p_target_issue_id,p_reason); $$;

create or replace function private.undo_issue_merge(p_merge_id uuid,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$
declare v public.issue_merges%rowtype; v_history record;
begin
  if not private.has_permission('issues.merge') then raise exception 'permission_denied'; end if;
  if char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'reason_required'; end if;
  select * into v from public.issue_merges where id=p_merge_id for update;
  if v.id is null or v.undone_at is not null then raise exception 'active_merge_required'; end if;
  update public.issues set archived_at=null where id=v.source_issue_id;
  for v_history in select * from public.report_issue_history where merge_id=v.id and undone_at is null order by changed_at for update loop
    if exists(select 1 from public.reports where id=v_history.report_id and issue_id=v.target_issue_id) then
      update public.reports set issue_id=v.source_issue_id where id=v_history.report_id;
      update public.report_issue_history set undone_by=auth.uid(),undone_at=now(),undo_reason=btrim(p_reason) where id=v_history.id;
      insert into public.report_issue_history(report_id,from_issue_id,to_issue_id,reason,changed_by)
      values(v_history.report_id,v.target_issue_id,v.source_issue_id,'Desfazer merge: '||btrim(p_reason),auth.uid());
    end if;
  end loop;
  update public.issue_merges set undone_by=auth.uid(),undone_at=now() where id=v.id;
  perform private.recalculate_issue_status(v.source_issue_id);perform private.recalculate_issue_status(v.target_issue_id);
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,reason)
  values(auth.uid(),'issue.merge_undone','issue_merge',v.id,btrim(p_reason));
end;
$$;

create or replace function public.undo_issue_merge(p_merge_id uuid,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.undo_issue_merge(p_merge_id,p_reason); $$;

create or replace function private.split_report_to_new_issue(p_report_id uuid,p_title text,p_reason text)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_report public.reports%rowtype; v_new uuid; v_split uuid;
begin
  if not private.has_permission('issues.split') then raise exception 'permission_denied'; end if;
  if char_length(btrim(coalesce(p_title,''))) not between 8 and 180 or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_split'; end if;
  select * into v_report from public.reports where id=p_report_id for update;
  if v_report.id is null then raise exception 'report_not_found'; end if;
  insert into public.issues(title,category_id,subcategory_id,first_occurred_at,last_occurred_at,created_by,source_origin)
  values(btrim(p_title),v_report.category_id,v_report.subcategory_id,v_report.occurred_at,v_report.occurred_at,auth.uid(),v_report.source_origin) returning id into v_new;
  update public.reports set issue_id=v_new where id=v_report.id;
  insert into public.issue_splits(report_id,source_issue_id,new_issue_id,reason,split_by)
  values(v_report.id,v_report.issue_id,v_new,btrim(p_reason),auth.uid()) returning id into v_split;
  insert into public.report_issue_history(report_id,from_issue_id,to_issue_id,reason,changed_by)
  values(v_report.id,v_report.issue_id,v_new,btrim(p_reason),auth.uid());
  insert into public.issue_locations(issue_id,location_id) select v_new,location_id from public.report_locations where report_id=v_report.id on conflict do nothing;
  perform private.recalculate_issue_status(v_report.issue_id);perform private.recalculate_issue_status(v_new);
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
  values(v_new,v_report.id,auth.uid(),'issue.split','issue_split',v_split,'Relato separado em novo problema coletivo',jsonb_build_object('from_issue_id',v_report.issue_id));
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,reason)
  values(auth.uid(),'issue.split','issue_split',v_split,btrim(p_reason));
  return v_split;
end;
$$;

create or replace function public.split_report_to_new_issue(p_report_id uuid,p_title text,p_reason text)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.split_report_to_new_issue(p_report_id,p_title,p_reason); $$;

create or replace function private.undo_issue_split(p_split_id uuid,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$
declare v public.issue_splits%rowtype;
begin
  if not private.has_permission('issues.split') then raise exception 'permission_denied'; end if;
  if char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'reason_required'; end if;
  select * into v from public.issue_splits where id=p_split_id for update;
  if v.id is null or v.undone_at is not null or not exists(select 1 from public.reports where id=v.report_id and issue_id=v.new_issue_id) then raise exception 'active_split_required'; end if;
  update public.reports set issue_id=v.source_issue_id where id=v.report_id;
  update public.issue_splits set undone_by=auth.uid(),undone_at=now(),undo_reason=btrim(p_reason) where id=v.id;
  update public.issues set archived_at=now(),derived_status='archived' where id=v.new_issue_id;
  insert into public.report_issue_history(report_id,from_issue_id,to_issue_id,reason,changed_by)
  values(v.report_id,v.new_issue_id,v.source_issue_id,'Desfazer split: '||btrim(p_reason),auth.uid());
  perform private.recalculate_issue_status(v.source_issue_id);
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,reason)
  values(auth.uid(),'issue.split_undone','issue_split',v.id,btrim(p_reason));
end;
$$;

create or replace function public.undo_issue_split(p_split_id uuid,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.undo_issue_split(p_split_id,p_reason); $$;

create or replace function private.flag_report(p_report_id uuid,p_reason text,p_details text default null)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_id uuid;
begin
  if p_reason not in('personal_data','harassment','potentially_inappropriate_allegation','spam','off_purpose','other') or not private.can_access_report(p_report_id) then raise exception 'invalid_flag'; end if;
  perform private.enforce_rate_limit('content.flag',30);
  insert into public.content_flags(report_id,reporter_user_id,reason,details)
  values(p_report_id,auth.uid(),p_reason,nullif(btrim(p_details),'')) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.flag_report(p_report_id uuid,p_reason text,p_details text default null)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.flag_report(p_report_id,p_reason,p_details); $$;

create or replace function private.apply_moderation_action(p_flag_id uuid,p_action text,p_reason text)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_flag public.content_flags%rowtype; v_id uuid; v_target_type text; v_target uuid; v_old jsonb:='{}'; v_new jsonb:='{}'; v_report uuid; v_issue uuid;
begin
  if not private.has_permission('moderation.review') then raise exception 'permission_denied'; end if;
  if p_action not in('no_action','restrict','hide','request_correction','restore','archive','remove_file','other') or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_moderation_action'; end if;
  if p_action in('restrict','hide','archive','remove_file') and not private.has_permission('moderation.restrict') then raise exception 'permission_denied'; end if;
  if p_action='restore' and not private.has_permission('moderation.restore') then raise exception 'permission_denied'; end if;
  select * into v_flag from public.content_flags where id=p_flag_id for update;
  if v_flag.id is null or v_flag.state='closed' then raise exception 'open_flag_required'; end if;
  if v_flag.report_id is not null then v_target_type:='report';v_target:=v_flag.report_id;v_report:=v_target;
    select jsonb_build_object('visibility',visibility,'hidden_at',hidden_at,'archived_at',archived_at) into v_old from public.reports where id=v_target for update;
    if p_action='restrict' then update public.reports set visibility='restricted' where id=v_target;
    elsif p_action='hide' then update public.reports set hidden_at=now() where id=v_target;
    elsif p_action='restore' then update public.reports set hidden_at=null,archived_at=null where id=v_target;
    elsif p_action='archive' then update public.reports set archived_at=now() where id=v_target; end if;
    select jsonb_build_object('visibility',visibility,'hidden_at',hidden_at,'archived_at',archived_at) into v_new from public.reports where id=v_target;
  elsif v_flag.response_id is not null then v_target_type:='response';v_target:=v_flag.response_id;
    select report_id,jsonb_build_object('hidden_at',hidden_at) into v_report,v_old from public.responses where id=v_target for update;
    if p_action='hide' then update public.responses set hidden_at=now() where id=v_target; elsif p_action='restore' then update public.responses set hidden_at=null where id=v_target; end if;
    select jsonb_build_object('hidden_at',hidden_at) into v_new from public.responses where id=v_target;
  else v_target_type:='attachment';v_target:=v_flag.attachment_id;
    select report_id,jsonb_build_object('hidden_at',hidden_at) into v_report,v_old from public.attachments where id=v_target for update;
    if p_action in('hide','remove_file') then update public.attachments set hidden_at=now() where id=v_target; elsif p_action='restore' then update public.attachments set hidden_at=null where id=v_target; end if;
    select jsonb_build_object('hidden_at',hidden_at) into v_new from public.attachments where id=v_target;
  end if;
  insert into public.moderation_actions(content_flag_id,action_type,target_type,target_id,reason,moderator_user_id,old_values,new_values)
  values(v_flag.id,p_action,v_target_type,v_target,btrim(p_reason),auth.uid(),v_old,v_new) returning id into v_id;
  update public.content_flags set state='closed' where id=v_flag.id;
  select issue_id into v_issue from public.reports where id=v_report;
  if v_report is not null then insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
    values(v_issue,v_report,auth.uid(),'moderation.applied','moderation_action',v_id,'Ação de moderação aplicada',jsonb_build_object('action',p_action)); end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,old_values,new_values,reason)
  values(auth.uid(),'moderation.'||p_action,v_target_type,v_target,v_old,v_new,btrim(p_reason));
  return v_id;
end;
$$;

create or replace function public.apply_moderation_action(p_flag_id uuid,p_action text,p_reason text)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.apply_moderation_action(p_flag_id,p_action,p_reason); $$;

create or replace function private.revert_moderation_action(p_action_id uuid,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$
declare v public.moderation_actions%rowtype; v_report uuid; v_issue uuid;
begin
  if not private.has_permission('moderation.restore') then raise exception 'permission_denied'; end if;
  if char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'reason_required'; end if;
  select * into v from public.moderation_actions where id=p_action_id for update;
  if v.id is null or v.reverted_at is not null then raise exception 'active_moderation_action_required'; end if;
  if v.target_type='report' then
    update public.reports set visibility=coalesce((v.old_values->>'visibility')::public.visibility_mode,visibility),hidden_at=(v.old_values->>'hidden_at')::timestamptz,archived_at=(v.old_values->>'archived_at')::timestamptz where id=v.target_id;v_report:=v.target_id;
  elsif v.target_type='response' then update public.responses set hidden_at=(v.old_values->>'hidden_at')::timestamptz where id=v.target_id returning report_id into v_report;
  elsif v.target_type='attachment' then update public.attachments set hidden_at=(v.old_values->>'hidden_at')::timestamptz where id=v.target_id returning report_id into v_report; end if;
  update public.moderation_actions set reverted_by=auth.uid(),reverted_at=now() where id=v.id;
  select issue_id into v_issue from public.reports where id=v_report;
  if v_report is not null then insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
    values(v_issue,v_report,auth.uid(),'moderation.reverted','moderation_action',v.id,'Ação de moderação revertida',jsonb_build_object('reason',btrim(p_reason))); end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,reason)
  values(auth.uid(),'moderation.reverted','moderation_action',v.id,btrim(p_reason));
end;
$$;

create or replace function public.revert_moderation_action(p_action_id uuid,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.revert_moderation_action(p_action_id,p_reason); $$;

create or replace function private.is_impacted_by_moderation(p_action_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
  select exists(
    select 1 from public.moderation_actions m where m.id=p_action_id and (
      (m.target_type='report' and exists(select 1 from public.reports r where r.id=m.target_id and r.author_user_id=auth.uid()))
      or (m.target_type='response' and exists(select 1 from public.responses r where r.id=m.target_id and r.recorded_by=auth.uid()))
      or (m.target_type='attachment' and exists(select 1 from public.attachments a where a.id=m.target_id and a.uploader_user_id=auth.uid()))
    )
  );
$$;

create or replace function private.submit_review_request(p_moderation_action_id uuid,p_suspension boolean,p_rationale text)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_action public.moderation_actions%rowtype; v_id uuid; v_impacted boolean:=false;
begin
  if char_length(btrim(coalesce(p_rationale,'')))<10 then raise exception 'rationale_required'; end if;
  if p_moderation_action_id is not null then
    select * into v_action from public.moderation_actions where id=p_moderation_action_id;
    if v_action.target_type='report' then v_impacted:=exists(select 1 from public.reports where id=v_action.target_id and author_user_id=auth.uid());
    elsif v_action.target_type='response' then v_impacted:=exists(select 1 from public.responses where id=v_action.target_id and recorded_by=auth.uid());
    elsif v_action.target_type='attachment' then v_impacted:=exists(select 1 from public.attachments where id=v_action.target_id and uploader_user_id=auth.uid()); end if;
  elsif p_suspension then
    v_impacted:=exists(select 1 from public.profiles where id=auth.uid() and suspended_at is not null);
  end if;
  if not v_impacted then raise exception 'review_request_not_allowed'; end if;
  insert into public.review_requests(requester_user_id,moderation_action_id,suspension_user_id,rationale)
  values(auth.uid(),p_moderation_action_id,case when p_suspension then auth.uid() else null end,btrim(p_rationale)) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.submit_review_request(p_moderation_action_id uuid default null,p_suspension boolean default false,p_rationale text default null)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.submit_review_request(p_moderation_action_id,p_suspension,p_rationale); $$;

create or replace function private.decide_review_request(p_request_id uuid,p_state text,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$ declare v public.review_requests%rowtype; begin
  if not private.has_permission('moderation.review') then raise exception 'permission_denied'; end if;
  if p_state not in('upheld','reversed','partially_reversed') or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_review_decision'; end if;
  select * into v from public.review_requests where id=p_request_id for update;
  if v.id is null or v.state not in('pending','reviewing') then raise exception 'open_review_required'; end if;
  if p_state='reversed' and v.moderation_action_id is not null then perform private.revert_moderation_action(v.moderation_action_id,p_reason); end if;
  update public.review_requests set state=p_state,reviewer_user_id=auth.uid(),decision_reason=btrim(p_reason),decided_at=now() where id=v.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values,reason)
  values(auth.uid(),'review.decided','review_request',v.id,jsonb_build_object('state',p_state),btrim(p_reason));
end $$;

create or replace function public.decide_review_request(p_request_id uuid,p_state text,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.decide_review_request(p_request_id,p_state,p_reason); $$;

create or replace function private.submit_privacy_request(p_request_type text,p_details text default null)
returns uuid language plpgsql volatile security definer set search_path=''
as $$ declare v_id uuid; begin
  if p_request_type not in('access','correction','closure','anonymization_blocking_deletion_review','treatment_information','other') then raise exception 'invalid_privacy_request'; end if;
  perform private.enforce_rate_limit('privacy.request',10);
  insert into public.privacy_requests(user_id,request_type,details) values(auth.uid(),p_request_type,nullif(btrim(p_details),'')) returning id into v_id;
  return v_id;
end $$;

create or replace function public.submit_privacy_request(p_request_type text,p_details text default null)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.submit_privacy_request(p_request_type,p_details); $$;

create or replace function private.decide_privacy_request(p_request_id uuid,p_state text,p_decision text,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$ declare v public.privacy_requests%rowtype; begin
  if not (private.has_permission('private_data.view') and private.has_permission('settings.manage')) then raise exception 'permission_denied'; end if;
  if p_state not in('completed','partially_completed','denied') or char_length(btrim(coalesce(p_decision,'')))<10 or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_privacy_decision'; end if;
  perform private.require_recent_auth();
  select * into v from public.privacy_requests where id=p_request_id for update;
  if v.id is null or v.state in('completed','partially_completed','denied') then raise exception 'open_privacy_request_required'; end if;
  update public.privacy_requests set state=p_state,decision=btrim(p_decision),decided_by=auth.uid(),decided_at=now() where id=v.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values,reason)
  values(auth.uid(),'privacy.decided','privacy_request',v.id,jsonb_build_object('state',p_state,'request_type',v.request_type),btrim(p_reason));
end $$;

create or replace function public.decide_privacy_request(p_request_id uuid,p_state text,p_decision text,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.decide_privacy_request(p_request_id,p_state,p_decision,p_reason); $$;

create or replace function private.manage_taxonomy(p_entity text,p_action text,p_payload jsonb)
returns uuid language plpgsql volatile security definer set search_path=''
as $$ declare v_id uuid; v_parent uuid; begin
  if not private.has_permission('categories.manage') then raise exception 'permission_denied'; end if;
  if p_entity='category' then
    if p_action='create' then insert into public.categories(slug,name,sort_order) values(p_payload->>'slug',p_payload->>'name',(p_payload->>'sort_order')::int) returning id into v_id;
    else select id into v_id from public.categories where slug=p_payload->>'slug' for update;
      if p_action='update' then update public.categories set name=coalesce(nullif(p_payload->>'name',''),name),sort_order=coalesce((p_payload->>'sort_order')::int,sort_order) where id=v_id;
      elsif p_action='archive' then update public.categories set archived_at=now() where id=v_id;
      elsif p_action='restore' then update public.categories set archived_at=null where id=v_id; else raise exception 'invalid_action'; end if;
    end if;
  elsif p_entity='location' then
    if p_action='create' then insert into public.locations(slug,label,sort_order) values(p_payload->>'slug',p_payload->>'name',(p_payload->>'sort_order')::int) returning id into v_id;
    else select id into v_id from public.locations where slug=p_payload->>'slug' for update;
      if p_action='update' then update public.locations set label=coalesce(nullif(p_payload->>'name',''),label),sort_order=coalesce((p_payload->>'sort_order')::int,sort_order) where id=v_id;
      elsif p_action='archive' then update public.locations set archived_at=now() where id=v_id;
      elsif p_action='restore' then update public.locations set archived_at=null where id=v_id; else raise exception 'invalid_action'; end if;
    end if;
  elsif p_entity='subcategory' then
    select id into v_parent from public.categories where slug=p_payload->>'category_slug';if v_parent is null then raise exception 'category_not_found';end if;
    if p_action='create' then insert into public.subcategories(category_id,slug,name,sort_order) values(v_parent,p_payload->>'slug',p_payload->>'name',(p_payload->>'sort_order')::int) returning id into v_id;
    else select id into v_id from public.subcategories where category_id=v_parent and slug=p_payload->>'slug' for update;
      if p_action='update' then update public.subcategories set name=coalesce(nullif(p_payload->>'name',''),name),sort_order=coalesce((p_payload->>'sort_order')::int,sort_order) where id=v_id;
      elsif p_action='archive' then update public.subcategories set archived_at=now() where id=v_id;
      elsif p_action='restore' then update public.subcategories set archived_at=null where id=v_id; else raise exception 'invalid_action'; end if;
    end if;
  else raise exception 'invalid_entity'; end if;
  if v_id is null then raise exception 'taxonomy_item_not_found'; end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'taxonomy.'||p_action,p_entity,v_id,jsonb_build_object('slug',p_payload->>'slug'));
  return v_id;
end $$;

create or replace function public.manage_taxonomy(p_entity text,p_action text,p_payload jsonb)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.manage_taxonomy(p_entity,p_action,p_payload); $$;

drop policy if exists flags_community_insert on public.content_flags;
drop policy if exists reviews_own_insert on public.review_requests;
drop policy if exists privacy_own_insert on public.privacy_requests;
revoke insert on public.content_flags,public.review_requests,public.privacy_requests from authenticated;

create policy flags_moderator_read on public.content_flags for select to authenticated using(private.has_permission('moderation.review'));
create policy moderation_actions_admin_or_author_read on public.moderation_actions for select to authenticated using(private.has_permission('moderation.review') or private.is_impacted_by_moderation(id));
create policy review_admin_read on public.review_requests for select to authenticated using(private.has_permission('moderation.review'));
create policy privacy_admin_read on public.privacy_requests for select to authenticated using(private.has_permission('private_data.view') and private.has_permission('settings.manage'));
create policy issue_merges_admin_read on public.issue_merges for select to authenticated using(private.has_permission('issues.merge'));
create policy issue_splits_admin_read on public.issue_splits for select to authenticated using(private.has_permission('issues.split'));
create policy report_history_authorized_read on public.report_issue_history for select to authenticated using(private.can_access_report(report_id));

grant select on public.moderation_actions,public.issue_merges,public.issue_splits,public.report_issue_history to authenticated;

revoke all on function public.merge_issues(uuid,uuid,text),public.undo_issue_merge(uuid,text),public.split_report_to_new_issue(uuid,text,text),public.undo_issue_split(uuid,text),public.flag_report(uuid,text,text),public.apply_moderation_action(uuid,text,text),public.revert_moderation_action(uuid,text),public.submit_review_request(uuid,boolean,text),public.decide_review_request(uuid,text,text),public.submit_privacy_request(text,text),public.decide_privacy_request(uuid,text,text,text),public.manage_taxonomy(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.merge_issues(uuid,uuid,text),public.undo_issue_merge(uuid,text),public.split_report_to_new_issue(uuid,text,text),public.undo_issue_split(uuid,text),public.flag_report(uuid,text,text),public.apply_moderation_action(uuid,text,text),public.revert_moderation_action(uuid,text),public.submit_review_request(uuid,boolean,text),public.decide_review_request(uuid,text,text),public.submit_privacy_request(text,text),public.decide_privacy_request(uuid,text,text,text),public.manage_taxonomy(text,text,jsonb) to authenticated;
grant execute on function private.merge_issues(uuid,uuid,text),private.undo_issue_merge(uuid,text),private.split_report_to_new_issue(uuid,text,text),private.undo_issue_split(uuid,text),private.flag_report(uuid,text,text),private.apply_moderation_action(uuid,text,text),private.revert_moderation_action(uuid,text),private.submit_review_request(uuid,boolean,text),private.decide_review_request(uuid,text,text),private.submit_privacy_request(text,text),private.decide_privacy_request(uuid,text,text,text),private.manage_taxonomy(text,text,jsonb) to authenticated;
grant execute on function private.is_impacted_by_moderation(uuid) to authenticated;
revoke all on all functions in schema private from public,anon;
