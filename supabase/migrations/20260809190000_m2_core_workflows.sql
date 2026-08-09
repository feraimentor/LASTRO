-- M2: safe full-text search, configurable locations, issue relationships and derived status.

create or replace function private.can_access_issue(p_issue_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and (
    private.has_permission_for_user('sensitive_content.view',auth.uid())
    or (
      private.is_verified_resident_for_user(auth.uid())
      and private.has_current_legal_acceptances_for_user(auth.uid())
      and exists(
        select 1 from public.issues i
         where i.id=p_issue_id and i.archived_at is null
           and exists(select 1 from public.reports r where r.issue_id=i.id and r.visibility='community' and r.hidden_at is null and r.archived_at is null)
      )
    )
    or exists(select 1 from public.reports r where r.issue_id=p_issue_id and private.can_access_report(r.id))
  );
$$;

create or replace function private.community_author_label(p_report_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
declare v_mode public.identity_mode; v_author uuid; v_name text; v_block text;
begin
  if not private.can_access_report(p_report_id) then return null; end if;
  select identity_mode,author_user_id into v_mode,v_author from public.reports
   where id=p_report_id and visibility='community' and hidden_at is null and archived_at is null;
  if v_author is null then return 'Registro histórico'; end if;
  if v_mode='identified' then
    select nullif(btrim(display_name),'') into v_name from public.profiles where id=v_author;
    return coalesce(v_name,'Usuário condominial verificado');
  end if;
  if v_mode='protected_with_block' then
    select b.label into v_block
      from public.resident_unit_links l
      join public.condo_units u on u.id=l.unit_id
      join public.blocks b on b.id=u.block_id
     where l.user_id=v_author and l.verification_status='approved'
     order by (l.ended_at is null) desc,l.created_at desc limit 1;
    return 'Usuário condominial verificado' || case when v_block is null then '' else ' — '||v_block end;
  end if;
  return 'Usuário condominial verificado';
end;
$$;

create or replace view public.community_reports with (security_invoker=true) as
select
  r.id,r.protocol,r.issue_id,r.report_type_id,r.category_id,r.subcategory_id,
  r.title,r.description,r.occurred_at,r.recorded_at,r.urgency,r.scope,
  r.sensitivity,r.identity_mode,r.source_origin,r.historical_outcome,
  private.community_author_label(r.id) as author_label,
  r.search_vector
from public.reports r
where r.visibility='community' and r.hidden_at is null and r.archived_at is null;

create or replace function public.search_community_reports(p_query text,p_limit integer default 30)
returns table(
  id uuid,protocol text,issue_id uuid,title text,description text,urgency text,
  recorded_at timestamptz,author_label text,source_origin public.source_origin,rank real
)
language sql stable security invoker
set search_path = ''
as $$
  select c.id,c.protocol,c.issue_id,c.title,c.description,c.urgency,c.recorded_at,
         c.author_label,c.source_origin,
         ts_rank(c.search_vector,websearch_to_tsquery('portuguese',btrim(p_query))) as rank
    from public.community_reports c
   where char_length(btrim(p_query)) between 2 and 120
     and c.search_vector @@ websearch_to_tsquery('portuguese',btrim(p_query))
   order by rank desc,c.recorded_at desc
   limit least(greatest(p_limit,1),50);
$$;

create or replace function private.set_issue_affected(
  p_issue_id uuid,p_affected boolean,p_unit_id uuid default null
)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid(); v_unit uuid; v_block smallint;
begin
  if not private.can_access_issue(p_issue_id) then raise exception 'issue_access_required'; end if;
  perform private.enforce_rate_limit('issue.affected',60);
  if p_affected then
    if p_unit_id is not null then
      select l.unit_id,u.block_id into v_unit,v_block
        from public.resident_unit_links l join public.condo_units u on u.id=l.unit_id
       where l.user_id=v_user and l.unit_id=p_unit_id and l.verification_status='approved' and l.ended_at is null;
      if v_unit is null then raise exception 'active_user_unit_required'; end if;
    else
      if (select count(*) from public.resident_unit_links l where l.user_id=v_user and l.verification_status='approved' and l.ended_at is null)>1 then
        raise exception 'unit_selection_required';
      end if;
      select l.unit_id,u.block_id into v_unit,v_block
        from public.resident_unit_links l join public.condo_units u on u.id=l.unit_id
       where l.user_id=v_user and l.verification_status='approved' and l.ended_at is null limit 1;
    end if;
    insert into public.issue_affected_users(issue_id,user_id,unit_id_snapshot,block_id_snapshot)
    values(p_issue_id,v_user,v_unit,v_block) on conflict(issue_id,user_id) do nothing;
    insert into public.timeline_events(issue_id,actor_user_id,event_type,entity_type,entity_id,display_text)
    values(p_issue_id,v_user,'issue.affected_added','issue',p_issue_id,'Uma pessoa declarou-se afetada');
  else
    delete from public.issue_affected_users where issue_id=p_issue_id and user_id=v_user;
    if found then
      insert into public.timeline_events(issue_id,actor_user_id,event_type,entity_type,entity_id,display_text)
      values(p_issue_id,v_user,'issue.affected_removed','issue',p_issue_id,'Uma pessoa retirou a declaração de afetada');
    end if;
  end if;
end;
$$;

create or replace function public.set_issue_affected(
  p_issue_id uuid,p_affected boolean,p_unit_id uuid default null
)
returns void language sql volatile security invoker set search_path=''
as $$ select private.set_issue_affected(p_issue_id,p_affected,p_unit_id); $$;

create or replace function private.set_issue_following(p_issue_id uuid,p_following boolean)
returns void
language plpgsql volatile security definer
set search_path=''
as $$
declare v_user uuid:=auth.uid();
begin
  if not private.can_access_issue(p_issue_id) then raise exception 'issue_access_required'; end if;
  perform private.enforce_rate_limit('issue.follow',60);
  if p_following then
    insert into public.issue_followers(issue_id,user_id) values(p_issue_id,v_user) on conflict do nothing;
  else
    delete from public.issue_followers where issue_id=p_issue_id and user_id=v_user;
  end if;
end;
$$;

create or replace function public.set_issue_following(p_issue_id uuid,p_following boolean)
returns void language sql volatile security invoker set search_path=''
as $$ select private.set_issue_following(p_issue_id,p_following); $$;

create or replace function private.current_issue_relationships(p_issue_id uuid)
returns table(is_affected boolean,is_following boolean)
language sql stable security definer
set search_path=''
as $$
  select
    private.can_access_issue(p_issue_id) and exists(
      select 1 from public.issue_affected_users a where a.issue_id=p_issue_id and a.user_id=auth.uid()
    ),
    private.can_access_issue(p_issue_id) and exists(
      select 1 from public.issue_followers f where f.issue_id=p_issue_id and f.user_id=auth.uid()
    );
$$;

create or replace function public.current_issue_relationships(p_issue_id uuid)
returns table(is_affected boolean,is_following boolean)
language sql stable security invoker set search_path=''
as $$ select * from private.current_issue_relationships(p_issue_id); $$;

create or replace function private.issue_affected_counts(p_issue_id uuid)
returns jsonb
language sql stable security definer
set search_path=''
as $$
  select case when private.can_access_issue(p_issue_id) then jsonb_build_object(
    'people',count(distinct a.user_id),'units',count(distinct a.unit_id_snapshot),'blocks',count(distinct a.block_id_snapshot)
  ) else '{}'::jsonb end
  from public.issue_affected_users a where a.issue_id=p_issue_id;
$$;

create or replace view public.issue_metrics with (security_invoker=true) as
select i.id as issue_id,
  count(distinct r.id) as report_count,
  coalesce((private.issue_affected_counts(i.id)->>'people')::bigint,0) as affected_people_count,
  coalesce((private.issue_affected_counts(i.id)->>'units')::bigint,0) as affected_unit_count,
  coalesce((private.issue_affected_counts(i.id)->>'blocks')::bigint,0) as affected_block_count,
  min(r.recorded_at) as first_recorded_at,max(r.recorded_at) as last_recorded_at
from public.issues i
left join public.reports r on r.issue_id=i.id and r.archived_at is null
group by i.id;

create or replace function private.recalculate_issue_status(p_issue_id uuid)
returns text
language plpgsql volatile security definer
set search_path=''
as $$
declare v_status text; v_old text;
begin
  select derived_status into v_old from public.issues where id=p_issue_id for update;
  if v_old is null then return null; end if;
  if exists(select 1 from public.issues i where i.id=p_issue_id and i.archived_at is not null) then
    v_status:='archived';
  elsif exists(select 1 from public.reports r where r.issue_id=p_issue_id and r.archived_at is null)
    and not exists(select 1 from public.reports r where r.issue_id=p_issue_id and r.archived_at is null and r.source_origin='native') then
    v_status:='historical_only';
  elsif exists(select 1 from public.commitments c where (c.issue_id=p_issue_id or c.report_id in(select id from public.reports where issue_id=p_issue_id)) and c.status in('active','overdue','awaiting_confirmation')) then
    v_status:='active';
  elsif exists(
    select 1 from public.reports r left join public.report_status_definitions s on s.id=r.status_definition_id
     where r.issue_id=p_issue_id and r.archived_at is null and coalesce(s.is_terminal,false)=false and coalesce(s.slug,'')<>'monitoring'
  ) then v_status:='active';
  elsif exists(
    select 1 from public.reports r join public.report_status_definitions s on s.id=r.status_definition_id
     where r.issue_id=p_issue_id and r.archived_at is null and not s.is_terminal and s.slug='monitoring'
  ) then v_status:='monitoring';
  elsif exists(select 1 from public.reports r where r.issue_id=p_issue_id and r.archived_at is null) then
    v_status:='resolved';
  else v_status:='active';
  end if;
  if v_status<>v_old then
    update public.issues set derived_status=v_status where id=p_issue_id;
    insert into public.timeline_events(issue_id,event_type,entity_type,entity_id,display_text,metadata)
    values(p_issue_id,'issue.status_derived','issue',p_issue_id,'Estado coletivo recalculado',jsonb_build_object('from',v_old,'to',v_status));
  end if;
  return v_status;
end;
$$;

create or replace function private.recalculate_issue_from_report()
returns trigger language plpgsql volatile security definer set search_path='' as $$
begin
  perform private.recalculate_issue_status(new.issue_id);
  if tg_op='UPDATE' and old.issue_id<>new.issue_id then perform private.recalculate_issue_status(old.issue_id); end if;
  return new;
end;
$$;
create trigger reports_recalculate_issue after insert or update of status_definition_id,issue_id,archived_at,source_origin,historical_outcome
on public.reports for each row execute function private.recalculate_issue_from_report();

create or replace function private.recalculate_issue_from_commitment()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_issue uuid;
begin
  v_issue:=coalesce(new.issue_id,(select issue_id from public.reports where id=new.report_id));
  if v_issue is not null then perform private.recalculate_issue_status(v_issue); end if;
  return new;
end;
$$;
create trigger commitments_recalculate_issue after insert or update of status,current_due_at,fulfilled_at
on public.commitments for each row execute function private.recalculate_issue_from_commitment();

create or replace function private.set_report_status(p_report_id uuid,p_status_slug text,p_reason text)
returns void
language plpgsql volatile security definer
set search_path=''
as $$
declare v_report public.reports%rowtype; v_status uuid; v_old text;
begin
  select * into v_report from public.reports where id=p_report_id for update;
  if v_report.id is null or v_report.author_user_id<>auth.uid() then raise exception 'report_author_required'; end if;
  if char_length(btrim(coalesce(p_reason,'')))<3 then raise exception 'reason_required'; end if;
  select id into v_status from public.report_status_definitions
   where report_type_id=v_report.report_type_id and slug=p_status_slug;
  if v_status is null then raise exception 'invalid_report_status'; end if;
  select slug into v_old from public.report_status_definitions where id=v_report.status_definition_id;
  update public.reports set status_definition_id=v_status where id=p_report_id;
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,display_text,metadata)
  values(v_report.issue_id,p_report_id,auth.uid(),'report.status_changed','report',p_report_id,
         'Morador atualizou o estado do próprio relato',jsonb_build_object('from',v_old,'to',p_status_slug,'reason',btrim(p_reason)));
end;
$$;

create or replace function public.set_report_status(p_report_id uuid,p_status_slug text,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.set_report_status(p_report_id,p_status_slug,p_reason); $$;

drop policy if exists affected_self_insert on public.issue_affected_users;
drop policy if exists affected_self_delete on public.issue_affected_users;
drop policy if exists affected_read on public.issue_affected_users;
drop policy if exists followers_self_insert on public.issue_followers;
drop policy if exists followers_self_delete on public.issue_followers;
drop policy if exists followers_read on public.issue_followers;
revoke all on public.issue_affected_users,public.issue_followers from authenticated;
create policy affected_self_read on public.issue_affected_users for select to authenticated
using(user_id=auth.uid());
create policy followers_self_read on public.issue_followers for select to authenticated
using(user_id=auth.uid());
grant select on public.issue_affected_users,public.issue_followers to authenticated;

grant select(search_vector) on public.reports to authenticated;
grant select on public.community_reports,public.issue_metrics to authenticated;
revoke all on all functions in schema public from public,anon,authenticated;
grant execute on function public.next_report_protocol(public.source_origin,timestamptz),public.create_report(jsonb),
  public.current_user_has_permission(text),public.accept_current_legal_documents(),
  public.review_verification_request(uuid,text,text),public.create_condo_unit(smallint,text),
  public.current_session_is_recent(),public.save_profile(text,text,text,public.identity_mode,text,boolean,text),
  public.submit_verification_request(smallint,uuid,text,boolean),public.end_resident_link(uuid,text),
  public.set_user_suspension(uuid,boolean,text),public.set_user_role(uuid,text,text,text),
  public.set_permission_override(uuid,text,text,text),public.create_legal_draft(text,text,text,text,boolean,text),
  public.publish_legal_version(uuid,timestamptz,text),public.search_community_reports(text,integer),
  public.set_issue_affected(uuid,boolean,uuid),public.set_issue_following(uuid,boolean),
  public.current_issue_relationships(uuid),public.set_report_status(uuid,text,text) to authenticated;

grant execute on function private.can_access_issue(uuid),private.community_author_label(uuid),
  private.set_issue_affected(uuid,boolean,uuid),private.set_issue_following(uuid,boolean),
  private.current_issue_relationships(uuid),private.issue_affected_counts(uuid),
  private.set_report_status(uuid,text,text) to authenticated;
revoke all on all functions in schema private from public,anon;
