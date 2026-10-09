-- Borrar definitivo: si la cuenta tiene pedidos, el administrador puede
-- confirmar y se eliminan junto con la cuenta. Antes el borrado se rechazaba.

create or replace function public.owner_profile_related_orders (p_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_orders jsonb;
begin
  perform public._guard_account_operator_target (p_profile_id);

  select count(*)::integer
    into v_count
  from public.transaction_requests tr
  where tr.aliado_id = p_profile_id
     or tr.importador_id = p_profile_id;

  select coalesce(
    jsonb_agg(item.payload order by item.created_at desc),
    '[]'::jsonb
  )
    into v_orders
  from (
    select
      tr.created_at,
      jsonb_build_object(
        'id', tr.id,
        'status', tr.status,
        'created_at', tr.created_at,
        'product_name', coalesce(nullif(trim(pr.name), ''), 'Producto'),
        'counterparty_name', case
          when tr.aliado_id = p_profile_id then coalesce(
            nullif(trim(imp.business_name), ''),
            'Proveedor'
          )
          else coalesce(nullif(trim(ali.business_name), ''), 'Tienda')
        end,
        'side', case
          when tr.aliado_id = p_profile_id and tr.importador_id = p_profile_id
            then 'Pedido'
          when tr.aliado_id = p_profile_id then 'Como tienda'
          else 'Como proveedor'
        end
      ) as payload
    from public.transaction_requests tr
    left join public.products pr on pr.id = tr.product_id
    left join public.profiles ali on ali.id = tr.aliado_id
    left join public.profiles imp on imp.id = tr.importador_id
    where tr.aliado_id = p_profile_id
       or tr.importador_id = p_profile_id
    order by tr.created_at desc
    limit 40
  ) item;

  return jsonb_build_object(
    'count', coalesce(v_count, 0),
    'orders', v_orders
  );
end;
$$;

create or replace function public.owner_hard_delete_profile (
  p_profile_id uuid,
  p_confirm text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_confirm text := lower(trim(coalesce(p_confirm, '')));
begin
  perform public._guard_account_operator_target (p_profile_id);

  select lower(trim(u.email::text))
    into v_email
  from auth.users u
  where u.id = p_profile_id;

  if v_email is null then
    raise exception 'Usuario de Auth no encontrado';
  end if;

  if v_confirm is distinct from v_email then
    raise exception 'Escriba el correo de la cuenta para confirmar el borrado';
  end if;

  update public.promo_campaigns pc
  set action_type = 'none'
  where pc.importador_id = p_profile_id
     or pc.product_id in (
       select p.id from public.products p where p.owner_id = p_profile_id
     )
     or pc.product_ids && array(
       select p.id from public.products p where p.owner_id = p_profile_id
     );

  delete from public.order_ratings r
  where r.aliado_id = p_profile_id
     or r.importador_id = p_profile_id;

  update public.transaction_requests tr
  set commission_settlement_id = null
  where tr.commission_settlement_id in (
    select cs.id
    from public.commission_settlements cs
    where cs.importador_id = p_profile_id
  )
     or tr.aliado_id = p_profile_id
     or tr.importador_id = p_profile_id;

  delete from public.transaction_requests tr
  where tr.aliado_id = p_profile_id
     or tr.importador_id = p_profile_id;

  delete from public.commission_settlements cs
  where cs.importador_id = p_profile_id;

  update public.commission_settlements
  set created_by = null
  where created_by = p_profile_id;

  update public.commission_settlements
  set issued_by = null
  where issued_by = p_profile_id;

  update public.order_ratings
  set comment_hidden_by = null
  where comment_hidden_by = p_profile_id;

  update public.order_ratings
  set submitted_by_admin_id = null
  where submitted_by_admin_id = p_profile_id;

  update public.profile_documents
  set reviewed_by = null
  where reviewed_by = p_profile_id;

  update public.transaction_requests
  set confirmado_por = null
  where confirmado_por = p_profile_id;

  delete from public.products p
  where p.owner_id = p_profile_id;

  delete from auth.identities i
  where i.user_id = p_profile_id;

  delete from auth.users u
  where u.id = p_profile_id;

  if not found then
    raise exception 'No se pudo borrar el usuario de Auth';
  end if;
end;
$$;

revoke all on function public.owner_profile_related_orders (uuid) from public;
revoke all on function public.owner_hard_delete_profile (uuid, text) from public;

grant execute on function public.owner_profile_related_orders (uuid)
  to authenticated;
grant execute on function public.owner_hard_delete_profile (uuid, text)
  to authenticated;

comment on function public.owner_profile_related_orders (uuid) is
  'Pedidos en los que la cuenta es tienda o proveedor, para avisar antes del borrado definitivo.';

comment on function public.owner_hard_delete_profile (uuid, text) is
  'Borra la cuenta y, si los hay, sus pedidos, valoraciones y cortes. Libera el correo.';
