-- El proveedor recibe aviso cuando un pedido usa saldo a favor de la tienda.

create or replace function public.mc_apply_checkout_importer_credits (
  p_group_id uuid,
  p_apply jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_imp uuid;
  v_subtotal numeric(14, 4);
  v_available numeric(14, 4);
  v_apply numeric(14, 4);
  v_cut numeric(14, 4);
  v_left numeric(14, 4);
  v_applied numeric(14, 4);
  v_i integer;
  v_n integer;
  v_line record;
  v_note record;
  v_shop text;
  v_anchor uuid;
begin
  if v_uid is null or p_group_id is null then
    return;
  end if;
  if p_apply is null or jsonb_typeof(p_apply) <> 'object' then
    return;
  end if;
  if not exists (
    select 1
    from public.transaction_requests tr
    where tr.checkout_group_id = p_group_id
      and tr.aliado_id = v_uid
  ) then
    raise exception 'Pedido no encontrado.';
  end if;

  for v_imp in
    select (e.key)::uuid
    from jsonb_each(p_apply) e
    where coalesce(e.value #>> '{}', '') in ('true', 't')
  loop
    select coalesce(sum(tr.precio_total_usd), 0)
      into v_subtotal
    from public.transaction_requests tr
    where tr.checkout_group_id = p_group_id
      and tr.importador_id = v_imp
      and tr.aliado_id = v_uid;

    select coalesce(sum(n.remaining), 0)
      into v_available
    from public.aliado_importer_credit_notes n
    where n.aliado_id = v_uid
      and n.importador_id = v_imp
      and n.status = 'vigente'
      and n.remaining > 0;

    v_apply := least(v_subtotal, v_available);
    if v_apply <= 0 then
      continue;
    end if;

    select count(*)
      into v_n
    from public.transaction_requests tr
    where tr.checkout_group_id = p_group_id
      and tr.importador_id = v_imp
      and tr.aliado_id = v_uid
      and tr.precio_total_usd > 0;

    v_left := v_apply;
    v_applied := 0;
    v_i := 0;

    for v_line in
      select tr.id, tr.precio_total_usd, tr.precio_base_aliado_total
      from public.transaction_requests tr
      where tr.checkout_group_id = p_group_id
        and tr.importador_id = v_imp
        and tr.aliado_id = v_uid
        and tr.precio_total_usd > 0
      order by tr.id
      for update
    loop
      v_i := v_i + 1;
      if v_i = v_n then
        v_cut := least(v_left, v_line.precio_total_usd);
      else
        v_cut := round((v_apply * v_line.precio_total_usd / v_subtotal)::numeric, 4);
        if v_cut > v_left then
          v_cut := v_left;
        end if;
        if v_cut > v_line.precio_total_usd then
          v_cut := v_line.precio_total_usd;
        end if;
      end if;
      if v_cut < 0 then
        v_cut := 0;
      end if;

      update public.transaction_requests
        set
          precio_total_usd = precio_total_usd - v_cut,
          precio_base_aliado_total = greatest(
            coalesce(precio_base_aliado_total, precio_total_usd) - v_cut,
            0
          ),
          credito_aplicado_monto = coalesce(credito_aplicado_monto, 0) + v_cut
        where id = v_line.id;

      v_left := v_left - v_cut;
      v_applied := v_applied + v_cut;
    end loop;

    v_left := v_applied;
    for v_note in
      select n.id, n.remaining
      from public.aliado_importer_credit_notes n
      where n.aliado_id = v_uid
        and n.importador_id = v_imp
        and n.status = 'vigente'
        and n.remaining > 0
      order by n.created_at, n.id
      for update
    loop
      exit when v_left <= 0;
      v_cut := least(v_note.remaining, v_left);
      update public.aliado_importer_credit_notes
        set
          remaining = remaining - v_cut,
          status = case
            when remaining - v_cut <= 0 then 'aplicado'
            else 'vigente'
          end,
          applied_checkout_group_id = case
            when remaining - v_cut <= 0 then p_group_id
            else applied_checkout_group_id
          end,
          applied_at = case
            when remaining - v_cut <= 0 then now()
            else applied_at
          end
        where id = v_note.id;
      v_left := v_left - v_cut;
    end loop;

    if v_applied > 0 then
      select coalesce(nullif(btrim(p.business_name), ''), 'La tienda')
        into v_shop
      from public.profiles p
      where p.id = v_uid;

      if v_shop is null or btrim(v_shop) = '' then
        v_shop := 'La tienda';
      end if;

      select tr.id
        into v_anchor
      from public.transaction_requests tr
      where tr.checkout_group_id = p_group_id
        and tr.importador_id = v_imp
        and tr.aliado_id = v_uid
      order by tr.created_at
      limit 1;

      perform public.mc_insert_notification (
        v_imp,
        v_shop || ' · Pedido con crédito',
        v_shop || ' aplicó ' || trim(to_char(v_applied, 'FM999999990.00'))
          || ' REF de saldo a favor en este pedido.',
        'pedido',
        coalesce(v_anchor, p_group_id)::text
      );
    end if;
  end loop;
end;
$$;

revoke all on function public.mc_apply_checkout_importer_credits (uuid, jsonb)
  from public, anon, authenticated;
