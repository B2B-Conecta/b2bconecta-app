-- =============================================================================
-- Restablecer contraseñas de usuarios @motoconecta.seed (sin re-seed completo)
-- =============================================================================
--   admin*@motoconecta.seed      → admin123
--   importador*@motoconecta.seed → importador123
--   aliado*@motoconecta.seed     → aliado123
--
-- Uso:
--   supabase db query --linked -f supabase/scripts/reset_seed_passwords.sql
-- =============================================================================

create extension if not exists pgcrypto;

update auth.users
set
  encrypted_password = case
    when email like 'admin%@motoconecta.seed'
      then crypt('admin123', gen_salt('bf'))
    when email like 'importador%@motoconecta.seed'
      then crypt('importador123', gen_salt('bf'))
    when email like 'aliado%@motoconecta.seed'
      then crypt('aliado123', gen_salt('bf'))
    else encrypted_password
  end,
  updated_at = now()
where email like '%@motoconecta.seed';
