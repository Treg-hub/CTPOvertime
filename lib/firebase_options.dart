import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCgdQmM5xjAFwtNk5PN61X2FEX7grg6e94',
    appId: '1:296041546243:web:273e88faf1a7a1abb60436',
    messagingSenderId: '296041546243',
    projectId: 'ctp-job-cards',
    authDomain: 'ctp-job-cards.firebaseapp.com',
    storageBucket: 'ctp-job-cards.firebasestorage.app',
    measurementId: 'G-CT3PJWFNBQ',
  );
}