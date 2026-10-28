# Integración de DEV en las mejoras de catálogo y carrito

Se integra `origin/dev` (hasta `dee62ee`) en la rama del PR #85, conservando el historial de ambos desarrollos. No se reescribe DEV ni se publican cambios directamente en esa rama.

## Resolución de conflictos

- `aliado_product_card.dart`: se conservan fotos sobre blanco sin recortar, altura por fila, precio USD/REF/Bs y estrella amarilla. Se incorpora el indicador de opciones de DEV. Una familia de variantes muestra «Elegir opciones» para abrir el detalle antes de añadir un SKU.
- `product_detail_screen.dart`: se conserva el detalle compacto, la galería con visor y los controles accesibles. Se incorporan la carga de variantes y los selectores por uno o varios atributos. Al seleccionar una variante se actualizan su identidad, precio, stock, mínimo y fotos; cada SKU tiene su propio estado de compra.
- `product_variant_selector.dart`: el selector de DEV se extrae como componente reutilizable sin duplicar la lógica de selección de atributos.

Los cambios de DEV en importación, exportación, mínimos definidos por proveedor y migraciones se mantienen. Las migraciones únicamente forman parte del historial recibido; esta integración no ejecuta SQL ni modifica bases de datos.

## Pruebas de integración añadidas

- Elegir opciones desde el catálogo abre la selección sin añadir automáticamente la variante principal.
- Cambiar entre variantes respeta sus precios, stock y mínimos distintos en 390 × 844, 320 × 640 con texto 1,6× y escritorio 1440 × 900.
- Cambiar de SKU conserva cantidades independientes en el carrito, incluidos mínimos de 1 y 2 unidades.

Los registros de esta integración se guardan localmente bajo `build/local-audit/dev-merge-*` y no se suben al repositorio.

## Resultado de validación

- Suite completa: 369 pruebas aprobadas, incluidos los casos nuevos de variantes y mínimos por proveedor.
- Análisis estático de los siete archivos de resolución y sus pruebas: sin incidencias.
- Compilación Flutter web release completada con el entorno sandbox.
- Comprobación de espacios y marcadores de conflicto de Git: sin incidencias.
- DEV se volvió a consultar antes de finalizar y seguía en `dee62ee`.

La revisión de disposición se ejecutó con pruebas de widgets de Flutter; no se utilizaron emuladores nativos en esta tarea.
