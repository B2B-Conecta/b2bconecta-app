// Los robots de la tarjeta leen app.b2bconecta.com.ve.
// Supabase reescribe text/html a text/plain en su dominio, así que
// esta capa pide la vista previa y la sirve como HTML.
//
// El navegador de Instagram incluye "Instagram" y el de WhatsApp a veces
// incluye "WhatsApp" junto con Mozilla. Esas visitas deben recibir la app.
const PREVIEW =
  "https://fzugzjcwdzcwfxgviltw.supabase.co/functions/v1/product-share-preview";

const CRAWLER =
  /facebookexternalhit|Facebot|Twitterbot|TelegramBot|Slackbot|LinkedInBot|Discordbot|Pinterestbot|Googlebot|bingbot|Applebot/i;

function isLinkPreviewCrawler(userAgent) {
  if (CRAWLER.test(userAgent)) return true;
  return /WhatsApp\//i.test(userAgent) && !/Mozilla/i.test(userAgent);
}

export const config = {
  matcher: ["/producto/:path*", "/vitrina/:path*"],
};

export default async function middleware(request) {
  const agent = request.headers.get("user-agent") || "";
  if (!isLinkPreviewCrawler(agent)) return;

  const parts = new URL(request.url).pathname.split("/").filter(Boolean);
  const kind = parts[0] === "vitrina" ? "store" : "product";
  const id = parts[1] || "";
  const upstream = await fetch(
    `${PREVIEW}?kind=${kind}&id=${encodeURIComponent(id)}`,
  );
  const html = await upstream.text();
  return new Response(html, {
    status: upstream.ok ? 200 : upstream.status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}
