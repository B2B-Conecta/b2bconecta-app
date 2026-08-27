# Migraciones Supabase

**Fuente de verdad del schema:** los archivos en esta carpeta. Hoy hay **116** migraciones: la baseline MotoConecta y todo lo posterior (pedidos, KYC, comisiones, logística, referidos, etc.).

Snapshot histórico del greenfield (no aplicar): [`docs/archive/motoconecta/`](../../docs/archive/motoconecta/).

## Local

```bash
supabase start
supabase db reset --yes    # reaplica todas las migraciones + supabase/seed.sql
```

Sin `start`, el CLI responde `supabase start is not running`.

## Remoto (DEV vs MAIN)

Ver [`config/ENVIRONMENTS.md`](../../config/ENVIRONMENTS.md) y [`docs/GETTING_STARTED.md`](../../docs/GETTING_STARTED.md).

| Entorno | Project ref | Cuándo `db push` |
|---------|-------------|------------------|
| Local Docker | — | `db reset` (no push) |
| DEV | `kdrccmqcrruixuworlmz` | Cuando el SQL de la rama esté estable |
| MAIN | `fzugzjcwdzcwfxgviltw` | Solo tras merge a `main`, no desde una feature branch |

```bash
# Ejemplo DEV (después de supabase login)
supabase link --project-ref kdrccmqcrruixuworlmz
supabase migration list
supabase db push
```

## Cómo añadir una migración

1. Archivo nuevo: `supabase/migrations/YYYYMMDDHHMMSS_descripcion_corta.sql`.
2. Probar en local con `db reset` (o `db push` contra una DB Docker ya levantada).
3. No editar el DDL de migraciones **ya aplicadas** en DEV/MAIN. Si hay que corregir, una migración posterior.
4. Comentarios de documentación en un SQL viejo sí se pueden actualizar; el orden y el hash de versiones los gestiona el CLI.

## Error: `Remote migration versions not found in local migrations directory`

`db push` exige que **todas** las versiones registradas en `supabase_migrations.schema_migrations` del remoto existan como archivos locales.

Eso ocurría cuando el remoto tenía historial **MotoLink** y el repo solo tenía la baseline MotoConecta. Los proyectos actuales B2B Conecta (`b2bconecta-db` / `b2bconecta-db-dev`) se alinean con **esta** carpeta `migrations/`.

Si aparece el error:

1. `supabase migration list` — compara local vs remoto.
2. No uses `migration repair` en producción sin saber qué versiones faltan.
3. Proyecto nuevo: `link` + `db push` aplica desde la baseline hacia adelante.

El historial SQL del broker MotoLink **no** está en este repo (`supabase/motolink/migrations_archive/` se mencionó en docs viejas y no existe aquí).
