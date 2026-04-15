-- Centro de notificaciones in-app: tabla, RLS y eventos automáticos.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  type text not null check (type in ('pago', 'kyc', 'mensaje', 'envio')),
  is_read boolean not null default false,
  related_id text,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Emisor interno para notificaciones por revisión de documento KYC.
create or replace function public.notify_profile_document_review_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.review_status is distinct from new.review_status then
    if new.review_status = 'aprobado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.profile_id,
        'Documento KYC aprobado',
        'MotoLink aprobó su documento "' || coalesce(new.doc_type, 'KYC') || '".',
        'kyc',
        new.id::text
      );
    elsif new.review_status = 'rechazado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.profile_id,
        'Documento KYC rechazado',
        'Revise observaciones y vuelva a cargar su documento "' || coalesce(new.doc_type, 'KYC') || '".',
        'kyc',
        new.id::text
      );
    elsif new.review_status = 'en_revision' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.profile_id,
        'Documento en revisión',
        'MotoLink está revisando su documento "' || coalesce(new.doc_type, 'KYC') || '".',
        'kyc',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_profile_document_review_change on public.profile_documents;
create trigger trg_notify_profile_document_review_change
after update of review_status on public.profile_documents
for each row
execute function public.notify_profile_document_review_change();

-- Notificación al aliado por revisión del comprobante de pago.
create or replace function public.notify_pago_revision_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.pago_estado_revision is distinct from new.pago_estado_revision then
    if new.pago_estado_revision = 'aprobado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pago aprobado',
        'MotoLink aprobó su comprobante de pago del pedido.',
        'pago',
        new.id::text
      );
    elsif new.pago_estado_revision = 'rechazado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Comprobante rechazado',
        'MotoLink rechazó su comprobante. Revise la nota y vuelva a cargarlo.',
        'pago',
        new.id::text
      );
    elsif new.pago_estado_revision = 'en_revision' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Comprobante en revisión',
        'MotoLink recibió su comprobante y está en revisión.',
        'pago',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_pago_revision_change on public.transaction_requests;
create trigger trg_notify_pago_revision_change
after update of pago_estado_revision on public.transaction_requests
for each row
execute function public.notify_pago_revision_change();

-- Notificación logística al aliado (envío/entrega).
create or replace function public.notify_logistica_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status then
    if new.status = 'en_transito' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido en tránsito',
        'Su pedido fue despachado y está en tránsito.',
        'envio',
        new.id::text
      );
    elsif new.status = 'entregado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido entregado',
        'El pedido fue marcado como entregado.',
        'envio',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_logistica_status_change on public.transaction_requests;
create trigger trg_notify_logistica_status_change
after update of status on public.transaction_requests
for each row
execute function public.notify_logistica_status_change();

-- Notificación por nuevo mensaje vinculado a un pedido.
create or replace function public.notify_transaction_request_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_owner uuid;
begin
  select tr.aliado_id, tr.owner_id
    into v_aliado, v_owner
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  if new.author_role = 'aliado' then
    if v_owner is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_owner,
        'Nuevo mensaje de aliado',
        'Tiene un nuevo mensaje en un pedido asignado.',
        'mensaje',
        new.transaction_request_id
      );
    end if;
  elsif new.author_role = 'importador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje del importador',
      'Tiene un nuevo mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id
    );
  elsif new.author_role = 'administrador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje de MotoLink',
      'MotoLink dejó un mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id
    );
    if v_owner is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_owner,
        'Nuevo mensaje de MotoLink',
        'MotoLink dejó un mensaje en un pedido de su inventario.',
        'mensaje',
        new.transaction_request_id
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_transaction_request_message_insert on public.transaction_request_messages;
create trigger trg_notify_transaction_request_message_insert
after insert on public.transaction_request_messages
for each row
execute function public.notify_transaction_request_message_insert();
