import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/localization_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Warning: Could not load .env file: $e");
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }

    // ไม่ให้ NotificationService บล็อกการรันแอป ถ้ารอฟรีสัพพลายเออร์นานไป
    NotificationService().init().catchError((e) {
      debugPrint("NotificationService init error: $e");
    });

    // Auto-seed ข้อมูลเบื้องต้นใน Backgroundพื้นฐาน
    DatabaseService().seedSchedules().catchError((e) {
      debugPrint("Error seeding schedules: $e");
    });
    DatabaseService().seedLocations().catchError((e) {
      debugPrint("Error seeding locations: $e");
    });

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ],
        child: const BusTrackerApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint("Initialization error: $e\n$stackTrace");
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "App Initialization Failed:\n\n$e\n\n$stackTrace",
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
