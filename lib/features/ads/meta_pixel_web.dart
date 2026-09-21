// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

import 'marketing_consent.dart';
import 'marketing_consent_storage.dart';
import 'meta_pixel_config.dart';
import 'meta_pixel_events.dart';

bool _scriptReady = false;
bool _pageViewSent = false;

/// Carga el Pixel y dispara [PageView] una sola vez por carga de página.
void syncMetaPixel({required bool marketingAllowed}) {
  if (!marketingAllowed) return;
  _ensureScript();
  _trackPageViewOnce();
}

void trackRegistrationStarted({String? identity}) {
  _trackOnce(
    MetaPixelEvents.registrationStarted,
    identity,
  );
}

void trackCompleteRegistration({String? email, String? userId}) {
  _trackOnce(
    MetaPixelEvents.completeRegistration,
    userId ?? email,
  );
}

void trackSubmitApplication({String? userId}) {
  _trackOnce(
    MetaPixelEvents.submitApplication,
    userId,
  );
}

void trackPurchase({
  required String orderId,
  required double valueUsd,
}) {
  _trackOnce(
    MetaPixelEvents.purchase,
    orderId,
    params: <String, dynamic>{
      'value': valueUsd,
      'currency': 'USD',
      'order_id': orderId,
    },
  );
}

void _trackOnce(
  String event,
  String? identity, {
  Map<String, dynamic>? params,
}) {
  if (readMarketingConsent() != MarketingConsent.accepted) return;
  _ensureScript();
  if (!js.context.hasProperty('fbq')) return;
  final key = MetaPixelEvents.dedupeKey(event, identity);
  if (_wasSent(key)) return;
  final eventId = MetaPixelEvents.eventId(event, identity);
  final payload = <String, dynamic>{
    ...?params,
  };
  js.context.callMethod('fbq', [
    'track',
    event,
    js.JsObject.jsify(payload),
    js.JsObject.jsify(<String, dynamic>{'eventID': eventId}),
  ]);
  _markSent(key);
}

bool _wasSent(String key) {
  try {
    return html.window.localStorage[key] == '1';
  } catch (_) {
    return false;
  }
}

void _markSent(String key) {
  try {
    html.window.localStorage[key] = '1';
  } catch (_) {}
}

void _ensureScript() {
  if (_scriptReady) return;
  if (js.context.hasProperty('fbq')) {
    _scriptReady = true;
    return;
  }
  final id = MetaPixelConfig.pixelId;
  js.context.callMethod('eval', [
    '''
    !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?
    n.callMethod.apply(n,arguments):n.queue.push(arguments)};
    if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
    n.queue=[];t=b.createElement(e);t.async=!0;
    t.src=v;s=b.getElementsByTagName(e)[0];
    s.parentNode.insertBefore(t,s)}(window, document,'script',
    'https://connect.facebook.net/en_US/fbevents.js');
    fbq('init', '$id');
    ''',
  ]);
  _scriptReady = true;
}

void _pageViewOnce() {
  if (_pageViewSent) return;
  if (!js.context.hasProperty('fbq')) return;
  js.context.callMethod('fbq', ['track', 'PageView']);
  _pageViewSent = true;
}

void _trackPageViewOnce() => _pageViewOnce();
