// Vista previa del enlace /producto/{id} para WhatsApp, Instagram y otros crawlers.
//
// Decisión: el catálogo solo se lee con sesión (RLS `products_select_marketplace`
// es `to authenticated`). Un crawler no tiene sesión, así que esta función usa
// la service role únicamente para armar la tarjeta.
//
// Si el producto está publicado (`is_active`): título = nombre y og:image = foto
// pública del bucket product-images. No se envían precio, stock, SKU ni proveedor.
// Si no existe o está en pausa: la misma tarjeta genérica de la marca, para no
// revelar que ese id existió. El minorista, ya dentro de la app, ve el aviso
// "no está disponible" sin datos del producto.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const ORIGIN = "https://app.b2bconecta.com.ve";
const BRAND_IMAGE = `${ORIGIN}/icons/Icon-512.png`;
const BRAND_TITLE = "B2B Conecta";
const BRAND_DESCRIPTION =
  "Marketplace B2B para importadores y tiendas. Inicia sesión para ver el catálogo.";

const UUID =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("method not allowed", { status: 405 });
  }

  const id = new URL(req.url).searchParams.get("id")?.trim() ?? "";
  const pageUrl = UUID.test(id) ? `${ORIGIN}/producto/${id}` : ORIGIN;

  let title = BRAND_TITLE;
  let description = BRAND_DESCRIPTION;
  let image = BRAND_IMAGE;

  if (UUID.test(id)) {
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (url && key) {
      const admin = createClient(url, key, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data } = await admin
        .from("products")
        .select("name, image_url, image_urls, is_active")
        .eq("id", id)
        .maybeSingle();
      const active = data?.is_active === true;
      const name = typeof data?.name === "string" ? data.name.trim() : "";
      const photo = active ? coverUrl(data) : "";
      if (active && name) {
        title = name;
        description =
          "Disponible en el catálogo B2B Conecta. Inicia sesión para ver precio y comprarlo.";
        if (photo) image = photo;
      }
    }
  }

  const html = render({ title, description, image, pageUrl });
  return new Response(req.method === "HEAD" ? null : html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
});

function coverUrl(row: {
  image_url?: unknown;
  image_urls?: unknown;
} | null): string {
  const urls = row?.image_urls;
  if (Array.isArray(urls)) {
    for (const item of urls) {
      const value = String(item ?? "").trim();
      if (value.startsWith("https://")) return value;
    }
  }
  const legacy = String(row?.image_url ?? "").trim();
  return legacy.startsWith("https://") ? legacy : "";
}

function render(card: {
  title: string;
  description: string;
  image: string;
  pageUrl: string;
}): string {
  const title = escapeHtml(card.title);
  const description = escapeHtml(card.description);
  const image = escapeHtml(card.image);
  const pageUrl = escapeHtml(card.pageUrl);
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <meta name="description" content="${description}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="B2B Conecta">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${description}">
  <meta property="og:url" content="${pageUrl}">
  <meta property="og:image" content="${image}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${title}">
  <meta name="twitter:description" content="${description}">
  <meta name="twitter:image" content="${image}">
  <link rel="canonical" href="${pageUrl}">
  <meta http-equiv="refresh" content="0; url=${pageUrl}">
</head>
<body>
  <p><a href="${pageUrl}">Abrir en B2B Conecta</a></p>
</body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
