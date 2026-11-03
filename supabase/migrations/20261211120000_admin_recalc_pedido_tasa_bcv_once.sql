-- Admin: una sola recálculo de Bs congelados con la tasa BCV vigente.
-- No altera REF/USD ni la tasa global; solo tasa_bcv_aplicada + total_bs del pedido/grupo.

alter table public.transaction_requests
  add column if not exists tasa_bcv_recalc_at timestamptz;

comment on column public.transaction_requests.tasa_bcv_recalc_at is
  'Si no es null, un admin ya reaplicó la tasa BCV vigente una vez a este pedido.';

create or replace function public.admin_recalc_pedido_tasa_bcv (p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.transaction_requests%rowtype;
  v_group uuid;
  v_tasa numeric;
  v_old_tasa numeric;
  v_old_bs numeric;
  v_new_bs numeric;
  v_updated int := 0;
  v_already int;
begin
  perform public._assert_administrador ();

  if p_request_id is null then
    raise exception 'Pedido inválido.';
  end if;

  select *
    into v_row
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  v_group := coalesce(v_row.checkout_group_id, v_row.original_checkout_group_id);

  select count(*)::int
    into v_already
  from public.transaction_requests tr
  where (
      (v_group is not null and (
        tr.checkout_group_id = v_group
        or tr.original_checkout_group_id = v_group
        or tr.id = p_request_id
      ))
      or (v_group is null and tr.id = p_request_id)
    )
    and tr.tasa_bcv_recalc_at is not null;

  if v_already > 0 then
    raise exception 'Este pedido ya tuvo una actualización de tasa BCV. Solo se permite una vez.';
  end if;

  select c.value_numeric
    into v_tasa
  from public.app_global_config c
  where c.key = 'tasa_bcv';

  if coalesce(v_tasa, 0) <= 0 then
    raise exception 'No hay tasa BCV vigente para recalcular.';
  end if;

  v_old_tasa := v_row.tasa_bcv_aplicada;
  if v_old_tasa is not null and abs(v_old_tasa - v_tasa) <= 0.00005 then
    raise exception 'La tasa congelada ya coincide con la tasa vigente.';
  end if;

  select coalesce(sum(tr.total_bs), 0)
    into v_old_bs
  from public.transaction_requests tr
  where (
    v_group is not null and (
      tr.checkout_group_id = v_group
      or tr.original_checkout_group_id = v_group
      or tr.id = p_request_id
    )
  ) or (v_group is null and tr.id = p_request_id);

  update public.transaction_requests tr
  set
    tasa_bcv_aplicada = v_tasa,
    total_bs = round(
      coalesce(tr.total_ref, tr.precio_total_usd, 0) * v_tasa,
      2
    ),
    tasa_bcv_recalc_at = now()
  where (
      v_group is not null and (
        tr.checkout_group_id = v_group
        or tr.original_checkout_group_id = v_group
        or tr.id = p_request_id
      )
    )
    or (v_group is null and tr.id = p_request_id);

  get diagnostics v_updated = row_count;

  select coalesce(sum(tr.total_bs), 0)
    into v_new_bs
  from public.transaction_requests tr
  where (
    v_group is not null and (
      tr.checkout_group_id = v_group
      or tr.original_checkout_group_id = v_group
      or tr.id = p_request_id
    )
  ) or (v_group is null and tr.id = p_request_id);

  return jsonb_build_object(
    'updated_rows', v_updated,
    'checkout_group_id', v_group,
    'old_tasa', v_old_tasa,
    'new_tasa', v_tasa,
    'old_total_bs', v_old_bs,
    'new_total_bs', v_new_bs
  );
end;
$$;

comment on function public.admin_recalc_pedido_tasa_bcv (uuid) is
  'Admin: reaplica la tasa BCV vigente a total_bs del pedido/grupo. Solo una vez.';

revoke all on function public.admin_recalc_pedido_tasa_bcv (uuid) from public;
grant execute on function public.admin_recalc_pedido_tasa_bcv (uuid) to authenticated;
