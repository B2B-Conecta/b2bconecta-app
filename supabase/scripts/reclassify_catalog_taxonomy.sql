-- Clasifica nombres históricos sin alterar productos ambiguos.
-- Los valores de familia / subcategoría ya reconocidos se conservan.
with categories(label, path) as (
  values
    ('Cauchos y ruedas', 'Cauchos y ruedas'),
    ('Cauchos y ruedas / Cauchos', 'Cauchos y ruedas / Cauchos'),
    ('Cauchos y ruedas / Tripas', 'Cauchos y ruedas / Tripas'),
    ('Cauchos y ruedas / Rodamientos de rueda', 'Cauchos y ruedas / Rodamientos de rueda'),
    ('Frenos', 'Frenos'),
    ('Frenos / Pastillas', 'Frenos / Pastillas'),
    ('Frenos / Bandas', 'Frenos / Bandas'),
    ('Frenos / Discos', 'Frenos / Discos'),
    ('Frenos / Manillas de freno', 'Frenos / Manillas de freno'),
    ('Transmisión', 'Transmisión'),
    ('Transmisión / Cadenas', 'Transmisión / Cadenas'),
    ('Transmisión / Coronas', 'Transmisión / Coronas'),
    ('Transmisión / Piñones', 'Transmisión / Piñones'),
    ('Transmisión / Kits de relación', 'Transmisión / Kits de relación'),
    ('Transmisión / Embragues', 'Transmisión / Embragues'),
    ('Transmisión / Tensores', 'Transmisión / Tensores'),
    ('Eléctrico e iluminación', 'Eléctrico e iluminación'),
    ('Eléctrico e iluminación / Baterías', 'Eléctrico e iluminación / Baterías'),
    ('Eléctrico e iluminación / Bujías', 'Eléctrico e iluminación / Bujías'),
    ('Eléctrico e iluminación / Bobinas', 'Eléctrico e iluminación / Bobinas'),
    ('Eléctrico e iluminación / CDI', 'Eléctrico e iluminación / CDI'),
    ('Eléctrico e iluminación / Reguladores y rectificadores', 'Eléctrico e iluminación / Reguladores y rectificadores'),
    ('Eléctrico e iluminación / Luces', 'Eléctrico e iluminación / Luces'),
    ('Eléctrico e iluminación / Fusibles y relés', 'Eléctrico e iluminación / Fusibles y relés'),
    ('Eléctrico e iluminación / Arranque', 'Eléctrico e iluminación / Arranque'),
    ('Motor', 'Motor'),
    ('Motor / Pistones y anillos', 'Motor / Pistones y anillos'),
    ('Motor / Árboles de levas', 'Motor / Árboles de levas'),
    ('Motor / Juntas y retenes de motor', 'Motor / Juntas y retenes de motor'),
    ('Lubricantes y mantenimiento', 'Lubricantes y mantenimiento'),
    ('Lubricantes y mantenimiento / Aceites', 'Lubricantes y mantenimiento / Aceites'),
    ('Lubricantes y mantenimiento / Grasas', 'Lubricantes y mantenimiento / Grasas'),
    ('Lubricantes y mantenimiento / Aditivos', 'Lubricantes y mantenimiento / Aditivos'),
    ('Lubricantes y mantenimiento / Limpiadores', 'Lubricantes y mantenimiento / Limpiadores'),
    ('Lubricantes y mantenimiento / Filtros de aceite', 'Lubricantes y mantenimiento / Filtros de aceite'),
    ('Suspensión', 'Suspensión'),
    ('Suspensión / Amortiguadores', 'Suspensión / Amortiguadores'),
    ('Suspensión / Horquillas', 'Suspensión / Horquillas'),
    ('Suspensión / Retenes de horquilla', 'Suspensión / Retenes de horquilla'),
    ('Admisión y combustible', 'Admisión y combustible'),
    ('Admisión y combustible / Filtros de aire', 'Admisión y combustible / Filtros de aire'),
    ('Admisión y combustible / Tapas de tanque', 'Admisión y combustible / Tapas de tanque'),
    ('Admisión y combustible / Carburadores e inyección', 'Admisión y combustible / Carburadores e inyección'),
    ('Admisión y combustible / Cables de acelerador', 'Admisión y combustible / Cables de acelerador'),
    ('Escape', 'Escape'),
    ('Escape / Tubos de escape', 'Escape / Tubos de escape'),
    ('Escape / Silenciadores', 'Escape / Silenciadores'),
    ('Accesorios', 'Accesorios'),
    ('Accesorios / Cascos', 'Accesorios / Cascos'),
    ('Accesorios / Visores', 'Accesorios / Visores'),
    ('Accesorios / Protección', 'Accesorios / Protección'),
    ('Accesorios / Espejos', 'Accesorios / Espejos'),
    ('Accesorios / Puños', 'Accesorios / Puños'),
    ('Accesorios / Soportes', 'Accesorios / Soportes'),
    ('Accesorios / Baúles', 'Accesorios / Baúles'),
    ('Accesorios / Fundas', 'Accesorios / Fundas'),
    ('Accesorios / Asientos', 'Accesorios / Asientos'),
    ('cauchos y tripas', 'Cauchos y ruedas'),
    ('ruedas', 'Cauchos y ruedas'),
    ('freno', 'Frenos'),
    ('transmisiones', 'Transmisión'),
    ('motores', 'Motor'),
    ('electrico', 'Eléctrico e iluminación'),
    ('electricidad', 'Eléctrico e iluminación'),
    ('iluminacion', 'Eléctrico e iluminación'),
    ('lubricacion', 'Lubricantes y mantenimiento'),
    ('cascos y proteccion', 'Accesorios'),
    ('accesorio', 'Accesorios'),
    ('accesorios universal', 'Accesorios'),
    ('accesorios universales', 'Accesorios'),
    ('caucho', 'Cauchos y ruedas / Cauchos'),
    ('cauchos', 'Cauchos y ruedas / Cauchos'),
    ('neumatico', 'Cauchos y ruedas / Cauchos'),
    ('neumaticos', 'Cauchos y ruedas / Cauchos'),
    ('tripa', 'Cauchos y ruedas / Tripas'),
    ('tripas', 'Cauchos y ruedas / Tripas'),
    ('camara', 'Cauchos y ruedas / Tripas'),
    ('camaras', 'Cauchos y ruedas / Tripas'),
    ('rodamiento de rueda', 'Cauchos y ruedas / Rodamientos de rueda'),
    ('rodamientos de rueda', 'Cauchos y ruedas / Rodamientos de rueda'),
    ('pastilla', 'Frenos / Pastillas'),
    ('pastillas', 'Frenos / Pastillas'),
    ('pastillas de freno', 'Frenos / Pastillas'),
    ('banda', 'Frenos / Bandas'),
    ('bandas', 'Frenos / Bandas'),
    ('bandas de freno', 'Frenos / Bandas'),
    ('disco de freno', 'Frenos / Discos'),
    ('discos de freno', 'Frenos / Discos'),
    ('manilla de freno', 'Frenos / Manillas de freno'),
    ('cadena', 'Transmisión / Cadenas'),
    ('cadenas', 'Transmisión / Cadenas'),
    ('corona', 'Transmisión / Coronas'),
    ('coronas', 'Transmisión / Coronas'),
    ('pinon', 'Transmisión / Piñones'),
    ('pinones', 'Transmisión / Piñones'),
    ('pi on', 'Transmisión / Piñones'),
    ('pi ones', 'Transmisión / Piñones'),
    ('kit de relacion', 'Transmisión / Kits de relación'),
    ('kits de relacion', 'Transmisión / Kits de relación'),
    ('kites de relaciones', 'Transmisión / Kits de relación'),
    ('embrague', 'Transmisión / Embragues'),
    ('embragues', 'Transmisión / Embragues'),
    ('tensor', 'Transmisión / Tensores'),
    ('tensores', 'Transmisión / Tensores'),
    ('bateria', 'Eléctrico e iluminación / Baterías'),
    ('baterias', 'Eléctrico e iluminación / Baterías'),
    ('bujia', 'Eléctrico e iluminación / Bujías'),
    ('bujias', 'Eléctrico e iluminación / Bujías'),
    ('bobina', 'Eléctrico e iluminación / Bobinas'),
    ('bobinas', 'Eléctrico e iluminación / Bobinas'),
    ('arranque', 'Eléctrico e iluminación / Arranque'),
    ('piston', 'Motor / Pistones y anillos'),
    ('pistones', 'Motor / Pistones y anillos'),
    ('anillo', 'Motor / Pistones y anillos'),
    ('anillos', 'Motor / Pistones y anillos'),
    ('arboleva', 'Motor / Árboles de levas'),
    ('arbol de levas', 'Motor / Árboles de levas'),
    ('aceite', 'Lubricantes y mantenimiento / Aceites'),
    ('aceites', 'Lubricantes y mantenimiento / Aceites'),
    ('lubricante', 'Lubricantes y mantenimiento / Aceites'),
    ('lubricantes', 'Lubricantes y mantenimiento / Aceites'),
    ('amortiguador', 'Suspensión / Amortiguadores'),
    ('amortiguadores', 'Suspensión / Amortiguadores'),
    ('filtro de aire', 'Admisión y combustible / Filtros de aire'),
    ('filtros de aire', 'Admisión y combustible / Filtros de aire'),
    ('tapa tanque', 'Admisión y combustible / Tapas de tanque'),
    ('tapa de tanque', 'Admisión y combustible / Tapas de tanque'),
    ('silenciador', 'Escape / Silenciadores'),
    ('silenciadores', 'Escape / Silenciadores'),
    ('casco', 'Accesorios / Cascos'),
    ('cascos', 'Accesorios / Cascos'),
    ('asiento', 'Accesorios / Asientos'),
    ('asientos', 'Accesorios / Asientos')
), mapped as (
  select p.id, p.name, p.owner_id, p.is_active, p.stock_covers_min_order,
         p.category as original_category, c.path as known_path,
         btrim(regexp_replace(translate(lower(coalesce(p.name, '')), 'áéíóúüñ', 'aeiouun'), '[^a-z0-9]+', ' ', 'g')) as product_key
  from public.products p
  left join categories c on btrim(regexp_replace(translate(lower(coalesce(c.label, '')), 'áéíóúüñ', 'aeiouun'), '[^a-z0-9]+', ' ', 'g')) = btrim(regexp_replace(translate(lower(coalesce(p.category, '')), 'áéíóúüñ', 'aeiouun'), '[^a-z0-9]+', ' ', 'g'))
), classified as (
  select *, case
    when strpos(known_path, ' / ') > 0 then known_path
    when product_key ~ $rx$\y(cauchos?|neumaticos?)\y$rx$ then 'Cauchos y ruedas / Cauchos'
    when product_key ~ $rx$\y(tripas?|camaras? de aire)\y$rx$ then 'Cauchos y ruedas / Tripas'
    when product_key ~ $rx$\yrodamientos?\y.*\yrueda\y$rx$ then 'Cauchos y ruedas / Rodamientos de rueda'
    when product_key ~ $rx$\ypastillas?\y$rx$ then 'Frenos / Pastillas'
    when product_key ~ $rx$\ybandas?\y.*\y(freno|rallo)\y$rx$ then 'Frenos / Bandas'
    when product_key ~ $rx$\ydisco\y.*\y(freno|ebc|flotante)\y$rx$ then 'Frenos / Discos'
    when product_key ~ $rx$\ymanillas?\y.*\yfreno\y$rx$ then 'Frenos / Manillas de freno'
    when product_key ~ $rx$\ykits?\y.*\yrelacion\y$rx$ then 'Transmisión / Kits de relación'
    when product_key ~ $rx$\yembragues?\y$rx$ then 'Transmisión / Embragues'
    when product_key ~ $rx$\ytensores?\y.*\ycadena\y|\ytensor\y.*\ycadena\y$rx$ then 'Transmisión / Tensores'
    when product_key ~ $rx$\ybaterias?\y$rx$ then 'Eléctrico e iluminación / Baterías'
    when product_key ~ $rx$\ybujias?\y$rx$ then 'Eléctrico e iluminación / Bujías'
    when product_key ~ $rx$\ybobinas?\y$rx$ then 'Eléctrico e iluminación / Bobinas'
    when product_key ~ $rx$\ycdi\y$rx$ then 'Eléctrico e iluminación / CDI'
    when product_key ~ $rx$\y(reguladores?|rectificadores?|regulador|rectificador)\y$rx$ then 'Eléctrico e iluminación / Reguladores y rectificadores'
    when product_key ~ $rx$\y(led|stop|faro|luces|bombillo|luz)\y$rx$ then 'Eléctrico e iluminación / Luces'
    when product_key ~ $rx$\y(fusibles?|reles?)\y$rx$ then 'Eléctrico e iluminación / Fusibles y relés'
    when product_key ~ $rx$\yarranque\y$rx$ then 'Eléctrico e iluminación / Arranque'
    when product_key ~ $rx$\yfiltros?\y.*\yaceite\y$rx$ then 'Lubricantes y mantenimiento / Filtros de aceite'
    when product_key ~ $rx$\ylimpiadores?\y|\ylimpiador\y$rx$ then 'Lubricantes y mantenimiento / Limpiadores'
    when product_key ~ $rx$\yaceites?\y$rx$ then 'Lubricantes y mantenimiento / Aceites'
    when product_key ~ $rx$\ygrasas?\y$rx$ then 'Lubricantes y mantenimiento / Grasas'
    when product_key ~ $rx$\yaditivos?\y$rx$ then 'Lubricantes y mantenimiento / Aditivos'
    when product_key ~ $rx$\yretenes?\y.*\yhorquilla\y$rx$ then 'Suspensión / Retenes de horquilla'
    when product_key ~ $rx$\y(amortiguador(es)?|mortiguador)\y$rx$ then 'Suspensión / Amortiguadores'
    when product_key ~ $rx$\yhorquillas?\y$rx$ then 'Suspensión / Horquillas'
    when product_key ~ $rx$\yfiltros?\y.*\y(aire|espuma)\y$rx$ then 'Admisión y combustible / Filtros de aire'
    when product_key ~ $rx$\ytapas?\y.*\ytanque\y$rx$ then 'Admisión y combustible / Tapas de tanque'
    when product_key ~ $rx$\y(carburador(es)?|inyector(es)?)\y$rx$ then 'Admisión y combustible / Carburadores e inyección'
    when product_key ~ $rx$\ycables?\y.*\yacelerador\y$rx$ then 'Admisión y combustible / Cables de acelerador'
    when product_key ~ $rx$\ysilenciador(es)?\y$rx$ then 'Escape / Silenciadores'
    when product_key ~ $rx$\yescapes?\y$rx$ then 'Escape / Tubos de escape'
    when product_key ~ $rx$\ycascos?\y$rx$ then 'Accesorios / Cascos'
    when product_key ~ $rx$\yvisores?\y|\yvisor\y$rx$ then 'Accesorios / Visores'
    when product_key ~ $rx$\y(espejos?|retrovisores?)\y$rx$ then 'Accesorios / Espejos'
    when product_key ~ $rx$\y(punos?|grips?)\y$rx$ then 'Accesorios / Puños'
    when product_key ~ $rx$\yasientos?\y$rx$ then 'Accesorios / Asientos'
    when product_key ~ $rx$\y(piston(es)?|anillos? de piston)\y$rx$ then 'Motor / Pistones y anillos'
    when product_key ~ $rx$\y(arboleva|arbol de levas)\y$rx$ then 'Motor / Árboles de levas'
    when product_key ~ $rx$\ycadenas?\y$rx$ then 'Transmisión / Cadenas'
    when product_key ~ $rx$\ycoronas?\y$rx$ then 'Transmisión / Coronas'
    when product_key ~ $rx$\ypinon(es)?\y$rx$ then 'Transmisión / Piñones'
    else known_path
  end as new_category
  from mapped
)
update public.products p
set category = c.new_category
from classified c
where p.id = c.id
  and c.new_category is not null
  and p.category is not distinct from c.original_category
  and p.category is distinct from c.new_category;
