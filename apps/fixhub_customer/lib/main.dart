import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'features/notifications/data/datasources/fcm_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase — wrapped so the app still launches if config is broken
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Initialize Hive for local storage (used for tokens & user data)
  await Hive.initFlutter();
  await dotenv.load(fileName: ".env");

  final container = ProviderContainer();

  // Initialize local notifications (no network)
  try {
    await FCMService.initLocalNotifications();
  } catch (e) {
    debugPrint('Local notifications init failed: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FixHubApp(),
    ),
  );
}

