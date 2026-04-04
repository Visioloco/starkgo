import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDwmWsB-k2CZ9pzWBH96mkTovpIFujBMIY",
            authDomain: "starkgo-3671b.firebaseapp.com",
            projectId: "starkgo-3671b",
            storageBucket: "starkgo-3671b.firebasestorage.app",
            messagingSenderId: "806017860604",
            appId: "1:806017860604:web:7a44796fce1e024652a879",
            measurementId: "G-5LLJK0DRHW"));
  } else {
    await Firebase.initializeApp();
  }
}
