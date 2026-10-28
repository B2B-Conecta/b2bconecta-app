# Acentos de color en la ficha del producto

Refinamiento local de la ficha compacta: usar el color para distinguir acciones, disponibilidad y valoración, manteniendo la identidad azul y blanca.

| Before | After | Why |
|---|---|---|
| Estrella y puntuación secundarias, ambas grises. | Estrella ámbar, puntuación en color de texto principal y seminegrita, cantidad de valoraciones en gris. | Destaca la reputación sin competir con la compra. |
| Valoración numérica sin aclaración accesible. | Tooltip y etiqueta de accesibilidad «Valoración del proveedor». | Evita confundir la reputación del vendedor con una reseña del repuesto. |
| Stock inferior al mínimo en gris, alerta azul. | Stock y alerta en ámbar, con icono informativo y texto del mínimo. | Identifica una condición que impide pedir, además del color. |
| Alerta sin stock en azul. | Estado agotado neutro. | Reserva el azul para las acciones y mantiene visible el motivo. |

Se conservan el verde para disponibilidad suficiente y USD promocional, el porcentaje con fondo verde suave, la categoría sobre azul suave, la compra azul sólida y la consulta secundaria. Nombre, descripción y especificaciones permanecen neutros. Los importes, cantidades y reglas de compra no cambian.

El ámbar utiliza tokens compartidos: `#946200` en claro y `#F2C66D` en oscuro. Contraste calculado: 5,24:1 sobre blanco, 4,89:1 sobre el panel claro de compra y 12,23:1 sobre el panel oscuro. La puntuación conserva los colores de texto del tema.

Archivos: `lib/app/theme/app_theme.dart`, `lib/features/catalog/product_detail_commerce.dart`, `lib/features/catalog/product_detail_screen.dart`. Se adaptaron las expectativas existentes en `test/product_detail_commerce_test.dart`.

La revisión visual utiliza el Disco EBC 245 mm del sandbox, que ya cuenta con valoración de proveedor y promoción USD. No se crean valoraciones ni se modifican productos para mostrar el cambio.

## Verificación

- Análisis de cuatro archivos: sin incidencias.
- 16 pruebas de la ficha aprobadas, incluida disposición con texto grande y tema oscuro.
- Detector de diseño sobre los dos componentes modificados: sin hallazgos.
- Compilación web completada y servidor local con respuesta HTTP 200; backend sandbox confirmado.
- Revisión visual del navegador a 390 × 844 y 1440 × 900: estrella ámbar, nota 4.0 en seminegrita, contador gris y etiqueta accesible de proveedor. Conserva 48.00 USD, descuento del 8 %, 52.00 REF y Bs 45.857,60.
- Capturas: `build/local-audit/ficha-color-antes-movil.png`, `ficha-color-despues-movil.png` y `ficha-color-despues-escritorio.png`.
- Registros: `build/local-audit/product-detail-color-*`.

La inspección visual corresponde a la web adaptable; no ejecutó pedidos ni consultas por chat.

## Ajuste del amarillo de valoración

A petición del usuario, la estrella del detalle utiliza ahora exactamente `Colors.amber.shade800` (`#FF8F00`), el mismo tono que la estrella de la tienda. La puntuación y el contador conservan sus estilos. El ámbar de advertencias de stock no cambia. Validación de esta revisión: análisis estático sin incidencias, compilación web completada y revisión visual del Disco EBC 245 mm en navegador local después de recuperar su control. Evidencia: `build/local-audit/ficha-estrella-amarilla.png`.

## Consistencia de la estrella del catálogo

| Before | After | Why |
|---|---|---|
| Estrella del catálogo en verde de stock. | `Colors.amber.shade800` (`#FF8F00`), igual a detalle y tienda. | La valoración conserva el mismo significado visual en todo el recorrido. |

Solo cambia el color del icono en `aliado_product_card.dart`. No se modifican puntuación, stock ni precios. Registros: `build/local-audit/catalog-star-*`.

Verificación de esta revisión: análisis estático sin incidencias, compilación web correcta y revisión visual local de la tarjeta Caucho 2,75-18 Firestone Alix ST 17, proveedor Motoboxes (5.0), con estrella amarilla. Evidencia: `build/local-audit/catalogo-estrella-amarilla.png`. Servidor local con respuesta HTTP 200.
