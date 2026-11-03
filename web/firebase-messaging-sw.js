/* B2B Conecta — root-scoped Web Push service worker (W3C Push API + VAPID).
 *
 * Named firebase-messaging-sw.js so it lives at the site root and can claim
 * scope "./" (required for Safari macOS / Chrome / Edge). Payload delivery is
 * standard Web Push, not Firebase Cloud Messaging.
 */
importScripts("push/handlers.js");
