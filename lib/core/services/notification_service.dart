import 'dart:developer';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart'; // เพิ่มกลับมา
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

// ต้องอยู่ระดับ top-level (นอกคลาส) เพื่อให้ทำงานตอนแอปปิดได้
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // บังคับ Initialize Firebase เพื่อให้การรับข้อความจาก Background ทำงานได้สมบูรณ์
  await Firebase.initializeApp();

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
    // กำหนด Timezone พื้นฐานสำหรับระบบ Scheduling
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

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

    // Explicitly request permissions for Local Notifications on Android 13+ and Exact Alarms on 12+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
      
      // ขอสิทธิ์ Unrestricted Battery บน Android เพื่อไม่ให้ OS ลบ Scheduled Notification ตอนปัดแอปทิ้ง
      final isBatteryOptimizationIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isBatteryOptimizationIgnored) {
        log('Requesting ignoreBatteryOptimizations permission...');
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
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

  // ยกเลิกการแจังเตือนทั้งหมดที่ถูกตั้งเวลาไว้
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    log("All scheduled notifications have been cancelled.");
  }

  // ฟังก์ชันจองการแจ้งเตือนเวลาล่วงหน้า
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: Color(0xFFFFFFFF),
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    log("Scheduled notification id: $id at $tzScheduledDate");
  }

}
