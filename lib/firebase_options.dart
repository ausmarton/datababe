// Firebase configuration — values injected at build time via --dart-define.
// For local development: flutter run --dart-define-from-file=firebase.env

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS is not configured — run flutterfire configure');
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not configured — run flutterfire configure');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not configured — run flutterfire configure');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured — run flutterfire configure');
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Fuchsia is not configured');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('WEB_API_KEY'),
    appId: String.fromEnvironment('WEB_APP_ID'),
    messagingSenderId: String.fromEnvironment('MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('STORAGE_BUCKET'),
    measurementId: String.fromEnvironment('MEASUREMENT_ID'),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('ANDROID_API_KEY'),
    appId: String.fromEnvironment('ANDROID_APP_ID'),
    messagingSenderId: String.fromEnvironment('MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('STORAGE_BUCKET'),
  );
}
