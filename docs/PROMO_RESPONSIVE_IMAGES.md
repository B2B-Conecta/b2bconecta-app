# Dos imágenes por promoción

- La imagen existente es la de escritorio y sigue siendo obligatoria. Referencia: **2100 × 300 px (7:1)**. Mínimo tras recorte: **1200 × 172 px**.
- La imagen móvil es opcional. Referencia: **1500 × 500 px (3:1)**. Mínimo tras recorte: **1200 × 400 px**, con su propia composición legible.
- En el panel admin, al subir cada creativo se abre un **recorte obligatorio** (`crop_your_image`) con el aspect ratio fijo correspondiente (web y móvil). El resultado se guarda como JPEG y se registran `image_width` / `image_height` (y el par móvil).
- El carrusel usa la imagen móvil cuando su espacio disponible mide menos de **600 px**; si falta o falla, usa la de escritorio.
- El marco del carrusel usa `AspectRatio` fijo (7:1 o 3:1 según el breakpoint) y `BoxFit.cover`, con altura máxima ~180 / ~220 y ancho acotado a la retícula del catálogo. Así no distorsiona la grilla aunque la creativa antigua no coincida.
- El administrador muestra ambos archivos, permite cambiar cada uno y retirar la versión móvil. Activar/desactivar o editar conserva ambos archivos; eliminar la campaña intenta retirar ambos del almacenamiento.
- Con varias campañas, la paginación aparece sobre la imagen: puntos pulsables y cápsula activa animada. Con una sola campaña no se muestran indicadores. Se respeta la preferencia de movimiento reducido.

## Despliegue

1. Aplicar `supabase/migrations/20261209130002_promo_responsive_images.sql` (columnas URL móvil + RPC).
2. Aplicar `supabase/migrations/20261216120000_promo_banner_image_dimensions.sql` (anchos/altos del creativo).

No requiere recargar campañas antiguas: las dimensiones quedan null hasta el próximo recorte/subida.
