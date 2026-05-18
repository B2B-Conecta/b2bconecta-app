-- Postgres no define min(uuid). Elegimos la fila ancla por created_at + id.

create or replace function public.mc_tr_is_notification_anchor_row (
  p_row public.transaction_requests,
  p_scope text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_anchor uuid;
  v_anchor_row_id uuid;
begin
  v_anchor := public.mc_tr_notif_anchor_id (p_row);

  if p_scope = 'aliado_importador' then
    select tr.id
      into v_anchor_row_id
    from public.transaction_requests tr
    where tr.aliado_id = p_row.aliado_id
      and tr.importador_id = p_row.importador_id
      and public.mc_tr_notif_anchor_id (tr) = v_anchor
    order by tr.created_at asc, tr.id asc
    limit 1;

    return p_row.id = v_anchor_row_id;
  elsif p_scope = 'importador_comprobante' then
    select tr.id
      into v_anchor_row_id
    from public.transaction_requests tr
    where tr.importador_id = p_row.importador_id
      and public.mc_tr_notif_anchor_id (tr) = v_anchor
      and coalesce(tr.comprobante_pago_storage_path, '')
        = coalesce(p_row.comprobante_pago_storage_path, '')
    order by tr.created_at asc, tr.id asc
    limit 1;

    return p_row.id = v_anchor_row_id;
  end if;

  return true;
end;
$$;
