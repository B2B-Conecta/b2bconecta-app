-- C1: importador registra pago de comisión (comprobante) + notificaciones admin/importador.

alter table public.commission_settlements
  add column if not exists pago_comprobante_storage_path text,
  add column if not exists pago_comprobante_file_name text,
  add column if not exists pago_comprobante_submitted_at timestamptz,
  add column if not exists pago_estado_revision text
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
  add column if not exists pago_rechazo_nota text;

comment on column public.commission_settlements.pago_estado_revision is
  'Revisión del comprobante de pago de comisión al importador (emitido → en_revision → aprobado/rechazado).';

-- ---------------------------------------------------------------------------
-- Notificar a todos los administradores
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_all_admins (
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
declare
  v_admin uuid;
begin
  for v_admin in
    select p.id
    from public.profiles p
    where p.role = 'administrador'
  loop
    perform public.mc_insert_notification (
      v_admin,
      p_title,
      p_body,
      p_type,
      p_related_id
    );
  end loop;
end;
$$;

revoke all on function public.mc_notify_all_admins (text, text, text, text) from public;

-- ---------------------------------------------------------------------------
-- Importador: registrar comprobante de pago de comisión
-- ---------------------------------------------------------------------------
create or replace function public.importador_registra_pago_comision_corte (
  p_settlement_id uuid,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_cs public.commission_settlements%rowtype;
  v_imp_name text;
  v_ref text;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  if p_storage_path is null or length(trim(p_storage_path)) = 0 then
    raise exception 'Indique la ruta del comprobante.';
  end if;

  select cs.*
  into v_cs
  from public.commission_settlements cs
  where cs.id = p_settlement_id
  for update;

  if not found then
    raise exception 'Corte no encontrado.';
  end if;

  if v_cs.importador_id <> v_uid then
    raise exception 'Solo el importador del corte puede registrar el pago.' using errcode = '42501';
  end if;

  if v_cs.status <> 'emitido'::text then
    raise exception 'Solo puede registrar pago cuando la factura está emitida.';
  end if;

  if v_cs.pago_estado_revision = 'en_revision'::text then
    raise exception 'Ya hay un comprobante en revisión.';
  end if;

  if v_cs.pago_estado_revision = 'aprobado'::text or v_cs.status = 'pagado'::text then
    raise exception 'Este corte ya fue marcado como pagado.';
  end if;

  update public.commission_settlements cs
  set
    pago_comprobante_storage_path = trim(p_storage_path),
    pago_comprobante_file_name = nullif(trim(p_file_name), ''),
    pago_comprobante_submitted_at = now (),
    pago_estado_revision = 'en_revision',
    pago_rechazo_nota = null
  where cs.id = p_settlement_id;

  select nullif(trim(p.business_name), '')
  into v_imp_name
  from public.profiles p
  where p.id = v_uid;

  v_ref := coalesce(nullif(trim(v_cs.invoice_reference), ''), p_settlement_id::text);

  perform public.mc_notify_all_admins (
    'Comprobante de comisión en revisión',
    coalesce(v_imp_name, 'Importador')
      || ' registró el pago del corte '
      || v_ref
      || ' (USD '
      || trim(to_char(v_cs.total_commission_usd, '999999990.00'))
      || ').',
    'comision',
    p_settlement_id::text
  );

  perform public.mc_insert_notification (
    v_uid,
    'Comprobante de comisión enviado',
    'MotoLink revisará su pago de la factura '
      || v_ref
      || '. Le avisaremos cuando se confirme.',
    'comision',
    p_settlement_id::text
  );
end;
$$;

grant execute on function public.importador_registra_pago_comision_corte (uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: aprobar comprobante → pagado
-- ---------------------------------------------------------------------------
create or replace function public.admin_approve_commission_settlement_pago (p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cs public.commission_settlements%rowtype;
  v_ref text;
begin
  perform public._assert_administrador ();

  select cs.*
  into v_cs
  from public.commission_settlements cs
  where cs.id = p_settlement_id
  for update;

  if not found then
    raise exception 'Corte no encontrado.';
  end if;

  if v_cs.status <> 'emitido'::text then
    raise exception 'Solo se aprueba pago de cortes con factura emitida.';
  end if;

  if v_cs.pago_estado_revision is distinct from 'en_revision'::text then
    raise exception 'No hay comprobante en revisión para este corte.';
  end if;

  update public.commission_settlements cs
  set
    status = 'pagado',
    paid_at = now (),
    pago_estado_revision = 'aprobado'
  where cs.id = p_settlement_id;

  v_ref := coalesce(nullif(trim(v_cs.invoice_reference), ''), p_settlement_id::text);

  perform public.mc_insert_notification (
    v_cs.importador_id,
    'Pago de comisión confirmado',
    'MotoLink confirmó el pago de la factura ' || v_ref || '.',
    'comision',
    p_settlement_id::text
  );
end;
$$;

grant execute on function public.admin_approve_commission_settlement_pago (uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: rechazar comprobante
-- ---------------------------------------------------------------------------
create or replace function public.admin_reject_commission_settlement_pago (
  p_settlement_id uuid,
  p_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cs public.commission_settlements%rowtype;
  v_ref text;
  v_nota text;
begin
  perform public._assert_administrador ();

  select cs.*
  into v_cs
  from public.commission_settlements cs
  where cs.id = p_settlement_id
  for update;

  if not found then
    raise exception 'Corte no encontrado.';
  end if;

  if v_cs.pago_estado_revision is distinct from 'en_revision'::text then
    raise exception 'No hay comprobante en revisión para este corte.';
  end if;

  v_nota := nullif(trim(p_nota), '');

  update public.commission_settlements cs
  set
    pago_estado_revision = 'rechazado',
    pago_rechazo_nota = v_nota
  where cs.id = p_settlement_id;

  v_ref := coalesce(nullif(trim(v_cs.invoice_reference), ''), p_settlement_id::text);

  perform public.mc_insert_notification (
    v_cs.importador_id,
    'Comprobante de comisión rechazado',
    'Revise el comprobante de la factura '
      || v_ref
      || coalesce('. ' || v_nota, '. Puede enviar uno nuevo desde su perfil.'),
    'comision',
    p_settlement_id::text
  );
end;
$$;

grant execute on function public.admin_reject_commission_settlement_pago (uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: marcar pagado sin comprobante (override operativo)
-- ---------------------------------------------------------------------------
create or replace function public.admin_mark_commission_settlement_paid (p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cs public.commission_settlements%rowtype;
  v_ref text;
begin
  perform public._assert_administrador ();

  select cs.*
  into v_cs
  from public.commission_settlements cs
  where cs.id = p_settlement_id
  for update;

  if not found then
    raise exception 'Corte no encontrado.';
  end if;

  if v_cs.status <> 'emitido'::text then
    raise exception 'Solo se puede marcar pagado un corte en estado emitido.';
  end if;

  if v_cs.pago_estado_revision = 'en_revision'::text then
    raise exception
      'Hay un comprobante en revisión. Use «Confirmar pago» o rechace el comprobante.';
  end if;

  update public.commission_settlements cs
  set
    status = 'pagado',
    paid_at = now (),
    pago_estado_revision = coalesce(cs.pago_estado_revision, 'aprobado')
  where cs.id = p_settlement_id
    and cs.status = 'emitido';

  if not found then
    raise exception 'Corte no encontrado o ya fue pagado/anulado.';
  end if;

  v_ref := coalesce(nullif(trim(v_cs.invoice_reference), ''), p_settlement_id::text);

  perform public.mc_insert_notification (
    v_cs.importador_id,
    'Pago de comisión confirmado',
    'MotoLink registró el pago de la factura ' || v_ref || '.',
    'comision',
    p_settlement_id::text
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage: comprobantes de comisión en order-payment-proofs/commission-settlements/{id}/
-- ---------------------------------------------------------------------------
drop policy if exists "order_payproof_select_commission_settlement" on storage.objects;
create policy "order_payproof_select_commission_settlement"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and (storage.foldername(name))[1] = 'commission-settlements'
  and (
    exists (
      select 1
      from public.commission_settlements cs
      where cs.id::text = (storage.foldername(name))[2]
        and cs.importador_id = auth.uid ()
    )
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  )
);

drop policy if exists "order_payproof_insert_commission_importador" on storage.objects;
create policy "order_payproof_insert_commission_importador"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-payment-proofs'
  and (storage.foldername(name))[1] = 'commission-settlements'
  and exists (
    select 1
    from public.commission_settlements cs
    where cs.id::text = (storage.foldername(name))[2]
      and cs.importador_id = auth.uid ()
      and cs.status = 'emitido'
  )
);

drop policy if exists "order_payproof_update_commission_importador" on storage.objects;
create policy "order_payproof_update_commission_importador"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and (storage.foldername(name))[1] = 'commission-settlements'
  and exists (
    select 1
    from public.commission_settlements cs
    where cs.id::text = (storage.foldername(name))[2]
      and cs.importador_id = auth.uid ()
  )
)
with check (
  bucket_id = 'order-payment-proofs'
  and (storage.foldername(name))[1] = 'commission-settlements'
  and exists (
    select 1
    from public.commission_settlements cs
    where cs.id::text = (storage.foldername(name))[2]
      and cs.importador_id = auth.uid ()
  )
);

drop policy if exists "order_payproof_delete_commission_importador" on storage.objects;
create policy "order_payproof_delete_commission_importador"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and (storage.foldername(name))[1] = 'commission-settlements'
  and exists (
    select 1
    from public.commission_settlements cs
    where cs.id::text = (storage.foldername(name))[2]
      and cs.importador_id = auth.uid ()
  )
);
