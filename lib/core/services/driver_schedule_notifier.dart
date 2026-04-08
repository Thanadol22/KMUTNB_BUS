import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'firebase_database.dart';
import 'firebase_auth.dart';

/// บริการแจ้งเตือนคนขับก่อนถึงรอบรถ
/// - แจ้งเตือน 1 ครั้ง ก่อนถึง 15 นาที
/// - แจ้งเตือน 1 ครั้ง เมื่อถึงเวลาออกรถ
class DriverScheduleNotifier {
  static final DriverScheduleNotifier _instance =
      DriverScheduleNotifier._internal();
  factory DriverScheduleNotifier() => _instance;
  DriverScheduleNotifier._internal();

  StreamSubscription<QuerySnapshot>? _scheduleSubscription;
  bool _isRunning = false;
  String? _busId;

  bool get isRunning => _isRunning;

  /// เริ่มตรวจสอบตารางเดินรถ และสั่งจองการแจ้งเตือนล่วงหน้า
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // โหลด busId ของคนขับ
    await _loadBusId();

    Query query = FirebaseFirestore.instance.collection('schedules');
    if (_busId != null) {
      query = query.where('bus_id', isEqualTo: _busId);
    }
    
    // ฟังการเปลี่ยนแปลงตารางเดินรถแบบ Real-time
    _scheduleSubscription = query.snapshots().listen((snapshot) {
      _scheduleUpcomingNotifications(snapshot.docs);
    });

    debugPrint('[DriverScheduleNotifier] Started tracking schedules via stream');
  }

  /// หยุดการตรวจสอบ
  void stop() {
    _scheduleSubscription?.cancel();
    _scheduleSubscription = null;
    _isRunning = false;
    debugPrint('[DriverScheduleNotifier] Stopped tracking schedules');
  }

  Future<void> _loadBusId() async {
    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) return;

      final busQuery = await DatabaseService().getBusForDriver(uid);
      if (busQuery != null && busQuery.docs.isNotEmpty) {
        final busDoc = busQuery.docs.first;
        final busData = busDoc.data() as Map<String, dynamic>;
        _busId = busData['bus_id'] ?? busDoc.id;
        debugPrint('[DriverScheduleNotifier] Bus ID loaded: $_busId');
      }
    } catch (e) {
      debugPrint('[DriverScheduleNotifier] Error loading bus ID: $e');
    }
  }

  Future<void> _scheduleUpcomingNotifications(List<QueryDocumentSnapshot> docs) async {
    final now = DateTime.now();

    try {
      // ยกเลิกข้อความเก่าทั้งหมดเพื่อตั้งเวลาใหม่ตามข้อมูลล่าสุด
      await NotificationService().cancelAllNotifications();

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startTime = data['start_time'] as String?;
        if (startTime == null) continue;

        final parts = startTime.split(':');
        if (parts.length != 2) continue;

        final targetHour = int.tryParse(parts[0]);
        final targetMinute = int.tryParse(parts[1]);
        if (targetHour == null || targetMinute == null) continue;

        DateTime target = DateTime(
          now.year,
          now.month,
          now.day,
          targetHour,
          targetMinute,
        );

        // ถ้าเวลาเป้าหมาย (เช่น ออกรถ 08:00) ผ่านไปแล้วของวันนี้
        // ให้เลื่อนไปเป็น 08:00 ของวันพรุ่งนี้แทน เพื่อให้การแจ้งเตือนทำงานในวันถัดไปเมื่อปิดแอป
        if (target.isBefore(now)) {
          target = target.add(const Duration(days: 1));
        }

        final routeName = data['route_name'] ?? '';
        final endTime = data['end_time'] ?? '';
        final scheduleKey = doc.id;

        // ======= แจ้งเตือนก่อน 15 นาที =======
        final fifteenMinTarget = target.subtract(const Duration(minutes: 15));
        if (fifteenMinTarget.isAfter(now)) {
            final int id15 = '${scheduleKey}_15min'.hashCode;
            NotificationService().scheduleNotification(
              id: id15,
              title: '⏰ อีก 15 นาทีถึงรอบรถ!',
              body: 'รอบ $startTime - $endTime ($routeName)\nเตรียมตัวออกรถได้เลย!',
              scheduledDate: fifteenMinTarget,
            );
        }

        // ======= แจ้งเตือนเมื่อถึงเวลาออกรถ =======
        if (target.isAfter(now)) {
            final int idDepart = '${scheduleKey}_depart'.hashCode;
            NotificationService().scheduleNotification(
              id: idDepart,
              title: '🚌 ถึงเวลาออกรถแล้ว!',
              body: 'รอบ $startTime - $endTime ($routeName)\nออกรถได้เลย!',
              scheduledDate: target,
            );
        }
      }
    } catch (e) {
      debugPrint('[DriverScheduleNotifier] Error scheduling notifications: $e');
    }
  }
}
