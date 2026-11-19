# Una etiqueta para inventario y clientes

Las nuevas etiquetas imprimibles contienen el mismo enlace que «Compartir producto»:
`https://app.b2bconecta.com.ve/producto/{id}`. El identificador permanece estable aunque
cambie el SKU, el nombre o las fotos. El enlace no contiene credenciales ni permisos.

## Apertura

- Desde **Inventario → Herramientas → Etiquetas QR → Escanear etiqueta**, el mayorista
  conserva el flujo de gestión y captura de fotos. La consulta exige que el producto
  pertenezca a su cuenta.
- Desde la cámara del teléfono, el enlace abre B2B Conecta. Con sesión del propietario,
  abre la edición del producto, incluso si está pausado. Las otras cuentas acceden a la
  ficha según sus permisos de catálogo.
- Sin sesión, abre la ficha pública del producto publicado. Ofrece «Regístrate para
  comprar» e «Iniciar sesión». Al continuar, conserva el producto seleccionado,
  incluida la variante elegida, hasta completar el acceso y la habilitación de la cuenta.
- Un producto no disponible muestra un aviso; el QR nunca otorga acceso al editor.

## Compatibilidad

El lector de Inventario y la lectura de QR en fotos/ZIP aceptan tanto los nuevos enlaces
como las etiquetas anteriores `B2BINV1:{id}`. Las anteriores no pueden convertirse en
enlaces sin regenerar e imprimir el PDF. No requieren cambios en los productos.

Los enlaces impresos apuntan a la aplicación publicada, igual que los enlaces de
compartir. El servidor local sirve para verificar el nuevo comportamiento antes de
publicarlo; un QR escaneado con la cámara normal seguirá abriendo el dominio publicado.
La disponibilidad depende de que el producto exista y esté publicado en ese entorno.

## Validación

Pruebas: `inventory_qr_test.dart`, `inventory_qr_destination_test.dart` y
`product_share_link_test.dart`. Cubren URL y formato anterior, identificación estable,
asignación de fotos, propiedad, acceso de clientes, vista pública y conservación del
destino durante autenticación. No se añaden migraciones ni se cambian permisos de datos.
