# Proveedores y tienda en móvil

Desde Inicio → Tus proveedores → Ver tiendas se abre el directorio completo.
La vista de escritorio conserva sus componentes y distribución anteriores.

- Búsqueda por negocio, ubicación, nombre, SKU, descripción o marca publicada.
  Los campos ERP privados no se usan para buscar marcas.
- Todos agrupa primero los proveedores donde ya hubo compras confirmadas y
  después los demás. Donde compraste excluye pedidos pendientes, rechazados y
  cancelados; incluye avances confirmados o pago aprobado del usuario conectado.
- Mejor valorados muestra solo proveedores con valoraciones reales, ordenados
  por promedio, cantidad de valoraciones, nombre e identificador.
- Filtros de estado y categoría, paginación de 40 proveedores y reintento.
  La búsqueda y los filtros se aplican en el servidor a todo el directorio.
- La tienda móvil conserva mínimos comerciales, métodos de pago, sellos y QR.
  RIF, dirección y teléfono quedan en Datos y ubicación. El chat es una acción
  visible y la ubicación se ofrece cuando el proveedor tiene un enlace de mapa.
- La búsqueda de productos conserva siempre el proveedor y la categoría elegida.
  Las respuestas anteriores no reemplazan los resultados de una búsqueda nueva.
- Las tarjetas usan las mismas reglas de precios, descuentos, variantes, stock
  y cantidades mínimas del catálogo. Se puede agregar sin abrir la ficha y ver
  el contador de la bolsa. Las filas tienen altura uniforme; el texto ampliado
  utiliza una columna para conservar la legibilidad.

## Ajuste visual móvil

Se conserva el encabezado existente. El directorio usa logos circulares de mayor
tamaño, nombres destacados, ubicación con icono, valoraciones legibles y etiquetas
claras con borde suave. Las tarjetas muestran dos familias y el número de familias
adicionales; los filtros siguen cubriendo el catálogo completo.

La franja inferior aprovecha todo el ancho para compartir espacio entre categorías
y Ver tienda, reduciendo la altura y el relleno inferior. Con texto ampliado o en
pantallas estrechas conserva filas independientes. La flecha de Ver tienda usa
`assets/angulo/angulo-pequeno-derecho.svg` a 16 px, igual que la acción de Inicio.

La ficha comercial se agrupa en un panel gris azulado con separadores, categorías
reales del inventario y métodos de pago en cápsulas. Las acciones Consultar proveedor
y Ver ubicación tienen mayor presencia. Las tarjetas de producto usan un estilo
compacto exclusivo de la tienda móvil, con fotografías completas y filas uniformes.
La barra inferior reutiliza la del Inicio y sus recargas al cambiar de módulo.
Los componentes de escritorio conservan el estilo anterior.

El buscador de Proveedores se desvanece con la misma curva de Inicio y Catálogo
y recoge sus 70 px de espacio mientras se desplaza la lista. El título, la bolsa
y los filtros de proveedores permanecen visibles. La lupa del encabezado compacto
restaura el buscador y enfoca el campo conservando la consulta. El desplazamiento
anidado evita saltos en listas cortas; se respeta la preferencia de movimiento reducido.

Las fotos repetidas de Tapa tanque gasolina y LED stop 12 V corresponden al mismo
archivo de demostración asignado en sandbox (`CAT-TRANSMISION.jpg`). Este ajuste
visual no reasigna fotografías ni inventa imágenes o logos para los proveedores.

## Base de datos

`mobile_supplier_directory` agrega la función `aliado_supplier_directory`.
Es invoker, respeta RLS y devuelve únicamente datos públicos del proveedor y un
indicador de compras del propio usuario. No admite acceso anónimo.

La migración está aplicada en sandbox. Aplicarla también en el ambiente de destino
antes de publicar el frontend; no se modificaron DEV ni producción en esta tarea.

## Comprobación

- `test/mobile_supplier_directory_test.dart`: búsqueda, respuestas tardías,
  filtros, paginación, reintento, navegación, ficha plegable, chat, compra y bolsa;
  pantallas pequeñas, texto ampliado y modo oscuro.
- `supabase/tests/mobile_supplier_directory.sql`: directorio, límite y orden,
  historial personal, marcas visibles frente a privadas y control de acceso.
  Las modificaciones de prueba están dentro de una transacción con rollback.
- Regresiones de Inicio, tienda y precios del catálogo.
