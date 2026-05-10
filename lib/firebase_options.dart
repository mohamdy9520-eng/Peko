import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIkxbnzU20EI0M_zU84EBPoBrMaxRyBHE',
    appId: '1:122686181921:web:7580efa31fa5342d504960',
    messagingSenderId: '122686181921',
    projectId: 'ai-expense-tracker-1efcf',
    authDomain: 'ai-expense-tracker-1efcf.firebaseapp.com',
    storageBucket: 'ai-expense-tracker-1efcf.firebasestorage.app',
    measurementId: 'G-XWMLRKLHW7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjIKebTg3E5OKqUPaIG7NgJ7hexAD1o0I',
    appId: '1:122686181921:android:e16d2b9344542fef504960',
    messagingSenderId: '122686181921',
    projectId: 'ai-expense-tracker-1efcf',
    storageBucket: 'ai-expense-tracker-1efcf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAhtR4FDvjBvxMj5Sw37WEPXTfZTFZ3yjw',
    appId: '1:122686181921:ios:7f430f12d479e9f5504960',
    messagingSenderId: '122686181921',
    projectId: 'ai-expense-tracker-1efcf',
    storageBucket: 'ai-expense-tracker-1efcf.firebasestorage.app',
    iosBundleId: 'com.example.aiExpenseTracker',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAhtR4FDvjBvxMj5Sw37WEPXTfZTFZ3yjw',
    appId: '1:122686181921:ios:7f430f12d479e9f5504960',
    messagingSenderId: '122686181921',
    projectId: 'ai-expense-tracker-1efcf',
    storageBucket: 'ai-expense-tracker-1efcf.firebasestorage.app',
    iosBundleId: 'com.example.aiExpenseTracker',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBIkxbnzU20EI0M_zU84EBPoBrMaxRyBHE',
    appId: '1:122686181921:web:64b26893d5d58ec7504960',
    messagingSenderId: '122686181921',
    projectId: 'ai-expense-tracker-1efcf',
    authDomain: 'ai-expense-tracker-1efcf.firebaseapp.com',
    storageBucket: 'ai-expense-tracker-1efcf.firebasestorage.app',
    measurementId: 'G-S7DXY68FL6',
  );
}
