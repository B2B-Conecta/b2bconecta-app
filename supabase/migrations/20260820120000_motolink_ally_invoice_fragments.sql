-- Facturación fragmentada: varias emisiones por pedido maestro (límite de ítems por documento).

drop function if exists public.admin_prepare_motolink_ally_document_emission(uuid, text, text);
drop function if exists public.admin_finalize_motolink_ally_document_emission(uuid, text, text);

alter table public.motolink_ally_document_emissions
  add column if not exists fragment_index integer not null default 1,
  add column if not exists fragment_total integer not null default 1;

comment on column public.motolink_ally_document_emissions.fragment_index is
  'Hoja del lote (1..fragment_total) para el mismo pedido y tipo de documento.';
comment on column public.motolink_ally_document_emissions.fragment_total is
  'Total de documentos del lote generado en una misma emisión.';

alter table public.motolink_ally_document_emissions
  drop constraint if exists motolink_ally_doc_fragments_ok;

alter table public.motolink_ally_document_emissions
  add constraint motolink_ally_doc_fragments_ok
  check (
    fragment_index >= 1
    and fragment_total >= 1
    and fragment_index <= fragment_total
  );

create or replace function public.admin_prepare_motolink_ally_document_emission(
  p_request_id uuid,
  p_document_type text,
  p_reissue_motivo text default null,
  p_fragment_index integer default 1,
  p_fragment_total integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_st text;
  v_is_m boolean;
  v_prov text;
  v_fa text;
  v_pe text;
  v_pref text;
  v_tasa numeric(18, 8);
  v_iva numeric(18, 8);
  v_igtf numeric(18, 8);
  v_corr integer;
  v_emission_id uuid;
  v_prev_id uuid;
  v_motivo text := nullif(trim(coalesce(p_reissue_motivo, '')), '');
  v_doc text := lower(trim(coalesce(p_document_type, '')));
  n_sub int;
  n_miss int;
  fi int := coalesce(p_fragment_index, 1);
  ft int := coalesce(p_fragment_total, 1);
begin
  if v_admin is null then
    raise exception 'No autenticado';
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = v_admin and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores';
  end if;

  if v_doc not in ('nota_entrega', 'factura_fiscal') then
    raise exception 'Tipo de documento inválido';
  end if;

  if fi < 1 or ft < 1 or fi > ft then
    raise exception 'Fragmento de documento inválido';
  end if;

  if v_motivo is not null and ft > 1 then
    raise exception 'Reemisión con varias hojas no está soportada; reemita solo documentos de una hoja.';
  end if;

  select
    tr.status,
    coalesce(tr.is_master_order, false),
    tr.proveedor_factura_storage_path,
    tr.factura_aliado_storage_path,
    tr.pago_estado_revision,
    tr.document_type_preference
  into v_st, v_is_m, v_prov, v_fa, v_pe, v_pref
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_st is null then
    raise exception 'Pedido no encontrado';
  end if;

  v_pref := nullif(trim(coalesce(v_pref, '')), '');
  if v_pref is null then
    raise exception 'El aliado no indicó tipo de documento (nota o factura) al aceptar el pedido.';
  end if;
  if v_pref <> v_doc then
    raise exception 'Este pedido está configurado como %. No puede emitir %.',
      case v_pref
        when 'nota_entrega' then 'nota de entrega simple'
        when 'factura_fiscal' then 'factura fiscal'
        else v_pref
      end,
      case v_doc
        when 'nota_entrega' then 'nota de entrega'
        else 'factura fiscal'
      end;
  end if;

  if v_st <> 'en_preparacion' and v_st <> 'pedido_listo' and not (v_is_m and v_st = 'aprobado_admin') then
    raise exception 'Solo aplica con el pedido en preparación, listo o (maestro) aprobado por MotoLink.';
  end if;

  if v_is_m then
    select count(*) into n_sub from public.sub_orders so where so.parent_order_id = p_request_id;
    if n_sub = 0 then
      raise exception 'Pedido maestro sin sub-pedidos';
    end if;
    select count(*) into n_miss
    from public.sub_orders so
    where so.parent_order_id = p_request_id
      and coalesce(trim(so.proveedor_factura_storage_path), '') = '';
    if n_miss > 0 then
      raise exception 'Falta factura del proveedor en uno o más sub-pedidos';
    end if;
  else
    if coalesce(trim(v_prov), '') = '' then
      raise exception 'El importador debe haber adjuntado la factura del proveedor';
    end if;
  end if;

  if v_pe = 'en_revision' then
    raise exception 'Hay un comprobante en revisión. Resuélvalo antes de cambiar la factura.';
  end if;
  if v_pe = 'aprobado' then
    raise exception 'El pago ya fue aprobado; no puede emitir o reemitir documento.';
  end if;

  if fi = 1 then
    if exists (
      select 1
      from public.motolink_ally_document_emissions m
      where m.transaction_request_id = p_request_id
        and m.document_type = v_doc
        and m.finalized_at is not null
        and m.fragment_index = 1
    ) and v_motivo is null then
      raise exception 'Ya existe la primera hoja de este documento. Continúe el lote desde la app o reemita indicando motivo.';
    end if;
  else
    if not exists (
      select 1
      from public.motolink_ally_document_emissions m
      where m.transaction_request_id = p_request_id
        and m.document_type = v_doc
        and m.fragment_index = fi - 1
        and m.finalized_at is not null
    ) then
      raise exception 'Debe finalizar el documento anterior del lote antes de preparar este fragmento.';
    end if;
  end if;

  if coalesce(trim(v_fa), '') <> '' and v_motivo is null then
    if not (ft > 1 and fi > 1) then
      raise exception 'Indique el motivo de reemisión (documento ya existente).';
    end if;
  end if;

  select value_numeric into v_tasa from public.app_global_config where key = 'tasa_bcv';
  if v_tasa is null or v_tasa <= 0 then
    raise exception 'Configure la tasa BCV en administración';
  end if;

  select value_numeric into v_iva from public.app_global_config where key = 'factura_iva_pct';
  select value_numeric into v_igtf from public.app_global_config where key = 'factura_igtf_pct';
  if v_iva is null then v_iva := 16; end if;
  if v_igtf is null then v_igtf := 3; end if;

  if v_doc = 'nota_entrega' then
    v_corr := nextval('public.motolink_nota_entrega_correlativo_seq');
  else
    v_corr := nextval('public.motolink_factura_fiscal_correlativo_seq');
  end if;

  select m.id into v_prev_id
  from public.motolink_ally_document_emissions m
  where m.transaction_request_id = p_request_id
    and m.finalized_at is not null
  order by m.finalized_at desc
  limit 1;

  insert into public.motolink_ally_document_emissions (
    transaction_request_id,
    document_type,
    correlativo,
    tasa_bcv_emision,
    iva_pct_emision,
    igtf_pct_emision,
    reissue_of,
    reissue_motivo,
    prepared_by,
    fragment_index,
    fragment_total
  ) values (
    p_request_id,
    v_doc,
    v_corr,
    v_tasa,
    v_iva,
    v_igtf,
    case when v_motivo is not null then v_prev_id else null end,
    v_motivo,
    v_admin,
    fi,
    ft
  )
  returning id into v_emission_id;

  return jsonb_build_object(
    'emission_id', v_emission_id,
    'correlativo', v_corr,
    'document_type', v_doc,
    'tasa_bcv_emision', v_tasa,
    'iva_pct_emision', v_iva,
    'igtf_pct_emision', v_igtf,
    'fragment_index', fi,
    'fragment_total', ft
  );
end;
$$;

create or replace function public.admin_finalize_motolink_ally_document_emission(
  p_emission_id uuid,
  p_storage_path text,
  p_file_name text,
  p_is_last_fragment boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_tr uuid;
  v_path text := nullif(trim(coalesce(p_storage_path, '')), '');
  v_name text := nullif(trim(coalesce(p_file_name, '')), '');
  v_pe text;
  v_fi int;
  v_ft int;
begin
  if v_admin is null then
    raise exception 'No autenticado';
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = v_admin and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores';
  end if;
  if v_path is null or v_name is null then
    raise exception 'Ruta y nombre de archivo requeridos';
  end if;

  select m.transaction_request_id, tr.pago_estado_revision, m.fragment_index, m.fragment_total
  into v_tr, v_pe, v_fi, v_ft
  from public.motolink_ally_document_emissions m
  join public.transaction_requests tr on tr.id = m.transaction_request_id
  where m.id = p_emission_id
  for update of m, tr;

  if v_tr is null then
    raise exception 'Emisión no encontrada';
  end if;

  update public.motolink_ally_document_emissions m
  set
    storage_path = v_path,
    file_name = v_name,
    finalized_at = now()
  where m.id = p_emission_id
    and m.finalized_at is null;

  if not found then
    raise exception 'Emisión ya finalizada o inválida';
  end if;

  if v_pe = 'en_revision' then
    raise exception 'Hay un comprobante en revisión';
  end if;
  if v_pe = 'aprobado' then
    raise exception 'El pago ya fue aprobado';
  end if;

  if coalesce(p_is_last_fragment, true) then
    update public.transaction_requests
    set
      factura_aliado_storage_path = v_path,
      factura_aliado_file_name = v_name,
      factura_aliado_submitted_at = now(),
      pago_estado_revision = 'pendiente',
      pago_metodo = null,
      comprobante_pago_storage_path = null,
      comprobante_pago_file_name = null,
      comprobante_pago_submitted_at = null,
      pago_comprobante_rechazo_nota = null,
      pago_aprobado_at = null,
      updated_at = now()
    where id = v_tr;
  end if;
end;
$$;

grant execute on function public.admin_prepare_motolink_ally_document_emission(uuid, text, text, integer, integer) to authenticated;
grant execute on function public.admin_finalize_motolink_ally_document_emission(uuid, text, text, boolean) to authenticated;
