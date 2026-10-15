import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Automatically configured for Android, Web, and Desktop.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return windows;
      case TargetPlatform.macOS:
        return web;
      case TargetPlatform.iOS:
        return web;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDogjF42VryLOxvuNmNW7U7Phhz7YrnAjg',
    appId: '1:767112171518:web:1c3e7ce7f900efd0b5faaf',
    messagingSenderId: '767112171518',
    projectId: 'mnpschool-bb50b',
    authDomain: 'mnpschool-bb50b.firebaseapp.com',
    storageBucket: 'mnpschool-bb50b.firebasestorage.app',
    measurementId: 'G-QEDYFV1K5R',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD51G45rkF9PDm6vFWd8ASSYF33NYyY20k',
    appId: '1:767112171518:android:8cbc165d9d0a8d18b5faaf',
    messagingSenderId: '767112171518',
    projectId: 'mnpschool-bb50b',
    storageBucket: 'mnpschool-bb50b.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDogjF42VryLOxvuNmNW7U7Phhz7YrnAjg',
    appId: '1:767112171518:web:1c3e7ce7f900efd0b5faaf',
    messagingSenderId: '767112171518',
    projectId: 'mnpschool-bb50b',
    authDomain: 'mnpschool-bb50b.firebaseapp.com',
    storageBucket: 'mnpschool-bb50b.firebasestorage.app',
  );
}
