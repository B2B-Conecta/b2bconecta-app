/* B2B Conecta — Web Push (W3C Push API + VAPID). Safari macOS 16+ / Chrome / Edge. */
(function (global) {
  "use strict";

  var ROOT_SW = "firebase-messaging-sw.js";
  var FALLBACK_SW = "push/sw.js";

  function ua() {
    return (global.navigator && global.navigator.userAgent) || "";
  }

  function isIos() {
    var t = ua();
    if (/iPad|iPhone|iPod/.test(t)) return true;
    // iPadOS 13+ may report as Mac with touch.
    if (global.navigator && global.navigator.platform === "MacIntel" && global.navigator.maxTouchPoints > 1) {
      return true;
    }
    return false;
  }

  function isAndroid() {
    return /Android/i.test(ua());
  }

  function isDesktopWeb() {
    return !isIos() && !isAndroid();
  }

  function isStandalone() {
    try {
      if (global.navigator && global.navigator.standalone === true) return true;
    } catch (_) {}
    try {
      if (global.matchMedia && global.matchMedia("(display-mode: standalone)").matches) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  function hasApi() {
    try {
      if (!global.navigator || !("serviceWorker" in global.navigator)) return false;
      if (!global.PushManager) return false;
      // iOS only exposes PushManager in Home Screen PWAs.
      if (isIos() && !isStandalone()) return false;
      if (typeof Notification === "undefined") return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  function getPermission() {
    try {
      if (typeof Notification === "undefined") return "unsupported";
      return Notification.permission || "default";
    } catch (_) {
      return "unsupported";
    }
  }

  function getPlatformHint() {
    var t = ua().toLowerCase();
    if (isIos()) return "ios";
    if (isAndroid()) return "android";
    if (t.indexOf("edg/") !== -1 || t.indexOf("edgios") !== -1) return "edge";
    if (t.indexOf("chrome/") !== -1 && t.indexOf("edg/") === -1) return "chrome";
    if (t.indexOf("safari/") !== -1 && t.indexOf("chrome/") === -1) return "safari";
    if (t.indexOf("firefox/") !== -1) return "firefox";
    return "desktop";
  }

  function urlBase64ToUint8Array(base64String) {
    var padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    var base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    var rawData = global.atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  function subscriptionToJson(sub) {
    if (!sub) return null;
    var json = sub.toJSON ? sub.toJSON() : null;
    if (!json || !json.endpoint) return null;
    var keys = json.keys || {};
    return {
      endpoint: json.endpoint,
      p256dh: keys.p256dh || "",
      auth: keys.auth || "",
    };
  }

  function prefersFlutterSw(reg) {
    if (!reg || !reg.active || !reg.active.scriptURL) return false;
    return reg.active.scriptURL.indexOf("flutter_service_worker") !== -1;
  }

  function prefersRootPushSw(reg) {
    if (!reg || !reg.active || !reg.active.scriptURL) return false;
    var url = reg.active.scriptURL;
    return (
      url.indexOf("firebase-messaging-sw.js") !== -1 ||
      url.indexOf("flutter_service_worker") !== -1
    );
  }

  function pickBestRegistration(regs) {
    var i;
    for (i = 0; i < regs.length; i++) {
      if (prefersFlutterSw(regs[i])) return regs[i];
    }
    for (i = 0; i < regs.length; i++) {
      if (prefersRootPushSw(regs[i])) return regs[i];
    }
    for (i = 0; i < regs.length; i++) {
      var scope = (regs[i].scope || "").replace(/\/?$/, "/");
      var origin = (global.location && global.location.origin) || "";
      if (scope === origin + "/" || scope.endsWith(global.location.pathname.replace(/[^/]+$/, ""))) {
        return regs[i];
      }
    }
    return regs.length ? regs[0] : null;
  }

  function getRegistration() {
    return global.navigator.serviceWorker.getRegistrations().then(function (regs) {
      var best = pickBestRegistration(regs || []);
      // Prefer Flutter SW (prod inject) or an existing root push SW — do not
      // register a second root worker alongside Flutter's.
      if (best && prefersRootPushSw(best)) return best;
      if (best && prefersFlutterSw(best)) return best;
      // Local / first visit: root-scoped worker so PushManager covers the panel.
      return global.navigator.serviceWorker
        .register(ROOT_SW, { scope: "./" })
        .catch(function () {
          return global.navigator.serviceWorker.register(FALLBACK_SW, {
            scope: "./push/",
          });
        });
    });
  }

  function ensureServiceWorker() {
    if (!global.navigator || !("serviceWorker" in global.navigator)) {
      return Promise.resolve(null);
    }
    return getRegistration().then(function (reg) {
      return global.navigator.serviceWorker.ready.then(function () {
        return reg;
      });
    });
  }

  function requestPermission() {
    if (typeof Notification === "undefined" || !Notification.requestPermission) {
      return Promise.resolve("denied");
    }
    // Must run from a user gesture (Safari macOS / Chrome).
    return Promise.resolve(Notification.requestPermission()).then(function (p) {
      return typeof p === "string" ? p : getPermission();
    });
  }

  function getSubscription() {
    return getRegistration().then(function (reg) {
      return reg.pushManager.getSubscription().then(function (sub) {
        return JSON.stringify(subscriptionToJson(sub) || {});
      });
    });
  }

  function subscribe(vapidPublicKey) {
    return requestPermission().then(function (permission) {
      if (permission !== "granted") {
        return JSON.stringify({ permission: permission, subscription: null });
      }
      return getRegistration().then(function (reg) {
        return global.navigator.serviceWorker.ready.then(function () {
          return reg.pushManager.getSubscription().then(function (existing) {
            if (existing) {
              return JSON.stringify({
                permission: "granted",
                subscription: subscriptionToJson(existing),
              });
            }
            return reg.pushManager
              .subscribe({
                userVisibleOnly: true,
                applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
              })
              .then(function (sub) {
                return JSON.stringify({
                  permission: "granted",
                  subscription: subscriptionToJson(sub),
                });
              });
          });
        });
      });
    });
  }

  function unsubscribe() {
    return getRegistration()
      .then(function (reg) {
        return reg.pushManager.getSubscription();
      })
      .then(function (sub) {
        if (!sub) return "";
        var endpoint = sub.endpoint || "";
        return sub.unsubscribe().then(function () {
          return endpoint;
        });
      })
      .catch(function () {
        return "";
      });
  }

  var clickHandler = null;

  function onClick(handler) {
    clickHandler = handler;
  }

  function consumeLaunchQuery() {
    try {
      var params = new URLSearchParams(global.location.search || "");
      var type = params.get("b2b_nt");
      if (!type) return "{}";
      var payload = {
        type: type,
        related_id: params.get("b2b_nr") || "",
        notification_id: params.get("b2b_nid") || "",
      };
      params.delete("b2b_nt");
      params.delete("b2b_nr");
      params.delete("b2b_nid");
      var next = params.toString();
      var path = global.location.pathname || "/";
      var hash = global.location.hash || "";
      var url = path + (next ? "?" + next : "") + hash;
      if (global.history && global.history.replaceState) {
        global.history.replaceState({}, "", url);
      }
      return JSON.stringify(payload);
    } catch (_) {
      return "{}";
    }
  }

  if (global.navigator && global.navigator.serviceWorker) {
    global.navigator.serviceWorker.addEventListener("message", function (event) {
      var data = event.data || {};
      if (data.source !== "b2b-web-push") return;
      if (typeof clickHandler === "function") {
        clickHandler(
          JSON.stringify({
            type: data.type || "mensaje",
            related_id: data.related_id || "",
            notification_id: data.notification_id || "",
          })
        );
      }
    });
  }

  // Warm the worker early so subscribe() on a click is fast and reliable.
  if (global.addEventListener) {
    global.addEventListener("load", function () {
      try {
        ensureServiceWorker();
      } catch (_) {}
    });
  }

  global.b2bWebPush = {
    hasApi: hasApi,
    isIos: isIos,
    isAndroid: isAndroid,
    isDesktopWeb: isDesktopWeb,
    isStandalone: isStandalone,
    getPermission: getPermission,
    getUserAgent: ua,
    getPlatformHint: getPlatformHint,
    requestPermission: requestPermission,
    getSubscription: getSubscription,
    subscribe: subscribe,
    unsubscribe: unsubscribe,
    onClick: onClick,
    consumeLaunchQuery: consumeLaunchQuery,
    ensureServiceWorker: ensureServiceWorker,
  };
})(typeof self !== "undefined" ? self : this);
