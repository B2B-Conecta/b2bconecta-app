-- Aviso in-app al aliado cuando MotoLink suspende o reactiva nuevos pedidos por morosidad.

create or replace function public.admin_set_aliado_pedidos_suspendidos_morosidad(
  p_aliado_id uuid,
  p_suspend boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mor boolean;
  role text;
  n integer;
begin
  if not exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden suspender o reactivar pedidos por morosidad.';
  end if;

  select p.role into role
  from public.profiles p
  where p.id = p_aliado_id;

  if role is null then
    raise exception 'Perfil no encontrado.';
  end if;

  if role is distinct from 'aliado' then
    raise exception 'Solo aplica a cuentas aliado.';
  end if;

  mor := public.aliado_tiene_pedidos_morosos(p_aliado_id);

  if p_suspend then
    if not mor then
      raise exception
        'No puede suspender pedidos: este aliado no tiene pedidos morosos (entregados con pago sin aprobar).';
    end if;

    update public.profiles
    set pedidos_suspendidos_morosidad = true
    where id = p_aliado_id
      and coalesce(pedidos_suspendidos_morosidad, false) is distinct from true;

    get diagnostics n = row_count;

    if n > 0 then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        p_aliado_id,
        'Cuenta: nuevos pedidos suspendidos',
        'MotoLink suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad. '
        'Regularice los pagos pendientes de pedidos ya entregados; cuando MotoLink confirme y reactive su cuenta, '
        'podrá volver a solicitar repuestos.',
        'pago',
        null
      );
    end if;
  else
    if mor then
      raise exception
        'No puede reactivar pedidos mientras el aliado siga con pedidos morosos. Apruebe los pagos pendientes primero.';
    end if;

    update public.profiles
    set pedidos_suspendidos_morosidad = false
    where id = p_aliado_id
      and coalesce(pedidos_suspendidos_morosidad, false) is distinct from false;

    get diagnostics n = row_count;

    if n > 0 then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        p_aliado_id,
        'Cuenta: nuevos pedidos reactivados',
        'MotoLink reactivó la creación de nuevos pedidos en su cuenta. Ya puede solicitar repuestos desde el catálogo.',
        'pago',
        null
      );
    end if;
  end if;
end;
$$;

grant execute on function public.admin_set_aliado_pedidos_suspendidos_morosidad(uuid, boolean)
  to authenticated;
