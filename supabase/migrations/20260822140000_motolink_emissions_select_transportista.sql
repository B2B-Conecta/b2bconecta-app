-- El transportista asignado debe poder leer las emisiones MotoLink al aliado (p. ej. facturas
-- fragmentadas) vía el embed en transaction_requests; sin esto solo veía factura_aliado_storage_path.

drop policy if exists "mde_select_transportista_asignado"
  on public.motolink_ally_document_emissions;

create policy "mde_select_transportista_asignado"
on public.motolink_ally_document_emissions
for select
to authenticated
using (
  exists (
    select 1
    from public.transaction_requests tr
    inner join public.profiles p on p.id = auth.uid()
    where tr.id = transaction_request_id
      and tr.assigned_transportista_id = auth.uid()
      and p.role = 'transportista'
  )
);
