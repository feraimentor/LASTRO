-- M7 release hardening: make administrative rate-limit settings effective.

create or replace function private.enforce_rate_limit(p_action text, p_limit integer)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_count integer;
  v_user uuid := auth.uid();
  v_effective_limit integer := p_limit;
  v_setting_key text;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  if p_limit < 1 then raise exception 'invalid_rate_limit'; end if;

  v_setting_key := case
    when p_action = 'report.create' then 'rate_limit_reports_per_hour'
    when p_action = 'attachment.reserve' then 'rate_limit_uploads_per_hour'
    when p_action in ('issue.affected', 'issue.follow', 'invitation.create', 'content.flag', 'privacy.request')
      then 'rate_limit_relations_per_hour'
    else null
  end;

  if v_setting_key is not null then
    select (s.value #>> '{}')::integer
      into v_effective_limit
      from public.app_settings s
      where s.key = v_setting_key;
    v_effective_limit := coalesce(v_effective_limit, p_limit);
  end if;

  select count(*) into v_count
    from public.rate_limit_events e
    where e.user_id = v_user
      and e.action = p_action
      and e.occurred_at > now() - interval '1 hour';

  if v_count >= v_effective_limit then raise exception 'rate_limit_exceeded'; end if;
  insert into public.rate_limit_events(user_id, action) values (v_user, p_action);
end;
$$;

comment on function private.enforce_rate_limit(text, integer) is
  'Enforces per-user hourly limits, preferring validated app_settings for known action families.';
