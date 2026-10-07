-- Tokens FCM inválidos o desregistrados: la Edge Function los borra con service_role.
-- No toca filas históricas válidas.

create or replace function public.deactivate_device_push_token (p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text := nullif(trim(p_token), '');
begin
  if v_token is null then
    return;
  end if;
  delete from public.device_push_tokens
  where token = v_token;
end;
$$;

revoke all on function public.deactivate_device_push_token (text) from public, anon, authenticated;
grant execute on function public.deactivate_device_push_token (text) to service_role;
