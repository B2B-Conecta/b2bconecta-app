-- Referencia: políticas RLS para public.products (owner_id → public.profiles.id).
-- Ejecutar en Supabase SQL Editor si aún no existen. Ajusta nombres si chocan con políticas previas.

alter table public.products enable row level security;

-- Lectura: usuarios autenticados ven el catálogo (ajusta si el catálogo es público con anon).
create policy "products_select_authenticated"
on public.products
for select
to authenticated
using (true);

-- Inserción: solo filas donde el dueño es el usuario actual.
create policy "products_insert_own"
on public.products
for insert
to authenticated
with check (owner_id = auth.uid());

-- Actualización: solo el dueño del producto.
create policy "products_update_own"
on public.products
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- Borrado (opcional): solo el dueño.
create policy "products_delete_own"
on public.products
for delete
to authenticated
using (owner_id = auth.uid());
