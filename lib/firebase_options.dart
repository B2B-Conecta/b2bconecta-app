import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIsojvI4tC7yVQp1E6-xEd95-oF0YBCc8',
    authDomain: 'moto-link-pro-app.firebaseapp.com',
    projectId: 'moto-link-pro-app',
    storageBucket: 'moto-link-pro-app.firebasestorage.app',
    messagingSenderId: '1032441463656',
    appId: '1:1032441463656:web:cc2597cd1a1731e0040cdd',
  );
}
