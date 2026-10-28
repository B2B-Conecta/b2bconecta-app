# Cantidades y precios en el catálogo local

## Recorrido

La acción inicial «Agregar al carrito» añade el mínimo efectivo del SKU. Después aparece el selector de cantidad en la misma tarjeta: reducir, escribir el número y aumentar. La barra general conserva «Ver carrito». El mínimo no elimina el producto: el botón de reducir se desactiva en ese límite y se puede quitar desde el carrito.

Los controles respetan stock, mínimo, cuenta habilitada, suspensión de pedidos y restauración del borrador. El campo se identifica por producto para lectores de pantalla y conserva la separación por cuenta. Foto, nombre, proveedor y favorito mantienen sus acciones independientes.

## Precios

`CatalogCartPrice` observa la cantidad y el producto actuales del carrito; antes de agregar usa el mínimo del SKU. La presentación conserva los importes publicados: `sale_price_usd` se muestra como USD promocional en verde, primero; `precio` sigue siendo el REF original y aparece debajo; Bs se calcula desde ese REF con la tasa BCV vigente. El porcentaje del chip compara la oferta USD publicada con el REF original.

Ejemplo de regresión aportado por el usuario: **48.00 USD**, **52.00 REF**, **Bs 45.857,60** con la tasa de su captura. No se sustituye 52 REF por 48 REF ni se aplica otro descuento al USD publicado. Sin una oferta USD positiva y menor al REF se muestran REF y Bs; sin tasa válida se omite Bs. Editar cantidades conserva estos precios publicados; las reglas de volumen del carrito siguen calculándose por separado.

El filtro rápido conserva «Promociones USD» y su selección activa «Promoción USD», sin modificar la consulta existente. La vista previa del importador explica el orden USD, REF y Bs.

Refinamiento posterior: se retiraron los sufijos visibles «/ ud» y la línea redundante «Precio USD». El chip de porcentaje acompaña al USD en la misma línea; si el espacio o el texto ampliado lo requieren, pasa a la siguiente para evitar superposiciones. REF y Bs conservan sus importes y su orden.

La corrección del 27 de octubre restaura la presentación del catálogo y de las vistas que comparten el componente de precios, incluida la ficha de detalle. No cambia los cálculos del carrito ni el checkout. La primera implementación había confundido el precio efectivo del carrito con el REF publicado; esa interpretación fue retirada a petición del usuario.

## Validación

La validación inicial del selector aprobó 300 pruebas; esas expectativas de presentación de precios se corrigieron junto con esta implementación. Se cubren agregado mínimo, edición directa, topes de stock, restauración, cuentas suspendidas y cálculos existentes del carrito. También se mantienen las pruebas de tarjeta estrecha, texto ampliado, modo oscuro, navegación independiente y alineación por fila.

La corrección añade la regresión exacta 52 REF / 48 USD / Bs del precio base tanto en grid como en detalle, con comprobación del color y el orden vertical. Los casos sin oferta, con cero, negativa, igual o superior al REF no presentan un USD promocional. Las pruebas de cantidades comprueban que ni el precio base ni la oferta publicada se sobrescriben al activar un tramo por volumen.

La suite completa, con estas expectativas corregidas, aprobó **306 pruebas** (`catalog-usd-ref-full-tests.txt`).

Los registros de la corrección se guardan en `build/local-audit/catalog-usd-ref-*`. Los archivos `catalog-quantity-pricing-*` y las capturas anteriores corresponden a la implementación previa; no certifican la distinción corregida entre USD y REF.

El análisis estático de los siete archivos afectados terminó sin problemas. El detector de Impeccable no reportó hallazgos (`catalog-usd-ref-impeccable.json`).

La compilación web release terminó correctamente y se sirve en `http://localhost:3001/`. Se comprobó HTTP 200 y el destino sandbox en los assets compilados.

En Chrome a 390 × 844, después de recargar la compilación, se verificó la tarjeta real «Disco EBC 245 mm»: 48.00 USD en verde, chip −8%, 52.00 REF y Bs 45.857,60, en ese orden. La tarjeta vecina sin promoción conserva 18.00 REF y sus Bs; las acciones inferiores siguen alineadas por fila. Evidencia: `build/local-audit/catalogo-usd-ref-corregido-movil.png`. La verificación visual no creó pedidos ni modificó los datos de los productos.

Para el refinamiento del porcentaje en línea se repitieron las 29 pruebas del catálogo y del selector; todas aprobaron. El análisis de los dos archivos afectados y el detector de Impeccable terminaron sin problemas. La nueva compilación release quedó disponible en el mismo puerto 3001, conectada al sandbox. Registros: `catalog-inline-discount-*`.

La comprobación visual a 390 × 844 confirmó «48.00 USD» y «−8%» juntos, sin «/ ud» ni la línea «Precio USD». Debajo se mantienen 52.00 REF y Bs 45.857,60; las tarjetas conservan sus botones alineados. Captura actualizada: `build/local-audit/catalogo-descuento-inline-movil.png`.

Trabajo local con el sandbox. No se cambiaron esquemas, funciones de checkout ni reglas comerciales en el servidor.
