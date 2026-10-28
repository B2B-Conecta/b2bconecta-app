# Auditoría de stock, mínimo, cantidad y acción de compra

Alcance: catálogo aliado, ficha de producto y controles de cantidad del carrito local. Revisión de código, inspección visual de la web en escritorio y a 390 × 844, y ejecución de pruebas existentes. No se modificó la implementación ni se añadieron productos al carrito real durante esta revisión.

## Lo resuelto

- El stock vendible descuenta lo reservado (`PartModel.stockForSale`).
- El mínimo efectivo se muestra y las acciones bloquean productos pausados, agotados o que no cubren el mínimo.
- El catálogo agrega el mínimo y transforma el botón en selector editable; acepta entrada numérica y botones de 44 px.
- El selector limita cantidades al mínimo y al stock. La cuenta suspendida o el carrito recuperándose bloquean la edición del catálogo.
- La compra del detalle tiene una acción azul de altura mínima 48 px; en móvil permanece en el pie fijo y en escritorio junto al resumen de compra.
- El carrito separa el mínimo por producto del mínimo por importe de cada proveedor.

## Hallazgos y propuestas

| Prioridad | Before | After propuesto | Why |
|---|---|---|---|
| P2 | En el detalle no existe selector; `_addToCart` añade exclusivamente el mínimo. | Selector con cantidad inicial igual al mínimo, edición numérica y límites visibles, junto al botón de compra. | Permite elegir 12 unidades sin añadir 5 y desplazarse a otra pantalla. |
| P2 | Un producto ya añadido conserva «Agregar al carrito» en el detalle; al pulsarlo solo informa «Ya está en el carrito. Ajusta la cantidad allí». | Estado visible «En tu carrito: X», ajuste de cantidad y acceso «Ver carrito» con comportamiento coherente con el catálogo. | Evita una acción cuya etiqueta promete agregar pero no modifica nada. |
| P2 | La primera adición del catálogo agrega 5 o el mínimo configurado; la explicación está en un tooltip y el mínimo queda separado del botón. | Conservar el botón compacto y añadir una indicación visible de la cantidad que se incorporará. | En pantalla táctil el usuario conoce la cantidad antes de pulsar. |
| P2 | `CartQuantityField._commit` corrige silenciosamente un valor fuera de rango. | Mensaje breve: «Mínimo 5 unidades» o «Disponibles 25», conservando la cantidad válida. | Explica por qué escribir 1 da 5, o 100 da 25. |
| P2 | El catálogo utiliza gris para stock positivo inferior al mínimo, mientras el detalle usa ámbar. | Compartir presentación de disponibilidad; texto como «3 disponibles · mínimo 5». | Mantiene el mismo significado en ambas vistas. |
| P1 | El stock del catálogo usa el verde fijo `#2E7D32` con texto de 12 px sobre `AppColors.card` oscuro. | Usar el verde adaptado al tema que ya emplea el resumen del detalle. | Contraste calculado 3,65:1 en oscuro, inferior al mínimo 4,5:1 para texto pequeño; en claro 5,13:1. |

Fuentes: `product_detail_screen.dart:211` (adición del mínimo), `:528` (CTA), `:566` (pie fijo); `catalog_cart_button.dart:57` (selector), `:126` (tooltip); `cart_quantity_field.dart:39` (ajuste silencioso); `aliado_product_card.dart:338` (stock y color); `product_detail_commerce.dart` (estados del resumen).

## Orden sugerido

1. Unificar la compra del detalle: cantidad explícita, mínimos y stock, estado del producto ya añadido y acceso al carrito.
2. Compartir los estados de stock y corregir contraste del catálogo oscuro.
3. Explicar los ajustes de cantidades fuera de rango sin añadir diálogos ni mensajes repetidos.

La acción azul se conserva como principal. No necesita más color, mayor tamaño ni una segunda acción de compra que compita con ella. En móvil el selector debe mantener compacto el pie y adaptarse al texto ampliado; en escritorio queda junto al resumen.

## Verificación y límites

- 30 pruebas existentes aprobadas: `catalog_cart_button_test.dart`, `cart_journey_test.dart`, `product_min_order_qty_test.dart`, `product_detail_commerce_test.dart`.
- Cobertura relevante: mínimo, máximo, entrada numérica, cuenta suspendida, recuperación del carrito, stock insuficiente, doble activación, precios publicados y reservas.
- Registro: `build/local-audit/audit-stock-quantity-cta-tests.txt`.
- Captura móvil: `build/local-audit/auditoria-stock-compra-movil.png`.
- Revisión visual del detalle móvil con LED stop 12 V: 150 disponibles, mínimo 5 y botón de compra fijo, sin selector.
- La valoración de contraste oscuro proviene de los tokens del código y cálculo de luminancia; no de una captura del modo oscuro. No se validaron aquí gestos en dispositivos físicos ni disponibilidad en tiempo real del servidor de pedidos.
