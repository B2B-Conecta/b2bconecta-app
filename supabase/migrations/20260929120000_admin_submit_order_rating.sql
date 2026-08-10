-- Admin puede registrar valoración en nombre del usuario SOLO si aún no calificó.
-- Notifica al usuario (rater) que administración completó la valoración.

alter table public.order_ratings
  add column if not exists submitted_by_admin_id uuid references public.profiles (id),
  add column if not exists submitted_on_behalf boolean not null default false;

comment on column public.order_ratings.submitted_by_admin_id is
  'Admin que registró la valoración en nombre del usuario (si aplica).';
comment on column public.order_ratings.submitted_on_behalf is
  'True si la valoración la cargó un administrador en nombre del rater.';

create or replace function public.admin_submit_order_rating (
  p_rater_role text,
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
  v_admin uuid := auth.uid ();
  v_role text := lower(trim(coalesce(p_rater_role, '')));
  v_comment text := trim(coalesce(p_comment, ''));
  v_tr record;
  v_res record;
  v_audience text;
  v_ratee text;
  v_notify uuid;
  v_exists boolean;
  v_eligible boolean;
begin
  if v_admin is null then
    raise exception 'No autenticado';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_admin
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden registrar valoraciones en nombre de usuarios.';
  end if;

  if v_role not in ('aliado', 'importador') then
    raise exception 'Rol de valoración inválido (aliado o importador).';
  end if;

  if p_request_id is null then
    raise exception 'Pedido requerido';
  end if;

  select
    tr.id,
    tr.checkout_group_id,
    tr.original_checkout_group_id,
    tr.importador_id,
    tr.aliado_id,
    tr.status,
    tr.cancelado_por_aliado,
    tr.importador_cancelacion_motivo,
    tr.aliado_experience_submitted_at,
    coalesce(tr.anulado_por_motolink, false) as anulado_por_motolink
  into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  v_eligible := (
    v_tr.status = 'entregado'::text
    or (
      v_tr.status = 'rechazado'::text
      and (
        coalesce(v_tr.cancelado_por_aliado, false)
        or coalesce(btrim(v_tr.importador_cancelacion_motivo), '') <> ''
      )
    )
  );

  if not v_eligible then
    raise exception 'El pedido no está en un estado elegible para valoración.';
  end if;

  if v_role = 'aliado' and v_tr.anulado_por_motolink then
    raise exception 'No se puede valorar un pedido anulado por B2B Conecta.';
  end if;

  -- ¿Ya existe valoración de esa parte?
  select exists (
    select 1
    from public.order_ratings r
    where r.rater_role = v_role
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
  )
  into v_exists;

  if v_exists
     or (v_role = 'aliado' and v_tr.aliado_experience_submitted_at is not null)
  then
    raise exception
      'El usuario ya valoró este pedido. No se puede registrar otra valoración.';
  end if;

  if v_role = 'aliado' then
    v_audience := 'aliado_rates_importer';
    v_ratee := 'importador';
    v_notify := v_tr.aliado_id;
  else
    v_audience := 'importer_rates_aliado';
    v_ratee := 'aliado';
    v_notify := v_tr.importador_id;
  end if;

  select *
    into v_res
  from public.resolve_rating_submission (
    v_audience,
    p_stars,
    coalesce(p_answers, '{}'::jsonb)
  );

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
    answers,
    submitted_by_admin_id,
    submitted_on_behalf
  )
  values (
    v_tr.checkout_group_id,
    v_tr.id,
    v_tr.importador_id,
    v_tr.aliado_id,
    v_role,
    v_ratee,
    v_res.overall_stars,
    v_comment,
    v_res.questionnaire_version,
    v_res.normalized_answers,
    v_admin,
    true
  );

  if v_role = 'aliado' then
    update public.transaction_requests tr
    set
      aliado_experience_stars = v_res.overall_stars,
      aliado_experience_comment = nullif(v_comment, ''),
      aliado_experience_submitted_at = now (),
      updated_at = now ()
    where tr.importador_id = v_tr.importador_id
      and tr.aliado_id = v_tr.aliado_id
      and tr.aliado_experience_submitted_at is null
      and (
        (
          v_tr.checkout_group_id is not null
          and (
            tr.checkout_group_id = v_tr.checkout_group_id
            or tr.original_checkout_group_id = v_tr.checkout_group_id
          )
        )
        or (
          v_tr.checkout_group_id is null
          and tr.id = v_tr.id
        )
      )
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
  end if;

  perform public.mc_insert_notification (
    v_notify,
    'Valoración registrada por administración',
    'B2B Conecta registró la valoración de su pedido en su nombre. '
      || 'Ya figura en el expediente del pedido.',
    'pedido',
    coalesce(v_tr.checkout_group_id, v_tr.id)::text
  );
end;
$$;

grant execute on function public.admin_submit_order_rating (
  text, uuid, integer, text, jsonb
) to authenticated;
