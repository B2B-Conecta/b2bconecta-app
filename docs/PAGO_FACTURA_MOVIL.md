# Pago y factura en móvil

Desde el detalle del pedido, **Pago y factura** abre un recorrido propio a menos de 768 px. Escritorio conserva su formulario anterior.

1. **Factura:** proveedor, referencia de pedido, facturas adjuntas con vista/descarga, productos e importe del proveedor. No se inventa el número de factura: se muestra el nombre real del archivo. El flete separado se identifica y no se suma como REF al importe de productos.
2. **Método:** opciones visibles compatibles con la moneda confirmada para ese proveedor y sus métodos habilitados. Los datos de pago se pueden copiar por línea o completos. No se vuelve a elegir USD/bolívares. Los pedidos nuevos conservan los precios, créditos y descuentos fijados en checkout.
3. **Comprobante:** cámara, galería o archivo; vista previa de imagen/PDF y cambio de archivo; referencia, fecha de pago, monto declarado y nota opcional. Elegir el archivo no lo sube ni registra el pago. La acción final es explícita. En efectivo, referencia y foto son opcionales. Se informa si el monto declarado difiere del importe del pedido; no se modifica la factura ni se interpreta como un plan de cuotas.
4. **Estado:** comprobante registrado, pendiente de revisión, confirmado o rechazado con el motivo real. Se puede corregir mientras no esté aprobado, conservando el método durante la revisión. El estado se consulta al abrir, al volver a la app, manualmente y cada 30 segundos mientras esta pantalla está visible. El chat del proveedor continúa disponible.

El pulido visual móvil del 23 de noviembre añade el estado junto a cada factura y agrupa los productos y el resumen en una tarjeta compacta. Cada producto muestra cantidad × precio unitario y total, conservando los precios de la cotización existente. Los métodos incluyen una explicación breve y el seguimiento conecta sus etapas; muestra las fechas reales de registro y aprobación cuando existen, sin atribuir una fecha al inicio de revisión. Con texto ampliado o poco ancho, el total de cada producto pasa debajo para evitar recortes. Los avisos de flete y la separación entre proveedores se conservan.

## Persistencia y permisos

`transaction_requests.pago_declaracion` guarda referencia textual (con ceros iniciales), fecha sin cambio de zona horaria, monto, moneda, nota, importe esperado y referencias de envío/corrección. El proveedor ve estos datos en su revisión móvil del comprobante. El monto declarado es informativo: la aprobación sigue correspondiendo al proveedor.

`aliado_submit_supplier_payment_v1` registra todas las líneas activas de un proveedor y checkout en una transacción. Verifica identidad de minorista habilitado, propietario de cada línea, conjunto completo, factura, estado, métodos permitidos, moneda, fecha, monto positivo y archivo de ese pedido. No mezcla proveedores. El servidor valida el objeto de Storage y su tipo/tamaño. Los archivos admitidos son JPG, PNG, WEBP y PDF hasta 8 MiB.

La referencia de envío se conserva al reintentar una respuesta incierta. El RPC reconoce una repetición exacta incluso después de la aprobación; rechaza reutilizarla con datos diferentes y las correcciones basadas en una versión antigua del comprobante. Durante una respuesta incierta, la app bloquea la edición para repetir exactamente el envío preparado. No elimina adjuntos anteriores ni el archivo nuevo ante un error de red.

El RPC usa `SECURITY DEFINER` para validar y escribir el conjunto atómicamente, con `search_path` vacío, contexto de RLS acotado y ejecución anónima revocada. Comprueba explícitamente identidad/propiedad/rol; el aviso del asesor por ejecución autenticada de esta función es esperado y deliberado. Un trigger impide que el cliente falsifique la nueva declaración mediante una actualización directa de la tabla. El permiso de esquema que necesita Inicio se conserva.

Migraciones aplicadas **solo en sandbox**, sin cambios en DEV ni producción:

- `20261121140005_mobile_supplier_payment_review.sql`
- `20261121140447_mobile_payment_role_context_guard.sql`
- `20261121141751_mobile_payment_snapshot_guards.sql`

Requieren la cadena de checkout REF/USD y monedas por proveedor existente. La lectura de pedidos conserva compatibilidad con entornos sin la nueva columna; el envío móvil explica si falta su función, sin recurrir a escrituras parciales del flujo antiguo.

## Verificación

`supabase/tests/mobile_supplier_payment_review.sql` se ejecutó en sandbox con reversión de todos los datos de ensayo. Comprueba: registro completo/atómico, rechazo de grupos parciales o proveedores mezclados, pago USD y Bs independientes, ceros en referencia, precio sin doble descuento, reintento idéntico, nonce incompatible, corrección de rechazo, rechazo de fecha futura y archivo faltante, efectivo sin foto incluso con proveedor solo divisas, bloqueo tras aprobación, rechazo de correcciones antiguas y acceso denegado a otro cliente y a ejecución anónima. También verifica que una escritura directa no pueda falsificar los datos declarados.

Pruebas móviles: `test/mobile_supplier_payment_test.dart` y `test/mobile_supplier_payment_service_test.dart`. Cubren revisión antes de enviar, cancelación de selección, envío único, errores de red, bloqueo de edición durante incertidumbre, efectivo, factura ausente, rechazo/corrección, actualización automática/manual y compatibilidad de lectura. Se revisaron capturas a 390 px en claro y 320 px en oscuro con texto ampliado. Los ejemplos de capturas no representan pagos reales.

Comprobación interactiva en Chrome completada el 21 de noviembre: desde Pedidos se abrió un pedido de pruebas con factura, el nuevo resumen, los métodos y el formulario de comprobante, y se volvió entre pasos. Se comprobó que un pedido histórico sin tasa aplicada bloquea el pago en bolívares. No se envió un comprobante ni se cambió el estado del pedido. Captura del formulario real: `build/local-audit/mobile-payment-browser-form.jpg`. La nueva pestaña resolvió el fallo de conexión anterior; se restauró la escala temporal del navegador al terminar. El pequeño desplazamiento detectado al regresar entre pasos se corrigió liberando el foco y llevando el contenido al inicio después de construir el nuevo paso; tiene prueba específica.

Validación final: 85 comprobaciones aprobadas (83 pruebas funcionales y dos recorridos de capturas claro/oscuro), en `build/local-audit/mobile-payment-release-tests.log`. El análisis de los archivos afectados terminó sin observaciones, registrado en `build/local-audit/mobile-payment-release-analysis.log`.

La compilación web release terminó correctamente. El servidor local de puerto 3001 se actualizó; se verificó respuesta HTTP 200 y coincidencia SHA-256 entre el archivo compilado y el servido en la red local. La configuración compilada continúa apuntando a sandbox.

Para el pulido del 23 de noviembre se ejecutaron 20 comprobaciones del flujo y sus servicios, incluidas dos secuencias de capturas con tema claro/oscuro. Se añadieron verificaciones del estado junto a la factura, cantidad/precio/total, descripciones de métodos y fechas reales del seguimiento. Las capturas adicionales muestran la línea de seguimiento completa a 390 y 320 px. El análisis de los dos archivos afectados terminó sin observaciones (`build/local-audit/mobile-payment-polish-analysis.log`). Este pulido no modifica escritorio ni requiere cambios en la base de datos.
