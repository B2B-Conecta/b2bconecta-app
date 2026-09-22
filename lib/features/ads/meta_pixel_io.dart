import 'dart:async';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'marketing_consent.dart';
import 'marketing_consent_storage.dart';
import 'meta_pixel_config.dart';
import 'meta_pixel_events.dart';

final FacebookAppEvents _fb = FacebookAppEvents();
bool _activateSent = false;

bool get _sdkReady {
  final id = MetaPixelConfig.resolveFacebookAppId(
    dotenv.env['META_APP_ID'],
  );
  return id != null;
}

Future<bool> _allow() async {
  if (!_sdkReady) return false;
  if (readMarketingConsent() != MarketingConsent.accepted) return false;
  return true;
}

Future<bool> _wasSent(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) == '1';
  } catch (_) {
    return false;
  }
}

Future<void> _markSent(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, '1');
  } catch (_) {}
}

Future<void> _log(
  String event,
  String? identity, {
  Map<String, dynamic>? params,
}) async {
  if (!await _allow()) return;
  final key = MetaPixelEvents.dedupeKey(event, identity);
  if (await _wasSent(key)) return;
  final eventId = MetaPixelEvents.eventId(event, identity);
  try {
    await _fb.logEvent(
      name: event,
      parameters: <String, dynamic>{
        ...?params,
        '_eventId': eventId,
      },
    );
    await _markSent(key);
  } catch (e) {
    debugPrint('[meta] $event failed: $e');
  }
}

void syncMetaPixel({required bool marketingAllowed}) {
  if (!marketingAllowed || !_sdkReady || _activateSent) return;
  _activateSent = true;
  unawaited(_fb.setAutoLogAppEventsEnabled(true));
  unawaited(_fb.setAdvertiserTracking(enabled: true));
  unawaited(_fb.logEvent(name: 'fb_mobile_activate_app'));
}

void trackRegistrationStarted({String? identity}) {
  unawaited(_log(MetaPixelEvents.registrationStarted, identity));
}

void trackSubmitApplication({String? userId}) {
  unawaited(_log(MetaPixelEvents.submitApplication, userId));
}

void trackCompleteRegistration({String? email, String? userId}) {
  unawaited(_log(MetaPixelEvents.completeRegistration, userId ?? email));
}

void trackPurchase({
  required String orderId,
  required double valueUsd,
}) {
  unawaited(
    _log(
      MetaPixelEvents.purchase,
      orderId,
      params: <String, dynamic>{
        'fb_currency': 'USD',
        'fb_content_id': orderId,
        '_valueToSum': valueUsd,
      },
    ),
  );
}
