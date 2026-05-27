import 'dart:math';
import '../../models/location_model.dart';

// ==================== ค่าคงที่ ====================

/// ความเร็วเฉลี่ยที่ใช้เมื่อรถหยุดหรือช้ามาก (km/h)
const double fallbackSpeedKmh = 20.0;

/// ตัวคูณชดเชยเพราะถนนไม่ใช่เส้นตรง (เส้นทางจริง ≈ เส้นตรง × 1.3)
const double roadFactor = 1.3;

/// ระยะ (เมตร) ที่ถือว่ารถถึงป้ายแล้ว
const double atStopThresholdM = 80.0;

/// ความเร็วขั้นต่ำ (km/h) ที่ถือว่ารถกำลังเคลื่อนที่
const double movingThresholdKmh = 3.0;

// ==================== Data Classes ====================

/// คลาสสำหรับเก็บข้อมูลพิกัดป้ายหยุดรถเมล์
class BusStop {
  final String id;
  final String name;
  final double lat;
  final double lng;

  BusStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });
}

/// ผลลัพธ์รวมทั้ง route info + ETA
class RouteEtaResult {
  final String round;
  final String currentStop;
  final String nextStop;

  /// ETA หลัก เช่น "~3 นาที" หรือ "กำลังถึงป้าย"
  final String etaText;

  /// เวลาถึงโดยประมาณ เช่น "(ถึง ~09:15 น.)" (อาจว่างถ้าไม่มีข้อมูล)
  final String etaAbsolute;

  RouteEtaResult({
    required this.round,
    required this.currentStop,
    required this.nextStop,
    required this.etaText,
    this.etaAbsolute = '',
  });

  Map<String, String> toMap() => {
        'round': round,
        'currentStop': currentStop,
        'nextStop': nextStop,
        'etaText': etaText,
        'etaAbsolute': etaAbsolute,
      };
}

// ==================== สูตร Haversine ====================

/// คำนวณระยะทาง (เมตร) ระหว่าง 2 จุดพิกัดบนพื้นโลก
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const double r = 6371000; // รัศมีโลก (เมตร)
  final double phi1 = lat1 * pi / 180;
  final double phi2 = lat2 * pi / 180;
  final double deltaPhi = (lat2 - lat1) * pi / 180;
  final double deltaLambda = (lon2 - lon1) * pi / 180;

  final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
      cos(phi1) * cos(phi2) *
      sin(deltaLambda / 2) * sin(deltaLambda / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return r * c; // ระยะทางจริงเป็นหน่วยเมตร
}

// ==================== ETA Service ====================

class EtaService {
  static final Map<String, int> _busNextStopIndices = {};
  static final Map<String, String> _busActiveRounds = {};

  /// ดึงลำดับป้ายจาก DB และแมปพิกัด
  static List<BusStop> buildOrderedStops(
    List<dynamic> scheduleStops,
    List<LocationModel> firestoreLocations,
  ) {
    final result = <BusStop>[];

    // คัดลอกและเรียงลำดับตามฟิลด์ order
    final sortedStops = List<Map<String, dynamic>>.from(
      scheduleStops.map((item) => Map<String, dynamic>.from(item as Map))
    );
    sortedStops.sort((a, b) => (a['order'] as num? ?? 0).compareTo(b['order'] as num? ?? 0));

    for (final stop in sortedStops) {
      final name = stop['name'] as String? ?? '';
      final locationId = stop['location_id'] as String? ?? '';
      double? lat = _toDouble(stop['lat']);
      double? lng = _toDouble(stop['lng']);

      // หากไม่มีพิกัดใน scheduleStops ให้หาจาก firestoreLocations
      if (lat == null || lng == null) {
        final matched = firestoreLocations.where((loc) => loc.id == locationId || loc.name == name).toList();
        if (matched.isNotEmpty) {
          lat = matched.first.lat;
          lng = matched.first.lng;
        } else {
          // ลองหาแบบ fuzzy match
          for (final loc in firestoreLocations) {
            if (loc.name.contains(name) || name.contains(loc.name)) {
              lat = loc.lat;
              lng = loc.lng;
              break;
            }
          }
        }
      }

      if (lat != null && lng != null) {
        result.add(BusStop(
          id: locationId,
          name: name,
          lat: lat,
          lng: lng,
        ));
      }
    }
    return result;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  /// ===== ฟังก์ชันหลัก: คำนวณ Route + ETA ทั้งหมด =====
  static RouteEtaResult compute({
    required String busId,
    required double busLat,
    required double busLng,
    required double speedKmh,
    required List<LocationModel> firestoreLocations,
    required Map<String, dynamic>? activeRound,
    required String boardDate,
    required String boardTime,
    String? lastVisitedStopName,
    int? lastVisitedTimestampMs,
    String locale = 'th',
  }) {
    // --- ตรวจสอบความสดใหม่ของข้อมูล (Staleness Check) ---
    bool isStale = false;
    try {
      final partsDate = boardDate.split('/');
      final partsTime = boardTime.split(':');
      if (partsDate.length == 3 && partsTime.length == 3) {
        int year = int.parse(partsDate[2]);
        if (year > 2500) year -= 543; // แปลงพ.ศ. เป็น ค.ศ.

        final boardDT = DateTime(
          year,
          int.parse(partsDate[1]),
          int.parse(partsDate[0]),
          int.parse(partsTime[0]),
          int.parse(partsTime[1]),
          int.parse(partsTime[2]),
        );
        final diff = DateTime.now().difference(boardDT).inMinutes;
        if (diff.abs() > 10) isStale = true;
      }
    } catch (_) {
      isStale = true;
    }

    if (activeRound == null || isStale) {
      return RouteEtaResult(
        round: isStale ? 'ข้อมูลไม่อัปเดต' : '-',
        currentStop: isStale ? 'GPS ขาดการติดต่อ' : 'นอกเวลาวิ่ง',
        nextStop: '-',
        etaText: '-',
        etaAbsolute: '',
      );
    }

    // --- ขั้นตอนที่ 1: ดึงลำดับป้ายจาก DB ---
    final List<dynamic> scheduleStops = activeRound['stops'] as List<dynamic>? ?? [];
    final orderedStops = buildOrderedStops(scheduleStops, firestoreLocations);

    final roundText = '${activeRound['start_time']} - ${activeRound['end_time']}';
    final String currentRoundId = activeRound['id']?.toString() ?? roundText;

    if (orderedStops.isEmpty) {
      return RouteEtaResult(
        round: roundText,
        currentStop: '-',
        nextStop: 'รอข้อมูลป้ายรถ',
        etaText: '-',
        etaAbsolute: '',
      );
    }

    // --- ตรวจจับการเปลี่ยนรอบ (Round Reset) ---
    if (_busActiveRounds[busId] != currentRoundId) {
      _busActiveRounds[busId] = currentRoundId;
      _busNextStopIndices[busId] = 0; // เริ่มต้นที่ป้ายแรกใหม่
    }

    int nextStopIdx = _busNextStopIndices[busId] ?? 0;

    // --- เช็คกรณีเลยป้ายสุดท้าย (ครบรอบเดินรถ) ---
    if (nextStopIdx >= orderedStops.length) {
      return RouteEtaResult(
        round: roundText,
        currentStop: orderedStops.last.name,
        nextStop: 'ครบรอบแล้ว',
        etaText: '-',
        etaAbsolute: '',
      );
    }

    // --- คำนวณระยะทางถึงป้ายเป้าหมาย (Next Stop) ---
    double distToNext = haversine(
      busLat, busLng,
      orderedStops[nextStopIdx].lat, orderedStops[nextStopIdx].lng
    );

    // --- บังคับเส้นทางด้วยข้อมูลจาก Daemon (Server Sync Fallback) ---
    // ใช้ข้อมูลจาก Node.js เผื่อแอปพลิเคชันมือถือพลาดการตรวจจับรัศมี 80 เมตร
    if (lastVisitedStopName != null && lastVisitedTimestampMs != null) {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      // มีผลเฉพาะข้อมูลที่เข้าป้ายที่อัปเดตไม่เกิน 30 นาที
      if ((nowMs - lastVisitedTimestampMs) < 30 * 60 * 1000) {
        final int lastIdx = orderedStops.indexWhere((s) => s.name == lastVisitedStopName);
        if (lastIdx != -1 && nextStopIdx <= lastIdx) {
          nextStopIdx = lastIdx + 1; // ขยับ Index ไปยังป้ายถัดไปจากที่ Daemon คอนเฟิร์ม
          _busNextStopIndices[busId] = nextStopIdx;
          
          if (nextStopIdx < orderedStops.length) {
             distToNext = haversine(
                busLat, busLng,
                orderedStops[nextStopIdx].lat, orderedStops[nextStopIdx].lng
             );
          }
        }
      }
    }

    // --- ตรรกะการเข้าถึงป้าย (Sequential Stop logic) ---
    if (distToNext <= atStopThresholdM) {
      // บันทึกว่าถึงแล้ว โดยการดันเป้าหมายไปเป็นป้ายถัดไป
      nextStopIdx++;
      _busNextStopIndices[busId] = nextStopIdx;

      if (nextStopIdx >= orderedStops.length) {
        return RouteEtaResult(
          round: roundText,
          currentStop: orderedStops.last.name,
          nextStop: 'ครบรอบแล้ว',
          etaText: '-',
          etaAbsolute: '',
        );
      }
      
      // เป้าหมายถัดไปเปลี่ยนไปแล้ว คำนวณระยะใหม่สำหรับป้ายหน้า
      distToNext = haversine(
        busLat, busLng,
        orderedStops[nextStopIdx].lat, orderedStops[nextStopIdx].lng
      );
    }

    final BusStop targetStop = orderedStops[nextStopIdx];

    // --- กำหนดชื่อป้ายปัจจุบัน (อ้างอิงจากป้ายที่เพิ่งผ่านมาหรือจุดเริ่มต้น) ---
    String currentStopResult;
    if (nextStopIdx == 0) {
      currentStopResult = locale == 'th' ? 'กำลังเริ่มไป ${targetStop.name}' : 'Starting to ${targetStop.name}';
    } else {
      final BusStop prevStop = orderedStops[nextStopIdx - 1];
      currentStopResult = locale == 'th' 
        ? 'ระหว่าง ${prevStop.name} กับ ${targetStop.name}' 
        : 'Between ${prevStop.name} and ${targetStop.name}';
    }

    // --- คำนวณระยะทางวิ่ง (ใช้ตรงเส้น + ชดเชย) ---
    double routeDistance = distToNext * roadFactor;

    // --- คำนวณ ETA ---
    if (routeDistance <= atStopThresholdM) {
      return RouteEtaResult(
        round: roundText,
        currentStop: targetStop.name, // ปรับให้แสดงชื่อเป้าหมายเป็นปัจจุบันเลย
        nextStop: targetStop.name,
        etaText: locale == 'th' ? 'กำลังถึงป้าย' : 'Arriving',
        etaAbsolute: '',
      );
    }

    final double activeSpeedKmh = (speedKmh > movingThresholdKmh)
        ? speedKmh
        : fallbackSpeedKmh;

    final double speedMs = activeSpeedKmh * (1000.0 / 3600.0);
    final double etaSeconds = routeDistance / speedMs;

    final DateTime arrivalTime = DateTime.now().add(Duration(seconds: etaSeconds.round()));
    final String padH = arrivalTime.hour.toString().padLeft(2, '0');
    final String padM = arrivalTime.minute.toString().padLeft(2, '0');
    final String timeStr = locale == 'th' ? "$padH:$padM น." : "$padH:$padM";

    String etaText;
    String etaAbsolute;
    if (etaSeconds < 60) {
      etaText = locale == 'th' ? '< 1 นาที' : '< 1 min';
      etaAbsolute = locale == 'th' ? 'ถึง ~$timeStr' : 'arrive ~$timeStr';
    } else {
      final int etaMinutes = (etaSeconds / 60.0).ceil();
      etaText = locale == 'th' ? '~$etaMinutes นาที' : '~$etaMinutes min';
      etaAbsolute = locale == 'th' ? 'ถึง ~$timeStr' : 'arrive ~$timeStr';
    }

    return RouteEtaResult(
      round: roundText,
      currentStop: currentStopResult,
      nextStop: targetStop.name,
      etaText: etaText,
      etaAbsolute: etaAbsolute,
    );
  }
}
