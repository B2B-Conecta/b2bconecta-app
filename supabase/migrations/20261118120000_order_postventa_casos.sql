-- Devolución o queja de un pedido entregado.
-- Queda anotada en el pedido. No cambia transaction_requests.status.

create table if not exists public.order_postventa_casos (
  id uuid primary key default gen_random_uuid(),
  transaction_request_id uuid not null
    references public.transaction_requests (id) on delete cascade,
  kind text not null check (kind in ('devolucion', 'queja')),
  body text not null check (char_length(btrim(body)) >= 3),
  opened_by uuid not null references public.profiles (id),
  opened_role text not null check (opened_role in ('aliado', 'importador')),
  created_at timestamptz not null default now(),
  unique (transaction_request_id, kind)
);

comment on table public.order_postventa_casos is
  'Devolución o queja registrada sobre un pedido entregado. Una por tipo y pedido.';

alter table public.transaction_requests
  add column if not exists postventa_devolucion_at timestamptz,
  add column if not exists postventa_queja_at timestamptz;

comment on column public.transaction_requests.postventa_devolucion_at is
  'Momento en que quedó registrada una devolución. No cambia el estado del pedido.';
comment on column public.transaction_requests.postventa_queja_at is
  'Momento en que quedó registrada una queja. No cambia el estado del pedido.';

alter table public.order_postventa_casos enable row level security;

drop policy if exists order_postventa_casos_select on public.order_postventa_casos;
create policy order_postventa_casos_select
  on public.order_postventa_casos
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.transaction_requests tr
      where tr.id = transaction_request_id
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

revoke all on table public.order_postventa_casos from public;
grant select on table public.order_postventa_casos to authenticated;

create or replace function public.register_order_postventa_caso (
  p_request_id uuid,
  p_kind text,
  p_body text
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
  v_anchor timestamptz;
  v_id uuid;
  v_at timestamptz := now();
  v_title text;
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

  insert into public.order_postventa_casos (
    transaction_request_id,
    kind,
    body,
    opened_by,
    opened_role,
    created_at
  )
  values (p_request_id, v_kind, v_body, v_uid, v_role, v_at)
  returning id into v_id;

  if v_kind = 'devolucion' then
    update public.transaction_requests
      set postventa_devolucion_at = v_at
      where id = p_request_id;
    v_title := 'Devolución registrada';
  else
    update public.transaction_requests
      set postventa_queja_at = v_at
      where id = p_request_id;
    v_title := 'Queja registrada';
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
    v_role,
    v_title || ' en este pedido. ' || v_body
  );

  return jsonb_build_object(
    'id', v_id,
    'kind', v_kind,
    'body', v_body,
    'opened_role', v_role,
    'created_at', v_at
  );
end;
$$;

revoke all on function public.register_order_postventa_caso (uuid, text, text) from public;
grant execute on function public.register_order_postventa_caso (uuid, text, text) to authenticated;
