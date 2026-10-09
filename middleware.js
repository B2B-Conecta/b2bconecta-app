// WhatsApp e Instagram leen la tarjeta en app.b2bconecta.com.ve.
// Supabase reescribe text/html a text/plain en su dominio, así que
// esta capa pide la vista previa y la sirve como HTML.
const PREVIEW =
  "https://fzugzjcwdzcwfxgviltw.supabase.co/functions/v1/product-share-preview";

const BOT =
  /WhatsApp|facebookexternalhit|Facebot|Twitterbot|TelegramBot|Slackbot|LinkedInBot|Discordbot|Instagram|Pinterest/i;

export const config = {
  matcher: "/producto/:path*",
};

export default async function middleware(request) {
  const agent = request.headers.get("user-agent") || "";
  if (!BOT.test(agent)) return;

  const parts = new URL(request.url).pathname.split("/").filter(Boolean);
  const id = parts[1] || "";
  const upstream = await fetch(`${PREVIEW}?id=${encodeURIComponent(id)}`);
  const html = await upstream.text();
  return new Response(html, {
    status: upstream.ok ? 200 : upstream.status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}
