export type AccountEmailEvent = "registration_submitted" | "profile_approved";

export interface EmailTemplate {
  subject: string;
  html: string;
  text: string;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function layout(params: {
  title: string;
  greeting: string;
  bodyHtml: string;
  footer: string;
}): string {
  const { title, greeting, bodyHtml, footer } = params;
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;padding:0;background:#f0f4fa;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f0f4fa;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:12px;border:1px solid #e3e8f0;overflow:hidden;">
          <tr>
            <td style="padding:28px 24px 12px;text-align:center;background:#f7fafc;">
              <img src="cid:motolink-logo" alt="MotoLink" width="168" style="display:block;margin:0 auto;max-width:168px;height:auto;" />
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 4px;font-size:22px;line-height:1.3;font-weight:700;color:#1565c0;">
              ${escapeHtml(title)}
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 16px;font-size:15px;line-height:1.6;color:#333333;">
              <p style="margin:0 0 12px;">${escapeHtml(greeting)}</p>
              ${bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="padding:16px 28px 28px;font-size:12px;line-height:1.5;color:#757575;border-top:1px solid #eef2f7;">
              ${escapeHtml(footer)}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export function buildAccountEmailTemplate(
  event: AccountEmailEvent,
  businessName: string,
): EmailTemplate {
  const name = businessName.trim() || "aliado";
  const greeting = `Hola ${name},`;

  if (event === "registration_submitted") {
    const title = "Recibimos su registro inicial";
    const bodyHtml = `
      <p style="margin:0 0 12px;">
        Gracias por completar su <strong>registro inicial</strong> en MotoLink.
        Ya tenemos su documentación y datos del negocio.
      </p>
      <p style="margin:0 0 12px;">
        Nuestro equipo revisará su expediente y le avisaremos por correo
        cuando su perfil esté validado y pueda ingresar a la plataforma.
      </p>
      <p style="margin:0;">
        Si necesita actualizar algún documento, puede volver a su perfil mientras
        la solicitud esté en revisión.
      </p>`;
    const text =
      `${greeting}\n\n` +
      "Gracias por completar su registro inicial en MotoLink. " +
      "Recibimos su documentación y nuestro equipo la revisará. " +
      "Le notificaremos cuando su perfil esté validado.\n\n" +
      "Equipo MotoLink";
    return {
      subject: "MotoLink — Registro inicial recibido",
      html: layout({
        title,
        greeting,
        bodyHtml,
        footer:
          "Este mensaje fue enviado por MotoLink Marketplace B2B. " +
          "No responda a este correo; es una notificación automática.",
      }),
      text,
    };
  }

  const title = "Su perfil fue validado";
  const bodyHtml = `
    <p style="margin:0 0 12px;">
      Nos complace informarle que su <strong>perfil aliado</strong> fue
      <strong>aprobado</strong> por MotoLink.
    </p>
    <p style="margin:0 0 12px;">
      Ya puede ingresar a MotoLink Pro con su usuario y comenzar a operar
      en el marketplace B2B.
    </p>
    <p style="margin:0;">
      Bienvenido a la red MotoLink. Estamos listos para acompañarle.
    </p>`;
  const text =
    `${greeting}\n\n` +
    "Su perfil aliado fue aprobado por MotoLink. " +
    "Ya puede ingresar a MotoLink Pro y comenzar a operar.\n\n" +
    "Bienvenido a MotoLink.";

  return {
    subject: "MotoLink — Perfil validado, bienvenido",
    html: layout({
      title,
      greeting,
      bodyHtml,
      footer:
        "Este mensaje confirma la habilitación de su acceso en MotoLink. " +
        "Ante dudas, contacte a soporte de MotoLink.",
    }),
    text,
  };
}
