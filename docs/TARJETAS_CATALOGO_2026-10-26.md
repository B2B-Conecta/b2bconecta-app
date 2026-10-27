# Tarjetas del catálogo — revisión visual local

Se conserva la paleta azul de B2B Conecta y el recorrido hacia el detalle del repuesto. Este cambio se realiza en la copia local con datos del sandbox; no publica ni modifica DEV o producción.

## Presentación

- Foto completa con `BoxFit.contain` sobre un lienzo blanco. El gris suave se conserva para los estados de carga o foto no disponible.
- Nombre con espacio para dos líneas, ajustado al tamaño de texto, y precio REF destacado. Se conservan las promociones USD, porcentajes y conversión BCV del componente compartido de precios.
- Existencias y mínimo de unidades en líneas separadas, para que el mínimo no desaparezca en tarjetas estrechas. Los productos sin stock o pausados lo indican.
- Categoría, proveedor y valoración agrupados en el pie. El proveedor conserva su acceso al catálogo y el nombre completo en la ayuda emergente.
- Botón «Agregar al carrito» de al menos 44 px con icono de carrito y signo de suma para aliados habilitados. El favorito conserva sus 44 px, etiqueta accesible y estado seleccionado. Foto y nombre abren el detalle; un producto ya añadido muestra «Ver carrito» y el icono de carrito para revisar sus cantidades.
- Sellos existentes de proveedor, garantía y envío conservados; las etiquetas largas se ajustan al ancho disponible.
- Filas construidas de forma diferida al desplazarse: cada fila toma la altura de su tarjeta con más contenido, sin una altura fija para todo el catálogo. El proveedor y el botón se alinean al pie; el espacio de dos líneas del nombre alinea los precios entre nombres cortos y largos. En móvil, el texto ampliado utiliza una columna para mantener la lectura.
- Campos ERP visibles según los permisos existentes; los campos internos permanecen ocultos.

## Validación

Primera revisión: 16 pruebas aprobadas entre tarjetas, sellos y campos personalizados. La revisión posterior de agregado directo y altura natural aprobó 34 pruebas de catálogo y carrito. Cubren mínimo de compra, stock insuficiente, producto pausado, cuenta no habilitada o suspendida, restauración del carrito, ausencia de proveedor y pulsaciones repetidas sin duplicar cantidades. Incluyen anchos de tarjeta de 168, 220, 280 y 358 px; texto al 160 %, modo oscuro, nombres largos, promociones, tamaño táctil, apertura independiente del producto y proveedor y una comprobación de la distancia entre mínimo y proveedor. La acción de carrito se probó dentro de la tarjeta para verificar que no abre además el detalle.

Compilación web release final correcta, servida en el puerto 3001. Se verificó el destino de datos contra el identificador del sandbox `czswojzpekcsisudgfsg`. El detector manual de Impeccable no reportó hallazgos; las pruebas de widgets complementan esa comprobación para Flutter.

No se crean fotos sustitutivas ni se inventan características de los repuestos: las imágenes ausentes se señalan explícitamente. No se enviaron pedidos ni mensajes para esta revisión.

El agregado directo y el detalle comparten `CartProductActions`: se añade inicialmente el mínimo efectivo del producto, con el cálculo de precios existente. Las cantidades se revisan en el carrito y el checkout conserva sus validaciones del servidor. La referencia UX consultada para señalar lo ya añadido es [Baymard: Highlight Items Already in the User’s Cart](https://baymard.com/research-articles/highlight-products-if-in-users-cart); la elección de agregado directo es una decisión para este catálogo de repuestos concretos y compras recurrentes.

Comprobación en navegador a 390 × 844: se verificaron las tarjetas sin relleno vertical, con y sin foto, y el agregado de «Manilla freno derecha». El contador pasó de 20 a 25 unidades; el botón cambió a «Ver carrito» y abrió una línea de 5 unidades sin duplicarla. Al terminar se retiró únicamente esa línea de prueba y se recuperó la selección anterior de 20 unidades. Evidencia local: `build/local-audit/catalogo-compacto-agregar-movil.png`.

También se revisó la distribución de escritorio a 1440 × 900, con cuatro columnas dentro del panel y sin desbordamientos visibles. Evidencia local: `build/local-audit/catalogo-compacto-agregar-escritorio.png`. Esta comprobación usa la web adaptable; no sustituye una revisión nativa en iOS o Android.

## Ajuste del 27 de octubre de 2026

Se unificó el lienzo blanco de las fotografías y se alinearon las tarjetas por fila según el contenido más alto, con el proveedor y la acción al pie. El título reserva dos líneas para alinear el precio. Cada fila continúa creándose de forma diferida; la medición adicional se limita a las tarjetas de esa fila. El botón conserva su etiqueta y añade un icono de carrito con suma; el estado «Ver carrito» utiliza el icono de carrito sin suma.

Se aprobaron 35 pruebas de catálogo y carrito, incluidos nombres de distinta longitud, filas con y sin promoción USD, alineación de precios y botones, y agregado pulsando directamente el icono. El análisis de los archivos modificados no reportó problemas y la compilación web release final fue correcta. El detector de Impeccable no reportó hallazgos de layout. Evidencia móvil de la versión nueva: `build/local-audit/catalogo-blanco-carrito-movil.png` y `build/local-audit/catalogo-blanco-fila-alineada-movil.png`.

En navegador móvil a 390 × 844 se pulsó el icono de «Corona de Moto 38 dientes»: el contador pasó de 20 a 25 unidades, la acción cambió a «Ver carrito» y su línea mostró 5 unidades. Se retiró únicamente ese producto al terminar, recuperando las 20 unidades originales. No se enviaron pedidos ni mensajes; el destino compilado continúa siendo el sandbox.

En escritorio a 1440 × 900 se verificó una fila con cuatro productos y una promoción USD: los precios REF y los botones quedan alineados, las tarjetas comparten el borde inferior y la corona se integra en el lienzo blanco. Evidencia: `build/local-audit/catalogo-blanco-alineado-escritorio.png`. Se restauró el tamaño habitual del navegador al terminar.
