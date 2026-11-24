# Inicio minorista

La pantalla usa Flutter y los datos del catálogo actual. No necesita React Native
ni una segunda implementación. La navegación se mantiene en `MainShell`.

## Componentes

- `lib/features/dashboard/aliado_home_dashboard.dart`: pantalla, carga de estado,
  refresco, navegación y composición de las secciones.
- `lib/features/dashboard/aliado_home_header.dart`: encabezado reutilizable con
  identidad, acciones y búsqueda inyectadas. Un `SliverPersistentHeader` mantiene
  la superficie azul y sus esquinas redondeadas durante todo el desplazamiento.
- `lib/features/dashboard/aliado_home_mobile.dart`: carrusel de promociones,
  tarjetas de recompra, listas horizontales, proveedores y acceso a consultas.
- `lib/features/dashboard/aliado_home_category_art.dart`: ilustraciones vectoriales
  de categorías.
- `lib/features/dashboard/aliado_home_service.dart`: carga de productos,
  promociones, categorías, proveedores y pedidos activos.
- `lib/core/layout/aliado_bottom_nav.dart`: cinco destinos y Catálogo elevado.
- `lib/core/widgets/ios_chrome.dart`: superficies translúcidas y respuesta
  elástica al pulsar.

## Comportamiento

La búsqueda se desvanece con el desplazamiento y aparece una lupa que abre el
buscador con filtros. Carrito, tasa BCV y Bandeja comparten la fila del negocio con áreas
táctiles de 44 × 44 px. Bandeja abre los accesos a Mensajes y Notificaciones.
Las barras respetan el área segura, el tamaño de texto, el alto
contraste y la preferencia de movimiento reducido.

Promociones: cero oculta la sección; una llena el ancho; varias permiten deslizar
con vista parcial de la siguiente y puntos de navegación. Se utilizan los recursos
móviles publicados, conservando su proporción. No se insertan anuncios ficticios.

Los contadores son reales; `9+` aparece cuando hay más de nueve elementos.
Seguimiento solo aparece con pedidos activos. Categorías y marcas se muestran
cuando existen en los datos disponibles; no se inventan marcas ni se reclasifican
productos. Las marcas se extraen de los productos cargados en Inicio.

Los precios reutilizan las reglas del catálogo: USD promocional cuando existe,
REF y conversión a Bs donde corresponda. Los proveedores que cobran únicamente
divisas conservan su tratamiento actual. Los cambios visuales no alteran cálculos.

## Validación

`flutter test --no-pub test/aliado_home_dashboard_test.dart test/aliado_home_service_test.dart`

Incluye pantallas estrechas, texto ampliado, navegación, búsqueda colapsada,
accesos persistentes, estados vacíos y promociones únicas/múltiples.
