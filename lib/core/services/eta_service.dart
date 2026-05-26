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

    if (orderedStops.isEmpty) {
      return RouteEtaResult(
        round: roundText,
        currentStop: '-',
        nextStop: 'รอข้อมูลป้ายรถ',
        etaText: '-',
        etaAbsolute: '',
      );
    }

    // --- ขั้นตอนที่ 2: หาป้ายที่อยู่ใกล้รถที่สุด (Nearest Stop) ---
    int nearestIdx = 0;
    double nearestDist = double.infinity;

    for (int i = 0; i < orderedStops.length; i++) {
      final double dist = haversine(
        busLat, busLng,
        orderedStops[i].lat, orderedStops[i].lng
      );
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }

    // --- ขั้นตอนที่ 3: กำหนดป้ายถัดไปตามสูตรและสถานะ Geofence ของรถ ---
    int nextStopIdx;

    if (nearestDist <= atStopThresholdM) {
      // รถจอดอยู่ที่สถานีแล้ว -> เป้าหมายถัดไปคือสถานีข้างหน้า
      nextStopIdx = nearestIdx + 1;
    } else {
      // อยู่ระหว่างเดินทาง -> เช็คว่าผ่านป้ายใกล้สุดไปหรือยัง
      if (nearestIdx + 1 < orderedStops.length) {
        final double distToNext = haversine(
          busLat, busLng,
          orderedStops[nearestIdx + 1].lat, orderedStops[nearestIdx + 1].lng
        );
        final double distBetween = haversine(
          orderedStops[nearestIdx].lat, orderedStops[nearestIdx].lng,
          orderedStops[nearestIdx + 1].lat, orderedStops[nearestIdx + 1].lng
        );

        if (distToNext < distBetween) {
          nextStopIdx = nearestIdx + 1; // วิ่งเลยป้ายใกล้สุดมาแล้ว
        } else {
          nextStopIdx = nearestIdx; // กำลังวิ่งไปหาป้ายใกล้สุด
        }
      } else {
        nextStopIdx = nearestIdx;
      }
    }

    // --- ขั้นตอนที่ 4: บังคับเส้นทางไม่ให้วิ่งย้อนกลับ (Sequence Enforcement) ร่วมกับข้อมูลจาก Daemon ---
    if (lastVisitedStopName != null && lastVisitedTimestampMs != null) {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      // มีผลเฉพาะข้อมูลที่เข้าป้ายที่อัปเดตไม่เกิน 30 นาที
      if ((nowMs - lastVisitedTimestampMs) < 30 * 60 * 1000) {
        final int lastIdx = orderedStops.indexWhere((s) => s.name == lastVisitedStopName);
        if (lastIdx != -1 && nextStopIdx <= lastIdx) {
          nextStopIdx = lastIdx + 1; // บังคับข้ามไปป้ายถัดไปจากป้ายที่พึ่งจอดแล้วจริง
        }
      }
    }

    // --- ขั้นตอนที่ 5: เช็คกรณีเลยป้ายสุดท้าย (ครบรอบเดินรถ) ---
    if (nextStopIdx >= orderedStops.length) {
      return RouteEtaResult(
        round: roundText,
        currentStop: orderedStops[nearestIdx].name,
        nextStop: 'ครบรอบแล้ว',
        etaText: '-',
        etaAbsolute: '',
      );
    }

    final BusStop targetStop = orderedStops[nextStopIdx];

    // --- กำหนดชื่อป้ายปัจจุบัน ---
    String currentStopResult;
    if (nearestDist <= atStopThresholdM) {
      currentStopResult = orderedStops[nearestIdx].name;
    } else {
      if (nextStopIdx == nearestIdx) {
        currentStopResult = locale == 'th' ? 'กำลังไป ${orderedStops[nearestIdx].name}' : 'Going to ${orderedStops[nearestIdx].name}';
      } else {
        currentStopResult = locale == 'th' 
          ? 'ระหว่าง ${orderedStops[nearestIdx].name} กับ ${orderedStops[nextStopIdx].name}' 
          : 'Between ${orderedStops[nearestIdx].name} and ${orderedStops[nextStopIdx].name}';
      }
    }

    // --- ขั้นตอนที่ 6: คำนวณระยะทางตามแนวถนน (Route Distance) ---
    double routeDistance = 0.0;
    if (nextStopIdx == nearestIdx) {
      routeDistance = nearestDist;
    } else {
      routeDistance = nearestDist;
      for (int i = nearestIdx; i < nextStopIdx; i++) {
        routeDistance += haversine(
          orderedStops[i].lat, orderedStops[i].lng,
          orderedStops[i + 1].lat, orderedStops[i + 1].lng
        );
      }
    }

    // คูณด้วยสัมประสิทธิ์ถนนคดเคี้ยว
    routeDistance = routeDistance * roadFactor;

    // --- ขั้นตอนที่ 7: คำนวณ ETA ---
    if (routeDistance <= atStopThresholdM) {
      return RouteEtaResult(
        round: roundText,
        currentStop: currentStopResult,
        nextStop: targetStop.name,
        etaText: locale == 'th' ? 'กำลังถึงป้าย' : 'Arriving',
        etaAbsolute: '',
      );
    }

    // คัดเลือกความเร็วใช้งาน
    final double activeSpeedKmh = (speedKmh > movingThresholdKmh)
        ? speedKmh
        : fallbackSpeedKmh;

    // แปลงความเร็วเป็น เมตร/วินาที
    final double speedMs = activeSpeedKmh * (1000.0 / 3600.0);
    final double etaSeconds = routeDistance / speedMs;

    // หาเวลาสัมบูรณ์ (Absolute Time) ที่จะถึง
    final DateTime arrivalTime = DateTime.now().add(Duration(seconds: etaSeconds.round()));
    final String padH = arrivalTime.hour.toString().padLeft(2, '0');
    final String padM = arrivalTime.minute.toString().padLeft(2, '0');
    final String timeStr = locale == 'th' ? "$padH:$padM น." : "$padH:$padM";

    // ฟอร์แมตข้อความแสดงผล
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
