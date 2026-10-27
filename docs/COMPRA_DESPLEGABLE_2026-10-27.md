# Compra móvil en una fila

Propuesta local solicitada por el usuario: reducir el pie de compra y revelar la cantidad con movimiento lateral al agregar el repuesto.

| Before | After | Why |
|---|---|---|
| Estado y cantidad en una fila superior; consulta y compra debajo. | Una fila: consulta a la izquierda y acción de compra a su lado. | Reduce el espacio ocupado en reposo. |
| Selector visible antes y después de agregar. | Al agregar el mínimo indicado, el área del botón revela el selector y un botón compacto para ver el carrito. | El control de cantidad aparece cuando se necesita y confirma la adición. |
| Altura distinta entre estados o mensajes temporales superpuestos. | El espacio de compra conserva altura y posición durante el cambio; el estado del carrito tiene una región accesible de aviso. | Mantiene estables los objetivos táctiles y evita cubrir la nueva acción con una confirmación duplicada. |
| Cambio brusco entre las dos composiciones. | Desplazamiento lateral de derecha a izquierda y fundido breve de 220 ms, salida de 160 ms. | Relaciona la adición con sus controles sin rebotes ni giro del texto. |

La transición usa Flutter `AnimatedSwitcher`, `SlideTransition` y `FadeTransition`, sin dependencias nuevas. No se anima cada incremento: solo el cambio entre sin añadir y en carrito. La reducción de movimiento y la navegación accesible eliminan el desplazamiento; la activación por teclado es inmediata. La altura reservada tiene en cuenta el texto ampliado. Se mantiene el mínimo de 48 px para consulta y acceso al carrito.

La primera pulsación móvil añade el mínimo efectivo mostrado en la ficha. Después se puede aumentar, reducir o escribir directamente otra cantidad, respetando las restricciones existentes. La vista de escritorio conserva la selección previa. El botón del catálogo sigue en una sola línea.

Las transiciones salientes excluyen los eventos de puntero y la semántica. La clave del campo se renueva al cambiar entre estados para admitir una reversión rápida sin duplicar claves globales. No se duplican líneas al activar repetidamente la compra.

Pruebas específicas: revelado con altura y posición estables a 390 × 844, 320 × 640 con texto 1,6× y 568 × 320; entrada numérica y apertura de carrito; movimiento reducido; teclado; reversión rápida y ausencia de duplicación. Se conservan las pruebas de mínimo, máximo, stock reservado, cuenta suspendida y selección de escritorio.

Registros: `build/local-audit/purchase-reveal-*`.

## Validación de código

- Análisis estático: sin incidencias.
- 19 pruebas específicas aprobadas.
- Suite completa de Flutter: 351 pruebas aprobadas.
- Detector Impeccable: sin hallazgos.

## Comprobación visual y funcional

Compilación web completada con sandbox confirmado. En navegador a 390 × 844 se comprobó el estado inicial en una fila, el revelado al añadir 5 unidades y el incremento inmediato a 6. Escribir 8 y pulsar directamente el icono del carrito abrió una línea de 8 unidades y subtotal 96.00 REF. El producto de prueba se retiró y se confirmó el carrito vacío, sin confirmar pedidos ni abrir consultas de chat.

Evidencias completas: `build/local-audit/compra-desplegable-inicial.png` y `compra-desplegable-agregado.png`. Recortes de la zona solicitada: `compra-desplegable-inicial-pie.png` y `compra-desplegable-agregado-pie.png`. La revisión corresponde a la web móvil adaptable; no se ejecutó un emulador.
