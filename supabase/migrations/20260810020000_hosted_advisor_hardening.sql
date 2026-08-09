-- Hardening discovered by the hosted Supabase advisors after the first full deploy.
-- Keep private data deny-by-default even if the private schema is exposed by mistake.
alter table private.user_private_data enable row level security;

-- auth.uid() is stable for the statement. Wrapping it in a scalar subquery lets
-- PostgreSQL evaluate it once instead of once per candidate row.
drop policy if exists affected_self_read on public.issue_affected_users;
create policy affected_self_read on public.issue_affected_users
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists followers_self_read on public.issue_followers;
create policy followers_self_read on public.issue_followers
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists official_representation_self_or_admin_read on public.official_representations;
create policy official_representation_self_or_admin_read on public.official_representations
for select to authenticated
using (
  user_id = (select auth.uid())
  or private.has_permission('official_accounts.verify')
);

drop policy if exists case_grants_self_read on public.case_access_grants;
create policy case_grants_self_read on public.case_access_grants
for select to authenticated
using (user_id = (select auth.uid()));

-- These pairs had overlapping permissive SELECT policies. The surviving policy
-- already expresses the union, except legal versions where the union is explicit.
drop policy if exists flags_moderator_read on public.content_flags;
drop policy if exists review_admin_read on public.review_requests;
drop policy if exists privacy_admin_read on public.privacy_requests;

drop policy if exists legal_versions_admin_read on public.legal_document_versions;
drop policy if exists legal_versions_public_read on public.legal_document_versions;
create policy legal_versions_public_read on public.legal_document_versions
for select to anon, authenticated
using (
  state = 'published'
  or private.has_permission('legal_documents.manage')
);

-- Add a deterministic leading-column index for every public FK that is not
-- already covered. The loop is tied to the schema catalog so future fresh
-- installs and the hosted database receive the exact same hardening.
do $$
declare
  fk record;
begin
  for fk in
    select
      n.nspname as schema_name,
      t.relname as table_name,
      c.conname as constraint_name,
      string_agg(quote_ident(a.attname), ', ' order by key_column.ordinality) as column_list
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    cross join lateral unnest(c.conkey) with ordinality as key_column(attnum, ordinality)
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = key_column.attnum
    where c.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = c.conrelid
          and i.indisvalid
          and i.indisready
          and cardinality(i.indkey::smallint[]) >= cardinality(c.conkey)
          and array(
            select (i.indkey::smallint[])[position]
            from generate_series(0, cardinality(c.conkey) - 1) as position
          ) = c.conkey
      )
    group by n.nspname, t.relname, c.conname
  loop
    execute format(
      'create index if not exists %I on %I.%I (%s)',
      'fkidx_' || substr(md5(fk.schema_name || '.' || fk.table_name || '.' || fk.constraint_name), 1, 16),
      fk.schema_name,
      fk.table_name,
      fk.column_list
    );
  end loop;
end;
$$;
