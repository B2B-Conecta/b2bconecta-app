-- PDF de factura de comisión MotoLink por corte (plantilla operativa).

alter table public.commission_settlements
  add column if not exists invoice_pdf_storage_path text,
  add column if not exists invoice_pdf_file_name text;

comment on column public.commission_settlements.invoice_pdf_storage_path is
  'Ruta en Storage del PDF de factura de comisión (bucket commission-settlement-invoices).';

-- ---------------------------------------------------------------------------
-- Adjuntar PDF tras generación en app (admin)
-- ---------------------------------------------------------------------------
create or replace function public.admin_attach_commission_invoice_pdf (
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
  v_cs public.commission_settlements%rowtype;
  v_ref text;
begin
  perform public._assert_administrador ();

  if p_storage_path is null or length(trim(p_storage_path)) = 0 then
    raise exception 'Ruta de PDF inválida.';
  end if;

  update public.commission_settlements cs
  set
    invoice_pdf_storage_path = trim(p_storage_path),
    invoice_pdf_file_name = nullif(trim(p_file_name), '')
  where cs.id = p_settlement_id
    and cs.status in ('emitido'::text, 'pagado'::text)
  returning * into v_cs;

  if not found then
    raise exception 'Corte no encontrado o aún no emitido.';
  end if;

  v_ref := coalesce(nullif(trim(v_cs.invoice_reference), ''), p_settlement_id::text);

  perform public.mc_insert_notification (
    v_cs.importador_id,
    'Factura de comisión disponible',
    'La factura ' || v_ref || ' ya puede descargarse en Perfil → Cortes de comisión.',
    'comision',
    p_settlement_id::text
  );
end;
$$;

grant execute on function public.admin_attach_commission_invoice_pdf (uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage bucket
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('commission-settlement-invoices', 'commission-settlement-invoices', false)
on conflict (id) do nothing;

drop policy if exists "commission_invoice_select" on storage.objects;
create policy "commission_invoice_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'commission-settlement-invoices'
  and (
    exists (
      select 1
      from public.commission_settlements cs
      where cs.id::text = (storage.foldername(name))[1]
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

drop policy if exists "commission_invoice_insert_admin" on storage.objects;
create policy "commission_invoice_insert_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'commission-settlement-invoices'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  )
);

drop policy if exists "commission_invoice_update_admin" on storage.objects;
create policy "commission_invoice_update_admin"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'commission-settlement-invoices'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  )
)
with check (
  bucket_id = 'commission-settlement-invoices'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  )
);

drop policy if exists "commission_invoice_delete_admin" on storage.objects;
create policy "commission_invoice_delete_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'commission-settlement-invoices'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  )
);
