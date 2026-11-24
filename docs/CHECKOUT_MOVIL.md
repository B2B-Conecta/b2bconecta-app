# Entrega y confirmación en móvil

El carrito abre `MobileCheckoutScreen` cuando el ancho de la ventana es menor de 768 px. La presentación de escritorio conserva su diálogo de destino y su recorrido anterior.

En el carrito móvil, cada proveedor tiene su selector **Bolívares / USD**, un subtotal y el ahorro disponible al pagar en USD. La decisión se guarda con la bolsa, aislada por usuario y entorno, y se hereda al continuar con la entrega. La revisión presenta las monedas elegidas y permite **Cambiar** sin repetir la elección obligatoriamente. Cambiar una moneda en la revisión también actualiza la preferencia de la bolsa si el cliente vuelve atrás.

## Recorrido

1. **Dirección:** elegir la dirección del perfil, una dirección guardada o una alternativa para este pedido. La alternativa conserva estado, ciudad, domicilio y enlace de mapas al volver entre los pasos. Se puede guardar con un nombre, editarla, eliminarla y marcar una como predeterminada. Editar la dirección del perfil en este recorrido crea una alternativa; no modifica el perfil. Una carga tardía de direcciones no reemplaza una elección manual.
2. **Entrega por proveedor:** dirección compacta y total estimado de envíos junto a **Revisar pedido**. Consultar los transportistas mediante `list_importer_carriers_for_checkout`, con el estado y ciudad del destino y coordenadas cuando provienen del perfil. Solo se ofrecen transportistas activos, del proveedor correcto y con cobertura. Además se puede elegir **Retiro en tienda** cuando el proveedor lo habilitó expresamente. Puede combinarse retiro en un proveedor y envío en otro. Cambiar el destino invalida las opciones anteriores. Una carga fallida requiere reintentar antes de avanzar; una lista vacía permite continuar como entrega a coordinar y costo por confirmar.
3. **Revisión:** productos, cantidades, precios efectivos, dirección, transportistas, moneda y saldo a favor por proveedor. Cada proveedor tiene un resumen de moneda con **Cambiar**, subtotal y ahorro real al pagar en USD cuando existe. Las opciones se abren solo al pulsarlo y conservan las restricciones de divisas y disponibilidad de tasa BCV. Se puede volver a editar. El transporte se envía al checkout únicamente al pulsar **Confirmar pedido**.
4. **Pedido creado:** referencia devuelta por el servidor, resumen, proveedores pendientes de confirmación y accesos a **Ver pedido** o **Seguir comprando**. Si la respuesta anterior se perdió, se recupera el pedido existente sin volver a crearlo.

## Precios y transporte

- En móvil, la moneda se elige por proveedor desde el carrito y se conserva en entrega y revisión. Puede elegirse USD para un proveedor y bolívares para otro. Los proveedores que solo aceptan divisas usan USD; la opción de bolívares queda deshabilitada si falta la tasa BCV. Se reutiliza el cálculo de precios de checkout, incluidos descuentos al pagar en USD. El saldo a favor se limita al subtotal de cada proveedor después de elegir la moneda. Escritorio conserva su selector general anterior.
- Los pedidos mixtos separan productos en USD y productos en Bs, sin sumar distintas monedas bajo una etiqueta única. Los resúmenes posteriores de Pedidos también conservan ambos importes. El transporte sigue mostrándose como estimación USD aparte.
- El resumen del carrito también separa USD y bolívares cuando las elecciones difieren; muestra el ahorro aplicado únicamente a los proveedores elegidos en USD. Los mínimos de compra siguen calculándose sobre REF y no cambian al alternar la moneda. Cambiar cantidades recalcula los precios y descuentos del proveedor correspondiente.
- Las tarifas de transportistas son USD y se muestran como estimaciones, con el modo de facturación de cada transportista. No se interpretan como REF del producto.
- Cuando todos los envíos tienen cotización, se muestra el total estimado. Si falta algún costo, se muestra el subtotal de productos y se advierte que falta confirmar envíos. Una tarifa vacía se distingue de una tarifa explícita de cero.
- La equivalencia estimada en Bs usa la tasa que se presenta en la revisión. El servidor conserva la autoridad sobre precios, stock, créditos, moneda, factura y sus snapshots.
- El retiro requiere un punto activo del proveedor, habilitado para clientes, con estado, ciudad, dirección y enlace de mapas. El proveedor lo configura desde **Transporte → Ubicaciones → Ofrecer retiro a clientes**, con horario y condiciones. Las ubicaciones internas existentes están deshabilitadas para clientes por defecto. El retiro no suma transporte y conserva dirección y condiciones en el pedido.
- La dirección seleccionada queda copiada en el pedido: editar o eliminar una dirección guardada después no cambia un pedido creado. Las direcciones son privadas por cuenta. Los detalles muestran esa copia y permiten abrir su ubicación.
- Un pedido para retiro pasa de preparación a **Listo para retirar**. El cliente confirma la recepción desde ese estado; no se le exige un tránsito ficticio. Se impiden transportistas y cargos de envío en los pedidos de retiro.

## Integración y validación

La versión móvil utiliza `aliado_checkout_confirmar_v2` para todas sus confirmaciones, con una referencia persistente de intento, monedas por proveedor, modalidad de entrega y dirección guardada opcional. Esta función conserva el cálculo de `aliado_checkout_proveedores_v1`: una referencia de pedido única, una transacción atómica, precios recalculados por el servidor, atribución de promociones y saldo por proveedor. Escritorio conserva su recorrido anterior con `aliado_checkout_multi_importador_moneda`.

La nueva migración requiere las migraciones previas de precios REF/USD y del ciclo de stock. Se aplicó en sandbox (`czswojzpekcsisudgfsg`) y la prueba SQL de persistencia y atomicidad pasó con reversión de los datos de ensayo. No se aplicó en DEV ni producción. Si falta la función en otro entorno, la app conserva la selección y explica que el pedido mixto no se creó. No se divide la compra en solicitudes independientes.

La bolsa se conserva al cancelar o fallar la confirmación y se limpia después de una respuesta válida. Se bloquean envíos simultáneos y la salida mientras se confirma. Antes de enviar se verifica que la cuenta, los productos, cantidades, mínimos y moneda sigan siendo válidos. Una falla de medición publicitaria no convierte un pedido creado en un checkout fallido.

La referencia de confirmación se guarda antes de enviar, dentro del borrador de bolsa aislado por entorno y usuario. Solo se guardan referencias y huellas de datos, sin direcciones ni datos personales en el borrador. El servidor serializa las solicitudes con la misma referencia y devuelve el pedido ya creado. El botón **Verificar confirmación anterior** permite recuperarlo incluso si al restaurar la bolsa ya no quedan productos disponibles.

Si el intento anterior aún no creó un pedido, `resolve_checkout_attempt` lo cancela de forma atómica antes de permitir un nuevo intento: una solicitud antigua que llegue después no podrá crearlo. Si ya lo creó, se muestra **Pedido recuperado**. Una bolsa modificada se conserva; cuando coincide con la compra confirmada se limpia. Una falla al verificar mantiene la referencia y bloquea un envío nuevo. No se añaden reintentos automáticos de compra.

Pruebas: `test/features/cart/mobile_checkout_test.dart`, `delivery_destination_dialog_test.dart`, `cart_journey_test.dart` y `test/supplier_currency_checkout_service_test.dart`. Cubren etapas, costos desconocidos y cero, monedas por proveedor, descuentos y créditos independientes, validación, cambio de destino, fallas de transporte, permisos de cobertura, confirmación única, regreso al carrito y preservación del recorrido de escritorio. `supabase/tests/checkout_supplier_currencies.sql` prepara verificaciones de persistencia y atomicidad dentro de una transacción que se revierte. Las capturas locales utilizan datos de ejemplo; no se crearon pedidos reales durante esta validación.

### Resultado de la verificación local (20 de noviembre de 2026)

- La validación conjunta de carrito, checkout, servicio, pagos y Pedidos pasó con 91 comprobaciones: 87 pruebas funcionales y cuatro capturas locales del carrito móvil/escritorio y las tarjetas de estado en claro/oscuro. Registro: `build/local-audit/checkout-order-fixes-all-tests.log`.
- La prueba SQL en sandbox confirmó monedas independientes, descuento USD, un único descuento de stock, rechazo de un mapa incompleto y reversión completa cuando un proveedor exige divisas. Todos los datos de ensayo se revirtieron. La función está habilitada para usuarios autenticados, sin permiso de ejecución anónimo.
- La compilación web de producción terminó correctamente. El archivo servido por el servidor local coincide con el compilado y su configuración apunta a sandbox.
- El análisis estático de los archivos revisados no produjo errores ni advertencias; conserva cinco avisos informativos de declaraciones privadas sin uso en `aliado_expandable_order_card.dart`.
- Los cinco fallos detectados en la revisión ampliada quedaron resueltos: se ajusta el tono del texto de estado hasta asegurar contraste 4,5:1 sobre las superficies claras y oscuras, tanto con el fondo de etiqueta al 10% como al 14%; se actualizan las pruebas del botón `Chat`; y se comprueba el paginador estándar y compacto con su texto real. Al volver del detalle se conservan la segunda página, sus productos y la posición del scroll. No fue necesario modificar el funcionamiento de la paginación ni del chat.

## Ampliación del 21 de noviembre de 2026

Se implementaron las tres ampliaciones pendientes: retiro configurable para clientes, direcciones guardadas y recuperación de confirmaciones inciertas. Las migraciones `20261120202927_checkout_completion_v2.sql` y `20261120205359_checkout_completion_guards.sql` están aplicadas solo en sandbox. Hay que instalar la cadena completa, incluida `20261210120000_checkout_supplier_currencies.sql`, antes de utilizar la función móvil v2: su llamada a la función de precios se resuelve en tiempo de ejecución.

`supabase/tests/checkout_completion_v2.sql` verificó con reversión de todos los datos de ensayo: referencia única y stock una sola vez; reintentos idénticos y con datos distintos; cancelación de solicitudes antiguas; retiro habilitado/deshabilitado; monedas y descuentos por proveedor; dirección inmutable en el pedido; bloqueo de cargos de envío para retiro; confirmación de retiro sin tránsito; y aislamiento de lectura y eliminación de direcciones mediante RLS con el rol autenticado.

El registro de intentos está en el esquema no expuesto `b2b_private`, sin permisos de lectura de cliente y con RLS de denegación por defecto. Los RPC públicos de confirmación/configuración necesitan privilegios de servidor para la operación atómica; exigen identidad y verifican propietario/rol según su función, con ejecución anónima revocada y `search_path` vacío. Los avisos informativos del asesor sobre esos RPC y la tabla privada son exposición deliberada y denegación deliberada, respectivamente; no se concedió acceso de cliente al registro.

Pruebas específicas nuevas: `checkout_attempt_test.dart`, `checkout_delivery_flow_test.dart` y `customer_pickup_settings_test.dart`. Cubren persistencia y cambio de cuenta, almacenamiento local fallido, recuperación sin conexión, dirección predeterminada y respuesta tardía, edición/eliminación, guardado fallido, retiro combinado con envío a 320 px y texto ampliado, costo de retiro cero y recepción desde Pedido listo.

Validación final: 114 comprobaciones aprobadas (112 pruebas funcionales y dos recorridos visuales que generan seis capturas a 320/390 px), sin fallos. Registro: `build/local-audit/checkout-completion-final-tests.log`. El análisis de los archivos afectados terminó sin observaciones. Se corrigió también el cierre del formulario del mayorista para no liberar el campo de condiciones mientras su diálogo todavía termina la animación.

La elección de moneda, descuentos y crédito por proveedor está implementada en la versión local y sandbox. El despliegue de la nueva función a DEV/producción no se realizó, respetando la instrucción de trabajar solo en la base de pruebas.

### Moneda por proveedor desde el carrito

La elección inicial se adelantó al carrito móvil. Cada proveedor muestra su selector USD/bolívares, el ahorro disponible o aplicado y su subtotal. La revisión hereda estas elecciones y permite corregirlas; al volver a la bolsa también se conserva el cambio. Las preferencias se guardan con el borrador privado de la cuenta y se eliminan al vaciar la bolsa. El recorrido de escritorio conserva su diseño y selector general.

Validación: 68 comprobaciones aprobadas, incluido el recorrido a 320 px con texto ampliado, restauración por cuenta, cambios de cantidades, restricciones de divisas/tasa BCV, regreso desde revisión y capturas móviles en claro/oscuro y escritorio. Registro: `build/local-audit/cart-supplier-currencies-final-tests.log`. El análisis de los archivos afectados terminó sin observaciones. Esta ampliación no requiere cambios en la base de datos.

### Corrección de las selecciones de Inicio

La migración de checkout había revocado `USAGE` del esquema `b2b_private` a `authenticated`. Esto bloqueaba el RPC existente de Inicio, que es `SECURITY INVOKER` y llama a la selección privada de productos. El síntoma era «No pudimos cargar tus compras y los más vendidos» y ambas secciones ocultas.

`20261121132517_restore_home_private_schema_usage.sql` restaura únicamente ese permiso de esquema. No concede acceso a tablas ni cambia la autorización del ranking. Se aplicó solo en sandbox. `supabase/tests/home_checkout_schema_access.sql` pasó ejecutando el RPC con el rol real `authenticated`: verifica ambas selecciones, denegación a proveedores y anónimos, y bloqueo de lectura/escritura del registro de intentos. La tabla conserva RLS sin políticas de cliente.

La consulta para la tienda de prueba devolvió 12 productos para recompra. «Más vendidos» devolvió cero porque la última entrega del sandbox fue el 15 de octubre de 2026, fuera del intervalo de 30 días al verificar el 21 de noviembre. No se alteraron fechas ni se inventaron ventas para poblar el ranking. Novedades, promociones y categorías cargaban correctamente. No se necesita recompilar el frontend para esta corrección; se debe reintentar o recargar Inicio.

Comprobación visual completada el 21 de noviembre en Chrome, `http://localhost:3001/`, con la vista móvil de la tienda ya iniciada: tras recargar desapareció el aviso de error y se mostraron «Compra de nuevo», promociones, categorías, seguimiento, novedades, proveedores y consulta. Al desplazarse, el buscador se ocultó y el encabezado quedó compacto. «Más vendidos» sigue oculto por el intervalo sin entregas descrito arriba. Captura: `build/local-audit/home-browser-verified-20261121.jpg`.
