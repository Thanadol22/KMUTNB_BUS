// ไฟล์นี้ถูกปลดประจำการแล้ว (Deprecated)
// ระบบแจ้งเตือนคนขับถูกย้ายไปใช้ FCM Push Notification จากฝั่ง Server (PHP)
// ดูรายละเอียดที่ fcm_notification_workflow.md
//
// ไฟล์นี้ถูกเก็บไว้เพื่อไม่ให้ import ที่อ้างอิงอยู่แตก
// สามารถลบได้เมื่อ remove import ออกจากไฟล์อื่นทั้งหมด

class DriverScheduleNotifier {
  static final DriverScheduleNotifier _instance =
      DriverScheduleNotifier._internal();
  factory DriverScheduleNotifier() => _instance;
  DriverScheduleNotifier._internal();

  bool get isRunning => false;

  Future<void> start() async {
    // No-op: ระบบแจ้งเตือนถูกย้ายไป Server-side FCM แล้ว
  }

  void stop() {
    // No-op
  }
}
