# Fotos de producto: auditoría y mejoras locales

Revisión del catálogo, la ficha y la selección/subida de fotos. Se conservan los archivos originales, los precios y el diseño de las tarjetas. La verificación visual corresponde a la web responsive; esta revisión no ejecuta los binarios de iOS o Android.

## Resultado

Las tarjetas ya mostraban el producto completo con `BoxFit.contain`, fondo blanco y espacio reservado para evitar saltos al cargar. Ese comportamiento se conserva. Las mejoras necesarias estaban en la inspección de las fotos de la ficha y en la comunicación de errores.

| Before | After | Why |
|---|---|---|
| Foto estática en la ficha, sin ampliación. | Foto pulsable y botón «Ampliar foto»; visor con zoom de 1× a 4×, doble toque y desplazamiento. | Permite revisar detalles de la pieza sin ampliar toda la interfaz. |
| Varias fotos con puntos decorativos; sin controles directos. | Deslizamiento, miniaturas seleccionables, flechas y contador. | La navegación resulta visible y funciona con ratón, tacto y teclado. |
| Imágenes sin un nombre accesible en la ficha. | Nombre del producto, posición de la foto y controles etiquetados. | Identifica qué foto se está viendo y qué hace cada control. |
| Sin una indicación de carga en la ficha; ausencia y error con un icono genérico. | Estados «Cargando foto…», «Foto no disponible» y «No se pudo cargar la foto»; reintento en la ficha. | Diferencia contenido ausente de una carga fallida. |
| Las tarjetas usan el mismo mensaje para una URL fallida y un producto sin foto. | Mensaje específico de fallo, manteniendo el estado de ausencia. | Un fallo de carga no se presenta como falta de contenido. |
| Fondo y encuadre correctos en el catálogo. | Se conservan; se aplica el mismo fondo blanco en la galería y el visor. | Evita recortes y marcos grises alrededor de fotos con fondo blanco. |

## Evaluación del componente

Puntuación orientativa de este alcance, basada en el código y la interacción web, no de toda la app.

| Dimensión | Inicial / 4 | Final / 4 | Evidencia o límite |
|---|---:|---:|---|
| Accesibilidad | 1 | 3 | Fotos identificadas, controles etiquetados, Escape y flechas probados; falta una sesión real con VoiceOver/TalkBack. |
| Rendimiento | 2 | 2 | Área de imagen estable, páginas bajo demanda y caché de imágenes de Flutter. Las rutas web/archivo pueden subir originales grandes. |
| Tema y superficies | 3 | 4 | Estados con tokens del tema; blanco intencional para respetar el color original de las fotos. |
| Adaptación | 3 | 3 | Pruebas de widgets a 320, 390, 568 y 1440 px; texto ampliado y tema oscuro. |
| Consistencia y estados | 2 | 3 | Mismo vocabulario de fotos, controles Material y recuperación de errores. |
| **Total** | **11 / 20** | **15 / 20** | El principal pendiente técnico son las variantes de imagen para cada tamaño. |

## Hallazgos y alcance

- **P2 resuelto — Inspección y navegación incompletas.** `product_detail_screen.dart` integra ahora `ProductPhotoGallery`. El visor conserva la foto seleccionada al cerrarse mediante su control; Escape cierra el visor y las flechas cambian la foto. El cambio de foto restablece el zoom para no heredar un encuadre ampliado.
- **P2 resuelto — Estados poco claros.** La ficha permite reintentar una foto fallida y no ofrece ampliar una foto vacía o que no ha cargado. El catálogo diferencia los mensajes de ausencia y error.
- **P2 pendiente — Originales grandes en web y archivos.** `UploadFileGuard.maxBytes` permite 8 MiB por archivo. Las rutas web y archivo validan firma/tamaño, pero no redimensionan antes de `InventoryService.uploadProductImage`. La cámara y galería nativas sí solicitan ancho máximo de 2400 px y calidad 85/90. Antes de cambiar el proceso conviene medir los archivos reales y definir variantes para tarjeta, ficha y ampliación. Esta revisión no vuelve a comprimir ni sobrescribe archivos existentes.
- **Contenido pendiente.** Hay productos del catálogo de prueba sin foto visible. El diseño puede informar esa ausencia; se necesitan fotos reales del proveedor para completarlos. No se añadieron imágenes ficticias.

## Implementación

- `lib/features/catalog/product_photo_gallery.dart`: galería, visor, navegación, zoom, estados y reintento; utiliza componentes incluidos en Flutter, sin dependencias nuevas.
- `lib/features/catalog/product_detail_screen.dart`: integración y recuperación de portada legada; desaparece la galería anterior duplicada.
- `lib/features/catalog/aliado_product_card.dart`: mensaje específico para fallos de carga.
- `test/product_photo_gallery_test.dart`: proveedor de imágenes en memoria; no descarga fotos de proveedores durante las pruebas.

## Validación

Las 36 pruebas específicas de galería, utilidades de fotos y tarjetas aprobaron. Incluyen apertura/cierre, zoom con botones y doble toque, desplazamiento ampliado, límite de 4×, navegación con flechas/miniaturas/deslizamiento, posición seleccionada al cerrar, reintento después de un error, fotos ausentes, texto ampliado, modo oscuro y tamaños móvil/escritorio.

La suite completa aprobó **316 pruebas**. La revisión final de los diez casos del nuevo componente también aprobó; el análisis de los cuatro archivos afectados terminó sin problemas, y el detector estático de Impeccable no informó hallazgos. La compilación web release terminó correctamente con destino sandbox. El servidor se reactivó en el puerto 3001 y respondió HTTP 200.

Evidencia inicial: `build/local-audit/fotos-ficha-antes-movil.png` y `fotos-ficha-antes-escritorio.png`. Los registros de esta revisión se guardan como `build/local-audit/product-photos-*`.

En el navegador se verificó el casco real a 1440 × 900: apertura del visor, zoom a 150% y cierre con Escape. A 390 × 844 se comprobó apertura, zoom a 150% y desplazamiento horizontal de la foto ampliada. La etiqueta del título del visor se verificó sin repetición. El producto utilizado tenía una foto; la navegación de tres fotos se validó con imágenes en memoria en las pruebas, sin modificar el sandbox. Capturas: `fotos-ficha-despues-movil.png`, `fotos-ficha-despues-escritorio.png`, `fotos-zoom-escritorio.png` y `fotos-visor-final-movil.png`.

La siguiente optimización de archivos corresponde a `$impeccable optimize`, una vez medidos los originales. Tras cualquier cambio de variantes, repetir `$impeccable audit` y terminar con `$impeccable polish`.
