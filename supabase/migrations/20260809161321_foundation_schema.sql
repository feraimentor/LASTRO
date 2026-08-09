-- LASTRO V1 foundation. PostgreSQL timestamps are UTC by convention.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create type public.access_state as enum (
  'onboarding', 'pending_verification', 'active', 'link_ended',
  'suspended', 'official', 'case_restricted'
);
create type public.verification_state as enum (
  'pending', 'needs_information', 'approved', 'rejected', 'cancelled'
);
create type public.visibility_mode as enum (
  'community', 'restricted', 'author_and_moderators'
);
create type public.identity_mode as enum (
  'identified', 'protected', 'protected_with_block'
);
create type public.source_origin as enum ('native', 'historical');
create type public.import_item_state as enum (
  'pending_review', 'approved', 'ignored', 'merged', 'needs_edit', 'published'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  first_name text,
  last_name text,
  display_name text,
  avatar_path text,
  public_identity_preference public.identity_mode not null default 'identified',
  access_state public.access_state not null default 'onboarding',
  relation_to_condo text,
  currently_resides boolean,
  suspended_at timestamptz,
  suspension_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_display_name_length check (display_name is null or char_length(display_name) between 2 and 100)
);

create table private.user_private_data (
  user_id uuid primary key references auth.users(id) on delete restrict,
  google_email text not null,
  whatsapp text,
  verification_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.blocks (
  id smallint primary key,
  label text not null unique,
  archived_at timestamptz,
  constraint blocks_range check (id between 1 and 14)
);

create table public.condo_units (
  id uuid primary key default gen_random_uuid(),
  block_id smallint not null references public.blocks(id),
  unit_label text not null,
  normalized_label text generated always as (lower(btrim(unit_label))) stored,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (block_id, normalized_label)
);

create table public.resident_unit_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  unit_id uuid not null references public.condo_units(id) on delete restrict,
  relation_type text not null check (relation_type in (
    'resident_owner', 'nonresident_owner', 'tenant', 'authorized_resident', 'owner_representative'
  )),
  verification_status public.verification_state not null default 'pending',
  starts_at date,
  ends_at date,
  verified_by uuid references auth.users(id) on delete restrict,
  verified_at timestamptz,
  ended_by uuid references auth.users(id) on delete restrict,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index resident_unit_links_active_unique
  on public.resident_unit_links(user_id, unit_id)
  where ended_at is null and verification_status <> 'cancelled';

create table public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  requested_unit_id uuid references public.condo_units(id) on delete restrict,
  requested_block_id smallint references public.blocks(id),
  requested_unit_label text,
  relation_type text not null,
  currently_resides boolean not null,
  state public.verification_state not null default 'pending',
  reviewer_id uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verification_has_unit check (requested_unit_id is not null or (requested_block_id is not null and requested_unit_label is not null))
);

create table public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  title text not null,
  public_slug text not null unique,
  created_at timestamptz not null default now()
);

create table public.legal_document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.legal_documents(id) on delete restrict,
  version text not null,
  state text not null default 'draft' check (state in ('draft', 'published')),
  published_at timestamptz,
  effective_at timestamptz,
  content_markdown text not null,
  content_hash_sha256 text not null check (content_hash_sha256 ~ '^[0-9a-f]{64}$'),
  requires_reacceptance boolean not null default true,
  is_current boolean not null default false,
  download_path text,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (document_id, version),
  constraint published_version_complete check (
    state = 'draft' or (published_at is not null and effective_at is not null and download_path is not null)
  )
);
create unique index legal_one_current_per_document
  on public.legal_document_versions(document_id) where is_current;

create table public.user_legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  document_version_id uuid not null references public.legal_document_versions(id) on delete restrict,
  accepted_hash_sha256 text not null check (accepted_hash_sha256 ~ '^[0-9a-f]{64}$'),
  accepted_at timestamptz not null default now(),
  unique (user_id, document_version_id)
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  level integer not null default 0,
  is_system boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  description text not null
);
create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete restrict,
  permission_id uuid not null references public.permissions(id) on delete restrict,
  granted_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);
create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  role_id uuid not null references public.roles(id) on delete restrict,
  granted_by uuid references auth.users(id) on delete restrict,
  granted_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  revocation_reason text
);
create unique index user_roles_active_unique on public.user_roles(user_id, role_id) where revoked_at is null;
create table public.user_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  permission_id uuid not null references public.permissions(id) on delete restrict,
  effect text not null check (effect in ('grant', 'deny')),
  granted_by uuid not null references auth.users(id) on delete restrict,
  granted_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  reason text
);
create unique index permission_override_active_unique
  on public.user_permission_overrides(user_id, permission_id) where revoked_at is null;

create table public.management_terms (
  id uuid primary key default gen_random_uuid(),
  organization text not null,
  starts_on date not null,
  ends_on date,
  created_at timestamptz not null default now()
);
create table public.official_representations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  role_type text not null check (role_type in ('manager', 'deputy_manager', 'council', 'administrator', 'authorized_representative', 'authorized_provider')),
  organization text,
  management_term_id uuid references public.management_terms(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz,
  status text not null default 'active' check (status in ('pending', 'active', 'ended', 'revoked')),
  verified_by uuid references auth.users(id) on delete restrict,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.access_invitations (
  id uuid primary key default gen_random_uuid(),
  invitation_type text not null check (invitation_type in ('admin', 'official_representative', 'case_participant')),
  email_hash_sha256 text not null check (email_hash_sha256 ~ '^[0-9a-f]{64}$'),
  token_hash_sha256 text not null unique check (token_hash_sha256 ~ '^[0-9a-f]{64}$'),
  report_id uuid,
  expires_at timestamptz not null,
  consumed_by uuid references auth.users(id) on delete restrict,
  consumed_at timestamptz,
  revoked_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.report_types (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  sort_order integer not null,
  archived_at timestamptz
);
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  sort_order integer not null,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete restrict,
  slug text not null,
  name text not null,
  sort_order integer not null,
  archived_at timestamptz,
  unique (category_id, slug)
);
create table public.category_aliases (
  id uuid primary key default gen_random_uuid(),
  alias text not null,
  category_id uuid not null references public.categories(id) on delete restrict,
  subcategory_id uuid references public.subcategories(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table public.locations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  sort_order integer not null,
  archived_at timestamptz
);
create table public.report_status_definitions (
  id uuid primary key default gen_random_uuid(),
  report_type_id uuid not null references public.report_types(id) on delete restrict,
  slug text not null,
  label text not null,
  sort_order integer not null,
  is_terminal boolean not null default false,
  unique (report_type_id, slug)
);

create table public.issues (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 8 and 180),
  category_id uuid references public.categories(id) on delete restrict,
  subcategory_id uuid references public.subcategories(id) on delete restrict,
  derived_status text not null default 'active' check (derived_status in ('historical_only', 'active', 'monitoring', 'resolved', 'archived')),
  criticality text not null default 'routine',
  first_occurred_at timestamptz,
  last_occurred_at timestamptz,
  persistence_started_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  source_origin public.source_origin not null default 'native',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search_vector tsvector generated always as (to_tsvector('portuguese', coalesce(title, ''))) stored
);

create sequence public.native_protocol_seq;
create sequence public.historical_protocol_seq;

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  protocol text not null unique,
  issue_id uuid not null references public.issues(id) on delete restrict,
  author_user_id uuid references auth.users(id) on delete restrict,
  affected_unit_id uuid references public.condo_units(id) on delete restrict,
  report_type_id uuid not null references public.report_types(id) on delete restrict,
  category_id uuid references public.categories(id) on delete restrict,
  subcategory_id uuid references public.subcategories(id) on delete restrict,
  status_definition_id uuid references public.report_status_definitions(id) on delete restrict,
  title text not null check (char_length(title) between 8 and 180),
  description text not null check (char_length(description) between 20 and 10000),
  occurred_at timestamptz,
  recorded_at timestamptz not null default now(),
  is_ongoing boolean,
  previously_communicated boolean,
  urgency text not null check (urgency in ('routine', 'attention', 'urgent', 'possible_immediate_risk')),
  declared_recurrence boolean not null default false,
  expected_responsible_party text,
  sensitivity text not null default 'normal',
  identifies_third_party boolean not null default false,
  identity_mode public.identity_mode not null default 'identified',
  visibility public.visibility_mode not null default 'community',
  scope text not null,
  suggested_category_text text,
  suggested_subcategory_text text,
  good_faith_accepted_at timestamptz not null,
  source_origin public.source_origin not null default 'native',
  historical_outcome text,
  withdrawn_at timestamptz,
  hidden_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search_vector tsvector generated always as (
    setweight(to_tsvector('portuguese', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('portuguese', coalesce(description, '')), 'B')
  ) stored,
  constraint historical_outcome_safe check (source_origin = 'native' or historical_outcome is not null)
);
alter table public.access_invitations add constraint access_invitation_report_fk foreign key (report_id) references public.reports(id) on delete restrict;

create table public.category_suggestions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  suggested_category_text text,
  suggested_subcategory_text text,
  state text not null default 'pending' check (state in ('pending', 'accepted', 'rejected', 'merged')),
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint category_suggestion_has_text check (coalesce(suggested_category_text, suggested_subcategory_text) is not null)
);
create table public.report_locations (
  report_id uuid not null references public.reports(id) on delete restrict,
  location_id uuid not null references public.locations(id) on delete restrict,
  primary key (report_id, location_id)
);
create table public.issue_locations (
  issue_id uuid not null references public.issues(id) on delete restrict,
  location_id uuid not null references public.locations(id) on delete restrict,
  primary key (issue_id, location_id)
);
create table public.report_versions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  version_number integer not null,
  title text not null,
  description text not null,
  reason text not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (report_id, version_number)
);
create table public.report_complements (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(body) between 2 and 10000),
  occurred_at timestamptz,
  recorded_at timestamptz not null default now()
);
create table public.report_issue_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  from_issue_id uuid references public.issues(id) on delete restrict,
  to_issue_id uuid not null references public.issues(id) on delete restrict,
  reason text not null,
  changed_by uuid not null references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now()
);
create table public.issue_occurrences (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues(id) on delete restrict,
  report_id uuid references public.reports(id) on delete restrict,
  occurred_at timestamptz not null,
  occurrence_type text not null,
  created_at timestamptz not null default now()
);
create table public.issue_merges (
  id uuid primary key default gen_random_uuid(),
  source_issue_id uuid not null references public.issues(id) on delete restrict,
  target_issue_id uuid not null references public.issues(id) on delete restrict,
  reason text not null,
  merged_by uuid not null references auth.users(id) on delete restrict,
  merged_at timestamptz not null default now(),
  undone_by uuid references auth.users(id) on delete restrict,
  undone_at timestamptz,
  constraint no_self_merge check (source_issue_id <> target_issue_id)
);
create table public.issue_affected_users (
  issue_id uuid not null references public.issues(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  unit_id_snapshot uuid references public.condo_units(id) on delete restrict,
  block_id_snapshot smallint references public.blocks(id),
  created_at timestamptz not null default now(),
  primary key (issue_id, user_id)
);
create table public.issue_followers (
  issue_id uuid not null references public.issues(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (issue_id, user_id)
);

create table public.report_parties (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  party_label text not null,
  organization text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table public.case_access_grants (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  invitation_id uuid references public.access_invitations(id) on delete restrict,
  granted_by uuid not null references auth.users(id) on delete restrict,
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz
);
create unique index case_access_active_unique on public.case_access_grants(report_id, user_id) where revoked_at is null;

create table public.responses (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  response_type text not null check (response_type in ('external_recorded', 'official', 'party_statement')),
  attributed_to text,
  channel text,
  occurred_at timestamptz not null,
  body text not null,
  action_informed text,
  recorded_by uuid not null references auth.users(id) on delete restrict,
  official_representation_id uuid references public.official_representations(id) on delete restrict,
  case_grant_id uuid references public.case_access_grants(id) on delete restrict,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  constraint response_provenance check (
    (response_type = 'external_recorded' and official_representation_id is null and case_grant_id is null) or
    (response_type = 'official' and official_representation_id is not null and case_grant_id is null) or
    (response_type = 'party_statement' and case_grant_id is not null and official_representation_id is null)
  )
);
create table public.commitments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete restrict,
  issue_id uuid references public.issues(id) on delete restrict,
  response_id uuid references public.responses(id) on delete restrict,
  source_label text not null,
  assigned_to text,
  recorded_by uuid not null references auth.users(id) on delete restrict,
  description text not null,
  assumed_at timestamptz not null,
  original_due_at timestamptz,
  current_due_at timestamptz,
  status text not null check (status in ('active', 'overdue', 'fulfilled_on_time', 'fulfilled_late', 'cancelled_with_reason', 'awaiting_confirmation')),
  fulfilled_at timestamptz,
  justification text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commitment_context check ((report_id is not null)::int + (issue_id is not null)::int >= 1)
);
create table public.commitment_deadline_history (
  id uuid primary key default gen_random_uuid(),
  commitment_id uuid not null references public.commitments(id) on delete restrict,
  previous_due_at timestamptz,
  new_due_at timestamptz,
  reason text not null,
  changed_by uuid not null references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now()
);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete restrict,
  response_id uuid references public.responses(id) on delete restrict,
  complement_id uuid references public.report_complements(id) on delete restrict,
  uploader_user_id uuid not null references auth.users(id) on delete restrict,
  bucket_id text not null default 'evidence',
  storage_path text not null unique,
  original_filename text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  description text,
  sensitivity text not null default 'normal',
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  constraint attachment_context check ((report_id is not null)::int + (response_id is not null)::int + (complement_id is not null)::int = 1)
);

create table public.timeline_events (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid references public.issues(id) on delete restrict,
  report_id uuid references public.reports(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete restrict,
  event_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  occurred_at timestamptz,
  recorded_at timestamptz not null default now(),
  display_text text,
  metadata jsonb not null default '{}'::jsonb
);
create table public.content_flags (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete restrict,
  response_id uuid references public.responses(id) on delete restrict,
  attachment_id uuid references public.attachments(id) on delete restrict,
  reporter_user_id uuid not null references auth.users(id) on delete restrict,
  reason text not null,
  details text,
  state text not null default 'open' check (state in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now()
);
create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  content_flag_id uuid references public.content_flags(id) on delete restrict,
  action_type text not null,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  moderator_user_id uuid not null references auth.users(id) on delete restrict,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now(),
  reverted_by uuid references auth.users(id) on delete restrict,
  reverted_at timestamptz
);
create table public.review_requests (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  moderation_action_id uuid references public.moderation_actions(id) on delete restrict,
  suspension_user_id uuid references auth.users(id) on delete restrict,
  rationale text not null,
  state text not null default 'pending' check (state in ('pending', 'reviewing', 'upheld', 'reversed', 'partially_reversed')),
  reviewer_user_id uuid references auth.users(id) on delete restrict,
  decision_reason text,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  request_type text not null,
  details text,
  state text not null default 'received' check (state in ('received', 'validating', 'in_progress', 'completed', 'partially_completed', 'denied')),
  decision text,
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete restrict,
  action text not null,
  target_type text not null,
  target_id uuid,
  correlation_id uuid,
  old_values jsonb,
  new_values jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete restrict,
  own_reports boolean not null default true,
  followed_issues boolean not null default true,
  block_issues boolean not null default false,
  responses boolean not null default true,
  commitments boolean not null default true,
  periodic_digest boolean not null default false,
  email_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  kind text not null,
  title text not null,
  body text not null,
  target_path text,
  essential boolean not null default false,
  email_state text not null default 'not_requested',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.historical_source_actors (
  id uuid primary key default gen_random_uuid(),
  pseudonym text not null unique check (pseudonym ~ '^historical_actor_[0-9]{4,}$'),
  internal_key_hash text not null unique,
  created_at timestamptz not null default now()
);
create table public.historical_sources (
  id uuid primary key default gen_random_uuid(),
  source_type text not null,
  source_name text not null,
  source_reference text,
  occurred_at timestamptz not null,
  imported_at timestamptz not null default now(),
  imported_by uuid not null references auth.users(id) on delete restrict,
  provenance_notes text,
  raw_source_text text,
  published_summary text,
  source_actor_id uuid references public.historical_source_actors(id) on delete restrict
);
create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_type text not null check (source_type in ('manual', 'csv', 'xlsx')),
  imported_by uuid not null references auth.users(id) on delete restrict,
  state text not null default 'staging' check (state in ('staging', 'reviewing', 'completed', 'cancelled')),
  imported_at timestamptz not null default now(),
  completed_at timestamptz
);
create table public.import_staging_items (
  id uuid primary key default gen_random_uuid(),
  import_batch_id uuid not null references public.import_batches(id) on delete restrict,
  historical_source_id uuid references public.historical_sources(id) on delete restrict,
  state public.import_item_state not null default 'pending_review',
  payload jsonb not null,
  validation_errors jsonb not null default '[]'::jsonb,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  published_report_id uuid references public.reports(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.app_settings (
  key text primary key,
  value jsonb not null,
  description text not null,
  updated_by uuid references auth.users(id) on delete restrict,
  updated_at timestamptz not null default now()
);
create table public.security_incidents (
  id uuid primary key default gen_random_uuid(),
  detected_at timestamptz not null,
  occurred_at timestamptz,
  severity text not null,
  systems text[] not null default '{}',
  summary text not null,
  data_categories text[] not null default '{}',
  containment text,
  remediation text,
  status text not null,
  decision_notes text,
  notifications_required boolean,
  notification_decision text,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.rate_limit_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  occurred_at timestamptz not null default now()
);

-- Common indexes based on V1 query paths.
create index issues_search_idx on public.issues using gin(search_vector);
create index reports_search_idx on public.reports using gin(search_vector);
create index reports_issue_recorded_idx on public.reports(issue_id, recorded_at desc);
create index reports_author_idx on public.reports(author_user_id, recorded_at desc);
create index reports_category_idx on public.reports(category_id, subcategory_id);
create index reports_visibility_idx on public.reports(visibility, hidden_at);
create index reports_origin_idx on public.reports(source_origin, recorded_at desc);
create index commitments_due_idx on public.commitments(current_due_at) where status in ('active', 'overdue', 'awaiting_confirmation');
create index timeline_report_idx on public.timeline_events(report_id, recorded_at);
create index timeline_issue_idx on public.timeline_events(issue_id, recorded_at);
create index notifications_user_idx on public.notifications(user_id, read_at, created_at desc);
create index audit_created_idx on public.audit_logs(created_at desc);
create index rate_limit_lookup_idx on public.rate_limit_events(user_id, action, occurred_at desc);

create or replace function private.is_verified_resident_for_user(p_user_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_user_id is not null
    and exists (
      select 1 from public.profiles p
      where p.id = p_user_id and p.access_state = 'active' and p.suspended_at is null
    )
    and exists (
      select 1 from public.resident_unit_links l
      where l.user_id = p_user_id and l.verification_status = 'approved' and l.ended_at is null
    );
$$;

create or replace function private.is_verified_resident()
returns boolean
language sql stable security definer
set search_path = ''
as $$ select private.is_verified_resident_for_user(auth.uid()); $$;

create or replace function private.has_permission_for_user(p_permission text, p_user_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1
      from public.user_permission_overrides o
      join public.permissions pe on pe.id = o.permission_id
      where o.user_id = p_user_id and pe.slug = p_permission
        and o.effect = 'grant' and o.revoked_at is null
    )
    or exists (
      select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      left join public.role_permissions rp on rp.role_id = r.id
      left join public.permissions pe on pe.id = rp.permission_id
      where ur.user_id = p_user_id and ur.revoked_at is null
        and (r.slug = 'master' or pe.slug = p_permission)
    )
  ) and not exists (
    select 1
    from public.user_permission_overrides denied
    join public.permissions pe on pe.id = denied.permission_id
    where denied.user_id = p_user_id and pe.slug = p_permission
      and denied.effect = 'deny' and denied.revoked_at is null
  );
$$;

create or replace function private.has_permission(p_permission text)
returns boolean
language sql stable security definer
set search_path = ''
as $$ select private.has_permission_for_user(p_permission, auth.uid()); $$;

create or replace function private.has_current_legal_acceptances_for_user(p_user_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_user_id is not null and not exists (
    select 1
    from public.legal_document_versions v
    where v.is_current and v.state = 'published'
      and not exists (
        select 1 from public.user_legal_acceptances a
        where a.user_id = p_user_id
          and a.document_version_id = v.id
          and a.accepted_hash_sha256 = v.content_hash_sha256
      )
  );
$$;

create or replace function private.has_current_legal_acceptances()
returns boolean
language sql stable security definer
set search_path = ''
as $$ select private.has_current_legal_acceptances_for_user(auth.uid()); $$;

create or replace function private.can_access_report(p_report_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.reports r
    where r.id = p_report_id and (
      r.author_user_id = auth.uid()
      or private.has_permission_for_user('sensitive_content.view', auth.uid())
      or (
        r.visibility = 'community'
        and r.hidden_at is null
        and private.is_verified_resident_for_user(auth.uid())
        and private.has_current_legal_acceptances_for_user(auth.uid())
      )
      or exists (
        select 1 from public.case_access_grants g
        where g.report_id = r.id and g.user_id = auth.uid() and g.revoked_at is null
          and (g.expires_at is null or g.expires_at > now())
      )
    )
  );
$$;

create or replace function private.is_report_author(p_report_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.reports r where r.id = p_report_id and r.author_user_id = auth.uid()
  );
$$;

create or replace function public.next_report_protocol(p_origin public.source_origin, p_occurred_at timestamptz default now())
returns text
language plpgsql volatile security invoker
set search_path = ''
as $$
declare
  v_seq bigint;
  v_year text;
begin
  v_year := to_char(coalesce(p_occurred_at, now()) at time zone 'America/Sao_Paulo', 'YYYY');
  if p_origin = 'historical' then
    v_seq := nextval('public.historical_protocol_seq');
    return 'HIST-' || v_year || '-' || lpad(v_seq::text, 6, '0');
  end if;
  v_seq := nextval('public.native_protocol_seq');
  return 'AI-' || v_year || '-' || lpad(v_seq::text, 6, '0');
end;
$$;

create or replace function private.enforce_rate_limit(p_action text, p_limit integer)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_count integer; v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select count(*) into v_count from public.rate_limit_events e
    where e.user_id = v_user and e.action = p_action and e.occurred_at > now() - interval '1 hour';
  if v_count >= p_limit then raise exception 'rate_limit_exceeded'; end if;
  insert into public.rate_limit_events(user_id, action) values (v_user, p_action);
end;
$$;

create or replace function public.create_report(p_payload jsonb)
returns table(report_id uuid, protocol text, issue_id uuid)
language plpgsql volatile security invoker
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_issue uuid;
  v_report uuid := gen_random_uuid();
  v_protocol text;
  v_type uuid;
  v_status uuid;
  v_category uuid;
  v_subcategory uuid;
  v_occurred timestamptz;
  v_location uuid;
begin
  if v_user is null or not private.is_verified_resident() or not private.has_current_legal_acceptances() then
    raise exception 'community_access_required';
  end if;
  perform private.enforce_rate_limit('report.create', 20);
  select id into v_type from public.report_types where slug = p_payload->>'type' and archived_at is null;
  select id into v_category from public.categories where slug = p_payload->>'category' and archived_at is null;
  select s.id into v_subcategory from public.subcategories s where s.category_id = v_category and s.slug = nullif(p_payload->>'subcategory','') and s.archived_at is null;
  if v_type is null or v_category is null then raise exception 'invalid_taxonomy'; end if;
  if (p_payload->>'category' = 'other' and nullif(btrim(p_payload->>'suggested_category_text'),'') is null)
     or (p_payload->>'subcategory' = 'other' and nullif(btrim(p_payload->>'suggested_subcategory_text'),'') is null) then
    raise exception 'category_suggestion_required';
  end if;
  v_occurred := nullif(p_payload->>'occurred_at','')::timestamptz;
  if nullif(p_payload->>'issue_id','') is not null then
    v_issue := (p_payload->>'issue_id')::uuid;
    if not exists (select 1 from public.issues i where i.id = v_issue) then raise exception 'issue_not_found'; end if;
  else
    insert into public.issues(id, title, category_id, subcategory_id, first_occurred_at, last_occurred_at, created_by)
    values (gen_random_uuid(), p_payload->>'title', v_category, v_subcategory, v_occurred, v_occurred, v_user)
    returning id into v_issue;
  end if;
  select id into v_status from public.report_status_definitions where report_type_id = v_type order by sort_order limit 1;
  v_protocol := public.next_report_protocol('native', coalesce(v_occurred, now()));
  insert into public.reports(
    id, protocol, issue_id, author_user_id, report_type_id, category_id, subcategory_id, status_definition_id,
    title, description, occurred_at, is_ongoing, previously_communicated, urgency, declared_recurrence,
    expected_responsible_party, sensitivity, identifies_third_party, identity_mode, visibility, scope,
    suggested_category_text, suggested_subcategory_text, good_faith_accepted_at
  ) values (
    v_report, v_protocol, v_issue, v_user, v_type, v_category, v_subcategory, v_status,
    p_payload->>'title', p_payload->>'description', v_occurred,
    coalesce((p_payload->>'is_ongoing')::boolean, false), coalesce((p_payload->>'previously_communicated')::boolean, false),
    p_payload->>'urgency', coalesce((p_payload->>'declared_recurrence')::boolean, false),
    nullif(p_payload->>'expected_responsible_party',''), coalesce(p_payload->>'sensitivity','normal'),
    coalesce((p_payload->>'identifies_third_party')::boolean,false),
    coalesce((p_payload->>'identity_mode')::public.identity_mode,'identified'),
    case when coalesce(p_payload->>'sensitivity','normal') in ('identified_third_party','child_or_adolescent','possible_personal_risk','sensitive_allegation')
         then 'author_and_moderators'::public.visibility_mode
         else coalesce((p_payload->>'visibility')::public.visibility_mode,'community') end,
    p_payload->>'scope',
    nullif(p_payload->>'suggested_category_text',''), nullif(p_payload->>'suggested_subcategory_text',''), now()
  );
  for v_location in
    select value::uuid from jsonb_array_elements_text(coalesce(p_payload->'location_ids','[]'::jsonb))
  loop
    if not exists(select 1 from public.locations l where l.id=v_location and l.archived_at is null) then
      raise exception 'invalid_location';
    end if;
    insert into public.report_locations(report_id,location_id) values(v_report,v_location) on conflict do nothing;
    insert into public.issue_locations(issue_id,location_id) values(v_issue,v_location) on conflict do nothing;
  end loop;
  if nullif(p_payload->>'suggested_category_text','') is not null or nullif(p_payload->>'suggested_subcategory_text','') is not null then
    insert into public.category_suggestions(report_id, suggested_category_text, suggested_subcategory_text)
    values (v_report, nullif(p_payload->>'suggested_category_text',''), nullif(p_payload->>'suggested_subcategory_text',''));
  end if;
  insert into public.report_issue_history(report_id, to_issue_id, reason, changed_by) values (v_report, v_issue, 'Criação do relato', v_user);
  insert into public.timeline_events(issue_id, report_id, actor_user_id, event_type, entity_type, entity_id, occurred_at, display_text, metadata)
  values (v_issue, v_report, v_user, 'report.created', 'report', v_report, v_occurred, 'Relato criado', jsonb_build_object('good_faith_accepted', true, 'protocol', v_protocol));
  return query select v_report, v_protocol, v_issue;
end;
$$;

create or replace function public.current_user_has_permission(p_permission text)
returns boolean
language sql stable security invoker
set search_path = ''
as $$ select private.has_permission(p_permission); $$;

create or replace function private.accept_current_legal_documents()
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_user uuid := auth.uid(); v_expected integer; v_inserted integer;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select count(*) into v_expected from public.legal_document_versions where state = 'published' and is_current;
  if v_expected <> 3 then raise exception 'current_legal_set_incomplete'; end if;
  insert into public.user_legal_acceptances(user_id, document_version_id, accepted_hash_sha256)
  select v_user, v.id, v.content_hash_sha256 from public.legal_document_versions v
   where v.state = 'published' and v.is_current
  on conflict (user_id, document_version_id) do nothing;
  get diagnostics v_inserted = row_count;
  insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values, reason)
  values (v_user, 'legal.current_set_accepted', 'user', v_user,
          jsonb_build_object('document_count', v_expected, 'new_acceptances', v_inserted), 'Aceite autenticado no servidor');
  return v_inserted;
end;
$$;

create or replace function public.accept_current_legal_documents()
returns integer
language sql volatile security invoker
set search_path = ''
as $$ select private.accept_current_legal_documents(); $$;

create or replace function private.review_verification_request(
  p_request_id uuid,
  p_decision text,
  p_reason text default null
)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_request public.verification_requests%rowtype; v_unit uuid;
begin
  if not private.has_permission('residents.verify') then raise exception 'permission_denied'; end if;
  if p_decision not in ('approved', 'rejected', 'needs_information') then raise exception 'invalid_decision'; end if;
  select * into v_request from public.verification_requests where id = p_request_id for update;
  if v_request.id is null or v_request.state not in ('pending', 'needs_information') then
    raise exception 'request_not_reviewable';
  end if;
  v_unit := v_request.requested_unit_id;
  if p_decision = 'approved' and v_unit is null then
    select id into v_unit from public.condo_units
     where block_id = v_request.requested_block_id
       and normalized_label = lower(btrim(v_request.requested_unit_label)) and archived_at is null;
    if v_unit is null then raise exception 'catalog_unit_required'; end if;
  end if;
  update public.verification_requests
     set state = p_decision::public.verification_state, requested_unit_id = coalesce(requested_unit_id, v_unit),
         reviewer_id = auth.uid(), reviewed_at = now(), decision_reason = nullif(btrim(p_reason), '')
   where id = p_request_id;
  if p_decision = 'approved' then
    insert into public.resident_unit_links(user_id, unit_id, relation_type, verification_status, verified_by, verified_at)
    values (v_request.user_id, v_unit, v_request.relation_type, 'approved', auth.uid(), now())
    on conflict do nothing;
    update public.profiles set access_state = 'active' where id = v_request.user_id;
  end if;
  insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values, reason)
  values (auth.uid(), 'verification.' || p_decision, 'verification_request', p_request_id,
          jsonb_build_object('state', p_decision), nullif(btrim(p_reason), ''));
end;
$$;

create or replace function public.review_verification_request(p_request_id uuid, p_decision text, p_reason text default null)
returns void
language sql volatile security invoker
set search_path = ''
as $$ select private.review_verification_request(p_request_id, p_decision, p_reason); $$;

create or replace function private.create_condo_unit(p_block_id smallint, p_unit_label text)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if not private.has_permission('units.manage') then raise exception 'permission_denied'; end if;
  if p_block_id not between 1 and 14 or char_length(btrim(p_unit_label)) not between 1 and 30 then raise exception 'invalid_unit'; end if;
  insert into public.condo_units(block_id, unit_label) values (p_block_id, btrim(p_unit_label)) returning id into v_id;
  insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values)
  values (auth.uid(), 'unit.created', 'condo_unit', v_id, jsonb_build_object('block_id', p_block_id, 'unit_label', btrim(p_unit_label)));
  return v_id;
end;
$$;

create or replace function public.create_condo_unit(p_block_id smallint, p_unit_label text)
returns uuid
language sql volatile security invoker
set search_path = ''
as $$ select private.create_condo_unit(p_block_id, p_unit_label); $$;

create or replace function private.prevent_append_only_mutation()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin raise exception '% is append-only', tg_table_name; end;
$$;
create trigger timeline_append_only before update or delete on public.timeline_events
  for each row execute function private.prevent_append_only_mutation();
create trigger audit_append_only before update or delete on public.audit_logs
  for each row execute function private.prevent_append_only_mutation();
create trigger complements_append_only before update or delete on public.report_complements
  for each row execute function private.prevent_append_only_mutation();
create trigger deadline_history_append_only before update or delete on public.commitment_deadline_history
  for each row execute function private.prevent_append_only_mutation();
create trigger acceptance_append_only before update or delete on public.user_legal_acceptances
  for each row execute function private.prevent_append_only_mutation();

create or replace function private.prevent_published_legal_mutation()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.state = 'published' then raise exception 'published_legal_version_is_immutable'; end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
create trigger legal_version_immutable before update or delete on public.legal_document_versions
  for each row execute function private.prevent_published_legal_mutation();

create or replace function private.guard_last_master()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_role_slug text; v_active integer;
begin
  select slug into v_role_slug from public.roles where id = old.role_id;
  if v_role_slug = 'master' and (tg_op = 'DELETE' or (old.revoked_at is null and new.revoked_at is not null)) then
    select count(*) into v_active from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where r.slug = 'master' and ur.revoked_at is null and ur.id <> old.id;
    if v_active = 0 then raise exception 'last_active_master_cannot_be_revoked'; end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
create trigger last_master_guard before update or delete on public.user_roles
  for each row execute function private.guard_last_master();

create or replace function private.touch_updated_at()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;
create trigger profiles_touch before update on public.profiles for each row execute function private.touch_updated_at();
create trigger units_touch before update on public.condo_units for each row execute function private.touch_updated_at();
create trigger verification_touch before update on public.verification_requests for each row execute function private.touch_updated_at();
create trigger issues_touch before update on public.issues for each row execute function private.touch_updated_at();
create trigger reports_touch before update on public.reports for each row execute function private.touch_updated_at();
create trigger commitments_touch before update on public.commitments for each row execute function private.touch_updated_at();

-- Safe community projections omit author UUID, unit UUID and PII.
create view public.community_reports with (security_invoker = true) as
select
  r.id, r.protocol, r.issue_id, r.report_type_id, r.category_id, r.subcategory_id,
  r.title, r.description, r.occurred_at, r.recorded_at, r.urgency, r.scope,
  r.sensitivity, r.identity_mode, r.source_origin, r.historical_outcome,
  case
    when r.identity_mode = 'identified' then 'Usuário condominial verificado'
    when r.identity_mode = 'protected_with_block' then 'Usuário condominial verificado — bloco informado'
    else 'Usuário condominial verificado'
  end as author_label
from public.reports r
where r.visibility = 'community' and r.hidden_at is null and r.archived_at is null;

create view public.issue_metrics with (security_invoker = true) as
select i.id as issue_id,
  count(distinct r.id) as report_count,
  count(distinct a.user_id) as affected_people_count,
  count(distinct a.unit_id_snapshot) as affected_unit_count,
  count(distinct a.block_id_snapshot) as affected_block_count,
  min(r.recorded_at) as first_recorded_at,
  max(r.recorded_at) as last_recorded_at
from public.issues i
left join public.reports r on r.issue_id = i.id and r.archived_at is null
left join public.issue_affected_users a on a.issue_id = i.id
group by i.id;

create view public.report_aging with (security_invoker = true) as
select r.id as report_id, r.recorded_at,
  extract(day from now() - r.recorded_at)::integer as age_days,
  case
    when now() - r.recorded_at <= interval '7 days' then 'até 7 dias'
    when now() - r.recorded_at <= interval '30 days' then '8–30'
    when now() - r.recorded_at <= interval '90 days' then '31–90'
    when now() - r.recorded_at <= interval '180 days' then '91–180'
    when now() - r.recorded_at <= interval '1 year' then '>180'
    else '>1 ano'
  end as aging_bucket
from public.reports r where r.archived_at is null;

-- RLS is enabled on every public base table.
do $$
declare rec record;
begin
  for rec in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', rec.tablename);
  end loop;
end $$;

-- Public legal read; all other community reads require verified status plus current legal acceptance.
create policy legal_documents_public_read on public.legal_documents for select to anon, authenticated using (true);
create policy legal_versions_public_read on public.legal_document_versions for select to anon, authenticated using (state = 'published');
create policy profiles_self_read on public.profiles for select to authenticated using ((select auth.uid()) = id or private.has_permission('private_data.view'));
create policy profiles_self_insert on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_self_update on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy acceptances_self_read on public.user_legal_acceptances for select to authenticated using ((select auth.uid()) = user_id);
create policy acceptances_self_insert on public.user_legal_acceptances for insert to authenticated
  with check ((select auth.uid()) = user_id and exists (
    select 1 from public.legal_document_versions v
    where v.id = document_version_id and v.state = 'published' and v.content_hash_sha256 = accepted_hash_sha256
  ));
create policy links_self_read on public.resident_unit_links for select to authenticated
  using ((select auth.uid()) = user_id or private.has_permission('residents.verify'));
create policy verification_self_read on public.verification_requests for select to authenticated
  using ((select auth.uid()) = user_id or private.has_permission('residents.verify'));
create policy verification_self_insert on public.verification_requests for insert to authenticated with check ((select auth.uid()) = user_id);
create policy verification_self_update on public.verification_requests for update to authenticated
  using ((select auth.uid()) = user_id and state in ('pending', 'needs_information'))
  with check ((select auth.uid()) = user_id and state in ('pending', 'needs_information', 'cancelled'));

create policy blocks_verified_read on public.blocks for select to authenticated
  using (private.is_verified_resident() or exists(select 1 from public.profiles p where p.id = (select auth.uid())));
create policy units_onboarding_read on public.condo_units for select to authenticated
  using (archived_at is null and exists(select 1 from public.profiles p where p.id = (select auth.uid())));
create policy taxonomy_verified_types on public.report_types for select to authenticated using (private.is_verified_resident());
create policy taxonomy_verified_categories on public.categories for select to authenticated using (private.is_verified_resident());
create policy taxonomy_verified_subcategories on public.subcategories for select to authenticated using (private.is_verified_resident());
create policy taxonomy_verified_aliases on public.category_aliases for select to authenticated using (private.is_verified_resident());
create policy taxonomy_verified_locations on public.locations for select to authenticated using (private.is_verified_resident());
create policy taxonomy_verified_status on public.report_status_definitions for select to authenticated using (private.is_verified_resident());

create policy issues_community_read on public.issues for select to authenticated
  using (private.is_verified_resident() and private.has_current_legal_acceptances());
create policy issues_verified_insert on public.issues for insert to authenticated
  with check (created_by = (select auth.uid()) and private.is_verified_resident() and private.has_current_legal_acceptances());
create policy reports_author_or_authorized_read on public.reports for select to authenticated using (private.can_access_report(id));
create policy reports_verified_insert on public.reports for insert to authenticated
  with check (
    author_user_id = (select auth.uid()) and private.is_verified_resident()
    and private.has_current_legal_acceptances()
    and (affected_unit_id is null or exists (
      select 1 from public.resident_unit_links l
      where l.user_id = (select auth.uid()) and l.unit_id = affected_unit_id
        and l.verification_status = 'approved' and l.ended_at is null
    ))
  );
create policy report_complements_read on public.report_complements for select to authenticated using (private.can_access_report(report_id));
create policy report_complements_own_insert on public.report_complements for insert to authenticated
  with check (author_user_id = (select auth.uid()) and private.is_report_author(report_id));
create policy report_issue_history_own_insert on public.report_issue_history for insert to authenticated
  with check (changed_by = (select auth.uid()) and private.is_report_author(report_id));
create policy category_suggestions_own_insert on public.category_suggestions for insert to authenticated
  with check (private.is_report_author(report_id));
create policy affected_read on public.issue_affected_users for select to authenticated using (private.is_verified_resident());
create policy affected_self_insert on public.issue_affected_users for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_verified_resident());
create policy affected_self_delete on public.issue_affected_users for delete to authenticated using (user_id = (select auth.uid()));
create policy followers_read on public.issue_followers for select to authenticated using (private.is_verified_resident());
create policy followers_self_insert on public.issue_followers for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_verified_resident());
create policy followers_self_delete on public.issue_followers for delete to authenticated using (user_id = (select auth.uid()));
create policy responses_authorized_read on public.responses for select to authenticated using (private.can_access_report(report_id));
create policy responses_authorized_insert on public.responses for insert to authenticated with check (
  recorded_by = (select auth.uid()) and private.can_access_report(report_id) and (
    response_type = 'external_recorded'
    or (response_type = 'official' and exists (
      select 1 from public.official_representations o where o.id = official_representation_id
        and o.user_id = (select auth.uid()) and o.status = 'active'
        and o.starts_at <= now() and (o.ends_at is null or o.ends_at > now())
    ))
    or (response_type = 'party_statement' and exists (
      select 1 from public.case_access_grants g where g.id = case_grant_id
        and g.user_id = (select auth.uid()) and g.report_id = responses.report_id
        and g.revoked_at is null and (g.expires_at is null or g.expires_at > now())
    ))
  )
);
create policy commitments_authorized_read on public.commitments for select to authenticated
  using ((report_id is not null and private.can_access_report(report_id)) or private.is_verified_resident());
create policy timeline_authorized_read on public.timeline_events for select to authenticated
  using ((report_id is not null and private.can_access_report(report_id)) or (report_id is null and private.is_verified_resident()));
create policy timeline_actor_insert on public.timeline_events for insert to authenticated
  with check (actor_user_id = (select auth.uid()) and (report_id is null or private.can_access_report(report_id)));
create policy attachments_authorized_read on public.attachments for select to authenticated
  using ((report_id is not null and private.can_access_report(report_id)) or exists(
    select 1 from public.responses rp where rp.id = response_id and private.can_access_report(rp.report_id)
  ) or exists(
    select 1 from public.report_complements c where c.id = complement_id and private.can_access_report(c.report_id)
  ));
create policy attachments_own_insert on public.attachments for insert to authenticated
  with check (uploader_user_id = (select auth.uid()) and private.is_verified_resident());
create policy flags_own_read on public.content_flags for select to authenticated
  using (reporter_user_id = (select auth.uid()) or private.has_permission('moderation.review'));
create policy flags_community_insert on public.content_flags for insert to authenticated
  with check (reporter_user_id = (select auth.uid()) and private.is_verified_resident());
create policy reviews_own_read on public.review_requests for select to authenticated
  using (requester_user_id = (select auth.uid()) or private.has_permission('moderation.review'));
create policy reviews_own_insert on public.review_requests for insert to authenticated with check (requester_user_id = (select auth.uid()));
create policy privacy_own_read on public.privacy_requests for select to authenticated
  using (user_id = (select auth.uid()) or private.has_permission('private_data.view'));
create policy privacy_own_insert on public.privacy_requests for insert to authenticated with check (user_id = (select auth.uid()));
create policy notifications_own_read on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy notifications_own_update on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy preferences_own_all on public.notification_preferences for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy roles_admin_read on public.roles for select to authenticated using (private.has_permission('admins.manage'));
create policy permissions_admin_read on public.permissions for select to authenticated using (private.has_permission('admins.manage'));
create policy role_permissions_admin_read on public.role_permissions for select to authenticated using (private.has_permission('admins.manage'));
create policy user_roles_admin_read on public.user_roles for select to authenticated using (private.has_permission('admins.manage'));
create policy overrides_admin_read on public.user_permission_overrides for select to authenticated using (private.has_permission('admins.manage'));
create policy audit_admin_read on public.audit_logs for select to authenticated using (private.has_permission('audit.view'));
create policy incidents_admin_read on public.security_incidents for select to authenticated using (private.has_permission('settings.manage'));
create policy imports_admin_batches on public.import_batches for select to authenticated using (private.has_permission('historical_import.manage'));
create policy imports_admin_items on public.import_staging_items for select to authenticated using (private.has_permission('historical_import.manage'));
create policy imports_admin_sources on public.historical_sources for select to authenticated using (private.has_permission('historical_import.manage'));
create policy imports_admin_actors on public.historical_source_actors for select to authenticated using (private.has_permission('historical_import.manage'));

-- Explicit Data API grants. Column grants keep protected identity fields out of direct community queries.
revoke all on all tables in schema public from anon, authenticated;
grant select on public.legal_documents, public.legal_document_versions to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert on public.user_legal_acceptances to authenticated;
grant select on public.blocks, public.condo_units, public.resident_unit_links to authenticated;
grant select, insert, update on public.verification_requests to authenticated;
grant select on public.report_types, public.categories, public.subcategories, public.category_aliases, public.locations, public.report_status_definitions to authenticated;
grant select, insert on public.issues to authenticated;
grant select (id, protocol, issue_id, report_type_id, category_id, subcategory_id, status_definition_id, title, description, occurred_at, recorded_at, is_ongoing, previously_communicated, urgency, declared_recurrence, expected_responsible_party, sensitivity, identifies_third_party, identity_mode, visibility, scope, source_origin, historical_outcome, hidden_at, archived_at, created_at, updated_at) on public.reports to authenticated;
grant insert on public.reports to authenticated;
grant select, insert on public.report_complements, public.issue_affected_users, public.issue_followers, public.responses, public.attachments, public.content_flags, public.review_requests, public.privacy_requests to authenticated;
grant delete on public.issue_affected_users, public.issue_followers to authenticated;
grant select on public.commitments, public.timeline_events to authenticated;
grant insert on public.timeline_events, public.report_issue_history, public.category_suggestions to authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant select on public.roles, public.permissions, public.role_permissions, public.user_roles, public.user_permission_overrides, public.audit_logs, public.security_incidents, public.import_batches, public.import_staging_items, public.historical_sources, public.historical_source_actors to authenticated;
grant select on public.community_reports, public.issue_metrics, public.report_aging to authenticated;
grant usage, select on sequence public.native_protocol_seq, public.historical_protocol_seq to authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function public.next_report_protocol(public.source_origin, timestamptz) to authenticated;
grant execute on function public.create_report(jsonb) to authenticated;
grant execute on function public.current_user_has_permission(text) to authenticated;
grant execute on function public.accept_current_legal_documents() to authenticated;
grant execute on function public.review_verification_request(uuid,text,text) to authenticated;
grant execute on function public.create_condo_unit(smallint,text) to authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_verified_resident(), private.has_permission(text), private.has_current_legal_acceptances(), private.can_access_report(uuid), private.is_report_author(uuid), private.enforce_rate_limit(text, integer), private.accept_current_legal_documents(), private.review_verification_request(uuid,text,text), private.create_condo_unit(smallint,text) to authenticated;
revoke all on all functions in schema private from public, anon;

-- Private evidence bucket. Object operations use Storage API; SQL only defines access policy.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('evidence', 'evidence', false, 52428800, array[
  'image/jpeg','image/png','image/webp','application/pdf','audio/mpeg','audio/mp4','video/mp4',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
]) on conflict (id) do update set public = false;

create policy evidence_insert_own_path on storage.objects for insert to authenticated with check (
  bucket_id = 'evidence' and (storage.foldername(name))[1] = (select auth.uid())::text
  and private.is_verified_resident()
);
create policy evidence_select_authorized on storage.objects for select to authenticated using (
  bucket_id = 'evidence' and exists (
    select 1 from public.attachments a
    where a.storage_path = storage.objects.name and a.bucket_id = storage.objects.bucket_id
      and (
        a.uploader_user_id = (select auth.uid())
        or (a.report_id is not null and private.can_access_report(a.report_id))
        or exists (select 1 from public.responses rp where rp.id = a.response_id and private.can_access_report(rp.report_id))
        or exists (select 1 from public.report_complements c where c.id = a.complement_id and private.can_access_report(c.report_id))
      )
  )
);

comment on view public.community_reports is 'Safe community projection: no author_user_id, unit_id or PII.';
comment on table public.audit_logs is 'Append-only administrative audit. Do not copy sensitive content indiscriminately.';
comment on table public.timeline_events is 'Append-only domain timeline; separate from administrative audit.';
