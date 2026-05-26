-- E1.2: notificar al importador cuando se registra/activa una campaña promocional suya.

create or replace function public.mc_notify_promo_campaign_importer ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_should_notify boolean := false;
  v_kind text;
  v_label text;
  v_title text;
  v_body text;
begin
  if new.importador_id is null or new.is_active is distinct from true then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_should_notify := true;
  elsif tg_op = 'UPDATE' then
    v_should_notify :=
      (old.is_active is distinct from true and new.is_active is true)
      or (old.importador_id is distinct from new.importador_id)
      or (old.importador_id is null and new.importador_id is not null);
  end if;

  if not v_should_notify then
    return new;
  end if;

  v_kind := case
    when new.campaign_type = 'popup' then 'pop-up'
    else 'banner'
  end;

  v_label := coalesce(
    nullif(trim(new.display_title), ''),
    nullif(trim(new.internal_title), ''),
    'Promoción'
  );

  v_title := 'Nueva promoción en catálogo aliado';
  v_body := format(
    'MotoLink registró un %s publicitario de su marca («%s») visible para aliados del %s al %s.',
    v_kind,
    v_label,
    to_char(new.starts_at at time zone 'America/Caracas', 'DD/MM/YYYY'),
    to_char(new.ends_at at time zone 'America/Caracas', 'DD/MM/YYYY')
  );

  perform public.mc_insert_notification (
    new.importador_id,
    v_title,
    v_body,
    'promocion',
    new.id::text
  );

  return new;
end;
$$;

drop trigger if exists promo_campaigns_notify_importer on public.promo_campaigns;

create trigger promo_campaigns_notify_importer
after insert or update on public.promo_campaigns
for each row
execute function public.mc_notify_promo_campaign_importer ();
