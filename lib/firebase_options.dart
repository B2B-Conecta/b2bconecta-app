import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase config for B2B Conecta (project: moto-link-pro-app).
abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Push notifications are not configured for web yet.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Push notifications are only supported on Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAT12-GE4vPt0n9rzCzhrpSNdT7y5kchaA',
    appId: '1:1032441463656:android:41de74deeb7542ee040cdd',
    messagingSenderId: '1032441463656',
    projectId: 'moto-link-pro-app',
    storageBucket: 'moto-link-pro-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBqpIeJfkfHUIRb07fftq0c_ofDtlOpZkM',
    appId: '1:1032441463656:ios:8d09d04064e19eec040cdd',
    messagingSenderId: '1032441463656',
    projectId: 'moto-link-pro-app',
    storageBucket: 'moto-link-pro-app.firebasestorage.app',
    iosBundleId: 've.com.b2bconecta.app',
  );
}
