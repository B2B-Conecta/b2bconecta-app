-- Aviso de prueba con copy de producto (sin jerga PWA / Web Push).
create or replace function public.request_my_web_push_test ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;
  perform public.mc_insert_notification (
    v_uid,
    'B2B Conecta',
    'Tus avisos están listos. Así te llegarán los pedidos y mensajes, incluso con la app cerrada.',
    'mensaje',
    null
  );
end;
$$;
