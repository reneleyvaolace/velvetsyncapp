// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/config/firebase_options.dart
// Configuración de Firebase - Reemplaza con tus credenciales reales
// ════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // ⚠️ REEMPLAZA estos valores con los de tu proyecto Firebase
  // Obtenlos en: Firebase Console → Configuración del proyecto → Tus apps
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDlUcGvwDcKUEb7zyxFoNjA3mr9Z3GZYjo',
    authDomain: 'velvet-sync.firebaseapp.com',
    projectId: 'velvet-sync',
    storageBucket: 'velvet-sync.appspot.com',
    messagingSenderId: '221572706400',
    appId: '1:221572706400:android:6aae5dc9216bc0ddc81305',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDlUcGvwDcKUEb7zyxFoNjA3mr9Z3GZYjo',
    authDomain: 'velvet-sync.firebaseapp.com',
    projectId: 'velvet-sync',
    storageBucket: 'velvet-sync.firebasestorage.app',
    messagingSenderId: '221572706400',
    appId: '1:221572706400:android:6aae5dc9216bc0ddc81305',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TU_API_KEY_IOS',
    authDomain: 'tu-proyecto.firebaseapp.com',
    projectId: 'tu-proyecto',
    storageBucket: 'tu-proyecto.appspot.com',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    appId: 'TU_APP_ID_IOS',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TU_API_KEY_MACOS',
    authDomain: 'tu-proyecto.firebaseapp.com',
    projectId: 'tu-proyecto',
    storageBucket: 'tu-proyecto.appspot.com',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    appId: 'TU_APP_ID_MACOS',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'TU_API_KEY_WINDOWS',
    authDomain: 'tu-proyecto.firebaseapp.com',
    projectId: 'tu-proyecto',
    storageBucket: 'tu-proyecto.appspot.com',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    appId: 'TU_APP_ID_WINDOWS',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'TU_API_KEY_LINUX',
    authDomain: 'tu-proyecto.firebaseapp.com',
    projectId: 'tu-proyecto',
    storageBucket: 'tu-proyecto.appspot.com',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    appId: 'TU_APP_ID_LINUX',
  );
}
