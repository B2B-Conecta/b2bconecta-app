# Corrección de precios por forma de pago

## Regla comercial confirmada

| Publicación del proveedor | Pago en divisas | Pago en bolívares |
|---|---:|---:|
| Solo 52 REF | 52 USD | 52 × tasa oficial BCV |
| 52 REF y oferta de 48 USD | 48 USD | 52 × tasa oficial BCV |

La oferta USD es un incentivo por pagar en divisas: no sustituye el REF ni la base para calcular Bs. Los descuentos generales por volumen y campaña siguen siendo caminos excluyentes; el descuento de divisas no se aplica al REF. Cuando existen varios incentivos de pago USD se utiliza el mejor importe válido, sin sumar dos veces descuentos sobre una oferta USD ya publicada. Los precios unitarios se redondean a cuatro decimales tanto en Dart como en Postgres.

## Aplicación local

- `ProductCatalogPricing.aliadoUnitRef` calcula el REF sin `salePriceUsd`. La función anterior de comparación USD se conserva para compatibilidad.
- `PartModel.precioUnitarioParaAliado` y el carrito usan esa base REF para agregar, editar cantidades y restaurar borradores.
- La línea de pago USD compara la oferta directa y el incentivo porcentual contra el REF, sin alterar su base.
- El catálogo conserva los precios publicados; muestra el incentivo USD también cuando procede de una regla porcentual. Sin incentivo no duplica innecesariamente la línea USD.
- REF y Bolívares representan el pago en Bs al BCV; USD representa divisas. El resumen y la selección de dirección lo explican. Si falta tasa para Bs, o un proveedor exige divisas, se impide confirmar esa modalidad.
- El crédito se limita al subtotal de la modalidad elegida, preservando la aplicación por proveedor.

## Confirmación en servidor

El nuevo RPC `aliado_checkout_multi_importador_moneda` recibe la moneda y los identificadores/cantidades, sin confiar en importes del cliente. Reutiliza las validaciones de usuario, stock, promociones y logística del checkout existente, calcula REF y USD por separado y crea el pedido con moneda y tasa en la misma transacción. Los mínimos por proveedor se verifican sobre REF.

Para pedidos nuevos:

- `precio_total_usd` y `precio_base_aliado_total` contienen el importe a pagar en la modalidad elegida, después del crédito, manteniendo su uso operativo en pagos y comisiones.
- `total_ref` conserva la referencia BCV, independiente de la oferta USD; `total_bs` se calcula desde esa referencia y la tasa congelada.
- El snapshot `discount_rules` incluye `checkout_pricing_version=1`, moneda y precios unitarios REF/USD. No conserva una regla que vuelva a descontar el mismo incentivo al pagar.
- Las fichas y resúmenes del pedido etiquetan los importes nuevos en USD cuando corresponde. Los pedidos anteriores conservan su presentación y cálculo anteriores.
- Los métodos de pago nuevos se limitan a la moneda fijada. Registrar un pago no aplica el descuento dos veces; el helper SQL valida también la correspondencia del método. La operación antigua de congelar moneda no puede cambiar la modalidad de un pedido nuevo.

No se recalcularon pedidos históricos ni se ejecutaron actualizaciones masivas de productos. La idempotencia frente a respuestas de red perdidas sigue siendo una mejora separada de esta corrección.

## Migración y alcance

Archivo: `supabase/migrations/20261207120001_checkout_ref_usd_payment_prices.sql`.

El archivo se creó con `supabase migration new checkout_ref_usd_payment_prices` (CLI oficial 2.81.3). Como el repositorio ya tenía migraciones con fechas posteriores al reloj actual, su prefijo se ordenó inmediatamente después de la última existente para evitar que una migración antigua sobrescriba después la compatibilidad de congelamiento.

Se aplicó mediante el complemento de Supabase al proyecto **sandbox `czswojzpekcsisudgfsg`**. No se aplicó a DEV ni producción. El cliente nuevo requiere este RPC: no se introduce una vuelta silenciosa al checkout antiguo, que volvería a producir la inconsistencia.

El RPC nuevo solo concede ejecución a `authenticated`, exige identidad y rol de aliado y no permite ejecución a `anon`. Los avisos de ejecución autenticada de funciones `SECURITY DEFINER` incluyen por ello esta nueva entrada intencional; no aumenta el número de funciones ejecutables por anónimos. Ver [privilegios de funciones de Supabase](https://supabase.com/docs/guides/database/functions).

## Validación

- Suite completa: **377 pruebas aprobadas**.
- Verificación focalizada posterior al ajuste de precisión y rótulos: **35 pruebas aprobadas**, incluidos los nueve casos nuevos de precios y compatibilidad de pedidos.
- Análisis estático final de 17 archivos: sin incidencias.
- En el sandbox se ejecutaron pedidos de dos proveedores dentro de `BEGIN`/`ROLLBACK`: cinco unidades de un producto de 52 REF/48 USD y cinco de otro de 12 REF sin oferta. Resultado verificado: **320 REF** de referencia; **300 USD** al elegir divisas o **320 REF × BCV** al elegir bolívares.
- Se comprobó que el stock disminuye exactamente una vez durante la transacción, que la moneda queda guardada, que no puede cambiarse con el RPC anterior, que no se aplica de nuevo el descuento al pagar y que la falta de tasa rechaza el checkout sin crear pedidos parciales.
- Tras el rollback se verificaron los stocks originales (90 y 150 unidades) y la tasa restaurada. Los pedidos de prueba no quedaron persistidos.
- Los helpers SQL devuelven 52 REF, 48 USD con oferta y 52 USD sin oferta, como el cliente. Se verificaron los permisos de ejecución del RPC.

Registros y pruebas SQL locales en `build/local-audit/pricing-*`; esos archivos están excluidos de Git.

## Verificación visual de la compilación

Compilación web release completada con sandbox confirmado. Se recargó el navegador tras actualizar su service worker, que en la primera recarga todavía servía la versión anterior.

En el carrito real de la web, cinco unidades del Disco EBC quedaron en **52 REF por unidad / 260 REF**. Al elegir USD se mostraron **48 USD por unidad / 240 USD**. En bolívares se conservó la base de **52 REF**, con el equivalente BCV de esa referencia. El producto añadido para verificar se retiró al finalizar; el carrito original estaba vacío.

Capturas: `build/local-audit/precios-ref-corregido.png`, `precios-usd-corregido.png` y `precios-bs-corregido.png`. El servidor local quedó activo en el puerto 3001. La verificación de navegador se realizó en la web adaptable; no se ejecutaron emuladores nativos.

## Ajuste de distribución de importes

El subtotal ya no reserva la mitad del ancho para su etiqueta y el importe de cada producto deja de usar una columna fija de 104 px. El ancho se adapta al monto completo, incluida la moneda. Cuando falta espacio, la etiqueta pasa arriba; los importes permanecen en una sola línea, sin puntos suspensivos. Los valores excepcionalmente largos se ajustan al ancho disponible.

Se añadieron tres regresiones de `Bs 229.287,99` (1440 px, 320 px y 390 px con texto al 160 %). Las 12 pruebas del carrito y el análisis de los dos archivos pasaron. La compilación web release se generó correctamente. Registros: `build/local-audit/cart-money-*`.

## Dos formas de pago en el carrito

Se sustituyeron las tres pestañas por **Bolívares (REF)** y **Divisas (USD)**. REF y Bs se presentan dentro de la misma opción: cada producto conserva su referencia y muestra la conversión; el resumen destaca el subtotal en Bs y deja la referencia en REF encima. La tasa usada se muestra debajo del subtotal, junto con su fecha de vigencia cuando existe un `effectiveDate` válido en la configuración. No se inventa una fecha a partir del reloj del dispositivo ni de una fecha de actualización sin vigencia.

El registro de tasa ya disponible (`fetchGlobalTasaBcvRecord`) aporta conjuntamente el valor y su vigencia. No se alteran precios, descuentos, RPC ni datos de Supabase. El checkout sigue enviando `BOLIVARES` o `DIVISAS`; el servidor conserva el congelamiento atómico de moneda y tasa.

Las 23 pruebas focalizadas de precios y carrito pasaron: REF y Bs simultáneos, oferta USD opcional, cantidades, múltiples proveedores, anchos de 320 a 1440 px, texto ampliado, ausencia de tasa y proveedor que solo acepta divisas. Registros: `build/local-audit/cart-ref-bs-*`.

El análisis de los tres archivos terminó sin incidencias y la compilación web release terminó correctamente. El servidor de localhost:3001 sirve el bundle nuevo con las dos opciones y el rótulo de tasa BCV.

Verificación visual completada en escritorio y móvil: cinco discos de 52 REF/48 USD y cinco cascos de 80 REF sumaron **660 REF / Bs 582.038,75** a la tasa configurada de **881,8769**, con vigencia **20/10/2026**. Al seleccionar divisas se mostraron **640 USD**. Las capturas están en `build/local-audit/cart-ref-bs-desktop.png`, `cart-ref-bs-mobile.png` y `cart-ref-bs-usd-mobile.png`. Se retiraron únicamente los dos productos añadidos para comprobar la interfaz; no se confirmaron pedidos.
