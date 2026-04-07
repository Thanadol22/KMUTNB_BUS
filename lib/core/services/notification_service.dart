import 'dart:developer';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ต้องอยู่ระดับ top-level (นอกคลาส) เพื่อให้ทำงานตอนแอปปิดได้
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ไม่บังคับต้อง Initialize Firebase ถ้าเราไม่ได้ใช้งาน Service อื่นๆ ของ Firebase ในนี้
  // ถ้ายกเลิกคอมเมนต์ต้องมั่นใจว่าเชื่อมต่อ Firebase เรียบร้อยแล้ว
  // await Firebase.initializeApp();

  log("Handling a background message: ${message.messageId}");
  // TODO: เตรียมสำหรับการอัปเดตข้อมูลสถิติหรือฐานข้อมูลเวลาแอปทำงานเบื้องหลัง
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

      // 3. เตรียมคว้ารับ Token เพื่อไว้เก็บในฐานข้อมูล (ให้ Server รู้ว่าต้องส่งหาใคร)
      String? token = await messaging.getToken();
      log("FCM Token: $token");

      messaging.onTokenRefresh.listen((newToken) {
        log("FCM Token Refreshed: $newToken");
      });

      // 4. รับข้อความตอนที่แอปเปิดใช้งานอยู่ (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Got a message whilst in the foreground!');
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          // แสดงเป็น Pop-up ทันทีเมื่อแอปเปิดอยู่
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
                color: const Color(0xFFFFFFFF),
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });
    } catch (e) {
      log('Firebase Messaging ยังไม่ได้ถูกตั้งค่า (รอเชื่อม Database): $e');
    }

    // 5. ตั้งค่า Local Notification สำหรับการแสดงแจ้งเตือนตอนเปิดแอป (Foreground / จำลอง)
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
  }

  // ฟังก์ชันจำลองการแจ้งเตือนแบบ Local (ไว้ใช้ทดสอบการทำงานของ Local Notification)
  Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'local_test_channel',
          'Local Testing',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: const Color(0xFFFFFFFF),
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
