// ค่าคงที่กลางของแอป KMUTNB Bus
// รวมข้อมูลที่เคย Hard Code ไว้หลายที่ให้มาอยู่ที่เดียว

class AppConstants {
  AppConstants._(); // ป้องกันสร้าง instance

  // ==================== สี Primary ====================
  /// สีหลักของแอป
  static const int primaryColorValue = 0xFFFF4009;

  // ==================== สถานะรถ (Bus Status) ====================
  /// สถานะทั้ง 4 ที่เก็บในฐานข้อมูล Firestore (buses collection)
  static const String statusReady = 'พร้อมบริการ';
  static const String statusStopped = 'หยุดบริการ';
  static const String statusMaintenance = 'ซ่อมบำรุง';
  static const String statusRefueling = 'เติมน้ำมัน';

  /// Mapping: status code (ใช้ใน UI) → ข้อความ (ใช้ใน DB)
  static const Map<String, String> statusCodeToText = {
    'status_ready': statusReady,
    'status_stop': statusStopped,
    'status_maintain': statusMaintenance,
    'status_fuel': statusRefueling,
  };

  /// Mapping กลับ: ข้อความ (จาก DB) → status code (ใช้ใน UI)
  static const Map<String, String> statusTextToCode = {
    statusReady: 'status_ready',
    statusStopped: 'status_stop',
    statusMaintenance: 'status_maintain',
    statusRefueling: 'status_fuel',
  };

  /// Default status code
  static const String defaultStatusCode = 'status_ready';

  // ==================== ประเภทรถ (Bus Types) ====================
  static const List<String> busTypeOptions = [
    'รถสองแถว',
    'รถบัส',
    'รถตู้',
    'รถอีวี',
    'มินิบัส',
  ];

  // ==================== Domain อีเมลที่อนุญาต ====================
  static const String studentEmailDomain = '@email.kmutnb.ac.th';
  static const List<String> teacherEmailDomains = [
    '@itm.kmutnb.ac.th',
    '@fitm.kmutnb.ac.th',
  ];

  /// ตรวจสอบว่าเป็นอีเมลนักศึกษาหรือไม่
  static bool isStudentEmail(String email) =>
      email.endsWith(studentEmailDomain);

  /// ตรวจสอบว่าเป็นอีเมลอาจารย์หรือไม่
  static bool isTeacherEmail(String email) =>
      teacherEmailDomains.any((domain) => email.endsWith(domain));

  /// ตรวจสอบว่าเป็นอีเมล KMUTNB ที่อนุญาตหรือไม่
  static bool isAllowedEmail(String email) =>
      isStudentEmail(email) || isTeacherEmail(email);

  // ==================== หัวข้อรายงานปัญหา ====================
  /// Mapping: issue code → ข้อความที่เก็บใน DB
  static const Map<String, String> reportTopics = {
    'late': 'รถไม่มาตรงเวลา',
    'driver': 'พฤติกรรมพนักงานขับรถ',
    'app': 'แอปพลิเคชันมีปัญหา',
    'other': 'อื่นๆ',
  };

  // ==================== ประเภทใบขับขี่ ====================
  static const List<String> licenseTypes = [
    'ส่วนบุคคล ชนิดที่ 2 (บ.2)',
    'ทุกประเภท ชนิดที่ 2 (ท.2)',
    'ส่วนบุคคล ชนิดที่ 3 (บ.3)',
    'ทุกประเภท ชนิดที่ 3 (ท.3)',
    'ส่วนบุคคล ชนิดที่ 4 (บ.4)',
    'ทุกประเภท ชนิดที่ 4 (ท.4)',
  ];
}
