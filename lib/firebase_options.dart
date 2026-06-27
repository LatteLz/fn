import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'dummy-api-key-cho-qua-buoc-compile',
    appId: '1:1234567890:android:abcdefg123456',
    messagingSenderId: '1234567890',
    projectId: 'strokeguard-nhom9',
    storageBucket: 'strokeguard-nhom9.appspot.com',
  );
}
