import '../../models/bus_model.dart';

class MockData {
  static List<BusModel> buses = [
    BusModel(
      id: 'b1',
      driverName: 'สมชาย รักดี',
      driverPhone: '081-234-5678',
      licensePlate: 'กข 1234 ปราจีนบุรี',
      latitude: 14.163200, // ขยับให้อยู่ใกล้กับ 14.163687 ในวิทยาเขตปราจีนบุรี
      longitude: 101.362500, // ขยับให้อยู่ใกล้กับ 101.3628841 ในวิทยาเขตปราจีนบุรี
      status: 'กำลังวิ่ง',
      eta: '3 นาที',
    ),
    BusModel(
      id: 'b2',
      driverName: 'สมปอง ยินดี',
      driverPhone: '089-876-5432',
      licensePlate: 'ขค 5678 ปราจีนบุรี',
      latitude: 14.164100, // ขยับให้อยู่ใกล้จุดเริ่มต้น ใน มจพ. ปราจีนบุรี
      longitude: 101.363100,
      status: 'รับส่งตรงป้าย',
      eta: '5 นาที',
    ),
  ];

  static List<Map<String, String>> schedules = [
    {'time': '07:30', 'route': 'วงเวียนใหญ่ - หน้ามหาลัย', 'status': 'ออกเดินทางแล้ว'},
    {'time': '08:00', 'route': 'หอพัก - คณะวิศวะ', 'status': 'กำลังออกรถ'},
    {'time': '08:30', 'route': 'หน้ามหาลัย - หอพัก', 'status': 'รอออกเดินทาง'},
    {'time': '09:00', 'route': 'หน้ามหาลัย - หอพัก', 'status': 'รอออกเดินทาง'},
  ];
}
