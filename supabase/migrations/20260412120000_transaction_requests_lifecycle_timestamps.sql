-- Fechas por etapa del ciclo (admin / trazabilidad). Se rellenan al entrar en cada estado.

alter table public.transaction_requests
  add column if not exists at_aprobado_admin timestamptz,
  add column if not exists at_rechazado timestamptz,
  add column if not exists at_en_preparacion timestamptz,
  add column if not exists at_en_transito timestamptz,
  add column if not exists at_entregado timestamptz;

comment on column public.transaction_requests.at_aprobado_admin is 'Cuando MotoLink aprueba la solicitud.';
comment on column public.transaction_requests.at_rechazado is 'Cuando MotoLink rechaza.';
comment on column public.transaction_requests.at_en_preparacion is 'Importador marca en preparación.';
comment on column public.transaction_requests.at_en_transito is 'Importador marca en tránsito.';
comment on column public.transaction_requests.at_entregado is 'Importador marca entregado (stock descontado).';

-- Debe ejecutarse después de tr_transaction_requests_status (orden alfabético: …_timestamps > …_status).
create or replace function public.transaction_requests_set_lifecycle_timestamps()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'aprobado_admin' and new.at_aprobado_admin is null then
      new.at_aprobado_admin := now();
    elsif new.status = 'rechazado' and new.at_rechazado is null then
      new.at_rechazado := now();
    elsif new.status = 'en_preparacion' and new.at_en_preparacion is null then
      new.at_en_preparacion := now();
    elsif new.status = 'en_transito' and new.at_en_transito is null then
      new.at_en_transito := now();
    elsif new.status = 'entregado' and new.at_entregado is null then
      new.at_entregado := now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_timestamps on public.transaction_requests;

create trigger tr_transaction_requests_timestamps
  before update on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_set_lifecycle_timestamps();
