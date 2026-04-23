-- A6: preferencia de documento (nota de entrega vs factura fiscal), recordatorio in-app
-- y experiencia del aliado (estrellas + comentario) tras entrega.
-- Debe aplicarse al final: reemplaza funciones de pago del aliado con validación A6.

alter table public.transaction_requests
  add column if not exists document_type_preference text
    check (
      document_type_preference is null
      or document_type_preference in ('nota_entrega', 'factura_fiscal')
    );

alter table public.transaction_requests
  add column if not exists document_type_nudge_sent_at timestamptz;

alter table public.transaction_requests
  add column if not exists aliado_experience_stars smallint
    check (aliado_experience_stars is null or (aliado_experience_stars >= 1 and aliado_experience_stars <= 5));

alter table public.transaction_requests
  add column if not exists aliado_experience_comment text;

alter table public.transaction_requests
  add column if not exists aliado_experience_submitted_at timestamptz;

comment on column public.transaction_requests.document_type_preference is
  'A6: nota de entrega simple vs factura fiscal; NULL hasta que el aliado elija.';
comment on column public.transaction_requests.aliado_experience_stars is
  'A6: calificación 1-5 tras entrega; NULL hasta que el aliado envíe.';


-- ---------------------------------------------------------------------------
-- Aliado: fija preferencia (solo si aún NULL; una sola vez).
-- ---------------------------------------------------------------------------
create or replace function public.aliado_set_document_type_preference(
  p_request_id uuid,
  p_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede registrar la preferencia de documento.';
  end if;

  if p_type is null or p_type not in ('nota_entrega', 'factura_fiscal') then
    raise exception 'Tipo de documento no válido.';
  end if;

  update public.transaction_requests tr
  set
    document_type_preference = p_type,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito',
      'entregado'
    )
    and tr.document_type_preference is null;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo guardar la preferencia. Compruebe que el pedido sea suyo, que aún no haya elegido '
      'o que no esté cancelado/rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_set_document_type_preference(uuid, text) to authenticated;


-- ---------------------------------------------------------------------------
-- Aliado: experiencia post-entrega (una sola vez).
-- ---------------------------------------------------------------------------
create or replace function public.aliado_submit_order_experience(
  p_request_id uuid,
  p_stars smallint,
  p_comment text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  t text;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede enviar la evaluación del pedido.';
  end if;

  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'La calificación debe ser entre 1 y 5 estrellas.';
  end if;

  t := left(nullif(trim(p_comment), ''), 2000);

  update public.transaction_requests tr
  set
    aliado_experience_stars = p_stars,
    aliado_experience_comment = t,
    aliado_experience_submitted_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status = 'entregado'
    and tr.aliado_experience_submitted_at is null;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la evaluación. Compruebe que el pedido esté entregado y que no haya enviado '
      'ya una calificación para este pedido.';
  end if;
end;
$$;

grant execute on function public.aliado_submit_order_experience(uuid, smallint, text) to authenticated;


-- ---------------------------------------------------------------------------
-- In-app: cuando MotoLink sube la factura al aliado y aún no hay preferencia.
-- ---------------------------------------------------------------------------
create or replace function public.trg_notify_document_type_preference_needed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.document_type_preference is not null then
    return null;
  end if;
  if new.document_type_nudge_sent_at is not null then
    return null;
  end if;
  if old.factura_aliado_storage_path is not distinct from new.factura_aliado_storage_path then
    return null;
  end if;
  if new.factura_aliado_storage_path is null or btrim(new.factura_aliado_storage_path) = '' then
    return null;
  end if;
  if old.factura_aliado_storage_path is not null and btrim(old.factura_aliado_storage_path) <> '' then
    return null;
  end if;

  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.aliado_id,
    'MotoLink',
    'Estamos listos para registrar tu compra. ¿Deseas nota de entrega simple o factura fiscal?',
    'envio',
    new.id::text
  );

  update public.transaction_requests
  set document_type_nudge_sent_at = now()
  where id = new.id;
  return null;
end;
$$;

drop trigger if exists trg_notify_document_type_preference_needed on public.transaction_requests;
create trigger trg_notify_document_type_preference_needed
after update of factura_aliado_storage_path on public.transaction_requests
for each row
execute function public.trg_notify_document_type_preference_needed();


-- ---------------------------------------------------------------------------
-- Pago: exigir preferencia de documento cuando ya existe factura MotoLink.
-- ---------------------------------------------------------------------------
create or replace function public.aliado_registra_comprobante_pago(
  p_request_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  base numeric;
  nuevo_total numeric;
begin
  if p_metodo not in (
    'pago_movil', 'zelle_divisas', 'transferencia', 'efectivo', 'credito_sistema'
  ) then
    raise exception 'Método de pago no válido.';
  end if;
  if p_metodo = 'credito_sistema' then
    raise exception 'El crédito del sistema se solicita con la acción dedicada, sin archivo de comprobante.';
  end if;
  if coalesce(trim(p_storage_path), '') = '' or coalesce(trim(p_file_name), '') = '' then
    raise exception 'Debe indicar ruta y nombre del comprobante.';
  end if;
  if p_storage_path not like p_request_id::text || '/%' then
    raise exception 'Ruta de archivo inválida.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if p_metodo = 'efectivo' then
    nuevo_total := round(base * 1.04, 2);
  else
    nuevo_total := base;
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = p_metodo,
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = p_file_name,
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = nuevo_total,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and tr.document_type_preference is not null
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'en_revision', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique la factura MotoLink, indique nota de entrega o factura '
      'fiscal en la ficha, y que el pago no esté ya aprobado.';
  end if;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago(uuid, text, text, text)
  to authenticated;

create or replace function public.aliado_declara_pago_efectivo(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  base numeric;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede declarar pago en efectivo.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  update public.transaction_requests tr
  set
    pago_metodo = 'efectivo',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = round(base * 1.04, 2),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and tr.document_type_preference is not null
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la declaración. Compruebe la factura MotoLink, indique nota de entrega o factura '
      'fiscal en la ficha, y que pueda reenviar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_efectivo(uuid) to authenticated;

create or replace function public.aliado_declara_pago_credito_sistema(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  pc int;
  lim numeric;
  preact boolean;
  base numeric;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede solicitar pago con crédito del sistema.';
  end if;

  select
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit,
    coalesce(credito_preactivado_por_admin, false)
  into pc, lim, preact
  from public.profiles
  where id = auth.uid();

  if pc < 3 and not preact then
    raise exception 'El pago con crédito del sistema solo aplica tras completar la fase de contado.';
  end if;
  if lim is null or lim <= 0 then
    raise exception 'Debe tener un límite de crédito asignado por MotoLink para usar esta modalidad.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  update public.transaction_requests tr
  set
    pago_metodo = 'credito_sistema',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = base,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and tr.document_type_preference is not null
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la solicitud. Compruebe la factura MotoLink, indique nota de entrega o factura '
      'fiscal en la ficha, y que pueda reintentar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_credito_sistema(uuid) to authenticated;


create or replace function public.aliado_registra_comprobante_pago_cuota(
  p_schedule_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_tr uuid;
  v_aliado uuid;
  st text;
  v_fact text;
  base numeric;
  base_now numeric;
begin
  if p_metodo = 'credito_sistema' then
    raise exception 'El crédito del sistema se declara a nivel de pedido con la acción dedicada, sin comprobante por cuota.';
  end if;
  if p_metodo not in (
    'pago_movil', 'zelle_divisas', 'transferencia', 'efectivo'
  ) then
    raise exception 'Método de pago no válido.';
  end if;
  if coalesce(trim(p_storage_path), '') = '' or coalesce(trim(p_file_name), '') = '' then
    raise exception 'Debe indicar ruta y nombre del comprobante.';
  end if;

  select
    ps.transaction_request_id,
    tr.aliado_id,
    tr.status,
    tr.factura_aliado_storage_path,
    tr.precio_base_aliado_total,
    tr.precio_total
  into
    v_tr, v_aliado, st, v_fact, base, base_now
  from public.payment_schedule ps
  join public.transaction_requests tr on tr.id = ps.transaction_request_id
  where ps.id = p_schedule_id;

  if v_tr is null or v_aliado is null then
    raise exception 'Cuota no encontrada.';
  end if;
  if v_aliado <> auth.uid() then
    raise exception 'No autorizado a registrar pago de esta cuota.';
  end if;
  if st = 'rechazado' then
    raise exception 'Pedido rechazado: no se puede subir comprobante.';
  end if;
  if coalesce(nullif(trim(v_fact), ''), '') = '' then
    raise exception 'Debe existir factura MotoLink al aliado para registrar el pago.';
  end if;
  if not exists (
    select 1
    from public.transaction_requests tr2
    where tr2.id = v_tr
      and tr2.document_type_preference is not null
  ) then
    raise exception
      'Indique en la ficha del pedido si desea nota de entrega simple o factura fiscal antes de subir comprobantes.';
  end if;

  if p_storage_path not like (v_tr::text || '/%') then
    raise exception 'Ruta de archivo inválida.';
  end if;

  update public.payment_schedule ps
  set
    pago_metodo = p_metodo,
    pago_comprobante_storage_path = p_storage_path,
    pago_comprobante_file_name = p_file_name,
    pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null
  where ps.id = p_schedule_id
    and coalesce(ps.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado', 'en_revision');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No se pudo actualizar la cuota (puede que ya esté aprobada).';
  end if;

  update public.transaction_requests
  set pago_estado_revision = 'en_revision', pago_comprobante_rechazo_nota = null, updated_at = now()
  where id = v_tr
    and status in (
      'pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito', 'entregado'
    );
end;
$$;
grant execute on function public.aliado_registra_comprobante_pago_cuota(uuid, text, text, text) to authenticated;
