/* Fallback worker under /push/ (limited scope). Prefer root firebase-messaging-sw.js
 * or Flutter's flutter_service_worker.js with injected handlers. */
importScripts("handlers.js");
