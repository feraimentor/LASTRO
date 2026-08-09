-- M6: mandatory staging, pseudonymized provenance and explicit historical publication.

alter table public.historical_sources add column import_batch_id uuid references public.import_batches(id) on delete restrict;
create sequence public.historical_actor_seq;
create table public.import_staging_item_versions(
  id uuid primary key default gen_random_uuid(),import_staging_item_id uuid not null references public.import_staging_items(id) on delete restrict,
  version_number integer not null,previous_payload jsonb not null,new_payload jsonb not null,reason text not null,
  changed_by uuid not null references auth.users(id) on delete restrict,changed_at timestamptz not null default now(),
  unique(import_staging_item_id,version_number)
);
alter table public.import_staging_item_versions enable row level security;

create or replace function private.create_import_batch(p_source_name text,p_source_type text)
returns uuid language plpgsql volatile security definer set search_path=''
as $$ declare v_id uuid;begin
  if not private.has_permission('historical_import.manage') then raise exception 'permission_denied';end if;
  if p_source_type not in('manual','csv','xlsx') or char_length(btrim(coalesce(p_source_name,'')))<2 then raise exception 'invalid_import_batch';end if;
  insert into public.import_batches(source_name,source_type,imported_by) values(btrim(p_source_name),p_source_type,auth.uid()) returning id into v_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'historical_import.batch_created','import_batch',v_id,jsonb_build_object('source_type',p_source_type));return v_id;
end $$;
create or replace function public.create_import_batch(p_source_name text,p_source_type text)
returns uuid language sql volatile security invoker set search_path=''
as $$ select private.create_import_batch(p_source_name,p_source_type); $$;

create or replace function private.create_historical_source(p_batch_id uuid,p_payload jsonb)
returns uuid language plpgsql volatile security definer set search_path=''
as $$
declare
  v_actor uuid;
  v_actor_hash text;
  v_source uuid;
begin
  v_actor_hash:=nullif(p_payload->>'_source_actor_hash','');
  if v_actor_hash is null and nullif(p_payload->>'source_actor_key','') is not null then
    v_actor_hash:=encode(extensions.digest(convert_to(p_payload->>'source_actor_key','UTF8'),'sha256'),'hex');
  end if;
  if v_actor_hash is not null then
    if v_actor_hash !~ '^[0-9a-f]{64}$' then raise exception 'invalid_source_actor_hash';end if;
    insert into public.historical_source_actors(pseudonym,internal_key_hash)
    values('historical_actor_'||lpad(nextval('public.historical_actor_seq')::text,4,'0'),v_actor_hash)
    on conflict(internal_key_hash) do update set internal_key_hash=excluded.internal_key_hash
    returning id into v_actor;
  end if;
  insert into public.historical_sources(
    source_type,source_name,source_reference,occurred_at,imported_by,provenance_notes,
    raw_source_text,published_summary,source_actor_id,import_batch_id
  ) values(
    p_payload->>'source_type',p_payload->>'source_name',nullif(p_payload->>'source_reference',''),
    (p_payload->>'occurred_at')::timestamptz,auth.uid(),p_payload->>'provenance_notes',
    nullif(coalesce(p_payload->>'raw_source_text',p_payload->>'_raw_source_text'),''),
    p_payload->>'published_summary',v_actor,p_batch_id
  ) returning id into v_source;
  return v_source;
end $$;

create or replace function private.stage_import_items(p_batch_id uuid,p_items jsonb)
returns integer language plpgsql volatile security definer set search_path=''
as $$
declare v_batch public.import_batches%rowtype;v_item jsonb;v_payload jsonb;v_staged jsonb;v_errors jsonb;v_source uuid;v_actor_hash text;v_count integer:=0;
begin
  if not private.has_permission('historical_import.manage') then raise exception 'permission_denied';end if;
  select * into v_batch from public.import_batches where id=p_batch_id for update;
  if v_batch.id is null or v_batch.state<>'staging' then raise exception 'staging_batch_required';end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 1000 then raise exception 'invalid_import_items';end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item)<>'object' or jsonb_typeof(v_item->'payload')<>'object' or jsonb_typeof(v_item->'errors')<>'array' then
      raise exception 'invalid_import_item_shape';
    end if;
    v_payload:=v_item->'payload';v_errors:=v_item->'errors';v_source:=null;v_actor_hash:=null;
    if nullif(v_payload->>'source_actor_key','') is not null then
      v_actor_hash:=encode(extensions.digest(convert_to(v_payload->>'source_actor_key','UTF8'),'sha256'),'hex');
    end if;
    if jsonb_array_length(v_errors)=0 then
      v_source:=private.create_historical_source(p_batch_id,v_payload);
      v_staged:=v_payload-'source_actor_key'-'raw_source_text';
    else
      -- Invalid source material remains restricted to the admin-only staging area.
      -- The actor key is never retained in plaintext, even while awaiting correction.
      v_staged:=jsonb_strip_nulls(
        (v_payload-'source_actor_key'-'raw_source_text')
        ||jsonb_build_object('_source_actor_hash',v_actor_hash,'_raw_source_text',nullif(v_payload->>'raw_source_text',''))
      );
    end if;
    insert into public.import_staging_items(import_batch_id,historical_source_id,state,payload,validation_errors)
    values(p_batch_id,v_source,case when jsonb_array_length(v_errors)=0 then 'pending_review'::public.import_item_state else 'needs_edit'::public.import_item_state end,
           v_staged,v_errors);
    v_count:=v_count+1;
  end loop;
  update public.import_batches set state='reviewing' where id=p_batch_id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'historical_import.staged','import_batch',p_batch_id,jsonb_build_object('item_count',v_count));
  return v_count;
end $$;
create or replace function public.stage_import_items(p_batch_id uuid,p_items jsonb)
returns integer language sql volatile security invoker set search_path=''
as $$ select private.stage_import_items(p_batch_id,p_items); $$;

create or replace function private.review_import_item(p_item_id uuid,p_state text,p_edited_payload jsonb,p_reason text)
returns void language plpgsql volatile security definer set search_path=''
as $$ declare v public.import_staging_items%rowtype;v_version integer;v_payload jsonb;v_source uuid;begin
  if not private.has_permission('historical_import.manage') then raise exception 'permission_denied';end if;
  if p_state not in('approved','ignored','needs_edit') or char_length(btrim(coalesce(p_reason,'')))<5 then raise exception 'invalid_review';end if;
  select * into v from public.import_staging_items where id=p_item_id for update;
  if v.id is null or v.state in('published','merged','ignored') then raise exception 'reviewable_item_required';end if;
  v_payload:=case when p_edited_payload is null then v.payload else v.payload||p_edited_payload end;
  if v_payload<>v.payload then
    select coalesce(max(version_number),0)+1 into v_version from public.import_staging_item_versions where import_staging_item_id=v.id;
    insert into public.import_staging_item_versions(import_staging_item_id,version_number,previous_payload,new_payload,reason,changed_by)
    values(v.id,v_version,v.payload,v_payload,btrim(p_reason),auth.uid());
  end if;
  if p_state='approved' and v.historical_source_id is null then
    if nullif(v_payload->>'source_name','') is null or nullif(v_payload->>'source_type','') is null
       or nullif(v_payload->>'occurred_at','') is null or nullif(v_payload->>'published_summary','') is null
       or nullif(v_payload->>'provenance_notes','') is null then raise exception 'valid_provenance_required';end if;
    v_source:=private.create_historical_source(v.import_batch_id,v_payload);
  else
    v_source:=v.historical_source_id;
  end if;
  update public.import_staging_items set
    payload=v_payload-'source_actor_key'-'raw_source_text'-'_source_actor_hash'-'_raw_source_text',
    historical_source_id=v_source,
    validation_errors=case when p_state='approved' then '[]'::jsonb else validation_errors end,
    state=p_state::public.import_item_state,reviewed_by=auth.uid(),reviewed_at=now()
  where id=v.id;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values,reason)
  values(auth.uid(),'historical_import.'||p_state,'import_staging_item',v.id,jsonb_build_object('state',p_state),btrim(p_reason));
end $$;
create or replace function public.review_import_item(p_item_id uuid,p_state text,p_edited_payload jsonb,p_reason text)
returns void language sql volatile security invoker set search_path=''
as $$ select private.review_import_item(p_item_id,p_state,p_edited_payload,p_reason); $$;

create or replace function private.publish_import_item(p_item_id uuid,p_target_issue_id uuid default null)
returns table(report_id uuid,protocol text,issue_id uuid)
language plpgsql volatile security definer set search_path=''
as $$
declare v public.import_staging_items%rowtype;v_source public.historical_sources%rowtype;v_payload jsonb;v_type uuid;v_category uuid;v_subcategory uuid;v_status uuid;v_issue uuid;v_report uuid:=gen_random_uuid();v_protocol text;v_response uuid;v_location_label text;v_expected_locations integer;v_matched_locations integer:=0;
begin
  if not private.has_permission('historical_import.manage') then raise exception 'permission_denied';end if;
  select * into v from public.import_staging_items where id=p_item_id for update;
  if v.id is null or v.state<>'approved' then raise exception 'approved_item_required';end if;
  select * into v_source from public.historical_sources where id=v.historical_source_id;
  v_payload:=v.payload;
  select id into v_type from public.report_types where slug=v_payload->>'record_type' and archived_at is null;
  select id into v_category from public.categories where slug=v_payload->>'category_slug' and archived_at is null;
  select id into v_subcategory from public.subcategories where category_id=v_category and slug=nullif(v_payload->>'subcategory_slug','') and archived_at is null;
  if v_type is null or v_category is null then raise exception 'invalid_taxonomy';end if;
  select id into v_status from public.report_status_definitions where report_type_id=v_type order by sort_order limit 1;
  if p_target_issue_id is null then
    insert into public.issues(title,category_id,subcategory_id,derived_status,first_occurred_at,last_occurred_at,created_by,source_origin)
    values(v_payload->>'title',v_category,v_subcategory,'historical_only',v_source.occurred_at,v_source.occurred_at,auth.uid(),'historical') returning id into v_issue;
  else
    select id into v_issue from public.issues where id=p_target_issue_id and archived_at is null for update;
    if v_issue is null then raise exception 'target_issue_not_found';end if;
  end if;
  v_protocol:=public.next_report_protocol('historical',v_source.occurred_at);
  insert into public.reports(id,protocol,issue_id,author_user_id,report_type_id,category_id,subcategory_id,status_definition_id,title,description,occurred_at,recorded_at,is_ongoing,previously_communicated,urgency,declared_recurrence,sensitivity,identifies_third_party,identity_mode,visibility,scope,good_faith_accepted_at,source_origin,historical_outcome)
  values(v_report,v_protocol,v_issue,null,v_type,v_category,v_subcategory,v_status,v_payload->>'title',v_source.published_summary,v_source.occurred_at,now(),false,false,v_payload->>'urgency',false,'normal',false,'protected','community',v_payload->>'scope',now(),'historical',coalesce(v_payload->>'historical_outcome','outcome_unknown'));
  insert into public.report_issue_history(report_id,from_issue_id,to_issue_id,reason,changed_by)
  values(v_report,null,v_issue,case when p_target_issue_id is null then 'Publicação histórica: nova issue' else 'Publicação histórica: associação curada' end,auth.uid());
  if nullif(v_payload->>'location_labels','') is not null then
    select count(*) into v_expected_locations from regexp_split_to_table(v_payload->>'location_labels','\s*;\s*');
    for v_location_label in select regexp_split_to_table(v_payload->>'location_labels','\s*;\s*') loop
      insert into public.report_locations(report_id,location_id) select v_report,id from public.locations where lower(label)=lower(btrim(v_location_label)) and archived_at is null on conflict do nothing;
      get diagnostics v_matched_locations=row_count;
      if v_matched_locations=0 then raise exception 'historical_location_not_found: %',v_location_label;end if;
      insert into public.issue_locations(issue_id,location_id) select v_issue,id from public.locations where lower(label)=lower(btrim(v_location_label)) and archived_at is null on conflict do nothing;
    end loop;
  end if;
  if nullif(v_payload->>'known_response_text','') is not null then
    insert into public.responses(report_id,response_type,attributed_to,channel,occurred_at,body,recorded_by)
    values(v_report,'external_recorded',v_source.source_name,'fonte histórica',coalesce(nullif(v_payload->>'known_response_at','')::timestamptz,v_source.occurred_at),v_payload->>'known_response_text',auth.uid()) returning id into v_response;
  end if;
  if nullif(v_payload->>'commitment_text','') is not null then
    insert into public.commitments(report_id,issue_id,response_id,source_label,recorded_by,description,assumed_at,original_due_at,current_due_at,status)
    values(v_report,v_issue,v_response,v_source.source_name,auth.uid(),v_payload->>'commitment_text',coalesce(nullif(v_payload->>'known_response_at','')::timestamptz,v_source.occurred_at),nullif(v_payload->>'commitment_due_at','')::timestamptz,nullif(v_payload->>'commitment_due_at','')::timestamptz,'awaiting_confirmation');
  end if;
  insert into public.timeline_events(issue_id,report_id,actor_user_id,event_type,entity_type,entity_id,occurred_at,display_text,metadata)
  values(v_issue,v_report,auth.uid(),'historical.imported','report',v_report,v_source.occurred_at,'Registro histórico importado',jsonb_build_object('source_name',v_source.source_name,'source_reference',v_source.source_reference,'imported_at',v_source.imported_at,'outcome',coalesce(v_payload->>'historical_outcome','outcome_unknown')));
  update public.import_staging_items set state=case when p_target_issue_id is null then 'published'::public.import_item_state else 'merged'::public.import_item_state end,published_report_id=v_report where id=v.id;
  if not exists(select 1 from public.import_staging_items where import_batch_id=v.import_batch_id and state in('pending_review','approved','needs_edit')) then update public.import_batches set state='completed',completed_at=now() where id=v.import_batch_id;end if;
  insert into public.audit_logs(actor_user_id,action,target_type,target_id,new_values)
  values(auth.uid(),'historical_import.published','import_staging_item',v.id,jsonb_build_object('report_id',v_report,'issue_id',v_issue,'protocol',v_protocol,'associated',p_target_issue_id is not null));
  return query select v_report,v_protocol,v_issue;
end $$;
create or replace function public.publish_import_item(p_item_id uuid,p_target_issue_id uuid default null)
returns table(report_id uuid,protocol text,issue_id uuid) language sql volatile security invoker set search_path=''
as $$ select * from private.publish_import_item(p_item_id,p_target_issue_id); $$;

create or replace function private.community_author_label(p_report_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
declare v_mode public.identity_mode; v_author uuid; v_name text; v_block text;v_origin public.source_origin;
begin
  if not private.can_access_report(p_report_id) then return null; end if;
  select identity_mode,author_user_id,source_origin into v_mode,v_author,v_origin from public.reports
   where id=p_report_id and visibility='community' and hidden_at is null and archived_at is null;
  if v_origin='historical' then return 'Registro histórico importado'; end if;
  if v_author is null then return 'Registro sem autoria identificada'; end if;
  if v_mode='identified' then
    select nullif(btrim(display_name),'') into v_name from public.profiles where id=v_author;
    return coalesce(v_name,'Usuário condominial verificado');
  end if;
  if v_mode='protected_with_block' then
    select b.label into v_block from public.resident_unit_links l
      join public.condo_units u on u.id=l.unit_id join public.blocks b on b.id=u.block_id
     where l.user_id=v_author and l.verification_status='approved'
     order by (l.ended_at is null) desc,l.created_at desc limit 1;
    return 'Usuário condominial verificado'||case when v_block is null then '' else ' — '||v_block end;
  end if;
  return 'Usuário condominial verificado';
end $$;

create policy import_versions_admin_read on public.import_staging_item_versions for select to authenticated using(private.has_permission('historical_import.manage'));
grant select on public.import_staging_item_versions to authenticated;
revoke all on function public.create_import_batch(text,text),public.stage_import_items(uuid,jsonb),public.review_import_item(uuid,text,jsonb,text),public.publish_import_item(uuid,uuid) from public,anon,authenticated;
grant execute on function public.create_import_batch(text,text),public.stage_import_items(uuid,jsonb),public.review_import_item(uuid,text,jsonb,text),public.publish_import_item(uuid,uuid) to authenticated;
grant execute on function private.create_import_batch(text,text),private.stage_import_items(uuid,jsonb),private.review_import_item(uuid,text,jsonb,text),private.publish_import_item(uuid,uuid) to authenticated;
revoke all on all functions in schema private from public,anon;
