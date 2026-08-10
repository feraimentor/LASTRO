create or replace function private.review_verification_request(
  p_request_id uuid,
  p_decision text,
  p_reason text default null
)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_request public.verification_requests%rowtype;
  v_unit uuid;
  v_created_unit boolean := false;
begin
  if not private.has_permission('residents.verify') then raise exception 'permission_denied'; end if;
  if p_decision not in ('approved', 'rejected', 'needs_information') then raise exception 'invalid_decision'; end if;

  select * into v_request
    from public.verification_requests
   where id = p_request_id
   for update;

  if v_request.id is null or v_request.state not in ('pending', 'needs_information') then
    raise exception 'request_not_reviewable';
  end if;

  v_unit := v_request.requested_unit_id;
  if p_decision = 'approved' and v_unit is null then
    select id into v_unit
      from public.condo_units
     where block_id = v_request.requested_block_id
       and normalized_label = lower(btrim(v_request.requested_unit_label))
       and archived_at is null;

    if v_unit is null then
      if not private.has_permission('units.manage') then
        raise exception 'catalog_unit_required';
      end if;

      insert into public.condo_units(block_id, unit_label)
      values (v_request.requested_block_id, btrim(v_request.requested_unit_label))
      on conflict (block_id, normalized_label) do nothing
      returning id into v_unit;

      if v_unit is not null then
        v_created_unit := true;
      else
        select id into v_unit
          from public.condo_units
         where block_id = v_request.requested_block_id
           and normalized_label = lower(btrim(v_request.requested_unit_label))
           and archived_at is null;
      end if;
    end if;
  end if;

  if p_decision = 'approved' and v_unit is null then raise exception 'catalog_unit_required'; end if;

  update public.verification_requests
     set state = p_decision::public.verification_state,
         requested_unit_id = coalesce(requested_unit_id, v_unit),
         reviewer_id = auth.uid(),
         reviewed_at = now(),
         decision_reason = nullif(btrim(p_reason), '')
   where id = p_request_id;

  if p_decision = 'approved' then
    insert into public.resident_unit_links(user_id, unit_id, relation_type, verification_status, verified_by, verified_at)
    values (v_request.user_id, v_unit, v_request.relation_type, 'approved', auth.uid(), now())
    on conflict do nothing;
    update public.profiles set access_state = 'active' where id = v_request.user_id;
  end if;

  if v_created_unit then
    insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values, reason)
    values (
      auth.uid(), 'unit.created', 'condo_unit', v_unit,
      jsonb_build_object('block_id', v_request.requested_block_id, 'unit_label', btrim(v_request.requested_unit_label), 'source', 'verification_approval'),
      'Unidade criada durante aprovação de vínculo'
    );
  end if;

  insert into public.audit_logs(actor_user_id, action, target_type, target_id, new_values, reason)
  values (
    auth.uid(), 'verification.' || p_decision, 'verification_request', p_request_id,
    jsonb_build_object('state', p_decision, 'unit_id', v_unit, 'unit_created', v_created_unit),
    nullif(btrim(p_reason), '')
  );
end;
$$;

revoke all on function private.review_verification_request(uuid,text,text) from public;
grant execute on function private.review_verification_request(uuid,text,text) to authenticated;
