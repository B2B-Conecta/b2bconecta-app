-- Alinea la postventa con el flujo comercial:
-- el aliado declara preferencia y evidencia, el importador aprueba o rechaza,
-- el crédito queda como saldo de la pareja y el cambio reserva stock.

alter table public.order_postventa_casos
  add column if not exists requested_resolution text,
  add column if not exists evidence jsonb not null default '[]'::jsonb,
  add column if not exists status text,
  add column if not exists rejection_note text;

update public.order_postventa_casos
set status = case
  when resolution = 'credito' then 'aprobada_credito'
  when resolution = 'cambio' then 'aprobada_cambio'
  else 'abierta'
end
where status is null;

alter table public.order_postventa_casos
  alter column status set default 'abierta';

alter table public.order_postventa_casos
  alter column status set not null;

comment on column public.order_postventa_casos.requested_resolution is
  'Preferencia de la tienda al abrir la devolución: credito o cambio.';
comment on column public.order_postventa_casos.evidence is
  'Fotos o video de la solicitud. Misma forma que los adjuntos del chat.';
comment on column public.order_postventa_casos.status is
  'abierta, aprobada_credito, aprobada_cambio o rechazada.';
comment on column public.order_postventa_casos.rejection_note is
  'Nota del proveedor cuando no acepta la devolución.';

alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_resolution_chk;
alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_requested_resolution_chk;
alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_evidence_chk;
alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_status_chk;
alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_rejection_note_chk;

alter table public.order_postventa_casos
  add constraint order_postventa_casos_requested_resolution_chk
  check (
    requested_resolution is null
    or requested_resolution in ('credito', 'cambio')
  );

alter table public.order_postventa_casos
  add constraint order_postventa_casos_evidence_chk
  check (public.order_message_attachments_ok(evidence));

alter table public.order_postventa_casos
  add constraint order_postventa_casos_status_chk
  check (status in (
    'abierta', 'aprobada_credito', 'aprobada_cambio', 'rechazada'
  ));

alter table public.order_postventa_casos
  add constraint order_postventa_casos_rejection_note_chk
  check (
    status <> 'rechazada'
    or char_length(btrim(coalesce(rejection_note, ''))) >= 3
  );

alter table public.order_postventa_casos
  add constraint order_postventa_casos_resolution_chk
  check (
    (
      status = 'abierta'
      and resolution is null
      and credit_amount is null
      and resolved_at is null
      and rejection_note is null
    )
    or (
      status = 'aprobada_cambio'
      and resolution = 'cambio'
      and credit_amount is null
      and resolved_at is not null
    )
    or (
      status = 'aprobada_credito'
      and resolution = 'credito'
      and credit_amount is not null
      and credit_amount >= 0
      and resolved_at is not null
    )
    or (
      status = 'rechazada'
      and resolution is null
      and credit_amount is null
      and resolved_at is not null
    )
  );

alter table public.transaction_requests
  drop constraint if exists transaction_requests_postventa_resolucion_chk;
alter table public.transaction_requests
  add constraint transaction_requests_postventa_resolucion_chk
  check (
    postventa_resolucion is null
    or (
      postventa_resolucion = 'cambio'
      and postventa_credito_monto is null
    )
    or (
      postventa_resolucion = 'credito'
      and postventa_credito_monto is not null
      and postventa_credito_monto >= 0
    )
    or (
      postventa_resolucion = 'rechazo'
      and postventa_credito_monto is null
    )
  );

alter table public.transaction_requests
  add column if not exists credito_aplicado_monto numeric(14, 4);

comment on column public.transaction_requests.credito_aplicado_monto is
  'Saldo a favor descontado de esta línea al confirmar el carrito.';

comment on column public.transaction_requests.postventa_resolucion is
  'cambio, credito o rechazo cuando el proveedor ya respondió la devolución.';

-- Stock libre = stock físico menos unidades reservadas para un cambio.
alter table public.products
  add column if not exists stock_reserved integer not null default 0;

alter table public.products
  drop constraint if exists products_stock_reserved_chk;
alter table public.products
  add constraint products_stock_reserved_chk
  check (stock_reserved >= 0);

comment on column public.products.stock_reserved is
  'Unidades apartadas para un cambio de producto. No se venden.';

alter table public.products
  drop column if exists stock_covers_min_order;

alter table public.products
  add column stock_covers_min_order boolean
  generated always as ((stock - stock_reserved) >= min_order_qty) stored;

comment on column public.products.stock_covers_min_order is
  'True si el stock libre (físico menos reservado) alcanza el mínimo de pedido.';

create index if not exists products_catalog_moq_idx
  on public.products (is_active, stock_covers_min_order)
  where is_active = true;

create or replace function public.mc_products_keep_reserved_within_stock ()
returns trigger
language plpgsql
as $$
begin
  if new.stock < 0 or new.stock_reserved < 0 then
    raise exception 'Stock inválido.';
  end if;
  if new.stock < new.stock_reserved then
    raise exception
      'Stock insuficiente: hay % unidad(es) disponible(s) para una línea del carrito.',
      greatest(old.stock - coalesce(old.stock_reserved, 0), 0);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_products_keep_reserved_within_stock on public.products;
create trigger trg_products_keep_reserved_within_stock
before update of stock, stock_reserved on public.products
for each row
execute function public.mc_products_keep_reserved_within_stock ();

create table if not exists public.aliado_importer_credit_notes (
  id uuid primary key default gen_random_uuid(),
  aliado_id uuid not null references public.profiles (id),
  importador_id uuid not null references public.profiles (id),
  caso_id uuid not null unique references public.order_postventa_casos (id),
  amount numeric(14, 4) not null check (amount > 0),
  remaining numeric(14, 4) not null check (remaining >= 0 and remaining <= amount),
  status text not null default 'vigente'
    check (status in ('vigente', 'aplicado', 'anulado')),
  applied_checkout_group_id uuid,
  applied_at timestamptz,
  erp_reference text,
  erp_sync_status text not null default 'pendiente'
    check (erp_sync_status in ('pendiente', 'enviado', 'error')),
  created_at timestamptz not null default now()
);

comment on table public.aliado_importer_credit_notes is
  'Saldo a favor de una tienda con un importador. No es cupo de plataforma.';

create index if not exists aliado_importer_credit_notes_pair_idx
  on public.aliado_importer_credit_notes (aliado_id, importador_id)
  where status = 'vigente';

insert into public.aliado_importer_credit_notes (
  aliado_id,
  importador_id,
  caso_id,
  amount,
  remaining,
  status,
  erp_reference
)
select
  tr.aliado_id,
  tr.importador_id,
  c.id,
  c.credit_amount,
  c.credit_amount,
  'vigente',
  'NC-' || left(c.id::text, 8)
from public.order_postventa_casos c
join public.transaction_requests tr on tr.id = c.transaction_request_id
where c.status = 'aprobada_credito'
  and c.credit_amount > 0
  and tr.aliado_id is not null
  and tr.importador_id is not null
on conflict (caso_id) do nothing;

create table if not exists public.replacement_orders (
  id uuid primary key default gen_random_uuid(),
  caso_id uuid not null unique references public.order_postventa_casos (id),
  source_transaction_request_id uuid not null
    references public.transaction_requests (id),
  product_id uuid references public.products (id),
  qty integer not null check (qty >= 1),
  commercial_amount numeric(14, 4) not null default 0
    check (commercial_amount = 0),
  status text not null default 'pendiente_retiro'
    check (status in (
      'pendiente_retiro', 'en_transito', 'entregado', 'cancelado'
    )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.replacement_orders is
  'Sub-orden de cambio, sin costo comercial, con seguimiento propio.';

alter table public.aliado_importer_credit_notes enable row level security;
alter table public.replacement_orders enable row level security;

drop policy if exists aliado_importer_credit_notes_select
  on public.aliado_importer_credit_notes;
create policy aliado_importer_credit_notes_select
  on public.aliado_importer_credit_notes
  for select
  to authenticated
  using (
    aliado_id = auth.uid()
    or importador_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'administrador'
    )
  );

drop policy if exists replacement_orders_select on public.replacement_orders;
create policy replacement_orders_select
  on public.replacement_orders
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.transaction_requests tr
      where tr.id = source_transaction_request_id
        and (
          tr.aliado_id = auth.uid()
          or tr.importador_id = auth.uid()
          or exists (
            select 1
            from public.profiles p
            where p.id = auth.uid()
              and p.role = 'administrador'
          )
        )
    )
  );

revoke all on table public.aliado_importer_credit_notes from public;
revoke all on table public.replacement_orders from public;
grant select on table public.aliado_importer_credit_notes to authenticated;
grant select on table public.replacement_orders to authenticated;

drop function if exists public.register_order_postventa_caso (uuid, text, text, integer);
drop function if exists public.register_order_postventa_caso (uuid, text, text);

create or replace function public.register_order_postventa_caso (
  p_request_id uuid,
  p_kind text,
  p_body text,
  p_affected_qty integer default null,
  p_requested_resolution text default null,
  p_evidence jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tr public.transaction_requests%rowtype;
  v_role text;
  v_kind text := lower(btrim(coalesce(p_kind, '')));
  v_body text := btrim(coalesce(p_body, ''));
  v_pref text := lower(btrim(coalesce(p_requested_resolution, '')));
  v_evidence jsonb := coalesce(p_evidence, '[]'::jsonb);
  v_anchor timestamptz;
  v_id uuid;
  v_at timestamptz := now();
  v_title text;
  v_qty integer;
  v_product_name text;
  v_pref_label text;
  v_message text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_kind not in ('devolucion', 'queja') then
    raise exception 'Indique si es una devolución o una queja.';
  end if;
  if char_length(v_body) < 3 then
    raise exception 'Escriba qué ocurrió (mínimo 3 caracteres).';
  end if;
  if not public.order_message_attachments_ok(v_evidence) then
    raise exception 'La evidencia no es válida. Use hasta 3 fotos o 1 video.';
  end if;

  select *
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_tr.aliado_id = v_uid then
    v_role := 'aliado';
  elsif v_tr.importador_id = v_uid then
    v_role := 'importador';
  else
    raise exception 'Solo la tienda o el proveedor de este pedido pueden registrarlo.';
  end if;

  if v_kind = 'devolucion' and v_role <> 'aliado' then
    raise exception 'Solo la tienda puede solicitar la devolución.';
  end if;

  if v_tr.status <> 'entregado' then
    raise exception 'Solo se registra en un pedido entregado.';
  end if;

  v_anchor := coalesce(v_tr.at_entregado, v_tr.updated_at);
  if v_anchor is null or v_anchor < now() - interval '7 days' then
    raise exception 'El plazo de 7 días para una devolución o una queja terminó.';
  end if;

  if exists (
    select 1
    from public.order_postventa_casos c
    where c.transaction_request_id = p_request_id
      and c.kind = v_kind
  ) then
    raise exception 'Eso ya quedó registrado en este pedido.';
  end if;

  if v_kind = 'devolucion' then
    if v_pref not in ('credito', 'cambio') then
      raise exception 'Elija crédito a favor o cambio de producto.';
    end if;
    if jsonb_array_length(v_evidence) < 1 then
      raise exception 'Adjunte al menos una foto o un video.';
    end if;
    if exists (
      select 1
      from jsonb_array_elements(v_evidence) e
      where split_part(coalesce(e ->> 'path', ''), '/', 1)
        is distinct from p_request_id::text
    ) then
      raise exception 'La evidencia no corresponde a este pedido.';
    end if;
  else
    v_pref := null;
    v_evidence := '[]'::jsonb;
  end if;

  v_qty := coalesce(p_affected_qty, nullif(v_tr.cantidad, 0), 1);
  if v_qty < 1 then
    v_qty := 1;
  end if;
  if coalesce(v_tr.cantidad, 0) > 0 and v_qty > v_tr.cantidad then
    raise exception 'La cantidad no puede superar las unidades de este producto en el pedido.';
  end if;

  select nullif(btrim(p.name), '')
    into v_product_name
  from public.products p
  where p.id = v_tr.product_id;

  if v_product_name is null then
    v_product_name := 'Producto del pedido';
  end if;

  insert into public.order_postventa_casos (
    transaction_request_id,
    kind,
    body,
    opened_by,
    opened_role,
    created_at,
    product_id,
    product_name,
    affected_qty,
    requested_resolution,
    evidence,
    status
  )
  values (
    p_request_id,
    v_kind,
    v_body,
    v_uid,
    v_role,
    v_at,
    v_tr.product_id,
    v_product_name,
    v_qty,
    nullif(v_pref, ''),
    v_evidence,
    'abierta'
  )
  returning id into v_id;

  if v_kind = 'devolucion' then
    update public.transaction_requests
      set postventa_devolucion_at = v_at
      where id = p_request_id;
    v_title := 'Solicitud de devolución';
    v_pref_label := case v_pref
      when 'credito' then 'crédito a favor'
      else 'cambio de producto'
    end;
    v_message := v_title
      || '. Preferencia: '
      || v_pref_label
      || '. Producto: '
      || v_product_name
      || '. Unidades: '
      || v_qty::text
      || '. '
      || v_body;
  else
    update public.transaction_requests
      set postventa_queja_at = v_at
      where id = p_request_id;
    v_title := 'Queja registrada';
    v_message := v_title
      || ' en este pedido. Producto: '
      || v_product_name
      || '. Unidades: '
      || v_qty::text
      || '. '
      || v_body;
  end if;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body,
    attachments
  )
  values (
    p_request_id,
    v_uid,
    v_role,
    v_message,
    v_evidence
  );

  return jsonb_build_object(
    'id', v_id,
    'kind', v_kind,
    'body', v_body,
    'opened_role', v_role,
    'created_at', v_at,
    'product_id', v_tr.product_id,
    'product_name', v_product_name,
    'affected_qty', v_qty,
    'requested_resolution', nullif(v_pref, ''),
    'status', 'abierta'
  );
end;
$$;

revoke all on function public.register_order_postventa_caso (
  uuid, text, text, integer, text, jsonb
) from public;
grant execute on function public.register_order_postventa_caso (
  uuid, text, text, integer, text, jsonb
) to authenticated;

drop function if exists public.resolve_order_postventa_caso (uuid, text);

create or replace function public.resolve_order_postventa_caso (
  p_request_id uuid,
  p_resolution text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tr public.transaction_requests%rowtype;
  v_caso public.order_postventa_casos%rowtype;
  v_resolution text := lower(btrim(coalesce(p_resolution, '')));
  v_note text := btrim(coalesce(p_note, ''));
  v_qty integer;
  v_unit numeric;
  v_credit numeric(14, 4);
  v_at timestamptz := now();
  v_product text;
  v_amount_label text;
  v_body text;
  v_title text;
  v_status text;
  v_note_id uuid;
  v_free integer;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_resolution not in ('cambio', 'credito', 'rechazo') then
    raise exception 'Indique crédito, cambio de producto o rechazo.';
  end if;
  if v_resolution = 'rechazo' and char_length(v_note) < 3 then
    raise exception 'Escriba por qué no acepta la devolución.';
  end if;

  select *
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_tr.importador_id is distinct from v_uid then
    raise exception 'Solo el proveedor de este pedido puede responder la devolución.';
  end if;

  select *
    into v_caso
  from public.order_postventa_casos c
  where c.transaction_request_id = p_request_id
    and c.kind = 'devolucion'
  for update;

  if not found then
    raise exception 'Primero tiene que existir una devolución registrada.';
  end if;

  if v_caso.status is distinct from 'abierta' or v_caso.resolution is not null then
    raise exception 'Esta devolución ya tiene una respuesta.';
  end if;

  v_qty := coalesce(v_caso.affected_qty, nullif(v_tr.cantidad, 0), 1);
  if v_qty < 1 then
    v_qty := 1;
  end if;

  v_unit := coalesce(v_tr.precio_unitario_aliado, 0);
  if v_unit <= 0 and coalesce(v_tr.cantidad, 0) > 0 then
    v_unit := coalesce(v_tr.precio_total_usd, 0) / v_tr.cantidad;
  end if;
  if v_unit < 0 then
    v_unit := 0;
  end if;

  v_product := coalesce(nullif(btrim(v_caso.product_name), ''), 'el producto');

  if v_resolution = 'credito' then
    v_credit := round(v_unit * v_qty, 4);
    if v_credit <= 0 then
      raise exception 'Este producto no tiene un monto para dejar como crédito.';
    end if;
    v_status := 'aprobada_credito';
    v_title := 'Crédito a favor';
    v_amount_label := trim(to_char(v_credit, 'FM999999990.00'));
    v_body := 'Crédito de '
      || v_amount_label
      || ' REF a favor de esta tienda para el próximo pedido con usted. Producto: '
      || v_product
      || '. Unidades: '
      || v_qty::text
      || '.';
  elsif v_resolution = 'cambio' then
    if v_caso.product_id is null then
      raise exception 'Este producto ya no está en el catálogo. No se puede reservar el cambio.';
    end if;
    select pr.stock - pr.stock_reserved
      into v_free
    from public.products pr
    where pr.id = v_caso.product_id
    for update;
    if v_free is null or v_free < v_qty then
      raise exception 'No hay stock libre para reservar el cambio.';
    end if;
    update public.products
      set stock_reserved = stock_reserved + v_qty
      where id = v_caso.product_id;
    v_credit := null;
    v_status := 'aprobada_cambio';
    v_title := 'Cambio de producto';
    v_body := 'El proveedor enviará el cambio sin costo. Producto: '
      || v_product
      || '. Unidades: '
      || v_qty::text
      || '. Queda pendiente de retiro.';
  else
    v_credit := null;
    v_status := 'rechazada';
    v_title := 'Devolución no aceptada';
    v_body := 'El proveedor no aceptó la devolución. ' || v_note;
  end if;

  update public.order_postventa_casos
    set
      resolution = case when v_resolution = 'rechazo' then null else v_resolution end,
      credit_amount = v_credit,
      resolved_at = v_at,
      resolved_by = v_uid,
      status = v_status,
      rejection_note = case when v_resolution = 'rechazo' then v_note else null end
    where id = v_caso.id;

  update public.transaction_requests
    set
      postventa_resolucion = v_resolution,
      postventa_credito_monto = v_credit
    where id = p_request_id;

  if v_resolution = 'credito' then
    insert into public.aliado_importer_credit_notes (
      aliado_id,
      importador_id,
      caso_id,
      amount,
      remaining,
      status,
      erp_reference
    )
    values (
      v_tr.aliado_id,
      v_tr.importador_id,
      v_caso.id,
      v_credit,
      v_credit,
      'vigente',
      'NC-' || left(v_caso.id::text, 8)
    )
    returning id into v_note_id;
  elsif v_resolution = 'cambio' then
    insert into public.replacement_orders (
      caso_id,
      source_transaction_request_id,
      product_id,
      qty,
      commercial_amount,
      status
    )
    values (
      v_caso.id,
      p_request_id,
      v_caso.product_id,
      v_qty,
      0,
      'pendiente_retiro'
    );
  end if;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body
  )
  values (
    p_request_id,
    v_uid,
    'importador',
    v_body
  );

  return jsonb_build_object(
    'id', v_caso.id,
    'resolution', v_resolution,
    'status', v_status,
    'credit_amount', v_credit,
    'credit_note_id', v_note_id,
    'resolved_at', v_at,
    'affected_qty', v_qty,
    'product_name', v_product,
    'rejection_note', case when v_resolution = 'rechazo' then v_note else null end
  );
end;
$$;

revoke all on function public.resolve_order_postventa_caso (uuid, text, text) from public;
grant execute on function public.resolve_order_postventa_caso (uuid, text, text) to authenticated;

create or replace function public.advance_replacement_order (
  p_caso_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.replacement_orders%rowtype;
  v_next text := lower(btrim(coalesce(p_status, '')));
  v_tr public.transaction_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_next not in ('en_transito', 'entregado') then
    raise exception 'Indique si el cambio va en tránsito o ya se entregó.';
  end if;

  select *
    into v_row
  from public.replacement_orders r
  where r.caso_id = p_caso_id
  for update;

  if not found then
    raise exception 'No hay un cambio de producto para este caso.';
  end if;

  select *
    into v_tr
  from public.transaction_requests tr
  where tr.id = v_row.source_transaction_request_id;

  if v_tr.importador_id is distinct from v_uid then
    raise exception 'Solo el proveedor puede actualizar el envío del cambio.';
  end if;

  if v_row.status = 'pendiente_retiro' and v_next = 'en_transito' then
    null;
  elsif v_row.status = 'en_transito' and v_next = 'entregado' then
    if v_row.product_id is not null then
      update public.products
        set
          stock = stock - v_row.qty,
          stock_reserved = stock_reserved - v_row.qty
        where id = v_row.product_id
          and stock >= v_row.qty
          and stock_reserved >= v_row.qty;
      if not found then
        raise exception 'No se pudo descontar el stock del cambio.';
      end if;
    end if;
  else
    raise exception 'Ese paso no corresponde al estado actual del cambio.';
  end if;

  update public.replacement_orders
    set status = v_next, updated_at = now()
    where id = v_row.id;

  perform public.mc_insert_notification (
    v_tr.aliado_id,
    case v_next
      when 'entregado' then 'Cambio entregado'
      else 'Cambio en tránsito'
    end,
    case v_next
      when 'entregado' then 'El cambio de producto ya fue entregado.'
      else 'El cambio de producto va en camino.'
    end,
    'pedido',
    public.mc_tr_notif_anchor_id (v_tr)::text
  );

  return jsonb_build_object('id', v_row.id, 'status', v_next);
end;
$$;

revoke all on function public.advance_replacement_order (uuid, text) from public;
grant execute on function public.advance_replacement_order (uuid, text) to authenticated;

create or replace function public.aliado_importer_credit_balances ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'importador_id', n.importador_id,
        'importer_name', coalesce(nullif(btrim(p.business_name), ''), 'Importador'),
        'remaining', n.remaining
      )
    ),
    '[]'::jsonb
  )
  from (
    select importador_id, sum(remaining) as remaining
    from public.aliado_importer_credit_notes
    where aliado_id = auth.uid()
      and status = 'vigente'
      and remaining > 0
    group by importador_id
  ) n
  join public.profiles p on p.id = n.importador_id;
$$;

revoke all on function public.aliado_importer_credit_balances () from public;
grant execute on function public.aliado_importer_credit_balances () to authenticated;

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
  end loop;
end;
$$;

revoke all on function public.mc_apply_checkout_importer_credits (uuid, jsonb)
  from public, anon, authenticated;

drop function if exists public.aliado_checkout_multi_importador (
  jsonb, boolean, text, text, jsonb, jsonb
);

create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null,
  p_promo_by_importador jsonb default '{}'::jsonb,
  p_carriers_by_importador jsonb default '{}'::jsonb,
  p_apply_credit_by_importador jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group text;
begin
  perform public.mc_assert_cart_min_order_amounts (p_lines);
  v_group := public.aliado_checkout_multi_importador_impl (
    p_lines,
    p_destino_entrega_usa_perfil,
    p_destino_entrega_texto,
    p_destino_entrega_maps_url,
    p_promo_by_importador,
    p_carriers_by_importador
  );
  perform public.mc_apply_checkout_importer_credits (
    v_group::uuid,
    coalesce(p_apply_credit_by_importador, '{}'::jsonb)
  );
  return v_group;
end;
$$;

comment on function public.aliado_checkout_multi_importador (
  jsonb, boolean, text, text, jsonb, jsonb, jsonb
) is
  'Checkout aliado: pedido mínimo, precios y saldo a favor de la pareja si se marcó.';

grant execute on function public.aliado_checkout_multi_importador (
  jsonb, boolean, text, text, jsonb, jsonb, jsonb
) to authenticated;

create or replace function public.admin_postventa_resumen ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_importers jsonb;
  v_casos jsonb;
begin
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'administrador'
  ) then
    raise exception 'Solo B2B Conecta puede ver este reporte.';
  end if;

  select coalesce(jsonb_agg(row_to_json(s)::jsonb order by s.devoluciones desc), '[]'::jsonb)
    into v_importers
  from (
    select
      tr.importador_id,
      coalesce(nullif(btrim(imp.business_name), ''), 'Importador') as importer_name,
      count(*) filter (where c.kind = 'devolucion')::integer as devoluciones,
      count(*) filter (
        where c.kind = 'devolucion' and c.status = 'abierta'
      )::integer as abiertas,
      count(*) filter (where c.status = 'aprobada_credito')::integer as creditos,
      count(*) filter (where c.status = 'aprobada_cambio')::integer as cambios,
      count(*) filter (where c.status = 'rechazada')::integer as rechazadas,
      coalesce(sum(n.remaining) filter (where n.status = 'vigente'), 0) as saldo_vigente
    from public.order_postventa_casos c
    join public.transaction_requests tr on tr.id = c.transaction_request_id
    left join public.profiles imp on imp.id = tr.importador_id
    left join public.aliado_importer_credit_notes n on n.caso_id = c.id
    where c.kind = 'devolucion'
    group by tr.importador_id, imp.business_name
  ) s;

  select coalesce(jsonb_agg(row_to_json(d)::jsonb), '[]'::jsonb)
    into v_casos
  from (
    select
      c.id,
      c.created_at,
      c.status,
      c.requested_resolution,
      c.product_name,
      c.affected_qty,
      c.credit_amount,
      c.rejection_note,
      coalesce(nullif(btrim(imp.business_name), ''), 'Importador') as importer_name,
      coalesce(nullif(btrim(ali.business_name), ''), 'Tienda') as aliado_name,
      n.remaining,
      n.erp_reference,
      n.erp_sync_status,
      r.status as replacement_status
    from public.order_postventa_casos c
    join public.transaction_requests tr on tr.id = c.transaction_request_id
    left join public.profiles imp on imp.id = tr.importador_id
    left join public.profiles ali on ali.id = tr.aliado_id
    left join public.aliado_importer_credit_notes n on n.caso_id = c.id
    left join public.replacement_orders r on r.caso_id = c.id
    where c.kind = 'devolucion'
    order by c.created_at desc
    limit 80
  ) d;

  return jsonb_build_object(
    'importers', coalesce(v_importers, '[]'::jsonb),
    'casos', coalesce(v_casos, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_postventa_resumen () from public;
grant execute on function public.admin_postventa_resumen () to authenticated;
