-- Administrative user directory. PII remains behind current database permissions.
create or replace function private.admin_search_users(
  p_query text default null,
  p_limit integer default 50
)
returns table(
  user_id uuid,
  email text,
  display_name text,
  first_name text,
  last_name text,
  access_state text,
  onboarding_step text,
  relation_types text[],
  block_labels text[],
  unit_labels text[],
  latest_verification_request_id uuid,
  latest_verification_state text,
  requested_relation_type text,
  requested_block_label text,
  requested_unit_label text,
  role_slugs text[],
  permission_slugs text[],
  created_at timestamptz,
  last_sign_in_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(lower(extensions.unaccent(btrim(coalesce(p_query, '')))), '');
begin
  if auth.uid() is null
     or not private.has_permission('admins.manage')
     or not private.has_permission('private_data.view') then
    raise exception 'permission_denied';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid_limit';
  end if;

  return query
  with directory as (
    select
      account.id as user_id,
      lower(coalesce(private_data.google_email, account.email)) as email,
      profile.display_name,
      profile.first_name,
      profile.last_name,
      coalesce(profile.access_state::text, 'onboarding') as access_state,
      case
        when not legal_state.complete then 'legal'
        when profile.first_name is null or profile.last_name is null or profile.display_name is null then 'profile'
        when current_links.link_count > 0 and profile.access_state = 'active' then 'complete'
        when latest_request.id is null then 'unit'
        when latest_request.state = 'needs_information' then 'verification'
        when latest_request.state in ('rejected', 'cancelled') then 'unit'
        else 'pending'
      end as onboarding_step,
      current_links.relation_types,
      current_links.block_labels,
      current_links.unit_labels,
      latest_request.id as latest_verification_request_id,
      latest_request.state as latest_verification_state,
      latest_request.relation_type as requested_relation_type,
      latest_request.block_label as requested_block_label,
      latest_request.unit_label as requested_unit_label,
      current_roles.role_slugs,
      effective_permissions.permission_slugs,
      account.created_at,
      account.last_sign_in_at
    from auth.users account
    left join public.profiles profile on profile.id = account.id
    left join private.user_private_data private_data on private_data.user_id = account.id
    left join lateral (
      select
        count(*)::integer as link_count,
        coalesce(array_agg(distinct link.relation_type order by link.relation_type), '{}'::text[]) as relation_types,
        coalesce(array_agg(distinct block.label order by block.label), '{}'::text[]) as block_labels,
        coalesce(array_agg(distinct unit.unit_label order by unit.unit_label), '{}'::text[]) as unit_labels
      from public.resident_unit_links link
      join public.condo_units unit on unit.id = link.unit_id
      join public.blocks block on block.id = unit.block_id
      where link.user_id = account.id
        and link.verification_status = 'approved'
        and link.ended_at is null
    ) current_links on true
    left join lateral (
      select
        request.id,
        request.state::text as state,
        request.relation_type,
        block.label as block_label,
        coalesce(requested_unit.unit_label, request.requested_unit_label) as unit_label
      from public.verification_requests request
      left join public.condo_units requested_unit on requested_unit.id = request.requested_unit_id
      left join public.blocks block on block.id = coalesce(requested_unit.block_id, request.requested_block_id)
      where request.user_id = account.id
      order by request.created_at desc
      limit 1
    ) latest_request on true
    left join lateral (
      select coalesce(array_agg(role.slug order by role.level desc, role.slug), '{}'::text[]) as role_slugs
      from public.user_roles assignment
      join public.roles role on role.id = assignment.role_id
      where assignment.user_id = account.id and assignment.revoked_at is null
    ) current_roles on true
    left join lateral (
      select coalesce(array_agg(permission.slug order by permission.slug), '{}'::text[]) as permission_slugs
      from public.permissions permission
      where private.has_permission_for_user(permission.slug, account.id)
    ) effective_permissions on true
    cross join lateral (
      select
        exists (
          select 1 from public.legal_document_versions version
          where version.is_current and version.state = 'published'
        )
        and not exists (
          select 1
          from public.legal_document_versions version
          where version.is_current and version.state = 'published'
            and not exists (
              select 1 from public.user_legal_acceptances acceptance
              where acceptance.user_id = account.id
                and acceptance.document_version_id = version.id
                and acceptance.accepted_hash_sha256 = version.content_hash_sha256
            )
        ) as complete
    ) legal_state
  )
  select
    directory.user_id,
    directory.email,
    directory.display_name,
    directory.first_name,
    directory.last_name,
    directory.access_state,
    directory.onboarding_step,
    directory.relation_types,
    directory.block_labels,
    directory.unit_labels,
    directory.latest_verification_request_id,
    directory.latest_verification_state,
    directory.requested_relation_type,
    directory.requested_block_label,
    directory.requested_unit_label,
    directory.role_slugs,
    directory.permission_slugs,
    directory.created_at,
    directory.last_sign_in_at
  from directory
  where v_query is null
     or strpos(lower(extensions.unaccent(directory.user_id::text)), v_query) > 0
     or strpos(lower(extensions.unaccent(coalesce(directory.email, ''))), v_query) > 0
     or strpos(lower(extensions.unaccent(coalesce(directory.display_name, ''))), v_query) > 0
     or strpos(lower(extensions.unaccent(concat_ws(' ', directory.first_name, directory.last_name))), v_query) > 0
     or strpos(lower(extensions.unaccent(coalesce(directory.requested_block_label, ''))), v_query) > 0
     or strpos(lower(extensions.unaccent(coalesce(directory.requested_unit_label, ''))), v_query) > 0
     or exists (
       select 1 from unnest(directory.block_labels) label
       where strpos(lower(extensions.unaccent(label)), v_query) > 0
     )
     or exists (
       select 1 from unnest(directory.unit_labels) label
       where strpos(lower(extensions.unaccent(label)), v_query) > 0
     )
  order by lower(coalesce(directory.display_name, directory.email, directory.user_id::text)), directory.user_id
  limit p_limit;
end;
$$;

create or replace function public.admin_search_users(
  p_query text default null,
  p_limit integer default 50
)
returns table(
  user_id uuid,
  email text,
  display_name text,
  first_name text,
  last_name text,
  access_state text,
  onboarding_step text,
  relation_types text[],
  block_labels text[],
  unit_labels text[],
  latest_verification_request_id uuid,
  latest_verification_state text,
  requested_relation_type text,
  requested_block_label text,
  requested_unit_label text,
  role_slugs text[],
  permission_slugs text[],
  created_at timestamptz,
  last_sign_in_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.admin_search_users(p_query, p_limit);
$$;

revoke all on function public.admin_search_users(text, integer) from public, anon, authenticated;
grant execute on function public.admin_search_users(text, integer) to authenticated;
revoke all on function private.admin_search_users(text, integer) from public, anon, authenticated;
grant execute on function private.admin_search_users(text, integer) to authenticated;

comment on function public.admin_search_users(text, integer) is
  'PII-bearing administrative directory. Requires current admins.manage and private_data.view permissions.';

notify pgrst, 'reload schema';
