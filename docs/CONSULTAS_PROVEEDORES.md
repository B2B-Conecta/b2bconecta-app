# Consultas a proveedores

Desde Inicio del minorista, **Consultar** abre un borrador antes de elegir al destinatario. La consulta requiere texto y admite un código o modelo opcional y una foto desde archivos o cámara. No crea un pedido.

El segundo paso permite buscar al proveedor por nombre o ubicación, elegir solo uno y revisar el destinatario antes de enviar. **Editar** y el botón de volver conservan el borrador. Salir del primer paso pide confirmación si hay contenido.

El envío reutiliza la conversación entre la tienda y el proveedor. Después abre ese chat, también disponible en **Chats → Consultas**. El código o modelo y la foto se guardan con el mensaje. El chat admite nuevas fotos y conserva los accesos directos desde productos y tiendas.

Los reintentos del formulario usan un identificador estable para evitar duplicados cuando se pierde una respuesta. Editar el contenido o cambiar de proveedor inicia un envío distinto. El borrador se conserva durante este recorrido; no se guarda entre reinicios de la app.

## Datos y despliegue

La migración `20261120153000_store_supplier_consultation_photos.sql` agrega `attachments` y `consultation_model` a `store_supplier_messages`, junto con el bucket privado `consultation-photos`. Solo los participantes del hilo pueden consultar sus fotos; cada autor administra sus propios archivos. Se aceptan JPG, PNG y WEBP de hasta 8 MB. El formulario y el chat adjuntan una foto por mensaje.

Antes de publicar este flujo en otro entorno, aplicar esa migración en el destino. Durante este trabajo se aplicó únicamente en sandbox (`czswojzpekcsisudgfsg`); no en DEV ni producción.

Las cargas con un envío fallido se conservan para reintentar. Si el usuario abandona ese borrador después de subir la foto, puede quedar un archivo privado sin mensaje asociado; este cambio no incorpora una tarea de limpieza periódica.

## Verificación

- `test/new_consultation_flow_test.dart`: borrador, foto, validación, selección, edición, salida, reintento, persistencia y tamaños 320/390/1280 px, incluido texto ampliado.
- `test/store_supplier_product_question_test.dart`: conservación del contexto de producto y acceso al chat existente.
- En sandbox se comprobó la carga privada, el acceso de ambos participantes y el bloqueo a terceros. Se eliminaron las fotos de prueba.
- En Chrome se recorrió el flujo a 320 y 390 px con envío interceptado, fallo inicial y reintento. No se enviaron mensajes ni notificaciones reales a proveedores.
