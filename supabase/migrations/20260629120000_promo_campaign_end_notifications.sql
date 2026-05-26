-- E1.2: notificar al importador al desactivar o eliminar su campaña promocional.

create or replace function public.mc_notify_promo_campaign_importer_end ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.promo_campaigns;
  v_kind text;
  v_label text;
  v_title text;
  v_body text;
begin
  if tg_op = 'DELETE' then
    v_row := old;
    if v_row.importador_id is null then
      return old;
    end if;

    v_kind := case
      when v_row.campaign_type = 'popup' then 'pop-up'
      else 'banner'
    end;
    v_label := coalesce(
      nullif(trim(v_row.display_title), ''),
      nullif(trim(v_row.internal_title), ''),
      'Promoción'
    );

    v_title := 'Promoción eliminada del catálogo';
    v_body := format(
      'MotoLink retiró su %s publicitario «%s». Ya no será visible para aliados.',
      v_kind,
      v_label
    );

    perform public.mc_insert_notification (
      v_row.importador_id,
      v_title,
      v_body,
      'promocion',
      v_row.id::text
    );

    return old;
  end if;

  if tg_op = 'UPDATE' then
    if old.importador_id is null then
      return new;
    end if;
    if old.is_active is not true or new.is_active is not false then
      return new;
    end if;

    v_row := new;
    v_kind := case
      when v_row.campaign_type = 'popup' then 'pop-up'
      else 'banner'
    end;
    v_label := coalesce(
      nullif(trim(v_row.display_title), ''),
      nullif(trim(v_row.internal_title), ''),
      'Promoción'
    );

    v_title := 'Promoción desactivada en catálogo aliado';
    v_body := format(
      'Su %s publicitario «%s» dejó de mostrarse a aliados. Puede reactivarla desde MotoLink si aplica.',
      v_kind,
      v_label
    );

    perform public.mc_insert_notification (
      v_row.importador_id,
      v_title,
      v_body,
      'promocion',
      v_row.id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists promo_campaigns_notify_importer_end on public.promo_campaigns;
drop trigger if exists promo_campaigns_notify_importer_deactivated on public.promo_campaigns;
drop trigger if exists promo_campaigns_notify_importer_deleted on public.promo_campaigns;

create trigger promo_campaigns_notify_importer_deactivated
after update on public.promo_campaigns
for each row
execute function public.mc_notify_promo_campaign_importer_end ();

create trigger promo_campaigns_notify_importer_deleted
before delete on public.promo_campaigns
for each row
execute function public.mc_notify_promo_campaign_importer_end ();
