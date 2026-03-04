import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for the data-babe project.
/// These are client-side API keys, protected by Firestore security rules.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS is not configured');
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not configured');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not configured');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured');
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Fuchsia is not configured');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBzqXdqTlNIT5zjNX2Jm9CuJz8XyHK0mjk',
    appId: '1:1093785663342:web:0c5ac11605f649ce63737f',
    messagingSenderId: '1093785663342',
    projectId: 'data-babe',
    authDomain: 'data-babe.firebaseapp.com',
    storageBucket: 'data-babe.firebasestorage.app',
    measurementId: 'G-10CKV9LN13',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfQHQdeswAg59qsWAuuLuKIaLGXZic-qY',
    appId: '1:1093785663342:android:44bb7db16241588e63737f',
    messagingSenderId: '1093785663342',
    projectId: 'data-babe',
    storageBucket: 'data-babe.firebasestorage.app',
  );
}
