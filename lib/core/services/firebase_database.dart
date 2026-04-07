import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/schedule_model.dart';
import '../../models/ticket_report.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // ==================== RTDB: Bus Tracking ====================

  /// Stream ข้อมูล tracking รถทั้งหมดแบบ Realtime
  Stream<DatabaseEvent> getBusTrackingStream() {
    return _rtdb.ref('tracking').onValue;
  }

  /// อัปเดตสถานะรถใน RTDB tracking node
  Future<void> updateBusStatusInRTDB(String busId, String status) async {
    await _rtdb.ref('tracking/$busId/status').set(status);
    await _rtdb.ref('tracking/$busId/last_updated').set(
      ServerValue.timestamp,
    );
  }

  // ==================== Firestore: Users ====================

  /// ดึงข้อมูลคนขับจาก users collection
  Future<Map<String, dynamic>?> getDriverInfo(String driverId) async {
    try {
      final doc = await _firestore.collection('users').doc(driverId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== Firestore: Buses ====================

  /// ดึงข้อมูลรถจาก buses collection ทั้งหมด
  Future<Map<String, Map<String, dynamic>>> getAllBusesInfo() async {
    final snapshot = await _firestore.collection('buses').get();
    final Map<String, Map<String, dynamic>> busMap = {};
    for (var doc in snapshot.docs) {
      busMap[doc.id] = doc.data();
    }
    return busMap;
  }

  /// หารถของคนขับคนนั้น
  Future<QuerySnapshot?> getBusForDriver(String driverId) async {
    try {
      final query = await _firestore
          .collection('buses')
          .where('driver_id', isEqualTo: driverId)
          .limit(1)
          .get();
      return query;
    } catch (e) {
      return null;
    }
  }

  // ==================== Firestore: Schedules ====================

  /// Stream ตารางเดินรถทั้งหมด
  Stream<QuerySnapshot> getSchedulesStream() {
    return _firestore.collection('schedules').snapshots();
  }

  /// ดึง schedules สำหรับรถคันที่กำหนด
  Stream<QuerySnapshot> getSchedulesForBus(String busId) {
    return _firestore
        .collection('schedules')
        .where('bus_id', isEqualTo: busId)
        .snapshots();
  }

  /// ดึง schedules ทั้งหมดแบบ Future (ไม่ใช่ stream)
  Future<List<ScheduleModel>> getSchedulesList() async {
    final snapshot = await _firestore.collection('schedules').get();
    return snapshot.docs
        .map((doc) => ScheduleModel.fromFirestore(doc))
        .toList();
  }

  // ==================== Firestore: Ticket Reports ====================

  /// ส่งรายงานตั๋วโดยสาร
  Future<void> submitTicketReport(TicketReportModel report) async {
    await _firestore.collection('ticket_reports').add(report.toMap());
  }

  /// ดึงรายงานตั๋วของคนขับ
  Stream<QuerySnapshot> getTicketReportsForDriver(String driverId) {
    return _firestore
        .collection('ticket_reports')
        .where('driver_id', isEqualTo: driverId)
        .snapshots();
  }

  // ==================== Firestore: Seed Schedules ====================

  /// เพิ่มข้อมูลตารางเดินรถ 21 รอบเข้า Firestore (เรียกครั้งเดียว)
  Future<void> seedSchedules() async {
    // ตรวจสอบว่ามีข้อมูลแล้วหรือยัง
    final existing = await _firestore.collection('schedules').limit(1).get();
    if (existing.docs.isNotEmpty) {
      return; // มีข้อมูลอยู่แล้ว ไม่ต้อง seed
    }

    const startTimes = [
      '08:00', '08:20', '08:40', '09:00', '09:30', '10:00',
      '11:00', '11:30', '12:00', '12:30', '13:00', '13:30',
      '14:30', '15:00', '15:30', '16:00', '16:30', '17:30',
      '18:30', '19:00', '19:30',
    ];

    const endTimes = [
      '08:25', '08:45', '09:05', '09:25', '09:55', '10:25',
      '11:25', '11:55', '12:25', '12:55', '13:25', '13:55',
      '14:55', '15:25', '15:55', '16:25', '16:55', '17:55',
      '18:55', '19:25', '19:55',
    ];

    const routeName = 'สายสองแถว มจพ. ปราจีนบุรี';

    final batch = _firestore.batch();
    for (int i = 0; i < startTimes.length; i++) {
      final docRef = _firestore.collection('schedules').doc('round_${(i + 1).toString().padLeft(2, '0')}');
      batch.set(docRef, {
        'bus_id': 'bus_01',
        'start_time': startTimes[i],
        'end_time': endTimes[i],
        'route_name': routeName,
      });
    }

    await batch.commit();
  }
}

