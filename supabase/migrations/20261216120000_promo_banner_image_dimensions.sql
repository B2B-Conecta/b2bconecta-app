-- Dimensiones del creativo recortado (escritorio y móvil opcionales).
alter table public.promo_campaigns
  add column if not exists image_width integer,
  add column if not exists image_height integer,
  add column if not exists mobile_image_width integer,
  add column if not exists mobile_image_height integer;

do $migration$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.promo_campaigns'::regclass
      and conname = 'promo_image_dimensions_positive'
  ) then
    alter table public.promo_campaigns
      add constraint promo_image_dimensions_positive check (
        (image_width is null or image_width > 0)
        and (image_height is null or image_height > 0)
        and (mobile_image_width is null or mobile_image_width > 0)
        and (mobile_image_height is null or mobile_image_height > 0)
      );
  end if;
end;
$migration$;

notify pgrst, 'reload schema';
