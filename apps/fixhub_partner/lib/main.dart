import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage (used for tokens & user data)
  await Hive.initFlutter();
  await dotenv.load(fileName: ".env");

  // Firebase — wrapped so the app still launches if config is broken
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  final container = ProviderContainer();

  try {
    await FcmService.initLocalNotifications();
    await container.read(fcmServiceProvider).initListeners();
  } catch (e) {
    debugPrint('FCM init failed: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
