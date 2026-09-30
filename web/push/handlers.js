/* B2B_WEB_PUSH_HANDLERS */
(function () {
  var ICON = "/icons/Icon-192.png";
  var BADGE = "/icons/Icon-192.png";

  function parsePayload(event) {
    var data = {
      title: "B2B Conecta",
      body: "Tienes un aviso nuevo.",
      type: "mensaje",
      related_id: "",
      notification_id: "",
    };
    if (!event.data) return data;
    try {
      var json = event.data.json();
      if (json && typeof json === "object") {
        if (json.title) data.title = String(json.title);
        if (json.body) data.body = String(json.body);
        if (json.type) data.type = String(json.type);
        if (json.related_id) data.related_id = String(json.related_id);
        if (json.notification_id) data.notification_id = String(json.notification_id);
        return data;
      }
    } catch (_) {}
    try {
      var text = event.data.text();
      if (text) data.body = text;
    } catch (_) {}
    return data;
  }

  function targetUrl(data) {
    var params = new URLSearchParams();
    params.set("b2b_nt", data.type || "mensaje");
    if (data.related_id) params.set("b2b_nr", data.related_id);
    if (data.notification_id) params.set("b2b_nid", data.notification_id);
    return "./?" + params.toString();
  }

  self.addEventListener("push", function (event) {
    var data = parsePayload(event);
    var title = data.title || "B2B Conecta";
    var body = data.body || title;
    event.waitUntil(
      self.registration.showNotification(title, {
        body: body,
        icon: ICON,
        badge: BADGE,
        tag: data.notification_id || data.type || "b2b-conecta",
        renotify: true,
        data: {
          type: data.type,
          related_id: data.related_id,
          notification_id: data.notification_id,
          url: targetUrl(data),
        },
      })
    );
  });

  self.addEventListener("notificationclick", function (event) {
    event.notification.close();
    var payload = event.notification.data || {};
    var url = payload.url || "./";
    event.waitUntil(
      self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(function (clientList) {
        var message = {
          source: "b2b-web-push",
          type: payload.type || "mensaje",
          related_id: payload.related_id || "",
          notification_id: payload.notification_id || "",
        };
        for (var i = 0; i < clientList.length; i++) {
          var client = clientList[i];
          if ("focus" in client) {
            client.postMessage(message);
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(url);
        }
      })
    );
  });
})();
