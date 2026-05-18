-- =============================================================================
-- MotoConecta — esquema (greenfield, alineado a la app Flutter)
-- =============================================================================
-- Tablas: profiles, products, transaction_requests, transaction_request_messages,
--         notifications (centro de notificaciones + Realtime).
-- No sub_orders, payment_schedule, transportista ni tablas broker MotoLink.
--
-- Orden: SQL Editor en proyecto vacío, o vía `supabase db reset` (migración baseline).
-- =============================================================================

create extension if not exists pgcrypto;

-- Orden de borrado: dependientes primero (no usar DROP TRIGGER antes: en base vacía
-- la tabla aún no existe y Postgres falla aunque el trigger sea IF EXISTS).
drop table if exists public.transaction_request_messages cascade;
drop table if exists public.notifications cascade;
drop table if exists public.messages cascade;
drop table if exists public.transaction_requests cascade;
drop table if exists public.products cascade;
drop table if exists public.profiles cascade;

-- 1. Perfiles
create table public.profiles (
  id uuid not null references auth.users (id) on delete cascade primary key,
  business_name text,
  rif text unique,
  role text not null
    check (role = any (array['importador'::text, 'aliado'::text, 'administrador'::text])),
  phone text,
  logo_storage_path text,
  estado text,
  ciudad text,
  direccion text,
  fiscal_maps_url text,
  primeros_pedidos_contado_entregados integer default 0,
  pedidos_suspendidos_morosidad boolean default false,
  kyc_status text,
  credit_limit numeric(14, 4),
  credito_consumido_acumulado numeric(14, 4) default 0,
  commission_rate_pct numeric(8, 6)
    check (
      commission_rate_pct is null
      or (commission_rate_pct >= 0 and commission_rate_pct <= 1)
    ),
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  created_at timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

-- 2. Productos (columnas opcionales usadas por PartModel / catálogo)
create table public.products (
  id uuid not null default gen_random_uuid () primary key,
  owner_id uuid references public.profiles (id) on delete set null,
  name text not null,
  sku text not null default ''::text,
  description text,
  compatibility text,
  image_url text,
  category text,
  price_usd numeric(14, 4) not null check (price_usd >= 0),
  stock integer not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  discount_rules jsonb
);

create index products_owner_idx on public.products (owner_id);
create index products_active_idx on public.products (is_active) where is_active = true;

create table public.platform_settings (
  key text not null primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.platform_settings (key, value)
values ('default_commission_rate', '0.05'::jsonb);

create table public.commission_settlements (
  id uuid not null default gen_random_uuid () primary key,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  period_start date not null,
  period_end date not null,
  total_commission_usd numeric(14, 4) not null default 0
    check (total_commission_usd >= 0),
  line_count integer not null default 0 check (line_count >= 0),
  status text not null default 'borrador'
    check (status = any (array['borrador'::text, 'emitido'::text, 'pagado'::text, 'anulado'::text])),
  invoice_reference text,
  issued_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles (id),
  pago_comprobante_storage_path text,
  pago_comprobante_file_name text,
  pago_comprobante_submitted_at timestamptz,
  pago_estado_revision text
    check (
      pago_estado_revision is null
      or pago_estado_revision = any (
        array[
          'pendiente'::text,
          'en_revision'::text,
          'aprobado'::text,
          'rechazado'::text
        ]
      )
    ),
  pago_rechazo_nota text,
  invoice_pdf_storage_path text,
  invoice_pdf_file_name text,
  constraint commission_settlements_period_chk check (period_end >= period_start),
  constraint commission_settlements_importador_week_uniq unique (importador_id, period_start, period_end)
);

create index commission_settlements_importador_idx
  on public.commission_settlements (importador_id, period_start desc);

-- 3. Pedidos directos
create table public.transaction_requests (
  id uuid not null default gen_random_uuid () primary key,
  aliado_id uuid not null references public.profiles (id) on delete restrict,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  product_id uuid references public.products (id) on delete set null,
  status text not null default 'pendiente'
    check (
      status = any (
        array[
          'pendiente'::text,
          'aprobado_admin'::text,
          'en_preparacion'::text,
          'pedido_listo'::text,
          'en_transito'::text,
          'enviado'::text,
          'entregado'::text,
          'rechazado'::text
        ]
      )
    ),
  cantidad integer not null check (cantidad > 0),
  precio_total_usd numeric(14, 4) not null check (precio_total_usd >= 0),
  commission_rate_snapshot numeric(8, 6) not null default 0.05,
  comision_devengada_usd numeric(14, 4),
  comision_devengada_at timestamptz,
  commission_settlement_id uuid references public.commission_settlements (id),
  factura_url text,
  proveedor_factura_storage_path text,
  proveedor_factura_file_name text,
  proveedor_factura_submitted_at timestamptz,
  tiempo_estimado_envio text,
  pago_metodo text,
  comprobante_pago_storage_path text,
  comprobante_pago_file_name text,
  comprobante_pago_submitted_at timestamptz,
  pago_estado_revision text,
  pago_comprobante_rechazo_nota text,
  pago_aprobado_at timestamptz,
  destino_entrega_usa_perfil boolean default true,
  destino_entrega_texto text,
  destino_entrega_maps_url text,
  checkout_group_id uuid,
  discount_rules jsonb,
  confirmado_por uuid references public.profiles (id),
  aliado_experience_stars integer,
  aliado_experience_comment text,
  aliado_experience_submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index transaction_requests_aliado_idx on public.transaction_requests (aliado_id);
create index transaction_requests_importador_idx on public.transaction_requests (importador_id);
create index transaction_requests_status_idx on public.transaction_requests (status);
create index transaction_requests_product_idx on public.transaction_requests (product_id);

-- 4. Chat por pedido (misma API PostgREST que usa Flutter: transaction_request_messages)
create table public.transaction_request_messages (
  id uuid not null default gen_random_uuid () primary key,
  transaction_request_id uuid not null references public.transaction_requests (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_role text not null
    check (
      author_role = any (
        array[
          'aliado'::text,
          'importador'::text,
          'administrador'::text,
          'transportista'::text
        ]
      )
    ),
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index transaction_request_messages_tr_idx on public.transaction_request_messages (
  transaction_request_id,
  created_at desc
);

-- 5. Notificaciones in-app
create table public.notifications (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'mensaje',
  is_read boolean not null default false,
  related_id text,
  created_at timestamptz not null default now ()
);

create index notifications_user_created_idx on public.notifications (user_id, created_at desc);

-- updated_at en pedidos
create or replace function public.set_transaction_requests_updated_at ()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger transaction_requests_set_updated_at
before update on public.transaction_requests
for each row
execute function public.set_transaction_requests_updated_at ();

-- Notificación al destinatario cuando hay mensaje en el hilo del pedido
create or replace function public.mc_notify_trm_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
begin
  perform set_config ('row_security', 'off', true);

  select tr.aliado_id, tr.importador_id
    into v_aliado, v_imp
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  if new.author_role = 'aliado' and v_imp is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_imp,
      'Nuevo mensaje',
      'Tiene un nuevo mensaje en un pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'importador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje del importador',
      'Tiene un nuevo mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'administrador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje',
      'El equipo dejó un mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
    if v_imp is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_imp,
        'Nuevo mensaje',
        'El equipo dejó un mensaje en un pedido.',
        'mensaje',
        new.transaction_request_id::text
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_mc_notify_trm_insert
after insert on public.transaction_request_messages
for each row
execute function public.mc_notify_trm_insert ();

-- Nuevo pedido → notificación al importador (una por importador y carrito si hay checkout_group_id)
create or replace function public.mc_notify_tr_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_es_duplicado_misma_linea_importador boolean;
begin
  perform set_config ('row_security', 'off', true);

  if new.checkout_group_id is not null then
    select exists (
      select 1
      from public.transaction_requests tr
      where tr.checkout_group_id = new.checkout_group_id
        and tr.importador_id = new.importador_id
        and tr.id <> new.id
    )
    into v_es_duplicado_misma_linea_importador;

    if v_es_duplicado_misma_linea_importador then
      return new;
    end if;
  end if;

  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.importador_id,
    'Nuevo pedido',
    'Un aliado solicitó un pedido. Revíselo en Pedidos.',
    'pedido',
    new.id::text
  );
  return new;
end;
$$;

create trigger trg_mc_notify_tr_insert
after insert on public.transaction_requests
for each row
execute function public.mc_notify_tr_insert ();

-- Cambio de estado → notificación al aliado o al importador
create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config ('row_security', 'off', true);

  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  )
  then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      case new.status
        when 'en_preparacion' then 'Pedido en preparación'
        when 'pedido_listo' then 'Listo para despacho'
        when 'en_transito' then 'Pedido en tránsito'
        else 'Actualización de pedido'
      end,
      case new.status
        when 'en_preparacion' then
          'El importador confirmó la solicitud y está preparando tu pedido.'
        when 'pedido_listo' then
          'El importador marcó el pedido como listo para despacho.'
        when 'en_transito' then
          'El pedido fue despachado y va en camino a tu taller.'
        else
          'Hay un cambio de estado en su pedido.'
      end,
      'pedido',
      new.id::text
    );
  elsif new.status = 'entregado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Pedido recibido en taller',
      'El aliado confirmó la recepción del pedido en su taller.',
      'pedido',
      new.id::text
    );
  elsif new.status = 'rechazado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Pedido rechazado',
      'Un pedido pasó a rechazado. Revíselo en Pedidos.',
      'pedido',
      new.id::text
    );
  end if;

  insert into public.notifications (user_id, title, body, type, related_id)
  select
    adm.id,
    'Supervisión · cambio de estado',
    format (
      'Pedido %s: %s → %s',
      substring (new.id::text, 1, 8) || '…',
      old.status,
      new.status
    ),
    'supervision',
    new.id::text
  from public.profiles adm
  where adm.role = 'administrador';

  return new;
end;
$$;

create trigger trg_mc_notify_tr_status
after update of status on public.transaction_requests
for each row
execute function public.mc_notify_tr_status_changed ();

-- Notificaciones: factura proveedor, comprobante y revisión de pago (tipo «pago»)
create or replace function public.mc_insert_notification (
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_related_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  if p_title is null or length(trim(p_title)) = 0 then
    return;
  end if;
  perform set_config ('row_security', 'off', true);
  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    p_user_id,
    trim(p_title),
    coalesce(nullif(trim(p_body), ''), trim(p_title)),
    coalesce(nullif(trim(p_type), ''), 'pago'),
    nullif(trim(p_related_id), '')
  );
end;
$$;

create or replace function public.mc_tr_notif_anchor_id (p_row public.transaction_requests)
returns uuid
language sql
immutable
as $$
  select coalesce(p_row.checkout_group_id, p_row.id);
$$;

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

create or replace function public.mc_notify_tr_pago_y_factura ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_aliado_name text;
  v_anchor text;
  v_nota text;
begin
  perform set_config ('row_security', 'off', true);

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;

  if new.proveedor_factura_storage_path is not null
     and length(trim(new.proveedor_factura_storage_path)) > 0
     and (
       old.proveedor_factura_storage_path is null
       or length(trim(old.proveedor_factura_storage_path)) = 0
       or old.proveedor_factura_storage_path is distinct from new.proveedor_factura_storage_path
     )
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    perform public.mc_insert_notification (
      new.aliado_id,
      case
        when old.proveedor_factura_storage_path is not null
             and length(trim(old.proveedor_factura_storage_path)) > 0
          then 'Factura del proveedor actualizada'
        else 'Factura del proveedor disponible'
      end,
      format(
        '%s adjuntó su factura%s. Revise el monto y registre su pago en Pedidos.',
        coalesce(v_imp_name, 'El importador'),
        case
          when new.checkout_group_id is not null then ' para su bloque en este carrito'
          else ''
        end
      ),
      'pago',
      v_anchor
    );
  end if;

  if new.pago_estado_revision = 'en_revision'
     and old.pago_estado_revision is distinct from 'en_revision'
     and new.comprobante_pago_storage_path is not null
     and length(trim(new.comprobante_pago_storage_path)) > 0
     and public.mc_tr_is_notification_anchor_row (new, 'importador_comprobante') then
    perform public.mc_insert_notification (
      new.importador_id,
      'Comprobante de pago recibido',
      format(
        '%s adjuntó un comprobante para revisar%s.',
        coalesce(v_aliado_name, 'El aliado'),
        case
          when new.checkout_group_id is not null then ' (varias líneas del mismo carrito)'
          else ''
        end
      ),
      'pago',
      new.id::text
    );
  end if;

  if new.pago_estado_revision is distinct from old.pago_estado_revision
     and new.pago_estado_revision in ('aprobado', 'rechazado')
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    v_nota := nullif(trim(new.pago_comprobante_rechazo_nota), '');

    if new.pago_estado_revision = 'aprobado' then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Pago confirmado por el importador',
        format(
          '%s confirmó su comprobante de pago.',
          coalesce(v_imp_name, 'El importador')
        ),
        'pago',
        v_anchor
      );
    else
      perform public.mc_insert_notification (
        new.aliado_id,
        'Comprobante de pago rechazado',
        format(
          '%s no aprobó su comprobante.%s',
          coalesce(v_imp_name, 'El importador'),
          case
            when v_nota is not null then ' Motivo: ' || v_nota
            else ' Revise el pedido y adjunte un nuevo comprobante si corresponde.'
          end
        ),
        'pago',
        v_anchor
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_mc_notify_tr_pago_y_factura
after update on public.transaction_requests
for each row
execute function public.mc_notify_tr_pago_y_factura ();

-- Aliado: confirma recepción (en tránsito / legado enviado → entregado)
create or replace function public.aliado_marca_pedido_entregado (p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.transaction_requests tr
  set status = 'entregado'::text
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ()
    and tr.status = any (array['en_transito'::text, 'enviado'::text]);

  if not found then
    raise exception
      'No se puede marcar como entregado (estado o permiso inválido).'
      using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.aliado_marca_pedido_entregado (uuid) to authenticated;

-- Realtime (ignora error si la publicación no existe en entornos mínimos)
do $$
begin
  begin
    alter publication supabase_realtime add table public.notifications;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.transaction_request_messages;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

-- Consumo de cupo: suma de pedidos activos (USD). RPC usada por la app (pestaña Pedidos aliado).
create or replace function public.aliado_effective_open_exposure (p_aliado_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    return 0;
  end if;
  if auth.uid () is distinct from p_aliado_id
     and not exists (
       select 1
       from public.profiles p
       where p.id = auth.uid ()
         and p.role = 'administrador'
     ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return coalesce(
    (
      select sum(tr.precio_total_usd)::numeric
      from public.transaction_requests tr
      where tr.aliado_id = p_aliado_id
        and tr.status = any (
          array[
            'pendiente'::text,
            'en_preparacion'::text,
            'pedido_listo'::text,
            'en_transito'::text,
            'enviado'::text
          ]
        )
    ),
    0::numeric
  );
end;
$$;

grant execute on function public.aliado_effective_open_exposure (uuid) to authenticated;
grant execute on function public.aliado_effective_open_exposure (uuid) to service_role;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.transaction_requests enable row level security;
alter table public.transaction_request_messages enable row level security;
alter table public.notifications enable row level security;

create policy profiles_select_authenticated
  on public.profiles for select
  to authenticated
  using (true);

create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = auth.uid ())
  with check (id = auth.uid ());

create policy profiles_insert_own
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid ());

create policy products_select_marketplace
  on public.products for select
  to authenticated
  using (is_active = true or owner_id = auth.uid ());

create policy products_insert_owner
  on public.products for insert
  to authenticated
  with check (owner_id = auth.uid ());

create policy products_update_owner
  on public.products for update
  to authenticated
  using (owner_id = auth.uid ())
  with check (owner_id = auth.uid ());

create policy products_delete_owner
  on public.products for delete
  to authenticated
  using (owner_id = auth.uid ());

create policy tr_select_participants
  on public.transaction_requests for select
  to authenticated
  using (
    aliado_id = auth.uid ()
    or importador_id = auth.uid ()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  );

create policy tr_insert_aliado
  on public.transaction_requests for insert
  to authenticated
  with check (
    aliado_id = auth.uid ()
    and exists (
      select 1 from public.profiles p
      where p.id = importador_id and p.role = 'importador'
    )
  );

create policy tr_update_participants
  on public.transaction_requests for update
  to authenticated
  using (
    aliado_id = auth.uid ()
    or importador_id = auth.uid ()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
  with check (
    aliado_id = auth.uid ()
    or importador_id = auth.uid ()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  );

create policy trm_select_participants
  on public.transaction_request_messages for select
  to authenticated
  using (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id = transaction_request_messages.transaction_request_id
        and (
          tr.aliado_id = auth.uid ()
          or tr.importador_id = auth.uid ()
          or exists (
            select 1 from public.profiles p
            where p.id = auth.uid () and p.role = 'administrador'
          )
        )
    )
  );

create policy trm_insert_participants
  on public.transaction_request_messages for insert
  to authenticated
  with check (
    author_id = auth.uid ()
    and exists (
      select 1 from public.transaction_requests tr
      where tr.id = transaction_request_id
        and (
          (tr.aliado_id = auth.uid () and author_role = 'aliado')
          or (tr.importador_id = auth.uid () and author_role = 'importador')
          or (
            exists (
              select 1 from public.profiles p
              where p.id = auth.uid () and p.role = 'administrador'
            )
            and author_role = 'administrador'
          )
        )
    )
  );

create policy notifications_select_own
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid ());

create policy notifications_update_own
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid ())
  with check (user_id = auth.uid ());

create policy notifications_delete_own
  on public.notifications for delete
  to authenticated
  using (user_id = auth.uid ());

-- Inserts: pedidos (triggers) y mensajes — solo si el destinatario es la contraparte del pedido.
create policy notifications_insert_tr_participant
  on public.notifications for insert
  to authenticated
  with check (
    related_id is not null
    and exists (
      select 1
      from public.transaction_requests tr
      where tr.id::text = related_id
        and (
          (
            tr.aliado_id = user_id
            and tr.importador_id = auth.uid ()
          )
          or (
            tr.importador_id = user_id
            and tr.aliado_id = auth.uid ()
          )
          or (
            exists (
              select 1
              from public.profiles p
              where p.id = auth.uid ()
                and p.role = 'administrador'
            )
            and (
              tr.aliado_id = user_id
              or tr.importador_id = user_id
            )
          )
        )
    )
  );

-- Permisos API (PostgREST)
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.transaction_requests to authenticated;
grant select, insert, update, delete on public.transaction_request_messages to authenticated;
grant select, insert, update, delete on public.notifications to authenticated;

grant all on public.profiles to service_role;
grant all on public.products to service_role;
grant all on public.transaction_requests to service_role;
grant all on public.transaction_request_messages to service_role;
grant all on public.notifications to service_role;

-- ---------------------------------------------------------------------------
-- Storage: facturas de pedido (MotoConecta — mismo bucket que usa Flutter)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('order-invoices', 'order-invoices', false)
on conflict (id) do nothing;

drop policy if exists "order_inv_select_participants" on storage.objects;
create policy "order_inv_select_participants"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-invoices'
  and (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
);

drop policy if exists "order_inv_insert_owner" on storage.objects;
create policy "order_inv_insert_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);

drop policy if exists "order_inv_update_owner" on storage.objects;
create policy "order_inv_update_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
)
with check (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);

drop policy if exists "order_inv_delete_owner" on storage.objects;
create policy "order_inv_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);
