# Entornos Supabase — B2B Conecta

Dos proyectos en la org **B2B Conecta C.A.**:

| Rol | Proyecto Supabase | Uso de datos | Env en este repo |
|-----|-------------------|--------------|------------------|
| **Principal (main)** | `b2bconecta-db` (`fzugzjcwdzcwfxgviltw`) | Plantilla limpia + **solo seed** demo | `production` / `mobile-production` |
| **Dev** | `b2bconecta-db-dev` (`kdrccmqcrruixuworlmz`) | Data de trabajo / migración desde staging MotoLink | `staging` / `mobile-staging` |
| **Local** | Docker (`supabase start`) | Seed vía `db reset` | `local` |

## Por qué dos proyectos

Cada entorno = un **project ref** distinto (URL + keys distintas).

## Puesta en marcha

### A) Principal — limpio + seed

```bash
supabase login   # cuenta B2B Conecta
supabase link --project-ref fzugzjcwdzcwfxgviltw
supabase db push
supabase migration list

supabase db query --linked -f supabase/scripts/clean_database_for_seed.sql
supabase db query --linked -f supabase/seed.sql
```

```bash
bash scripts/use_env.sh production
```

### B) Dev — schema (+ data)

```bash
supabase link --project-ref kdrccmqcrruixuworlmz
supabase db push
supabase migration list
```

Datos:

- Opción rápida QA: `seed.sql` también en DEV.
- Opción real: dump/restore desde staging MotoLink (`lwrqjpqyitnveizshawc`).

```bash
bash scripts/use_env.sh staging
```

Auth: Site URL + Redirect URLs en **cada** Dashboard (main y dev).
Ver `config/supabase-auth-redirects.example`.

### SMTP (confirmación de correo + recuperación de contraseña)

Sender: `b2bconecta.ve@gmail.com` (Gmail App Password).

1. Copiar `config/smtp.env.example` → `config/smtp.env` y pegar `SMTP_PASS`.
2. Aplicar en remoto:
   ```bash
   bash scripts/configure_supabase_smtp.sh staging    # b2bconecta-db-dev
   bash scripts/configure_supabase_smtp.sh production # b2bconecta-db
   ```
3. Local: por defecto Inbucket (`http://127.0.0.1:54324`). Para Gmail real, ver comentarios en `supabase/config.toml` → `[auth.email.smtp]`.
4. Vercel: `SUPABASE_AUTH_REDIRECT_URL` debe coincidir con Site URL del proyecto:
   - Production → `https://www.b2bconecta.com.ve`
   - Preview `dev` → `https://b2bconecta-app-git-dev-b2bconecta.vercel.app`

## Mapeo CLI ↔ app

| Comando | Apunta a |
|---------|----------|
| `bash scripts/use_env.sh production` | Main limpio + seed |
| `bash scripts/use_env.sh staging` | Dev (`kdrccmqcrruixuworlmz`) |
| `bash scripts/use_env.sh mobile-production` | Main + deep link móvil |
| `bash scripts/use_env.sh mobile-staging` | Dev + deep link móvil |
| `bash scripts/use_env.sh local` | Docker |

## Refs históricos (MotoLink, solo referencia)

- Staging antiguo: `lwrqjpqyitnveizshawc`
- Production antigua: `ufrphhiynowsychgxvkn`

No mezclar keys de la org MotoLink con la org B2B Conecta.
