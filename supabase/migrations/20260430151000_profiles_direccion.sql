-- Dirección física B2B (calle / urbanización); complementa estado y ciudad.

alter table public.profiles
  add column if not exists direccion text;
