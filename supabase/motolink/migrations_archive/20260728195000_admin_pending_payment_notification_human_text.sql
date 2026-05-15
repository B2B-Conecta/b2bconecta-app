-- Notificación admin "Entrega con pago pendiente":
-- reemplazar cuerpo con texto legible (sin UUID), incluyendo contexto del aliado/pedido.

create or replace function public.notifications_humanize_admin_pending_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean;
  v_tr_id uuid;
  v_aliado_name text;
  v_is_master boolean;
  v_product_name text;
  v_label text;
begin
  if new.title is distinct from 'Entrega con pago pendiente' then
    return new;
  end if;
  if new.type is distinct from 'pago' then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = new.user_id and p.role = 'administrador'
  ) into v_is_admin;

  if not coalesce(v_is_admin, false) then
    return new;
  end if;

  begin
    v_tr_id := nullif(trim(coalesce(new.related_id, '')), '')::uuid;
  exception
    when others then
      return new;
  end;

  if v_tr_id is null then
    return new;
  end if;

  select
    a.business_name,
    coalesce(tr.is_master_order, false),
    pr.name
  into
    v_aliado_name,
    v_is_master,
    v_product_name
  from public.transaction_requests tr
  left join public.profiles a on a.id = tr.aliado_id
  left join public.products pr on pr.id = tr.product_id
  where tr.id = v_tr_id;

  if v_is_master then
    v_label := 'pedido multi-producto';
  else
    v_label := coalesce(nullif(trim(v_product_name), ''), 'pedido');
  end if;

  new.body :=
    format(
      'El aliado %s confirmó la recepción de %s; el pago aún no está aprobado por MotoLink.',
      coalesce(nullif(trim(v_aliado_name), ''), 'sin nombre'),
      v_label
    );

  return new;
end;
$$;

drop trigger if exists tr_notifications_humanize_admin_pending_payment on public.notifications;
create trigger tr_notifications_humanize_admin_pending_payment
before insert on public.notifications
for each row
execute procedure public.notifications_humanize_admin_pending_payment();
