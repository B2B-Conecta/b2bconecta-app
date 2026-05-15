-- Referencia: lectura de perfiles para filtros del catálogo (lista de importadores).
-- Ejecutar en Supabase SQL Editor si el desplegable de importadores falla por RLS.
-- Ajusta o elimina políticas duplicadas según tu proyecto.

alter table public.profiles enable row level security;

create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);
