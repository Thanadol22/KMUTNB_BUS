/// ข้อมูลตารางเดินรถสองแถว มจพ. วิทยาเขตปราจีนบุรี
/// อ้างอิงจากตารางเวลาอย่างเป็นทางการ
class ScheduleData {
  /// ชื่อจุดจอดทั้งหมด (7 จุด)
  static const List<String> stopNames = [
    'หอพักนักศึกษา',
    'หน้ามหาวิทยาลัย',
    'คณะบริหารธุรกิจฯ',
    'คณะอุตสาหกรรมเกษตร',
    'อาคารบริหาร',
    'คณะเทคโนฯ',
    'คณะวิศวะฯ',
  ];

  /// ชื่อจุดจอดแบบย่อ (ใช้ใน header ตาราง)
  static const List<String> stopNamesShort = [
    'หอพักฯ',
    'หน้า ม.',
    'บริหารฯ',
    'อุตฯ',
    'อาคาร',
    'เทคโนฯ',
    'วิศวะฯ',
  ];

  /// Offset เวลา (นาที) ของแต่ละจุดจอดจากจุดเริ่มต้น
  static const List<int> stopOffsets = [0, 10, 12, 17, 18, 22, 25];

  /// ชื่อเส้นทาง
  static const String routeName = 'สายสองแถว มจพ. ปราจีนบุรี';

  /// เวลาเริ่มต้นของแต่ละรอบ (รอบที่ 1-21)
  static const List<String> roundStartTimes = [
    '08:00', // รอบ 1
    '08:20', // รอบ 2
    '08:40', // รอบ 3
    '09:00', // รอบ 4
    '09:30', // รอบ 5
    '10:00', // รอบ 6
    '11:00', // รอบ 7
    '11:30', // รอบ 8
    '12:00', // รอบ 9
    '12:30', // รอบ 10
    '13:00', // รอบ 11
    '13:30', // รอบ 12
    '14:30', // รอบ 13
    '15:00', // รอบ 14
    '15:30', // รอบ 15
    '16:00', // รอบ 16
    '16:30', // รอบ 17
    '17:30', // รอบ 18
    '18:30', // รอบ 19
    '19:00', // รอบ 20
    '19:30', // รอบ 21
  ];

  /// เวลาสิ้นสุดของแต่ละรอบ (start + 25 นาที)
  static const List<String> roundEndTimes = [
    '08:25', '08:45', '09:05', '09:25', '09:55', '10:25',
    '11:25', '11:55', '12:25', '12:55', '13:25', '13:55',
    '14:55', '15:25', '15:55', '16:25', '16:55', '17:55',
    '18:55', '19:25', '19:55',
  ];

  /// ข้อมูลผู้รับผิดชอบ
  static const List<Map<String, String>> drivers = [
    {'name': 'นายสมทบ งามวาจา (ลุงเอ)', 'phone': '086-0542759'},
    {'name': 'นายณรงค์ชัย ทองประดับ (ลุงไจ้)', 'phone': '092-9379983'},
  ];

  /// คำนวณเวลาที่รถถึงแต่ละจุดจอดสำหรับรอบที่กำหนด
  static List<String> getStopTimes(int roundIndex) {
    final startParts = roundStartTimes[roundIndex].split(':');
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);

    return stopOffsets.map((offset) {
      int totalMinutes = startHour * 60 + startMinute + offset;
      int hour = totalMinutes ~/ 60;
      int minute = totalMinutes % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }).toList();
  }

  /// หารอบที่ใกล้เคียงกับเวลาปัจจุบันมากที่สุด
  /// คืนค่า index ของรอบ (0-based) หรือ -1 ถ้าไม่มีรอบ
  static int findNearestRound(DateTime now) {
    final nowMinutes = now.hour * 60 + now.minute;

    // หารอบที่กำลังวิ่งอยู่ หรือรอบถัดไป
    int bestIndex = -1;
    int bestDiff = 999999;

    for (int i = 0; i < roundStartTimes.length; i++) {
      final parts = roundStartTimes[i].split(':');
      final roundMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

      // ใช้เวลาเริ่มต้นรอบ
      int diff = (roundMinutes - nowMinutes).abs();

      // ให้ความสำคัญกับรอบที่กำลังวิ่ง (เวลาปัจจุบันอยู่ระหว่าง start - end)
      final endParts = roundEndTimes[i].split(':');
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (nowMinutes >= roundMinutes && nowMinutes <= endMinutes) {
        return i; // รอบปัจจุบันที่กำลังวิ่ง
      }

      // ถ้ายังไม่ถึงรอบนี้ (ในอนาคต)
      if (roundMinutes > nowMinutes) {
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIndex = i;
        }
      }
    }

    // ถ้าไม่พบรอบในอนาคต ให้ใช้รอบสุดท้ายที่ผ่านไป
    if (bestIndex == -1) {
      for (int i = roundStartTimes.length - 1; i >= 0; i--) {
        final parts = roundStartTimes[i].split(':');
        final roundMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        if (roundMinutes <= nowMinutes) {
          return i;
        }
      }
      return 0;
    }

    return bestIndex;
  }

  /// หารอบใกล้เคียง (ก่อน + หลัง) สำหรับ dropdown
  /// คืน list ของ index ที่ใกล้เคียง (ย้อนหลัง 1 รอบ, ล่วงหน้า 2 รอบ)
  static List<int> getNearbyRounds(DateTime now) {
    final nearest = findNearestRound(now);
    final List<int> nearby = [];

    for (int i = nearest - 1; i <= nearest + 2; i++) {
      if (i >= 0 && i < roundStartTimes.length) {
        nearby.add(i);
      }
    }

    return nearby;
  }
}
