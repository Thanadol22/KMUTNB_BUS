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

  Timer? _timer;
  bool _isRunning = false;
  String? _busId;

  /// เก็บ set ของ notification ที่ส่งไปแล้ว เพื่อไม่ให้ส่งซ้ำ
  /// format: "round_01_15min" หรือ "round_01_depart"
  final Set<String> _sentNotifications = {};

  /// วันที่ล่าสุดที่ reset (เพื่อ reset ทุกวัน)
  int _lastResetDay = -1;

  bool get isRunning => _isRunning;

  /// เริ่มตรวจสอบตารางเดินรถ ทุกๆ 30 วินาที
  Future<void> start() async {
    if (_isRunning) return;

    // โหลด busId ของคนขับ
    await _loadBusId();

    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkSchedules();
    });

    // เช็ครอบแรกทันที
    _checkSchedules();
    debugPrint('[DriverScheduleNotifier] Started monitoring schedules');
  }

  /// หยุดการตรวจสอบ
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('[DriverScheduleNotifier] Stopped monitoring schedules');
  }

  /// รีเซ็ตรายการที่ส่งไปแล้ว (สำหรับวันใหม่)
  void resetSentNotifications() {
    _sentNotifications.clear();
    debugPrint('[DriverScheduleNotifier] Reset sent notifications');
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

  Future<void> _checkSchedules() async {
    final now = DateTime.now();

    // รีเซ็ตทุกวันใหม่
    if (_lastResetDay != now.day) {
      _sentNotifications.clear();
      _lastResetDay = now.day;
    }

    try {
      List<QueryDocumentSnapshot> docs;

      if (_busId != null) {
        // ดึง schedules ของรถคันนี้
        final snapshot = await FirebaseFirestore.instance
            .collection('schedules')
            .where('bus_id', isEqualTo: _busId)
            .get();
        docs = snapshot.docs;

        // ถ้าไม่มีเฉพาะคัน ให้ดึงทั้งหมด
        if (docs.isEmpty) {
          final allSnapshot = await FirebaseFirestore.instance
              .collection('schedules')
              .get();
          docs = allSnapshot.docs;
        }
      } else {
        final allSnapshot = await FirebaseFirestore.instance
            .collection('schedules')
            .get();
        docs = allSnapshot.docs;
      }

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startTime = data['start_time'] as String?;
        if (startTime == null) continue;

        final parts = startTime.split(':');
        if (parts.length != 2) continue;

        final targetHour = int.tryParse(parts[0]);
        final targetMinute = int.tryParse(parts[1]);
        if (targetHour == null || targetMinute == null) continue;

        final target = DateTime(
          now.year,
          now.month,
          now.day,
          targetHour,
          targetMinute,
        );
        final diff = target.difference(now);
        final diffMinutes = diff.inSeconds / 60.0; // ใช้ทศนิยมเพื่อความแม่นยำ

        final routeName = data['route_name'] ?? '';
        final endTime = data['end_time'] ?? '';
        final scheduleKey = doc.id;

        // ======= แจ้งเตือนก่อน 15 นาที =======
        // ช่วง 14.0 - 15.5 นาทีก่อนออกรถ (window 1.5 นาที เพื่อความชัวร์ในการเช็คทุก 30 วิ)
        final fifteenMinKey = '${scheduleKey}_15min';
        if (diffMinutes >= 14.0 &&
            diffMinutes <= 15.5 &&
            !_sentNotifications.contains(fifteenMinKey)) {
          _sentNotifications.add(fifteenMinKey);
          NotificationService().showLocalNotification(
            '⏰ อีก 15 นาทีถึงรอบรถ!',
            'รอบ $startTime - $endTime ($routeName)\nเตรียมตัวออกรถได้เลย!',
          );
          debugPrint(
            '[DriverScheduleNotifier] 15-min notification sent for $startTime',
          );
        }

        // ======= แจ้งเตือนเมื่อถึงเวลาออกรถ =======
        // ช่วง -0.5 ถึง 0.5 นาที (window 1 นาที)
        final departKey = '${scheduleKey}_depart';
        if (diffMinutes >= -0.5 &&
            diffMinutes <= 0.5 &&
            !_sentNotifications.contains(departKey)) {
          _sentNotifications.add(departKey);
          NotificationService().showLocalNotification(
            '🚌 ถึงเวลาออกรถแล้ว!',
            'รอบ $startTime - $endTime ($routeName)\nออกรถได้เลย!',
          );
          debugPrint(
            '[DriverScheduleNotifier] Departure notification sent for $startTime',
          );
        }
      }
    } catch (e) {
      debugPrint('[DriverScheduleNotifier] Error checking schedules: $e');
    }
  }

  /// ดูรายการ notification ที่ส่งไปแล้ว (debug)
  Set<String> get sentNotifications => Set.unmodifiable(_sentNotifications);
}
