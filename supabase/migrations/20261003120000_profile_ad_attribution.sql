-- Atribución de anuncios (first-touch) en el perfil / empresa.

alter table public.profiles
  add column if not exists utm_source text,
  add column if not exists utm_medium text,
  add column if not exists utm_campaign text,
  add column if not exists utm_content text,
  add column if not exists utm_term text,
  add column if not exists fbclid text,
  add column if not exists attribution_captured_at timestamptz;

comment on column public.profiles.utm_source is
  'First-touch: utm_source del enlace de anuncio al registrarse.';
comment on column public.profiles.utm_medium is
  'First-touch: utm_medium del enlace de anuncio.';
comment on column public.profiles.utm_campaign is
  'First-touch: utm_campaign del enlace de anuncio.';
comment on column public.profiles.utm_content is
  'First-touch: utm_content del enlace de anuncio.';
comment on column public.profiles.utm_term is
  'First-touch: utm_term del enlace de anuncio.';
comment on column public.profiles.fbclid is
  'First-touch: fbclid (clic de Facebook/Meta).';
comment on column public.profiles.attribution_captured_at is
  'Momento en que se guardó la atribución first-touch.';

create or replace function public.profiles_ad_attribution_guard ()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if nullif(trim(old.utm_source), '') is not null then
      new.utm_source := old.utm_source;
    end if;
    if nullif(trim(old.utm_medium), '') is not null then
      new.utm_medium := old.utm_medium;
    end if;
    if nullif(trim(old.utm_campaign), '') is not null then
      new.utm_campaign := old.utm_campaign;
    end if;
    if nullif(trim(old.utm_content), '') is not null then
      new.utm_content := old.utm_content;
    end if;
    if nullif(trim(old.utm_term), '') is not null then
      new.utm_term := old.utm_term;
    end if;
    if nullif(trim(old.fbclid), '') is not null then
      new.fbclid := old.fbclid;
    end if;
    if old.attribution_captured_at is not null then
      new.attribution_captured_at := old.attribution_captured_at;
    end if;
  end if;

  if new.attribution_captured_at is null
     and (
       nullif(trim(new.utm_source), '') is not null
       or nullif(trim(new.utm_medium), '') is not null
       or nullif(trim(new.utm_campaign), '') is not null
       or nullif(trim(new.utm_content), '') is not null
       or nullif(trim(new.utm_term), '') is not null
       or nullif(trim(new.fbclid), '') is not null
     ) then
    new.attribution_captured_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_ad_attribution_guard on public.profiles;
create trigger profiles_ad_attribution_guard
before insert or update on public.profiles
for each row
execute function public.profiles_ad_attribution_guard ();
