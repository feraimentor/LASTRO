-- M5: privacy-aware reference KPIs, notification service queue and email outbox.

alter table public.notifications add column dedupe_key text;
create unique index notifications_dedupe_unique on public.notifications(dedupe_key) where dedupe_key is not null;

create or replace function private.min_aggregate_count()
returns integer language sql stable security definer set search_path=''
as $$ select coalesce((select (value#>>'{}')::integer from public.app_settings where key='min_public_aggregate_count'),3); $$;

create or replace function private.suppress_small_count(p_value bigint)
returns bigint language sql stable security definer set search_path=''
as $$ select case when p_value>=private.min_aggregate_count() then p_value else null end; $$;

create or replace view public.community_kpis with(security_invoker=true) as
with accessible_reports as(
  select r.id,r.issue_id,r.report_type_id,r.recorded_at,r.declared_recurrence,r.status_definition_id
  from public.reports r where r.source_origin='native' and r.archived_at is null
), first_known as(
  select r.id,min(p.occurred_at) as first_at from accessible_reports r join public.responses p on p.report_id=r.id and p.hidden_at is null group by r.id
), first_official as(
  select r.id,min(p.occurred_at) as first_at from accessible_reports r join public.responses p on p.report_id=r.id and p.response_type='official' and p.hidden_at is null group by r.id
), resolved_issues as(
  select i.id,min(t.recorded_at) as resolved_at from public.issues i join public.timeline_events t on t.issue_id=i.id and t.event_type='issue.status_derived' and t.metadata->>'to'='resolved' where i.source_origin='native' group by i.id
), base as(
select
  (select count(*) from accessible_reports) as reports_count,
  (select count(distinct issue_id) from accessible_reports) as issues_count,
  (select count(*) from public.issues i where i.source_origin='native' and i.archived_at is null and i.derived_status='active') as active_issues_count,
  (select count(*) from public.issues i where i.source_origin='native' and i.created_at>=now()-interval '30 days') as new_issues_30d_count,
  (select count(*) from public.issues i where i.source_origin='native' and i.derived_status='resolved') as resolved_issues_count,
  (select count(*) from accessible_reports r where not exists(select 1 from public.responses p where p.report_id=r.id and p.hidden_at is null)) as no_response_count,
  (select count(*) from first_known) as first_known_sample,
  (select percentile_cont(0.5) within group(order by extract(epoch from(f.first_at-r.recorded_at))/3600) from first_known f join accessible_reports r on r.id=f.id) as median_first_known_hours,
  (select count(*) from first_official) as first_official_sample,
  (select percentile_cont(0.5) within group(order by extract(epoch from(f.first_at-r.recorded_at))/3600) from first_official f join accessible_reports r on r.id=f.id) as median_first_official_hours,
  (select count(*) from resolved_issues) as resolution_sample,
  (select percentile_cont(0.5) within group(order by extract(epoch from(x.resolved_at-i.created_at))/3600) from resolved_issues x join public.issues i on i.id=x.id) as median_resolution_hours,
  (select count(*) from public.commitments c where c.status='fulfilled_on_time') as commitments_on_time,
  (select count(*) from public.commitments c where c.status='fulfilled_late') as commitments_late,
  (select count(*) from public.commitments c where c.status in('active','awaiting_confirmation')) as commitments_active,
  (select count(*) from public.commitments c where c.status='overdue') as commitments_overdue,
  (select count(*) from accessible_reports where declared_recurrence) as declared_recurrence_count,
  (select count(*) from accessible_reports r join public.official_status_current o on o.report_id=r.id left join public.report_status_definitions s on s.id=r.status_definition_id where o.status in('service_reported_completed','closed_by_management') and coalesce(s.is_terminal,false)=false) as divergent_status_count,
  (select count(*) from accessible_reports r join public.report_types t on t.id=r.report_type_id where t.slug='information_request' and not exists(select 1 from public.responses p where p.report_id=r.id and p.hidden_at is null)) as information_without_response_count
)
select
  private.suppress_small_count(reports_count) reports_count,
  private.suppress_small_count(issues_count) issues_count,
  private.suppress_small_count(active_issues_count) active_issues_count,
  private.suppress_small_count(new_issues_30d_count) new_issues_30d_count,
  private.suppress_small_count(resolved_issues_count) resolved_issues_count,
  private.suppress_small_count(no_response_count) no_response_count,
  case when first_known_sample>=private.min_aggregate_count() then median_first_known_hours end median_first_known_hours,
  case when first_official_sample>=private.min_aggregate_count() then median_first_official_hours end median_first_official_hours,
  case when resolution_sample>=private.min_aggregate_count() then median_resolution_hours end median_resolution_hours,
  private.suppress_small_count(commitments_on_time) commitments_on_time,
  private.suppress_small_count(commitments_late) commitments_late,
  private.suppress_small_count(commitments_active) commitments_active,
  private.suppress_small_count(commitments_overdue) commitments_overdue,
  private.suppress_small_count(declared_recurrence_count) declared_recurrence_count,
  private.suppress_small_count(divergent_status_count) divergent_status_count,
  private.suppress_small_count(information_without_response_count) information_without_response_count,
  first_known_sample,first_official_sample,resolution_sample,private.min_aggregate_count() minimum_group_size
from base;

create or replace view public.report_aging with(security_invoker=true) as
select r.id as report_id,r.recorded_at,
  extract(day from now()-r.recorded_at)::integer as age_days,
  case when now()-r.recorded_at<=interval '7 days' then 'até 7 dias'
       when now()-r.recorded_at<=interval '30 days' then '8–30'
       when now()-r.recorded_at<=interval '90 days' then '31–90'
       when now()-r.recorded_at<=interval '180 days' then '91–180'
       when now()-r.recorded_at<=interval '1 year' then '>180' else '>1 ano' end aging_bucket,
  r.source_origin
from public.reports r where r.archived_at is null;

create or replace function public.kpi_drilldown(p_metric text,p_origin text default 'native',p_limit integer default 50)
returns table(id uuid,protocol text,issue_id uuid,title text,description text,urgency text,recorded_at timestamptz,author_label text,source_origin public.source_origin)
language sql stable security invoker set search_path=''
as $$
  select c.id,c.protocol,c.issue_id,c.title,c.description,c.urgency,c.recorded_at,c.author_label,c.source_origin
  from public.community_reports c join public.reports r on r.id=c.id join public.issues i on i.id=c.issue_id
  where (p_origin='all' or c.source_origin::text=p_origin)
    and case p_metric
      when 'active' then i.derived_status='active'
      when 'resolved' then i.derived_status='resolved'
      when 'no_response' then not exists(select 1 from public.responses x where x.report_id=c.id and x.hidden_at is null)
      when 'recurrence' then r.declared_recurrence
      when 'divergent' then exists(select 1 from public.official_status_current o left join public.report_status_definitions s on s.id=r.status_definition_id where o.report_id=r.id and o.status in('service_reported_completed','closed_by_management') and coalesce(s.is_terminal,false)=false)
      when 'information_without_response' then exists(select 1 from public.report_types t where t.id=r.report_type_id and t.slug='information_request') and not exists(select 1 from public.responses x where x.report_id=r.id and x.hidden_at is null)
      else true end
  order by c.recorded_at desc limit least(greatest(p_limit,1),100);
$$;

create or replace function private.enqueue_notification(
  p_user_id uuid,p_kind text,p_title text,p_body text,p_target_path text,p_essential boolean,p_dedupe_key text
)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare v_pref public.notification_preferences%rowtype; v_enabled boolean:=true; v_id uuid;
begin
  select * into v_pref from public.notification_preferences where user_id=p_user_id;
  if not p_essential and v_pref.user_id is not null then
    v_enabled:=case
      when p_kind like 'report.%' then v_pref.own_reports
      when p_kind like 'issue.followed.%' then v_pref.followed_issues
      when p_kind like 'response.%' then v_pref.responses
      when p_kind like 'commitment.%' then v_pref.commitments
      else true end;
  end if;
  if not v_enabled then return null; end if;
  insert into public.notifications(user_id,kind,title,body,target_path,essential,email_state,dedupe_key)
  values(p_user_id,p_kind,p_title,p_body,p_target_path,p_essential,
         case when p_essential or coalesce(v_pref.email_enabled,true) then 'requested' else 'not_requested' end,p_dedupe_key)
  on conflict(dedupe_key) where dedupe_key is not null do nothing returning id into v_id;
  return v_id;
end;
$$;

create or replace function private.notify_response_created()
returns trigger language plpgsql volatile security definer set search_path=''
as $$ declare v_author uuid; v_issue uuid; v_user uuid; begin
  select author_user_id,issue_id into v_author,v_issue from public.reports where id=new.report_id;
  if v_author is not null and v_author<>new.recorded_by then perform private.enqueue_notification(v_author,'response.created','Novo retorno no seu relato','Um retorno foi registrado. Consulte a trilha para contexto e autoria.','/demandas/'||new.report_id,false,'response:'||new.id||':user:'||v_author);end if;
  for v_user in select user_id from public.issue_followers where issue_id=v_issue and user_id<>new.recorded_by and user_id is distinct from v_author loop
    perform private.enqueue_notification(v_user,'issue.followed.response','Atualização em problema acompanhado','Um novo retorno foi registrado em um problema que você acompanha.','/demandas/'||new.report_id,false,'response:'||new.id||':user:'||v_user);
  end loop;
  return new;
end $$;
create trigger responses_notify after insert on public.responses for each row execute function private.notify_response_created();

create or replace function private.notify_commitment_change()
returns trigger language plpgsql volatile security definer set search_path=''
as $$ declare v_report uuid:=new.report_id;v_author uuid;begin
  if v_report is null and new.issue_id is not null then select id into v_report from public.reports where issue_id=new.issue_id order by recorded_at limit 1;end if;
  select author_user_id into v_author from public.reports where id=v_report;
  if v_author is not null and v_author<>new.recorded_by then perform private.enqueue_notification(v_author,'commitment.'||new.status,'Compromisso atualizado','O estado ou prazo de um compromisso associado foi atualizado.','/demandas/'||v_report,false,'commitment:'||new.id||':status:'||new.status||':user:'||v_author);end if;
  return new;
end $$;
create trigger commitments_notify after insert or update of status,current_due_at on public.commitments for each row execute function private.notify_commitment_change();

create or replace function private.notify_moderation_created()
returns trigger language plpgsql volatile security definer set search_path=''
as $$ declare v_user uuid;v_report uuid;begin
  if new.target_type='report' then select author_user_id,id into v_user,v_report from public.reports where id=new.target_id;
  elsif new.target_type='response' then select recorded_by,report_id into v_user,v_report from public.responses where id=new.target_id;
  elsif new.target_type='attachment' then select uploader_user_id,report_id into v_user,v_report from public.attachments where id=new.target_id;end if;
  if v_user is not null then perform private.enqueue_notification(v_user,'moderation.own_content','Moderação em conteúdo próprio','Uma ação de moderação foi registrada e pode ser revisada conforme as regras.','/demandas/'||v_report,true,'moderation:'||new.id||':user:'||v_user);end if;return new;
end $$;
create trigger moderation_notify after insert on public.moderation_actions for each row execute function private.notify_moderation_created();

create or replace function private.notify_privacy_decision()
returns trigger language plpgsql volatile security definer set search_path=''
as $$ begin if old.state is distinct from new.state and new.state in('completed','partially_completed','denied') then perform private.enqueue_notification(new.user_id,'privacy.decision','Sua solicitação de privacidade foi decidida','A decisão está disponível na área de privacidade.','/perfil/privacidade',true,'privacy:'||new.id||':decision');end if;return new;end $$;
create trigger privacy_decision_notify after update of state on public.privacy_requests for each row execute function private.notify_privacy_decision();

create or replace function private.notify_verification_decision()
returns trigger language plpgsql volatile security definer set search_path=''
as $$ begin if old.state is distinct from new.state and new.state in('approved','rejected','needs_information') then perform private.enqueue_notification(new.user_id,'verification.'||new.state,'Atualização na verificação do vínculo','A situação da sua verificação condominial foi atualizada.','/onboarding/pending',true,'verification:'||new.id||':state:'||new.state);end if;return new;end $$;
create trigger verification_decision_notify after update of state on public.verification_requests for each row execute function private.notify_verification_decision();

create or replace function private.update_notification_preferences(p_preferences jsonb)
returns void language plpgsql volatile security definer set search_path=''
as $$ begin
  insert into public.notification_preferences(user_id,own_reports,followed_issues,block_issues,responses,commitments,periodic_digest,email_enabled)
  values(auth.uid(),coalesce((p_preferences->>'own_reports')::boolean,true),coalesce((p_preferences->>'followed_issues')::boolean,true),coalesce((p_preferences->>'block_issues')::boolean,false),coalesce((p_preferences->>'responses')::boolean,true),coalesce((p_preferences->>'commitments')::boolean,true),coalesce((p_preferences->>'periodic_digest')::boolean,false),coalesce((p_preferences->>'email_enabled')::boolean,true))
  on conflict(user_id) do update set own_reports=excluded.own_reports,followed_issues=excluded.followed_issues,block_issues=excluded.block_issues,responses=excluded.responses,commitments=excluded.commitments,periodic_digest=excluded.periodic_digest,email_enabled=excluded.email_enabled,updated_at=now();
end $$;
create or replace function public.update_notification_preferences(p_preferences jsonb)
returns void language sql volatile security invoker set search_path=''
as $$ select private.update_notification_preferences(p_preferences); $$;

create or replace function private.mark_notification_read(p_notification_id uuid)
returns void language sql volatile security definer set search_path=''
as $$ update public.notifications set read_at=coalesce(read_at,now()) where id=p_notification_id and user_id=auth.uid(); $$;
create or replace function public.mark_notification_read(p_notification_id uuid)
returns void language sql volatile security invoker set search_path=''
as $$ select private.mark_notification_read(p_notification_id); $$;

create or replace function private.claim_notification_emails(p_limit integer default 25)
returns table(notification_id uuid,email text,subject text,body text,target_path text)
language plpgsql volatile security definer set search_path=''
as $$
begin
  return query with claimed as(
    select n.id from public.notifications n where n.email_state='requested' order by n.created_at for update skip locked limit least(greatest(p_limit,1),100)
  ),updated as(
    update public.notifications n set email_state='sending' from claimed c where n.id=c.id returning n.*
  ) select u.id,p.google_email,u.title,u.body,u.target_path from updated u join private.user_private_data p on p.user_id=u.user_id;
end $$;
create or replace function public.claim_notification_emails(p_limit integer default 25)
returns table(notification_id uuid,email text,subject text,body text,target_path text)
language sql volatile security invoker set search_path=''
as $$ select * from private.claim_notification_emails(p_limit); $$;

create or replace function private.complete_notification_email(p_notification_id uuid,p_success boolean)
returns void language sql volatile security definer set search_path=''
as $$ update public.notifications set email_state=case when p_success then 'sent' else 'failed' end where id=p_notification_id and email_state='sending'; $$;
create or replace function public.complete_notification_email(p_notification_id uuid,p_success boolean)
returns void language sql volatile security invoker set search_path=''
as $$ select private.complete_notification_email(p_notification_id,p_success); $$;

revoke update on public.notifications from authenticated;
grant select on public.community_kpis to authenticated;
revoke all on function public.kpi_drilldown(text,text,integer),public.update_notification_preferences(jsonb),public.mark_notification_read(uuid),public.claim_notification_emails(integer),public.complete_notification_email(uuid,boolean) from public,anon,authenticated;
grant execute on function public.kpi_drilldown(text,text,integer),public.update_notification_preferences(jsonb),public.mark_notification_read(uuid) to authenticated;
grant execute on function public.claim_notification_emails(integer),public.complete_notification_email(uuid,boolean) to service_role;
grant execute on function private.min_aggregate_count(),private.suppress_small_count(bigint),private.enqueue_notification(uuid,text,text,text,text,boolean,text),private.update_notification_preferences(jsonb),private.mark_notification_read(uuid) to authenticated;
grant execute on function private.claim_notification_emails(integer),private.complete_notification_email(uuid,boolean) to service_role;
revoke all on all functions in schema private from public,anon;
