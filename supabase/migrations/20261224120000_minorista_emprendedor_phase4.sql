-- Fase 4: listado admin con retailer_tier / entrepreneur_status + alertas emprendedor.

drop function if exists public.owner_list_profiles ();

create function public.owner_list_profiles ()
returns table (
  id uuid,
  business_name text,
  rif text,
  role text,
  phone text,
  email text,
  account_access_status text,
  account_review_note text,
  kyc_status text,
  is_owner boolean,
  deactivated_at timestamptz,
  deactivated_by uuid,
  created_at timestamptz,
  estado text,
  ciudad text,
  retailer_tier text,
  entrepreneur_status text,
  first_purchase_deadline timestamptz,
  kyc_completion_deadline timestamptz,
  is_entrepreneur_badge boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  return query
  select
    p.id,
    p.business_name,
    p.rif,
    p.role,
    p.phone,
    u.email::text,
    p.account_access_status,
    p.account_review_note,
    p.kyc_status,
    p.is_owner,
    p.deactivated_at,
    p.deactivated_by,
    p.created_at,
    p.estado,
    p.ciudad,
    coalesce(p.retailer_tier, 'standard') as retailer_tier,
    p.entrepreneur_status,
    p.first_purchase_deadline,
    p.kyc_completion_deadline,
    coalesce(p.is_entrepreneur_badge, false) as is_entrepreneur_badge
  from public.profiles p
  left join auth.users u on u.id = p.id
  order by
    p.is_owner desc,
    coalesce(p.business_name, u.email, p.rif, p.id::text);
end;
$$;

revoke all on function public.owner_list_profiles () from public;
grant execute on function public.owner_list_profiles () to authenticated;

comment on function public.owner_list_profiles () is
  'Administrador: listado de cuentas con email Auth + campos Minorista-Emprendedor.';

-- Alertas operativas (tres bandejas) para el dashboard / atajos.
create or replace function public.admin_list_entrepreneur_alerts ()
returns table (
  id uuid,
  business_name text,
  email text,
  phone text,
  entrepreneur_status text,
  first_purchase_deadline timestamptz,
  kyc_completion_deadline timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  return query
  select
    p.id,
    p.business_name,
    u.email::text,
    p.phone,
    p.entrepreneur_status,
    p.first_purchase_deadline,
    p.kyc_completion_deadline,
    p.created_at
  from public.profiles p
  left join auth.users u on u.id = p.id
  where p.retailer_tier = 'entrepreneur'
    and p.entrepreneur_status in (
      'pending_first_purchase_alert',
      'expired_locked',
      'reactivation_requested'
    )
    and p.deactivated_at is null
  order by
    case p.entrepreneur_status
      when 'reactivation_requested' then 0
      when 'expired_locked' then 1
      else 2
    end,
    p.created_at desc nulls last;
end;
$$;

revoke all on function public.admin_list_entrepreneur_alerts () from public;
grant execute on function public.admin_list_entrepreneur_alerts () to authenticated;

-- Prórroga: aceptar semanas (UI) además de días (compat Fase 3).
create or replace function public.admin_extend_entrepreneur_kyc (
  p_aliado_id uuid,
  p_extra_days integer default 14
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_days integer := greatest(1, least(coalesce(p_extra_days, 14), 112));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if coalesce(v_role, '') <> 'administrador' then
    raise exception 'Solo administradores.';
  end if;

  perform set_config('b2b.profile_privilege_ok', '1', true);

  update public.profiles
  set
    entrepreneur_status = 'kyc_in_progress',
    kyc_completion_deadline = now() + make_interval(days => v_days)
  where id = p_aliado_id
    and retailer_tier = 'entrepreneur'
    and entrepreneur_status in (
      'expired_locked',
      'reactivation_requested',
      'kyc_in_progress'
    );

  if not found then
    raise exception 'No hay cuenta emprendedora elegible para prorrogar.';
  end if;

  perform public.mc_insert_notification(
    p_aliado_id,
    'Prórroga de documentación concedida',
    'Un asesor habilitó una prórroga de '
      || v_days::text
      || ' días para completar tu expediente comercial.',
    'entrepreneur',
    p_aliado_id::text
  );
end;
$$;

revoke all on function public.admin_extend_entrepreneur_kyc (uuid, integer) from public;
grant execute on function public.admin_extend_entrepreneur_kyc (uuid, integer) to authenticated;
