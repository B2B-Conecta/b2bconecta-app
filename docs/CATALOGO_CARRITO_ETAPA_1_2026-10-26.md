# Catálogo y carrito — primera etapa local

Fecha: 26 de octubre de 2026. Copia de trabajo en `E:\B2B-Conecta-App`.
Entorno de datos: sandbox `czswojzpekcsisudgfsg`. Servidor: http://localhost:3001/.

## Cambios

- Catálogo: acción explícita «Ver repuesto», títulos más legibles, indicación de fotos no disponibles, una columna en pantallas menores de 360 px y recuperación de búsquedas sin resultados.
- Acceso persistente al carrito desde el catálogo; el agregado desde el detalle ofrece «Ver carrito».
- Borrador local separado por proyecto y usuario. Solo guarda identificadores, cantidades y campañas; vuelve a consultar productos, precios, promociones y existencias al restaurar. No guarda contraseñas ni sesiones adicionales.
- Restauración con ajuste a mínimos y stock disponible. Los fallos de red conservan el borrador y permiten reintentar; un borrador ilegible requiere elegir explícitamente iniciar otro.
- Proveedores agrupados por identificador, incluyendo sus mínimos de compra y saldos, para evitar mezclar negocios con el mismo nombre.
- Cantidad editable con teclado y botones de 44 px; límites de compra y stock; eliminar con «Deshacer».
- Resumen junto a los productos en escritorio y debajo en móvil, con desplazamiento en pantallas bajas. Subtotal separado del paso de entrega y acción final «Confirmar pedido».
- Se evita abrir varias ventanas de entrega y continuar con un carrito de otra sesión tras cambiar de cuenta.

## Verificación

- Suite completa: 276 pruebas aprobadas.
- Verificación posterior del catálogo y carrito: 16 pruebas aprobadas; comprobación adicional de abrir/cancelar entrega: 4 aprobadas.
- Análisis general: sin errores ni advertencias; conserva observaciones informativas existentes. Análisis de los componentes de carrito, ficha y rejilla modificados: sin observaciones.
- Detector manual de Impeccable: sin hallazgos. Su detector estático no sustituye la revisión de widgets Flutter ni las pruebas visuales.
- Compilación web release local: correcta, sin publicación.
- Navegador local: catálogo y detalle en móvil, agregado de 5 unidades, edición a 8, recuperación de las 8 tras recargar y búsqueda sin resultados con retorno al catálogo.
- Pruebas de widgets del carrito en 390×844, 1440×900 y 568×320, incluyendo edición, eliminación y recuperación.

## Límites y siguiente etapa

No se enviaron pedidos ni mensajes durante esta revisión. No se publicaron cambios ni se modificaron DEV o producción. El emulador permanece cerrado; esta etapa comprueba la versión web adaptable, no acredita pruebas nativas de iOS/Android.

Se conserva el backend actual. La paginación de servidor, la confirmación atómica de pedido y moneda, y la idempotencia del checkout siguen pendientes según la auditoría inicial. El guardado local no sustituye la validación de permisos, precios y stock del servidor al confirmar. Las fotos ausentes en el catálogo necesitan datos o archivos de origen; se muestran como ausentes.

El borrador pertenece al dispositivo/navegador: no se sincroniza entre equipos y se pierde si se borran los datos locales del navegador. Las integraciones de correo, Google y notificaciones mantienen las limitaciones documentadas del sandbox.

## Refinamiento visual del carrito

Tras la revisión del usuario se compactó la composición, conservando las reglas de compra y el borrador:

- Ancho máximo de 1100 px en escritorio, encabezado común y resumen de 312 px alineado con la lista.
- Una superficie por proveedor; sus productos son filas con separadores, sin tarjetas anidadas.
- Imagen de 56 px, referencia y precio unitario juntos; cantidad en un control integrado y el importe alineado a la derecha.
- Resumen sin sombra, con selector de moneda accesible, subtotal destacado y botón de entrega de 48 px.
- En móvil y tablet la compra y el resumen usan un solo recorrido de desplazamiento, sin una zona vacía forzada entre ambos.
- Fondo suave de la paleta existente; botones de cantidad de 44 px y foco visible en la entrada numérica.

Validación posterior: 19 pruebas de carrito y mínimos aprobadas, incluyendo 320×640, 390×844, 568×320, 800×1000 y 1440×900; varios proveedores con nombres iguales, referencias largas, texto a 160 %, modo oscuro, monedas, cantidades, eliminar/deshacer y abrir/cancelar entrega. Análisis de carrito y pruebas sin observaciones. Detector de distribución de Impeccable sin hallazgos; revisión visual adicional en el navegador local. No se confirmaron pedidos.

La vista previa compilada se sirve con `node scripts/preview_web_local.cjs 3001`, después de compilar el entorno sandbox. Para desarrollo con recarga se conserva `scripts/local_qa.ps1 -Action serve -Environment sandbox -Port 3001` usando el SDK de E: según la guía local. No se deben ejecutar ambos servidores a la vez en el mismo puerto.

Compilación final release completada correctamente. Se cerró el servidor de depuración de Flutter y se dejó activa la vista previa Node en el puerto 3001; el entorno de datos compilado se verificó contra el identificador exacto del sandbox.
