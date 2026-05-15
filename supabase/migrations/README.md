# Migraciones Supabase (rama MotoConecta)

**Local:** ejecuta `supabase start` (Docker) y luego `supabase db reset --yes`. Sin `start`, el CLI responde «supabase start is not running».

En esta rama **no se aplican** las migraciones históricas del broker MotoLink. Fueron movidas a:

`supabase/motolink/migrations_archive/`

El único archivo aquí es **`20260106000000_motoconecta_baseline.sql`**, que define el esquema MotoConecta (`profiles`, `products`, `transaction_requests`, `transaction_request_messages`, `notifications`, RLS y triggers mínimos).

- **`supabase db reset`** (local): aplica esta migración y luego `supabase/seed.sql` según `config.toml`.
- **Proyecto remoto**: enlaza el CLI y usa `db push` / reset según tu flujo, o pega el SQL desde `motoconecta/schema.sql` en el SQL Editor (mismo contenido que la migración baseline).

Para recuperar el historial MotoLink en otra rama, restaura los `.sql` desde `motolink/migrations_archive/` a `supabase/migrations/`.

---

## Error: `Remote migration versions not found in local migrations directory`

Al ejecutar **`supabase db push`**, el remoto tiene filas en `supabase_migrations.schema_migrations` (versiones de migraciones ya aplicadas) que **no tienen** archivo correspondiente en tu `supabase/migrations/` local. En esta rama solo existe la baseline MotoConecta; el remoto suele seguir con el historial MotoLink.

`db push` exige alinear ese historial con los archivos del repo.

### Qué hacer (elige una)

1. **Proyecto Supabase nuevo** dedicado a MotoConecta: `supabase link` y luego **`supabase db push`** — sin historial viejo, aplica solo `20260106000000_motoconecta_baseline.sql`.

2. **Mismo proyecto remoto, sin `db push`**: pega **`supabase/motoconecta/schema.sql`** en **Dashboard → SQL Editor** (y `seed.sql` si quieres datos de prueba). La app solo necesita URL + clave publishable; no hace falta que el CLI marque las migraciones.

3. **`supabase migration repair` / `db pull`** (lo que sugiere el CLI): sirve para **reparar metadatos** de migraciones cuando sabes lo que haces; **no** sustituye borrar/reemplazar el esquema MotoLink en Postgres. No lo uses como “parche mágico” sobre un remoto productivo sin plan.

### Resumen

| Entorno | Comando típico |
|--------|----------------|
| Local Docker | `supabase start` → `supabase db reset --yes` |
| Nube, repo solo baseline | **SQL Editor** o **proyecto nuevo** + `db push` |
| Nube con historial MotoLink + carpeta local sin esos `.sql` | `db push` **fallará** hasta alinear historial o usar otra estrategia arriba |
