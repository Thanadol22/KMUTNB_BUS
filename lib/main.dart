import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/localization_provider.dart';
import 'core/services/notification_service.dart';
// import 'package:firebase_core/firebase_core.dart'; // เตรียมไว้เมื่อเชื่อม Firebase
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(); // คอมเมนต์ไว้ก่อน รอเชื่อมต่อฐานข้อมูล

  // เรียกใช้งานระบบจำลองแจ้งเตือน (และเตรียม Firebase Messaging ให้พร้อม)
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: DevicePreview(
        enabled: true, // เปิดใช้งาน Device Preview
        builder: (context) => const BusTrackerApp(),
      ),
    ),
  );
}
