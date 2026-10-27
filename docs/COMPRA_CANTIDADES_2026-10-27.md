# Cantidades y compra desde el detalle

Implementación local de los hallazgos de `AUDITORIA_STOCK_CANTIDAD_COMPRA_2026-10-27.md`, conservando las reglas B2B, los precios publicados y la acción de compra azul.

| Before | After | Why |
|---|---|---|
| El detalle siempre agrega el mínimo. | Selector con botones y entrada numérica antes de agregar, inicializado en el mínimo efectivo. | Permite elegir la compra en la misma pantalla. |
| El detalle mantiene «Agregar al carrito» cuando ya está añadido. | «En tu carrito: X unidades», edición inmediata y botón «Ver carrito». | Alinea lo que promete la interfaz con lo que hace. |
| El botón del catálogo repetía «5 unidades» además del mínimo visible en la tarjeta. | Se conserva solo «Agregar al carrito» con su icono; la cantidad sigue en el mínimo y en la etiqueta accesible. | Evita repetición visual, según la preferencia posterior del usuario. |
| La entrada fuera de rango se corrige silenciosamente. | Mensaje breve con el mínimo o las unidades disponibles y la cantidad ajustada. | El cambio automático tiene una explicación concreta. |
| Los estados del stock se implementan por separado. | `ProductStockSummary` compartido, verde adaptable al tema, ámbar al no cubrir el mínimo y neutro para agotado/pausado. | Conserva el mismo significado y mejora el contraste oscuro. |
| La compra depende de que el campo pierda el foco. | El selector confirma su valor explícitamente antes de agregar, incrementar o abrir el carrito. | Evita que se compre el valor anterior si el usuario aún tiene el teclado abierto. |

El pie móvil reúne el estado y el selector en una fila superior. Debajo, el icono de consulta a la izquierda acompaña al botón principal de compra. La consulta mantiene la etiqueta accesible «Preguntar sobre este producto». Los objetivos táctiles mantienen al menos 44 px y la compra 48 px. El campo crece con el texto ampliado. La rejilla conserva sus pruebas de alineación y altura compacta. La vista de escritorio conserva su disposición anterior.

Las acciones nuevas reutilizan `CartProductActions`: acceso de cuenta, rol, recuperación del carrito, morosidad, proveedor, actividad del producto, reservas, mínimo y stock. La adición seleccionada no duplica líneas existentes. Los cambios en el carrito se reflejan en el detalle, y cambiar de cuenta reinicia la selección pendiente.

No se altera la presentación USD/REF/Bs ni la lógica de descuentos por cantidad. El subtotal del carrito sigue recalculándose con sus reglas existentes. No se modifica DEV ni se publican cambios.

Pruebas añadidas en `test/features/cart/product_detail_purchase_controls_test.dart`: elección previa, edición de línea existente, entrada pendiente al agregar o abrir el carrito, incremento desde el texto visible, mensajes de límites, producto pausado/agotado/insuficiente, recuperación de carrito, cuenta suspendida, tamaños móvil/paisaje/escritorio, texto ampliado y contraste oscuro.

Registros de validación: `build/local-audit/purchase-controls-*`.

## Validación de código

- Análisis estático de diez archivos: sin incidencias.
- Suite completa: 345 pruebas aprobadas.
- Pruebas de las tarjetas: 18 aprobadas, incluidas alineación, compacidad y estados de compra.
- Detector Impeccable de los nuevos controles, stock y entrada numérica: sin hallazgos.
- La prueba de compra con el campo activo detectó y permitió corregir un valor pendiente sin confirmar; ahora la acción confirma el número visible de forma explícita.

## Comprobación de la web compilada

- Compilación web completada y entorno sandbox confirmado.
- Revisión a 390 × 844 y 1440 × 900: selector, cantidad explícita, consulta secundaria y compra visibles sin desbordamientos.
- Recorrido con LED stop 12 V: escribir 12 y pulsar directamente «Agregar al carrito» incorporó 12; incrementar desde el detalle mostró 13; «Ver carrito» abrió una línea de 13 unidades y subtotal 156.00 REF.
- Introducir 1 mostró «Mínimo 5 unidades. Cantidad ajustada a 5.». Los límites máximos y el contraste oscuro también están cubiertos por las pruebas.
- El producto utilizado en el recorrido se retiró del borrador y se confirmó el carrito vacío. No se confirmaron pedidos ni se abrió una consulta de chat.
- Servidores de PC y red con respuesta HTTP 200: `http://localhost:3001/` y `http://192.168.0.106:3001/`. La segunda respuesta se verificó desde la PC; no representa una prueba del firewall desde el teléfono.
- Evidencias: `build/local-audit/compra-catalogo-unidades-movil.png`, `compra-detalle-selector-movil.png`, `compra-detalle-en-carrito-movil.png`, `compra-detalle-escritorio.png`.

La validación visual corresponde a la web adaptable. No se arrancó el emulador ni se publicaron despliegues.

## Refinamiento solicitado del pie de compra

Se eliminó la segunda línea «5 unidades» del botón del catálogo y se recuperó el icono de consulta a la izquierda de la acción principal en móvil. Cantidad y estado ocupan una fila superior. Análisis de los tres archivos sin incidencias, 54 pruebas relacionadas aprobadas y compilación web completada. Revisión visual a 390 × 844 confirmada sin añadir productos ni enviar consultas. Evidencias: `build/local-audit/compra-catalogo-boton-simple.png` y `compra-detalle-consulta-izquierda.png`. Registros: `purchase-layout-refine-*`.
