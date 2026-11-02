# Dos imágenes por promoción

- La imagen existente es la de escritorio y sigue siendo obligatoria. Referencia: 2100 × 300 px.
- La imagen móvil es opcional. Referencia: 1500 × 500 px, con su propia composición legible.
- El carrusel usa la imagen móvil cuando su espacio disponible mide menos de 600 px; si falta o falla, usa la de escritorio. Conserva la proporción real, la vigencia y el destino.
- El administrador muestra ambos archivos, permite cambiar cada uno y retirar la versión móvil. Activar/desactivar o editar conserva ambos archivos; eliminar la campaña intenta retirar ambos del almacenamiento.
- El banner se muestra centrado, sin franja inferior; toda la imagen conserva el acceso al destino configurado. La vigencia también se conserva en su descripción accesible y en las vistas de la promoción.
- Con varias campañas, la paginación aparece sobre la imagen: puntos pulsables y cápsula activa animada. Con una sola campaña no se muestran indicadores. Se respeta la preferencia de movimiento reducido.

## Despliegue

Aplicar **antes de desplegar la app** `supabase/migrations/20261209130002_promo_responsive_images.sql`. Añade dos columnas opcionales y el campo de URL móvil a los tres RPC existentes, preservando sus filtros y permisos. No requiere recargar campañas antiguas.

La migración se creó con la CLI y se ordenó después de los archivos existentes, que incluyen fechas posteriores a la fecha de este desarrollo.

Aplicado únicamente al sandbox `czswojzpekcsisudgfsg`. DEV y producción pendientes; no se han modificado sus esquemas ni sus archivos.
