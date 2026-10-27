# Ficha: nombre, descripción y especificaciones

Cambio local de presentación, conectado al sandbox. Los datos del producto, precios y reglas de compra se conservan. La galería de fotos de la etapa anterior permanece integrada.

## Organización

| Before | After | Why |
|---|---|---|
| SKU, categoría y proveedor antes del nombre. | Nombre como encabezado principal, seguido de categoría y código real, cuando existen. | Identifica primero el repuesto que se está viendo. |
| Parte del UUID usada como SKU al faltar un código. | Sin SKU registrado no se inventa un código visible. | Evita confundir un identificador de base de datos con el código del proveedor. |
| Nombre comercial en mayúsculas sin contexto. | «Vendido por» y nombre con su escritura original; se conserva el acceso al catálogo del proveedor. | Explica quién ofrece el producto. |
| Descripción y compatibilidad en cajas con etiquetas pequeñas en mayúsculas. | Secciones con títulos legibles y texto seleccionable que conserva los saltos de línea. | Facilita leer y copiar datos del producto. |
| Campos técnicos publicados en cajas individuales sin un encabezado común. | Sección «Especificaciones» con pares etiqueta/valor y separadores. | Permite comparar atributos rápidamente sin acumular tarjetas. |
| Identificador interno siempre visible en la ficha. | Fuera de la ficha del comprador; administración e importador pueden desplegar «Información para soporte». | Los datos operativos no compiten con la información para comprar. |

Se muestran únicamente la descripción, la compatibilidad y los campos técnicos que estén registrados. No se infieren compatibilidades, marcas, medidas o cualidades a partir del nombre o las fotos. Los campos personalizados mantienen el filtro existente de publicación al aliado. Si no hay información técnica, aparece un solo mensaje breve, sin secciones vacías.

Las especificaciones pasan de dos columnas a filas apiladas cuando el ancho o el tamaño del texto lo requiere. Nombres, códigos y valores largos pueden ocupar varias líneas. El indicador de stock también puede ajustar su texto al ancho disponible.

## Archivos

- `lib/features/catalog/product_detail_information.dart`: identidad, secciones técnicas y referencia operativa opcional.
- `lib/features/catalog/product_detail_screen.dart`: integración y orden del contenido.
- `lib/features/inventory/product_custom_fields_section.dart`: filas adaptables para los campos publicados; el editor de inventario conserva su comportamiento.
- `test/product_detail_information_test.dart`: casos de datos incompletos, identificación, privacidad de campos publicados, soporte y adaptación.

## Validación

Las 24 pruebas específicas de información, campos personalizados y galería aprobaron. Se probaron anchuras de 320, 390, 800 y 1440 px, texto ampliado y tema oscuro, más la integración de la ficha para visitantes. Registros: `build/local-audit/product-information-*`.

La suite completa aprobó **325 pruebas**. El análisis de los cinco archivos de información, ficha y galería terminó sin problemas; el detector estático de Impeccable no informó hallazgos. Las capturas `ficha-informacion-antes-movil.png` y `ficha-informacion-antes-escritorio.png` conservan la organización previa.

La compilación release se verificó en el puerto 3001 con destino sandbox. En la ficha real «Casco Venture 1.0 MIPS», a 390 × 844 y 1440 × 900, el nombre aparece primero, seguido de categoría y proveedor; la descripción conserva su texto y no aparece un SKU generado desde el UUID. Al no haber compatibilidad o especificaciones publicadas en ese producto, no se fabrican secciones. La galería conservó la ampliación y se comprobó que el título del visor se anuncia una sola vez. Capturas: `ficha-informacion-despues-movil.png`, `ficha-informacion-despues-escritorio.png` y `fotos-visor-final-movil.png`.
