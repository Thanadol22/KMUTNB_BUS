import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// ต้องอยู่ระดับ top-level (นอกคลาส) เพื่อให้ทำงานตอนแอปปิดได้
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // บังคับ Initialize Firebase เพื่อให้การรับข้อความจาก Background ทำงานได้สมบูรณ์
  await Firebase.initializeApp();
  log("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. ตั้งค่า Background Handler สำหรับตอนปิดแอป (Terminated) หรือพับจอ (Background)
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 2. ขอสิทธิ์แจ้งเตือน
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      log('User granted permission: ${settings.authorizationStatus}');

      // 3. ดึง FCM Token และบันทึกลง Firestore
      String? token = await messaging.getToken();
      log("FCM Token: $token");
      if (token != null) {
        await _saveFcmTokenToFirestore(token);
      }

      // 4. เมื่อ Token ถูก Refresh (เช่น หลัง reinstall, clear data) ให้อัปเดตอัตโนมัติ
      messaging.onTokenRefresh.listen((newToken) {
        log("FCM Token Refreshed: $newToken");
        _saveFcmTokenToFirestore(newToken);
      });

      // 5. รับข้อความตอนที่แอปเปิดใช้งานอยู่ (Foreground) → แสดงเป็น Local Notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Got a message whilst in the foreground!');
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                importance: Importance.max,
                icon: '@drawable/ic_notification',
                color: Color(0xFFFFFFFF),
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });
    } catch (e) {
      log('Firebase Messaging ยังไม่ได้ถูกตั้งค่า (รอเชื่อม Database): $e');
    }

    // ตั้งค่า Local Notifications Plugin (ใช้แสดง Foreground notification)
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log("Notification clicked with payload: ${response.payload}");
        // TODO: นำทางเมื่อกดแจ้งเตือน
      },
    );

    // ขอสิทธิ์ Notification สำหรับ Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();

      // ขอสิทธิ์ Unrestricted Battery เพื่อไม่ให้ OS ลบ Notification ตอนปัดแอปทิ้ง
      final isBatteryOptimizationIgnored =
          await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isBatteryOptimizationIgnored) {
        log('Requesting ignoreBatteryOptimizations permission...');
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  /// บันทึก FCM Token ลง Firestore ที่ users/{uid}/fcm_token
  /// เพื่อให้ Server (PHP) สามารถดึง token ไปยิง Push Notification ได้
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null || uid.isEmpty) {
        log('Cannot save FCM token: No user logged in');
        return;
      }

      // Check role from SharedPreferences or Firestore to decide if we should skip saving
      String? role = prefs.getString('role');
      if (role == null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          role = doc.data()?['role'];
        }
      }

      // Removed the role check that skips FCM token save

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcm_token': token,
      });
      log('FCM Token saved to Firestore for user: $uid');
    } catch (e) {
      log('Error saving FCM token to Firestore: $e');
    }
  }

  /// แสดง Local Notification ทันที (ใช้ทดสอบ)
  Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'local_test_channel',
          'Local Testing',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: Color(0xFFFFFFFF),
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}
