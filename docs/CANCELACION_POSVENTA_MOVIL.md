# Cancelación y posventa en móvil

La vista móvil de Pedidos (menos de `AppBreakpoints.mobileMenu`) usa un recorrido propio para cancelar; escritorio conserva el diálogo y recibe la validación visible del motivo.

## Cancelación

- Muestra referencia, proveedor y productos que realmente se cancelarán, cantidades, importes y estado. No incluye líneas que ya no permiten cancelación.
- En una multicompra móvil, el menú de la cabecera se evalúa para el proveedor seleccionado y lo nombra al cancelar. Una factura o pago de otro proveedor no bloquea la opción. Solo se pasan al recorrido las líneas del proveedor elegido; la cabecera conserva el resumen total de la compra. La factura del propio proveedor sigue bloqueando su cancelación, aunque aún no esté pagada.
- Permite conservar el pedido sin escribir ni cancelar. Exige un motivo de 3 a 4000 caracteres antes de enviar.
- Relee los pedidos al confirmar y comprueba de nuevo si hay factura o cambió su estado. La autorización definitiva continúa correspondiendo a las operaciones existentes del servidor.
- Bloquea dobles pulsaciones. Si solo se completan algunas líneas, informa cuántas y permite reintentar las restantes con el mismo motivo. Ante respuesta incierta, consulta si la línea ya fue cancelada con ese motivo.
- Muestra la confirmación únicamente al terminar todas las líneas seleccionadas, el motivo y la fecha de cancelación devuelta por los datos, si está disponible. La valoración se ofrece como opción, separada por proveedor cuando corresponde; no se abre automáticamente.
- Permite volver a Pedidos o explorar el catálogo. Al salir se actualiza la lista, incluso si hubo una respuesta incierta.

## Reporte y seguimiento

- Conserva el plazo vigente de 7 días desde la entrega, selección de productos y unidades afectadas. Muestra la fecha de entrega disponible y el vencimiento más cercano de las líneas habilitadas.
- Usa encabezado azul, un formulario compacto, un único bloque de evidencia y acción de envío al pie. La vista previa duplicada se conserva solo en escritorio.
- Admite hasta 3 fotos o 1 video. Elegir evidencia no registra el reporte. Los avisos y errores se llevan a una posición visible.
- El envío es explícito. Durante la misma sesión conserva los productos registrados y las evidencias subidas para reintentar sin repetir los envíos completos. Después de una respuesta incierta comprueba motivo, cantidad y rutas de evidencia del caso existente. No elimina archivos que puedan estar asociados a un reporte ya guardado. El servidor continúa validando cada caso.
- Después del registro abre el chat del proveedor correspondiente con datos actualizados. Si falla la apertura del chat, informa que el reporte ya está registrado y ofrece reabrirlo sin volver a enviarlo.
- El chat móvil identifica la posventa y muestra el estado de los casos: pendiente de acuerdo, cambio aprobado, crédito aprobado, no aceptado o resultado agregado. No interpreta la recepción de un mensaje como aceptación del reclamo.
- Consulta el estado al abrir, volver a la app, recibir actividad y cada 30 segundos mientras la ruta está visible. Una consulta fallida muestra estado sin actualizar y permite reintentar.

La solución se acuerda con el proveedor. Se mantienen los mecanismos existentes de crédito y seguimiento del cambio. Este ajuste de interfaz no modifica plazos, permisos ni esquema de base de datos.

## Comprobación

Las pruebas de `test/features/orders/mobile_order_actions_test.dart` cubren motivo obligatorio, conservar pedido, llegada de factura durante el formulario, bloqueo de doble envío, cancelación parcial, valoración opcional, evidencia obligatoria/límites, envío explícito, apertura/reintento de chat, respuesta incierta de reporte, envío parcial y actualización del estado real. También verifican 320 y 390 px con texto ampliado y tema oscuro. Las capturas de ensayo se generan en `build/local-audit/postventa-*.png`; no son operaciones ni conversaciones reales.

El conjunto de cancelación, adjuntos, presentación de Pedidos y chats terminó con **68 comprobaciones aprobadas**, incluidas dos secuencias de capturas claro/oscuro (`build/local-audit/postventa-mobile-tests.log`). No se cancelaron pedidos ni se enviaron reportes reales durante estas pruebas.

El análisis de los archivos afectados terminó sin observaciones. La compilación web release se completó y se actualizó el servidor local del puerto 3001, verificando respuesta HTTP 200 y coincidencia SHA-256 entre el archivo compilado y el servido por la red local.

La corrección posterior de cancelación por proveedor se verificó con 56 pruebas de detalle, cancelación, reportes y presentación, más dos recorridos de capturas a 320 y 390 px. Incluye una multicompra con A pagado/facturado y B con dos productos cancelables, cambio de selección, llegada de factura tras actualizar, y confirmación que solo invoca la cancelación de B. El análisis no detectó errores; conserva cinco avisos informativos de declaraciones antiguas sin uso en `aliado_expandable_order_card.dart`.

## Pulido de presentación

La confirmación de cancelación reúne producto, etiqueta de estado, motivo y fecha en una misma tarjeta. La fecha usa «Hoy» o «Ayer» según el calendario local; para días anteriores mantiene la fecha completa y hora. Solo se presenta cuando existe la fecha guardada.

La evidencia del formulario móvil se organiza en miniaturas más grandes y un recuadro adyacente para agregar foto o video. Al alcanzar el máximo de tres fotos o un video se oculta ese recuadro; quitar un adjunto lo habilita otra vez. Los controles se bloquean durante la selección o el envío.

El reporte en el chat móvil muestra referencia del pedido, producto, unidades afectadas y motivo en una tarjeta interior legible, con evidencia al ancho disponible. El reporte saliente conserva fondo azul y título/hora claros. Las fotos se siguen abriendo en el visor ampliable y los videos conservan sus controles. Los estados de carga y error de la foto reservan el mismo espacio. Los controles de acuerdo del proveedor conservan la confirmación explícita antes de registrar una decisión. La presentación de escritorio se conserva.

Este pulido pasó 55 comprobaciones, incluidas las capturas claro/oscuro, fechas locales «Hoy/Ayer», texto ampliado, contraste del reporte saliente, confirmación de acuerdos y regresión de la cancelación por proveedor. El análisis terminó sin observaciones (`build/local-audit/postventa-polish-analysis.log`). Las pruebas no registraron cancelaciones, acuerdos ni reportes reales.
