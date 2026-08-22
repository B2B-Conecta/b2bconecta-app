-- Marca pública: MotoLink → B2B Conecta en copy de notificaciones y RPCs.
-- No toca identificadores (anulado_por_motolink, etc.).

update public.notifications
set
  title = replace(title, 'MotoLink', 'B2B Conecta'),
  body = replace(body, 'MotoLink', 'B2B Conecta')
where title like '%MotoLink%'
   or body like '%MotoLink%';

do $rebrand$
declare
  r record;
  def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and pg_get_functiondef(p.oid) like '%MotoLink%'
  loop
    def := pg_get_functiondef(r.oid);
    def := replace(def, 'CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
    def := replace(def, 'MotoLink', 'B2B Conecta');
    execute def;
  end loop;
end;
$rebrand$;
