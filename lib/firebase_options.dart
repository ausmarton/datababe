// File generated manually for Firebase project: data-babe
// Replace TODO values with your actual Firebase config from:
//   https://console.firebase.google.com/project/data-babe/settings/general
//
// Or run: flutterfire configure --project=data-babe
// (install via: dart pub global activate flutterfire_cli)

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
    apiKey: 'TODO_WEB_API_KEY',
    appId: 'TODO_WEB_APP_ID',
    messagingSenderId: 'TODO_MESSAGING_SENDER_ID',
    projectId: 'data-babe',
    authDomain: 'data-babe.firebaseapp.com',
    storageBucket: 'data-babe.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO_ANDROID_API_KEY',
    appId: 'TODO_ANDROID_APP_ID',
    messagingSenderId: 'TODO_MESSAGING_SENDER_ID',
    projectId: 'data-babe',
    storageBucket: 'data-babe.firebasestorage.app',
  );
}
