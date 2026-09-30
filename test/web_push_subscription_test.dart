import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/notifications/web_push_environment.dart';
import 'package:motolink_pro_app/core/notifications/web_push_status.dart';
import 'package:motolink_pro_app/core/notifications/web_push_subscription_keys.dart';

void main() {
  group('webPushEnvironmentFromSupabaseUrl', () {
    test('local Docker', () {
      expect(
        webPushEnvironmentFromSupabaseUrl('http://127.0.0.1:54321'),
        WebPushEnvironment.local,
      );
      expect(
        webPushEnvironmentFromSupabaseUrl('http://localhost:54321'),
        WebPushEnvironment.local,
      );
    });

    test('DEV vs MAIN refs', () {
      expect(
        webPushEnvironmentFromSupabaseUrl(
          'https://kdrccmqcrruixuworlmz.supabase.co',
        ),
        WebPushEnvironment.dev,
      );
      expect(
        webPushEnvironmentFromSupabaseUrl(
          'https://fzugzjcwdzcwfxgviltw.supabase.co',
        ),
        WebPushEnvironment.main,
      );
    });
  });

  group('WebPushSubscriptionKeys', () {
    test('acepta un endpoint https válido', () {
      expect(
        isWebPushEndpointValid(
          'https://web.push.apple.com/Q1w2e3r4t5y6u7i8o9p0',
        ),
        isTrue,
      );
    });

    test('rechaza http, espacios o hosts vacíos', () {
      expect(isWebPushEndpointValid('http://example.com/push'), isFalse);
      expect(isWebPushEndpointValid('https://example.com/push path'), isFalse);
      expect(isWebPushEndpointValid('not-a-url'), isFalse);
      expect(isWebPushEndpointValid(''), isFalse);
    });

    test('rechaza claves cortas o con espacio', () {
      expect(isWebPushKeyValid('abc'), isFalse);
      expect(isWebPushKeyValid('abcd efghijkl'), isFalse);
      expect(isWebPushKeyValid('BNabcdefghijklmnopqrstuv'), isTrue);
    });

    test('fromJson y isValid', () {
      final ok = WebPushSubscriptionKeys.fromJson({
        'endpoint': 'https://fcm.googleapis.com/fcm/send/abc123abc123abc123',
        'p256dh': 'BNabcdefghijklmnopqrstuvwx',
        'auth': 'authToken12',
      });
      expect(ok.isValid, isTrue);

      final bad = WebPushSubscriptionKeys.fromJson({
        'endpoint': 'https://fcm.googleapis.com/fcm/send/abc123abc123abc123',
        'p256dh': '',
        'auth': 'authToken12',
      });
      expect(bad.isValid, isFalse);
    });
  });

  test('webPushPlatformFromUserAgent', () {
    expect(
      webPushPlatformFromUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17)',
          isIos: true),
      'ios',
    );
    expect(
      webPushPlatformFromUserAgent('Mozilla/5.0 (Linux; Android 14)',
          isIos: false),
      'android',
    );
    expect(
      webPushPlatformFromUserAgent('Mozilla/5.0 (Macintosh)', isIos: false),
      'desktop',
    );
  });

  test('estados de UI: activar vs activo', () {
    expect(WebPushUiStatus.permissionDefault.canActivate, isTrue);
    expect(WebPushUiStatus.expired.canActivate, isTrue);
    expect(WebPushUiStatus.subscribed.canActivate, isFalse);
    expect(WebPushUiStatus.permissionDenied.canActivate, isFalse);
    expect(WebPushUiStatus.subscribed.isActive, isTrue);
    expect(WebPushUiStatus.iosNeedsInstall.isActive, isFalse);
  });
}
