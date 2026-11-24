# Presentación móvil de chats

Los cambios visuales se activan por debajo de `AppBreakpoints.mobileMenu` (768 px), usando el ancho de la ventana completa. Un panel estrecho dentro de la vista de escritorio mantiene su presentación anterior.

- Bandeja móvil en pantalla completa, encabezado azul con buscador, pestañas Pedidos/Consultas, filtros y número de conversaciones.
- Logo real del interlocutor cuando está disponible, con inicial como alternativa. Se reutilizan las fotos de perfil y sus permisos existentes.
- Conversaciones sin leer resaltadas con su contador. Los pedidos que no admiten respuesta conservan la indicación «Solo lectura» y las reglas actuales de permisos.
- Conversación de pedido con identidad del negocio, opciones en el encabezado y resumen del pedido a todo el ancho: foto, referencia, productos, estado y acceso al pedido. Los grupos con distintos estados conservan la etiqueta agregada.
- Mensajes propios azules y recibidos neutros; fecha agrupada y barra de escritura redondeada. Se mantienen fotos, videos, ayuda, actualización y funciones de posventa.
- Los componentes compartidos reciben una opción explícita de estilo móvil. Los chats de soporte no cambian por este trabajo.

No se añadieron confirmaciones de lectura por mensaje ni se modificó la base de datos. Los contadores siguen utilizando las notificaciones existentes.

Verificación: pruebas de bandeja, filtros, permisos, mensajes sin leer y consultas; tamaños 320/390/1280 px, texto ampliado y teclado. Revisión en Chrome con mensajes simulados interceptados, sin enviarlos a proveedores.
