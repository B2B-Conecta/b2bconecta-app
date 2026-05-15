-- PostgREST PGRST203: no puede elegir entre admin_assign_transportista_pedido(uuid, uuid)
-- y (uuid, uuid, text). Solo debe existir la firma de 3 argumentos (tercero con default null).

drop function if exists public.admin_assign_transportista_pedido(uuid, uuid);

-- Asegurar permisos sobre la firma única
revoke all on function public.admin_assign_transportista_pedido(uuid, uuid, text) from public;
grant execute on function public.admin_assign_transportista_pedido(uuid, uuid, text) to authenticated;
