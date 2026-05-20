-- Config global: tasa BCV del día (admin) + RPC admin_set_tasa_bcv

create table if not exists public.app_global_config (
  key text primary key,
  value_numeric numeric,
  value_text text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

comment on table public.app_global_config is
  'Parámetros globales de la app (ej. tasa BCV vigente para REF→Bs).';

alter table public.app_global_config enable row level security;

drop policy if exists app_global_config_select_authenticated on public.app_global_config;
create policy app_global_config_select_authenticated
  on public.app_global_config
  for select
  to authenticated
  using (true);

drop policy if exists app_global_config_admin_write on public.app_global_config;
create policy app_global_config_admin_write
  on public.app_global_config
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  );

create or replace function public.admin_set_tasa_bcv (p_tasa numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();
  if p_tasa is null or p_tasa <= 0 then
    raise exception 'La tasa BCV debe ser un número mayor que cero.';
  end if;
  insert into public.app_global_config (key, value_numeric, updated_at, updated_by)
  values ('tasa_bcv', p_tasa, now (), auth.uid ())
  on conflict (key) do update
  set
    value_numeric = excluded.value_numeric,
    updated_at = excluded.updated_at,
    updated_by = excluded.updated_by;
end;
$$;

comment on function public.admin_set_tasa_bcv (numeric) is
  'Admin: fija la tasa BCV del día (VES por 1 REF) usada en snapshots y facturas.';

grant execute on function public.admin_set_tasa_bcv (numeric) to authenticated;
