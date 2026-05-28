-- Aliado puede cancelar hasta factura del proveedor; valoración tras cancelación (aliado/importador).

-- ---------------------------------------------------------------------------
-- 1) Cancelación aliado (hasta emisión de factura del proveedor)
-- ---------------------------------------------------------------------------
create or replace function public.aliado_cancela_pedido_pendiente (
  p_request_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_aliado uuid;
  v_owner uuid;
  v_status text;
  v_product text;
  v_factura text;
  v_adj text;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'aliado' then
    raise exception 'Solo el aliado puede cancelar este pedido de esta forma';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  if length(v_motivo) < 3 then
    raise exception 'Debe indicar un motivo de al menos 3 caracteres';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    coalesce(btrim(tr.proveedor_factura_storage_path), ''),
    coalesce(tr.qty_adjustment_status, ''),
    coalesce(pr.name, 'Pedido')
    into v_aliado, v_owner, v_status, v_factura, v_adj, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_aliado is distinct from v_uid then
    raise exception 'Este pedido no corresponde a su cuenta';
  end if;

  if v_status in ('entregado', 'rechazado') then
    raise exception 'El pedido ya está cerrado';
  end if;

  if v_factura <> '' then
    raise exception
      'No puede cancelar después de que el proveedor emitió su factura';
  end if;

  if v_adj = 'pendiente_aliado' then
    raise exception
      'Responda primero a la propuesta de cantidad del proveedor';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    at_rechazado = now(),
    cancelado_por_aliado = true,
    aliado_cancelacion_motivo = v_motivo,
    importador_cancelacion_motivo = null,
    original_checkout_group_id = coalesce(original_checkout_group_id, checkout_group_id),
    checkout_group_id = null,
    updated_at = now()
  where id = p_request_id;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body
  )
  values (
    p_request_id,
    v_uid,
    'aliado',
    format('Pedido cancelado por el aliado. Motivo: %s', v_motivo)
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_owner,
      'Pedido cancelado por el aliado',
      format('El aliado canceló "%s". Revisa el motivo en el detalle del pedido.', v_product),
      'envio',
      p_request_id
    );

  insert into public.notifications (user_id, title, body, type, related_id)
  select
    p.id,
    'Cancelación por aliado',
    format('El aliado canceló "%s". Revisa seguimiento y motivo.', v_product),
    'supervision',
    p_request_id
  from public.profiles p
  where p.role = 'administrador';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Valoración aliado → importador (entregado o cancelado)
-- ---------------------------------------------------------------------------
create or replace function public.aliado_submit_order_experience (
  p_request_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tr record;
  v_comment text := trim(coalesce(p_comment, ''));
  v_res record;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'aliado_rates_importer',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id, tr.checkout_group_id, tr.importador_id, tr.aliado_id, tr.status
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ()
    and tr.aliado_experience_submitted_at is null
    and (
      tr.status = 'entregado'::text
      or (
        tr.status = 'rechazado'::text
        and (
          coalesce(tr.cancelado_por_aliado, false)
          or coalesce(btrim(tr.importador_cancelacion_motivo), '') <> ''
        )
      )
    );

  if not found then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    v_tr.checkout_group_id,
    v_tr.id,
    v_tr.importador_id,
    v_tr.aliado_id,
    'aliado',
    'importador',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );

  update public.transaction_requests tr
  set
    aliado_experience_stars = v_res.overall_stars,
    aliado_experience_comment = nullif(v_comment, ''),
    aliado_experience_submitted_at = now (),
    updated_at = now ()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ();
end;
$$;

create or replace function public.aliado_submit_order_experience_importador_grupo (
  p_checkout_group_id uuid,
  p_importador_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
  v_comment text := trim(coalesce(p_comment, ''));
  v_aliado uuid := auth.uid ();
  v_anchor uuid;
  v_res record;
begin
  if v_aliado is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'aliado_rates_importer',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id
    into v_anchor
  from public.transaction_requests tr
  where (
      tr.checkout_group_id = p_checkout_group_id
      or tr.original_checkout_group_id = p_checkout_group_id
    )
    and tr.importador_id = p_importador_id
    and tr.aliado_id = v_aliado
    and tr.aliado_experience_submitted_at is null
    and (
      tr.status = 'entregado'::text
      or (
        tr.status = 'rechazado'::text
        and (
          coalesce(tr.cancelado_por_aliado, false)
          or coalesce(btrim(tr.importador_cancelacion_motivo), '') <> ''
        )
      )
    )
  limit 1;

  if v_anchor is null then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    p_checkout_group_id,
    v_anchor,
    p_importador_id,
    v_aliado,
    'aliado',
    'importador',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );

  update public.transaction_requests tr
  set
    aliado_experience_stars = v_res.overall_stars,
    aliado_experience_comment = nullif(v_comment, ''),
    aliado_experience_submitted_at = now (),
    updated_at = now ()
  where (
      tr.checkout_group_id = p_checkout_group_id
      or tr.original_checkout_group_id = p_checkout_group_id
    )
    and tr.importador_id = p_importador_id
    and tr.aliado_id = v_aliado
    and tr.aliado_experience_submitted_at is null
    and (
      tr.status = 'entregado'::text
      or (
        tr.status = 'rechazado'::text
        and (
          coalesce(tr.cancelado_por_aliado, false)
          or coalesce(btrim(tr.importador_cancelacion_motivo), '') <> ''
        )
      )
    );

  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Valoración importador → aliado (entregado o cancelado)
-- ---------------------------------------------------------------------------
create or replace function public.importer_submit_order_rating (
  p_request_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tr record;
  v_comment text := trim(coalesce(p_comment, ''));
  v_res record;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'importer_rates_aliado',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id, tr.checkout_group_id, tr.importador_id, tr.aliado_id
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.importador_id = auth.uid ()
    and (
      tr.status = 'entregado'::text
      or (
        tr.status = 'rechazado'::text
        and (
          coalesce(btrim(tr.importador_cancelacion_motivo), '') <> ''
          or coalesce(tr.cancelado_por_aliado, false)
        )
      )
    );

  if not found then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.order_ratings r
    where r.rater_role = 'importador'
      and r.importador_id = v_tr.importador_id
      and r.aliado_id = v_tr.aliado_id
      and (
        (
          v_tr.checkout_group_id is not null
          and r.checkout_group_id = v_tr.checkout_group_id
        )
        or (
          v_tr.checkout_group_id is null
          and r.transaction_request_id = v_tr.id
        )
      )
  ) then
    raise exception 'La valoración de este aliado ya fue registrada.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    v_tr.checkout_group_id,
    v_tr.id,
    v_tr.importador_id,
    v_tr.aliado_id,
    'importador',
    'aliado',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );
end;
$$;

create or replace function public.importer_submit_order_rating_importador_grupo (
  p_checkout_group_id uuid,
  p_aliado_id uuid,
  p_stars integer,
  p_comment text,
  p_answers jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_comment text := trim(coalesce(p_comment, ''));
  v_owner uuid := auth.uid ();
  v_anchor uuid;
  v_res record;
begin
  if v_owner is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    'importer_rates_aliado',
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

  select tr.id
    into v_anchor
  from public.transaction_requests tr
  where (
      tr.checkout_group_id = p_checkout_group_id
      or tr.original_checkout_group_id = p_checkout_group_id
    )
    and tr.importador_id = v_owner
    and tr.aliado_id = p_aliado_id
    and (
      tr.status = 'entregado'::text
      or (
        tr.status = 'rechazado'::text
        and (
          coalesce(btrim(tr.importador_cancelacion_motivo), '') <> ''
          or coalesce(tr.cancelado_por_aliado, false)
        )
      )
    )
  limit 1;

  if v_anchor is null then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.order_ratings r
    where r.rater_role = 'importador'
      and r.importador_id = v_owner
      and r.aliado_id = p_aliado_id
      and (
        r.checkout_group_id = p_checkout_group_id
        or r.transaction_request_id = v_anchor
      )
  ) then
    raise exception 'La valoración de este aliado ya fue registrada.'
      using errcode = 'P0001';
  end if;

  insert into public.order_ratings (
    checkout_group_id,
    transaction_request_id,
    importador_id,
    aliado_id,
    rater_role,
    ratee_role,
    overall_stars,
    comment,
    questionnaire_version,
    answers
  )
  values (
    p_checkout_group_id,
    v_anchor,
    v_owner,
    p_aliado_id,
    'importador',
    'aliado',
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers
  );

  return 1;
end;
$$;
