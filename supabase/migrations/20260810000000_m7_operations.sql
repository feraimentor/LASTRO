-- M7: operational observability, security incident workflow and restore evidence.

create table public.job_runs(
  id uuid primary key default gen_random_uuid(),
  job_name text not null check(job_name in('commitment_deadlines','notification_email')),
  status text not null check(status in('succeeded','failed','partial')),
  attempted_count integer not null default 0 check(attempted_count>=0),
  succeeded_count integer not null default 0 check(succeeded_count>=0),
  error_code text,
  correlation_id uuid not null,
  started_at timestamptz not null,
  finished_at timestamptz not null default now(),
  constraint job_result_consistent check(status='succeeded' or error_code is not null)
);
alter table public.job_runs enable row level security;

create table public.operational_failures(
  id uuid primary key default gen_random_uuid(),
  correlation_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  route text not null,
  operation text not null,
  error_code text not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint safe_metadata_object check(jsonb_typeof(safe_metadata)='object'),
  constraint operational_text_limits check(char_length(route)<=200 and char_length(operation)<=120 and char_length(error_code)<=120)
);
alter table public.operational_failures enable row level security;

create table public.backup_restore_drills(
  id uuid primary key default gen_random_uuid(),
  environment text not null check(environment in('development','staging','preview')),
  backup_started_at timestamptz not null,
  restored_at timestamptz not null,
  database_verified boolean not null,
  storage_inventory_verified boolean not null,
  legal_hashes_verified boolean not null,
  rls_verified boolean not null,
  rpo_minutes integer check(rpo_minutes is null or rpo_minutes>=0),
  rto_minutes integer check(rto_minutes is null or rto_minutes>=0),
  evidence_reference text not null,
  notes text,
  recorded_by uuid not null references auth.users(id) on delete restrict,
  recorded_at timestamptz not null default now(),
  constraint restore_after_backup check(restored_at>=backup_started_at)
);
alter table public.backup_restore_drills enable row level security;

create policy job_runs_admin_read on public.job_runs for select to authenticated using(private.has_permission('settings.manage'));
create policy operational_failures_admin_read on public.operational_failures for select to authenticated using(private.has_permission('settings.manage'));
create policy restore_drills_admin_read on public.backup_restore_drills for select to authenticated using(private.has_permission('settings.manage'));
grant select on public.job_runs,public.operational_failures,public.backup_restore_drills to authenticated;

create or replace function private.record_job_result(
  p_job_name text,p_status text,p_attempted integer,p_succeeded integer,p_error_code text,p_correlation_id uuid,p_started_at timestamptz
) returns uuid language plpgsql volatile security definer set search_path=''
as $$declare v_id uuid;begin
  insert into public.job_runs(job_name,status,attempted_count,succeeded_count,error_code,correlation_id,started_at)
  values(p_job_name,p_status,greatest(coalesce(p_attempted,0),0),greatest(coalesce(p_succeeded,0),0),nullif(p_error_code,''),p_correlation_id,p_started_at)
  returning id into v_id;return v_id;
end $$;
create or replace function public.record_job_result(
  p_job_name text,p_status text,p_attempted integer,p_succeeded integer,p_error_code text,p_correlation_id uuid,p_started_at timestamptz
) returns uuid language sql volatile security invoker set search_path=''
as $$select private.record_job_result(p_job_name,p_status,p_attempted,p_succeeded,p_error_code,p_correlation_id,p_started_at);$$;

create or replace function private.record_operational_failure(
  p_correlation_id uuid,p_route text,p_operation text,p_error_code text,p_safe_metadata jsonb default '{}'::jsonb,p_user_id uuid default null
) returns uuid language plpgsql volatile security definer set search_path=''
as $$declare v_id uuid;begin
  if p_safe_metadata ?| array['token','secret','authorization','password','raw_source_text','content','document'] then raise exception 'unsafe_log_metadata';end if;
  insert into public.operational_failures(correlation_id,user_id,route,operation,error_code,safe_metadata)
  values(p_correlation_id,p_user_id,btrim(p_route),btrim(p_operation),btrim(p_error_code),coalesce(p_safe_metadata,'{}'::jsonb)) returning id into v_id;
  return v_id;
end $$;
create or replace function public.record_operational_failure(
  p_correlation_id uuid,p_route text,p_operation text,p_error_code text,p_safe_metadata jsonb default '{}'::jsonb,p_user_id uuid default null
) returns uuid language sql volatile security invoker set search_path=''
as $$select private.record_operational_failure(p_correlation_id,p_route,p_operation,p_error_code,p_safe_metadata,p_user_id);$$;

create or replace function private.manage_security_incident(p_incident_id uuid,p_payload jsonb)
returns uuid language plpgsql volatile security definer set search_path=''
as $$declare v_id uuid:=p_incident_id;v_old jsonb;begin
  if not private.has_permission('settings.manage') then raise exception 'permission_denied';end if;
  if p_payload->>'severity' not in('low','medium','high','critical') or p_payload->>'status' not in('detected','contained','investigating','remediating','recovered','closed')
     or char_length(btrim(coalesce(p_payload->>'summary',''))) not between 10 and 1000 then raise exception 'invalid_incident';end if;
  if p_incident_id is null then
    insert into public.security_incidents(detected_at,occurred_at,severity,systems,summary,data_categories,containment,remediation,status,decision_notes,notifications_required,notification_decision,closed_at)
    values(coalesce(nullif(p_payload->>'detected_at','')::timestamptz,now()),nullif(p_payload->>'occurred_at','')::timestamptz,p_payload->>'severity',
      coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'systems','[]'::jsonb))),'{}'),btrim(p_payload->>'summary'),
      coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'data_categories','[]'::jsonb))),'{}'),nullif(p_payload->>'containment',''),nullif(p_payload->>'remediation',''),p_payload->>'status',nullif(p_payload->>'decision_notes',''),
      nullif(p_payload->>'notifications_required','')::boolean,nullif(p_payload->>'notification_decision',''),case when p_payload->>'status'='closed' then now() end)
    returning id into v_id;
  else
    select to_jsonb(i) into v_old from public.security_incidents i where i.id=p_incident_id for update;
    if v_old is null then raise exception 'incident_not_found';end if;
    update public.security_incidents set severity=p_payload->>'severity',systems=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'systems','[]'::jsonb))),'{}'),
      summary=btrim(p_payload->>'summary'),data_categories=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'data_categories','[]'::jsonb))),'{}'),
      containment=nullif(p_payload->>'containment',''),remediation=nullif(p_payload->>'remediation',''),status=p_payload->>'status',decision_notes=nullif(p_payload->>'decision_notes',''),
      notifications_required=nullif(p_payload->>'notifications_required','')::boolean,notification_decision=nullif(p_payload->>'notification_decision',''),
      closed_at=case when p_payload->>'status'='closed' then coalesce(closed_at,now()) else null end where id=p_incident_id;
  end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,old_values,new_values)
  values(auth.uid(),case when p_incident_id is null then 'security_incident.created' else 'security_incident.updated' end,'security_incident',v_id,v_old,p_payload-'summary'-'containment'-'remediation'-'decision_notes');
  return v_id;
end $$;
create or replace function public.manage_security_incident(p_incident_id uuid,p_payload jsonb)
returns uuid language sql volatile security invoker set search_path=''
as $$select private.manage_security_incident(p_incident_id,p_payload);$$;

create or replace function private.update_app_setting(p_key text,p_value jsonb,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$declare v_old jsonb;v_number numeric;begin
  if not private.has_permission('settings.manage') then raise exception 'permission_denied';end if;
  if char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'reason_required';end if;
  select value into v_old from public.app_settings where key=p_key for update;
  if v_old is null then raise exception 'unknown_setting';end if;
  if p_key in('min_public_aggregate_count','max_upload_bytes','rate_limit_reports_per_hour','rate_limit_uploads_per_hour','rate_limit_relations_per_hour') then
    if jsonb_typeof(p_value)<>'number' then raise exception 'numeric_setting_required';end if;v_number:=(p_value#>>'{}')::numeric;
    if (p_key='min_public_aggregate_count' and v_number not between 3 and 100)
       or (p_key='max_upload_bytes' and v_number not between 1048576 and 52428800)
       or (p_key like 'rate_limit_%' and v_number not between 1 and 10000) then raise exception 'setting_out_of_range';end if;
  end if;
  update public.app_settings set value=p_value,updated_by=auth.uid(),updated_at=now() where key=p_key;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,old_values,new_values,reason)
  values(auth.uid(),'app_setting.updated','app_setting',gen_random_uuid(),jsonb_build_object('key',p_key,'value',v_old),jsonb_build_object('key',p_key,'value',p_value),btrim(p_reason));
end $$;
create or replace function public.update_app_setting(p_key text,p_value jsonb,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$select private.update_app_setting(p_key,p_value,p_reason);$$;

create or replace function private.record_restore_drill(p_payload jsonb)
returns uuid language plpgsql volatile security definer set search_path=''
as $$declare v_id uuid;begin
  if not private.has_permission('settings.manage') then raise exception 'permission_denied';end if;
  if p_payload->>'environment' not in('development','staging','preview') then raise exception 'production_restore_drill_forbidden';end if;
  insert into public.backup_restore_drills(environment,backup_started_at,restored_at,database_verified,storage_inventory_verified,legal_hashes_verified,rls_verified,rpo_minutes,rto_minutes,evidence_reference,notes,recorded_by)
  values(p_payload->>'environment',(p_payload->>'backup_started_at')::timestamptz,(p_payload->>'restored_at')::timestamptz,coalesce((p_payload->>'database_verified')::boolean,false),
    coalesce((p_payload->>'storage_inventory_verified')::boolean,false),coalesce((p_payload->>'legal_hashes_verified')::boolean,false),coalesce((p_payload->>'rls_verified')::boolean,false),
    nullif(p_payload->>'rpo_minutes','')::integer,nullif(p_payload->>'rto_minutes','')::integer,p_payload->>'evidence_reference',nullif(p_payload->>'notes',''),auth.uid()) returning id into v_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values) values(auth.uid(),'restore_drill.recorded','backup_restore_drill',v_id,p_payload-'notes');return v_id;
end $$;
create or replace function public.record_restore_drill(p_payload jsonb)
returns uuid language sql volatile security invoker set search_path=''
as $$select private.record_restore_drill(p_payload);$$;

create or replace view public.admin_health_summary with(security_invoker=true) as
select
  (select count(*) from public.operational_failures where occurred_at>=now()-interval '7 days') recent_failures,
  (select count(*) from public.job_runs where status<>'succeeded' and finished_at>=now()-interval '7 days') failed_jobs,
  (select count(*) from public.attachments where upload_status='failed' and created_at>=now()-interval '7 days') failed_uploads,
  (select count(*) from public.notifications where email_state='failed' and created_at>=now()-interval '7 days') failed_emails,
  (select count(*) from public.security_incidents where status<>'closed') open_incidents,
  (select max(recorded_at) from public.backup_restore_drills where database_verified and rls_verified) last_verified_restore;
grant select on public.admin_health_summary to authenticated;

create or replace function private.community_kpi_summary(p_origin text default 'native')
returns jsonb language plpgsql stable security definer set search_path=''
as $$declare v_result jsonb;begin
  if p_origin not in('native','historical','all') then raise exception 'invalid_kpi_origin';end if;
  if auth.uid() is null then raise exception 'authentication_required';end if;
  with accessible_reports as(
    select r.id,r.issue_id,r.report_type_id,r.recorded_at,r.declared_recurrence,r.status_definition_id
      from public.reports r where r.archived_at is null and r.hidden_at is null and r.visibility='community'
       and (p_origin='all' or r.source_origin::text=p_origin) and private.can_access_report(r.id)
  ), accessible_issues as(select distinct issue_id from accessible_reports),
  first_known as(select r.id,min(p.occurred_at) first_at from accessible_reports r join public.responses p on p.report_id=r.id and p.hidden_at is null group by r.id),
  first_official as(select r.id,min(p.occurred_at) first_at from accessible_reports r join public.responses p on p.report_id=r.id and p.response_type='official' and p.hidden_at is null group by r.id),
  resolved_issues as(select a.issue_id,min(t.recorded_at) resolved_at from accessible_issues a join public.timeline_events t on t.issue_id=a.issue_id and t.event_type='issue.status_derived' and t.metadata->>'to'='resolved' group by a.issue_id),
  base as(select
    (select count(*) from accessible_reports) reports_count,(select count(*) from accessible_issues) issues_count,
    (select count(*) from accessible_issues a join public.issues i on i.id=a.issue_id where i.derived_status='active') active_count,
    (select count(*) from accessible_issues a join public.issues i on i.id=a.issue_id where i.created_at>=now()-interval '30 days') new_count,
    (select count(*) from accessible_issues a join public.issues i on i.id=a.issue_id where i.derived_status='resolved') resolved_count,
    (select count(*) from accessible_reports r join public.report_status_definitions d on d.id=r.status_definition_id where d.slug='partially_resolved') partially_resolved_count,
    (select count(*) from accessible_reports r where not exists(select 1 from public.responses p where p.report_id=r.id and p.hidden_at is null)) no_response_count,
    (select count(*) from first_known) first_known_sample,
    (select percentile_cont(.5) within group(order by extract(epoch from(f.first_at-r.recorded_at))/3600) from first_known f join accessible_reports r on r.id=f.id) median_known,
    (select count(*) from first_official) first_official_sample,
    (select percentile_cont(.5) within group(order by extract(epoch from(f.first_at-r.recorded_at))/3600) from first_official f join accessible_reports r on r.id=f.id) median_official,
    (select count(*) from resolved_issues) resolution_sample,
    (select percentile_cont(.5) within group(order by extract(epoch from(x.resolved_at-i.created_at))/3600) from resolved_issues x join public.issues i on i.id=x.issue_id) median_resolution,
    (select count(*) from public.commitments c join accessible_reports r on r.id=c.report_id where c.status='fulfilled_on_time') commitments_on_time,
    (select count(*) from public.commitments c join accessible_reports r on r.id=c.report_id where c.status='fulfilled_late') commitments_late,
    (select count(*) from public.commitments c join accessible_reports r on r.id=c.report_id where c.status in('active','awaiting_confirmation')) commitments_active,
    (select count(*) from public.commitments c join accessible_reports r on r.id=c.report_id where c.status='overdue') commitments_overdue,
    (select count(*) from accessible_reports where declared_recurrence) recurrence_count,
    (select count(*) from accessible_reports r join public.official_status_current o on o.report_id=r.id left join public.report_status_definitions s on s.id=r.status_definition_id where o.status in('service_reported_completed','closed_by_management') and coalesce(s.is_terminal,false)=false) divergent_count,
    (select count(*) from accessible_reports r join public.report_types t on t.id=r.report_type_id where t.slug='information_request' and not exists(select 1 from public.responses p where p.report_id=r.id and p.hidden_at is null)) information_count,
    (select count(distinct a.user_id) from public.issue_affected_users a join accessible_issues i on i.issue_id=a.issue_id) affected_people,
    (select count(distinct a.unit_id_snapshot) from public.issue_affected_users a join accessible_issues i on i.issue_id=a.issue_id) affected_units,
    (select count(distinct a.block_id_snapshot) from public.issue_affected_users a join accessible_issues i on i.issue_id=a.issue_id) affected_blocks
  )
  select jsonb_build_object(
    'reports_count',private.suppress_small_count(reports_count),'issues_count',private.suppress_small_count(issues_count),
    'active_issues_count',private.suppress_small_count(active_count),'new_issues_30d_count',private.suppress_small_count(new_count),'resolved_issues_count',private.suppress_small_count(resolved_count),
    'partially_resolved_count',private.suppress_small_count(partially_resolved_count),
    'no_response_count',private.suppress_small_count(no_response_count),'median_first_known_hours',case when first_known_sample>=private.min_aggregate_count() then median_known end,
    'median_first_official_hours',case when first_official_sample>=private.min_aggregate_count() then median_official end,
    'median_resolution_hours',case when resolution_sample>=private.min_aggregate_count() then median_resolution end,
    'commitments_on_time',private.suppress_small_count(commitments_on_time),'commitments_late',private.suppress_small_count(commitments_late),
    'commitments_active',private.suppress_small_count(commitments_active),'commitments_overdue',private.suppress_small_count(commitments_overdue),
    'declared_recurrence_count',private.suppress_small_count(recurrence_count),'divergent_status_count',private.suppress_small_count(divergent_count),
    'information_without_response_count',private.suppress_small_count(information_count),'affected_people_count',private.suppress_small_count(affected_people),
    'affected_unit_count',private.suppress_small_count(affected_units),'affected_block_count',private.suppress_small_count(affected_blocks),
    'minimum_group_size',private.min_aggregate_count(),'origin',p_origin
  ) into v_result from base;return v_result;
end $$;
create or replace function public.community_kpi_summary(p_origin text default 'native')
returns jsonb language sql stable security invoker set search_path=''
as $$select private.community_kpi_summary(p_origin);$$;

revoke all on function public.record_job_result(text,text,integer,integer,text,uuid,timestamptz),public.record_operational_failure(uuid,text,text,text,jsonb,uuid),public.manage_security_incident(uuid,jsonb),public.update_app_setting(text,jsonb,text),public.record_restore_drill(jsonb),public.community_kpi_summary(text) from public,anon,authenticated;
grant execute on function public.record_job_result(text,text,integer,integer,text,uuid,timestamptz),public.record_operational_failure(uuid,text,text,text,jsonb,uuid) to service_role;
grant execute on function public.manage_security_incident(uuid,jsonb),public.update_app_setting(text,jsonb,text),public.record_restore_drill(jsonb) to authenticated;
grant execute on function public.community_kpi_summary(text),private.community_kpi_summary(text) to authenticated;
grant execute on function private.record_job_result(text,text,integer,integer,text,uuid,timestamptz),private.record_operational_failure(uuid,text,text,text,jsonb,uuid) to service_role;
grant usage on schema private to service_role;
grant execute on function private.manage_security_incident(uuid,jsonb),private.update_app_setting(text,jsonb,text),private.record_restore_drill(jsonb) to authenticated;
revoke all on all functions in schema private from public,anon;
