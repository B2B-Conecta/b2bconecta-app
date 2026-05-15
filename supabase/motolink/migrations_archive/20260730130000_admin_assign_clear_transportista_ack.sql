-- Al cambiar o quitar el transportista asignado, se invalida el reconocimiento previo.

create or replace function public.admin_assign_transportista_pedido(
  p_request_id uuid,
  p_transportista_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo MotoLink puede asignar transportista.';
  end if;

  if p_transportista_id is not null then
    if not exists (
      select 1 from public.profiles p
      where p.id = p_transportista_id and p.role = 'transportista'
    ) then
      raise exception 'El usuario indicado no es un transportista.';
    end if;
    if not exists (
      select 1 from public.transportista_info t where t.id = p_transportista_id
    ) then
      raise exception 'El transportista debe completar su expediente (transportista_info).';
    end if;
  end if;

  update public.transaction_requests tr
  set
    assigned_transportista_id = p_transportista_id,
    transportista_assignment_acknowledged_at = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_assignment_acknowledged_at
    end,
    updated_at = now()
  where tr.id = p_request_id;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'Pedido no encontrado.';
  end if;
end;
$$;
