-- Share the same set of verified, enabled stores across importer surfaces.
-- Keep one representative profile per normalized RIF.
create view b2b_private.active_retailer_stores as
select distinct on (lower(btrim(p.rif))) p.id as profile_id
from public.profiles p
where p.role = 'aliado'
  and p.kyc_status = 'aprobado'
  and p.account_access_status = 'active'
  and p.deactivated_at is null
  and nullif(btrim(p.rif), '') is not null
order by lower(btrim(p.rif)), p.id;

revoke all on b2b_private.active_retailer_stores from public, anon, authenticated;

create or replace function public.importer_daily_store_notice ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_seen date;
  v_today date;
  v_count integer;
begin
  if auth.uid () is null then
    return jsonb_build_object('show', false, 'store_count', null);
  end if;

  select p.role, p.daily_store_notice_on
    into v_role, v_seen
  from public.profiles p
  where p.id = auth.uid ();

  if v_role is distinct from 'importador' then
    return jsonb_build_object('show', false, 'store_count', null);
  end if;

  v_today := (timezone('America/Caracas', now()))::date;

  select count(*)
    into v_count
  from b2b_private.active_retailer_stores;

  return jsonb_build_object(
    'show', v_seen is distinct from v_today and coalesce(v_count, 0) > 0,
    'store_count', v_count,
    'seen_on', v_seen
  );
end;
$$;

create or replace function public.list_kyc_approved_aliados_for_importador ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select p.role
    into v_role
  from public.profiles p
  where p.id = auth.uid ();

  if v_role is distinct from 'importador' then
    raise exception 'Solo importadores pueden consultar aliados verificados.';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'business_name', p.business_name,
          'rif', p.rif,
          'phone', p.phone,
          'estado', p.estado,
          'ciudad', p.ciudad,
          'direccion', p.direccion,
          'fiscal_maps_url', p.fiscal_maps_url,
          'logo_storage_path', p.logo_storage_path,
          'kyc_status', p.kyc_status,
          'rating_as_payer_avg_rolling100', p.rating_as_payer_avg_rolling100,
          'rating_as_payer_count_rolling100', p.rating_as_payer_count_rolling100,
          'approved_document_count', (
            select count(*)::int
            from public.profile_documents pd
            where pd.profile_id = p.id
              and pd.is_current = true
              and pd.review_status = 'aprobado'
          )
        )
        order by p.business_name nulls last, p.id
      )
      from b2b_private.active_retailer_stores store
      join public.profiles p on p.id = store.profile_id
    ),
    '[]'::jsonb
  );
end;
$$;
