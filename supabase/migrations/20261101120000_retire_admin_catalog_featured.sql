-- Retira el destacado manual de mayoristas en catálogo (admin).
-- La vitrina del proveedor queda estándar para importadores activos;
-- ya no se habilita ni se prioriza desde el panel de administración.

drop trigger if exists mc_tr_guard_catalog_featured_until on public.profiles;
drop function if exists public.mc_guard_catalog_featured_until ();
drop function if exists public.admin_set_importer_catalog_featured (uuid, integer);

update public.profiles
set catalog_featured_until = null
where catalog_featured_until is not null;

comment on column public.profiles.catalog_featured_until is
  'Legacy: destacado manual de catálogo retirado. Columna nula; la vitrina es estándar para importadores activos.';
