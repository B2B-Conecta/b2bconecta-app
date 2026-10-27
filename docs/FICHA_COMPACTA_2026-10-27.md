# Ficha compacta: refinamiento visual

Objetivo: que el producto, el precio y las condiciones de compra se entiendan de un vistazo, conservando los datos y las reglas existentes. Se mantiene la identidad azul y blanca de B2B Conecta y la galería con ampliación.

| Before | After | Why |
|---|---|---|
| Foto cuadrada que ocupa casi media pantalla móvil y navegación superpuesta. | Barra superior con regreso y favorito; foto de altura contenida y ampliación disponible. | La información de compra aparece antes sin recortar el producto. |
| Un área grande de imagen aun cuando falta la foto. | Estado vacío más corto, adaptado al tamaño del texto. | Evita desplazar información útil por un espacio vacío. |
| Precio y stock en bloques separados. | Resumen de compra con precio USD, REF y Bs, disponibilidad y mínimo juntos. | Reúne las condiciones que se necesitan para decidir. |
| Proveedor, ubicación y valoraciones repetidos en distintas zonas. | Fila única con logo, nombre, ubicación y valoración, cuando existe. | Reduce repetición y conserva el acceso al proveedor. |
| Dos botones de ancho completo en el pie móvil. | Consulta accesible desde un botón de chat y compra como acción principal de 48 px. | Mantiene ambas acciones y reduce la altura del pie; con texto grande conserva la disposición vertical. |
| Separaciones amplias y margen final de 100 px además del pie fijo. | Espaciado más ajustado y sin el margen duplicado. | La descripción y la ficha técnica aparecen antes. |

El nombre encabeza el contenido, la categoría queda como etiqueta secundaria y el código se muestra solo cuando está registrado. Las secciones técnicas mantienen todos los campos publicados. Las fotos siguen usando encuadre completo y fondo blanco.

La disponibilidad utiliza `stockForSale`, descontando lo reservado, y respeta el mínimo efectivo. El resumen reutiliza `CatalogCartPrice`: no cambia el USD promocional, el REF original ni el Bs correspondiente. Las acciones de compra y consulta conservan sus permisos y callbacks. En escritorio la compra se sitúa junto al resumen, antes de las descripciones largas.

Archivos: `product_detail_screen.dart`, `product_detail_commerce.dart`, `product_detail_information.dart`, `product_photo_gallery.dart`. La nueva composición no modifica productos, pedidos, mensajes ni configuración del sandbox.

Las pruebas específicas cubren importes separados, stock reservado, proveedor y navegación, ausencia de valoraciones, campos publicados, identificación y ficha completa en móvil, paisaje, escritorio, texto ampliado y modo oscuro. Registros: `build/local-audit/product-detail-compact-*`.

## Validación final

- Análisis estático de los seis archivos: sin incidencias.
- Suite completa de Flutter: 332 pruebas aprobadas.
- Compilación web de producción: completada; vista local en `http://localhost:3001/`.
- Revisión visual en navegador a 390 × 844 y 1440 × 900 con Casco Venture 1.0 MIPS: nombre, precio 80.00 REF, Bs 70.550,15, 10 unidades disponibles, mínimo de 5 y descripción original visibles. Favorito, ampliación, consulta y compra conservan sus accesos. La inspección visual no ejecutó consultas por chat ni pedidos.
- Evidencia móvil: `build/local-audit/ficha-compacta-despues-movil.png`.
- Evidencia escritorio: `build/local-audit/ficha-compacta-despues-escritorio.png`.
- Comparación previa: `build/local-audit/ficha-compacta-antes-movil.png` y `ficha-compacta-antes-escritorio.png`.

Las verificaciones visuales corresponden a la versión web adaptable. No se arrancó el emulador Android.
