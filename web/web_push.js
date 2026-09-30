(function () {
  function urlBase64ToUint8Array(base64String) {
    var padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    var base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    var raw = atob(base64);
    var output = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) output[i] = raw.charCodeAt(i);
    return output;
  }

  function isIos() {
    var ua = navigator.userAgent || "";
    var iOSDevice = /iPad|iPhone|iPod/.test(ua);
    var iPadOs = navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1;
    return iOSDevice || iPadOs;
  }

  function isStandalone() {
    var media = window.matchMedia && window.matchMedia("(display-mode: standalone)").matches;
    var iosStandalone = window.navigator.standalone === true;
    return !!(media || iosStandalone);
  }

  function hasApi() {
    return (
      "serviceWorker" in navigator &&
      "PushManager" in window &&
      "Notification" in window
    );
  }

  function keysFromSubscription(sub) {
    var json = sub.toJSON();
    var k = json.keys || {};
    return {
      endpoint: json.endpoint || sub.endpoint,
      p256dh: k.p256dh || "",
      auth: k.auth || "",
    };
  }

  async function getRegistration() {
    if (!("serviceWorker" in navigator)) {
      throw new Error("Service Worker no disponible");
    }
    var list = await navigator.serviceWorker.getRegistrations();
    var flutter = list.find(function (r) {
      var url = (r.active && r.active.scriptURL) || "";
      return url.indexOf("flutter_service_worker") >= 0;
    });
    if (flutter) return flutter;
    try {
      return await navigator.serviceWorker.register("push/sw.js", { scope: "./push/" });
    } catch (e) {
      return navigator.serviceWorker.ready;
    }
  }

  function consumeLaunchQuery() {
    try {
      var url = new URL(window.location.href);
      var type = url.searchParams.get("b2b_nt");
      if (!type) return "";
      var related = url.searchParams.get("b2b_nr") || "";
      var nid = url.searchParams.get("b2b_nid") || "";
      url.searchParams.delete("b2b_nt");
      url.searchParams.delete("b2b_nr");
      url.searchParams.delete("b2b_nid");
      var next = url.pathname + (url.search ? url.search : "") + url.hash;
      window.history.replaceState({}, "", next || "/");
      return JSON.stringify({ type: type, related_id: related, notification_id: nid });
    } catch (_) {
      return "";
    }
  }

  window.b2bWebPush = {
    hasApi: hasApi,
    isIos: isIos,
    isStandalone: isStandalone,
    getPermission: function () {
      if (!("Notification" in window)) return "unsupported";
      return Notification.permission || "default";
    },
    requestPermission: async function () {
      if (!("Notification" in window)) return "denied";
      return Notification.requestPermission();
    },
    getSubscription: async function () {
      if (!hasApi()) return "";
      var reg = await getRegistration();
      var sub = await reg.pushManager.getSubscription();
      return sub ? JSON.stringify(keysFromSubscription(sub)) : "";
    },
    subscribe: async function (vapidPublicKey) {
      if (!hasApi()) throw new Error("Web Push no está disponible en este navegador.");
      var perm = await Notification.requestPermission();
      if (perm !== "granted") {
        return JSON.stringify({ permission: perm, subscription: null });
      }
      var reg = await getRegistration();
      var existing = await reg.pushManager.getSubscription();
      if (existing) {
        try {
          await existing.unsubscribe();
        } catch (_) {}
      }
      var sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });
      return JSON.stringify({
        permission: "granted",
        subscription: keysFromSubscription(sub),
      });
    },
    unsubscribe: async function () {
      if (!hasApi()) return "";
      var reg = await getRegistration();
      var sub = await reg.pushManager.getSubscription();
      if (!sub) return "";
      var endpoint = sub.endpoint || "";
      await sub.unsubscribe();
      return endpoint;
    },
    onClick: function (handler) {
      if (!("serviceWorker" in navigator)) return;
      navigator.serviceWorker.addEventListener("message", function (event) {
        var data = event.data || {};
        if (data.source !== "b2b-web-push") return;
        handler(JSON.stringify({
          type: data.type || "mensaje",
          related_id: data.related_id || "",
          notification_id: data.notification_id || "",
        }));
      });
    },
    consumeLaunchQuery: consumeLaunchQuery,
  };
})();
