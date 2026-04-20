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

// ==================== ลำดับป้ายในเส้นทาง ====================

/// ลำดับป้ายรถในเส้นทาง 1 รอบ (วงกลม)
/// - firestoreIds: document IDs ใน Firestore collection `locations` ที่ match กับป้ายนี้
///   (หอพักฯ มี 2 จุด: ชาย + หญิง ถ้าถึงจุดใดจุดหนึ่งถือว่าถึงป้าย)
const List<Map<String, dynamic>> busStopsSequence = [
  {
    'id': 'dorm',
    'name': 'หอพักฯ',
    'firestoreIds': ['loc_dorm_male', 'loc_dorm_female'],
  },
  {
    'id': 'front',
    'name': 'หน้า ม.',
    'firestoreIds': ['loc_uni_front'],
  },
  {
    'id': 'admin',
    'name': 'บริหารฯ',
    'firestoreIds': ['loc_faculty_bus'],
  },
  {
    'id': 'industry',
    'name': 'อุตฯ',
    'firestoreIds': ['loc_faculty_agri'],
  },
  {
    'id': 'building',
    'name': 'อาคาร',
    'firestoreIds': ['loc_building_adm'],
  },
  {
    'id': 'tech',
    'name': 'เทคโนฯ',
    'firestoreIds': ['loc_faculty_tech'],
  },
  {
    'id': 'eng',
    'name': 'วิศวะฯ',
    'firestoreIds': ['loc_faculty_eng'],
  },
];

// ==================== Data Classes ====================

/// ป้ายรถที่จับคู่กับพิกัดแล้ว
class StopWithCoords {
  final String id;
  final String name;

  /// พิกัดทั้งหมดที่เป็นไปได้สำหรับป้ายนี้ (หอพัก มี 2 จุด)
  final List<LatLngSimple> coordinates;

  StopWithCoords({
    required this.id,
    required this.name,
    required this.coordinates,
  });

  /// พิกัดหลัก (ตัวแรก) สำหรับคำนวณระยะทางระหว่างป้าย
  double get lat => coordinates.first.lat;
  double get lng => coordinates.first.lng;

  /// หาระยะทางที่ใกล้ที่สุดจากจุดที่กำหนดถึงป้ายนี้
  /// (ถ้ามีหลายพิกัด เช่น หอพักชาย/หญิง จะใช้จุดที่ใกล้ที่สุด)
  double distanceFrom(double lat, double lng) {
    double minDist = double.infinity;
    for (final coord in coordinates) {
      final d = haversine(lat, lng, coord.lat, coord.lng);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }
}

/// พิกัด lat/lng แบบเรียบง่าย (ไม่ต้องพึ่ง latlong2 package)
class LatLngSimple {
  final double lat;
  final double lng;

  const LatLngSimple(this.lat, this.lng);
}

/// ผลลัพธ์ ETA
class EtaResult {
  /// จำนวนนาทีถึง (null ถ้าเป็นกรณีพิเศษ)
  final int? etaMinutes;

  /// เวลาถึงจริง (null ถ้าเป็นกรณีพิเศษ)
  final DateTime? arrivalTime;

  /// ข้อความพิเศษ (เช่น "กำลังถึงป้าย", "ครบรอบแล้ว")
  final String? text;

  /// ใช้ fallback speed หรือไม่
  final bool usedFallbackSpeed;

  EtaResult({
    this.etaMinutes,
    this.arrivalTime,
    this.text,
    this.usedFallbackSpeed = false,
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
  const R = 6371000; // รัศมีโลก (เมตร)

  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final deltaPhi = (lat2 - lat1) * pi / 180;
  final deltaLambda = (lon2 - lon1) * pi / 180;

  final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
      cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c; // ระยะทาง (เมตร)
}

// ==================== ETA Service ====================

class EtaService {
  /// ขั้นตอนที่ 1: จับคู่ป้ายกับพิกัด GPS จาก Firestore locations
  static List<StopWithCoords> buildOrderedStops(
    List<LocationModel> firestoreLocations,
  ) {
    final result = <StopWithCoords>[];

    for (final stop in busStopsSequence) {
      final firestoreIds = List<String>.from(stop['firestoreIds'] as List);
      final coords = <LatLngSimple>[];

      for (final fId in firestoreIds) {
        // Match by Firestore document ID
        final matched = firestoreLocations
            .where((loc) => loc.id == fId)
            .toList();
        if (matched.isNotEmpty) {
          coords.add(LatLngSimple(matched.first.lat, matched.first.lng));
        }
      }

      // Fallback: ถ้า match by ID ไม่ได้ ลอง match by name (fuzzy)
      if (coords.isEmpty) {
        final stopName = stop['name'] as String;
        for (final loc in firestoreLocations) {
          if (loc.name == stopName ||
              loc.name.contains(stopName) ||
              stopName.contains(loc.name)) {
            coords.add(LatLngSimple(loc.lat, loc.lng));
            break;
          }
        }
      }

      if (coords.isNotEmpty) {
        result.add(StopWithCoords(
          id: stop['id'] as String,
          name: stop['name'] as String,
          coordinates: coords,
        ));
      }
    }

    return result;
  }

  /// ขั้นตอนที่ 2: หาป้ายที่ใกล้รถที่สุด (Nearest Stop)
  /// คืน (nearestIdx, nearestDist)
  static (int, double) findNearestStop(
    double busLat,
    double busLng,
    List<StopWithCoords> stops,
  ) {
    int nearestIdx = 0;
    double nearestDist = double.infinity;

    for (int i = 0; i < stops.length; i++) {
      final dist = stops[i].distanceFrom(busLat, busLng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }

    return (nearestIdx, nearestDist);
  }

  /// ขั้นตอนที่ 3: กำหนดป้ายถัดไป (Next Stop)
  /// คืน nextStopIdx (-1 ถ้าครบรอบ)
  static int determineNextStop(
    int nearestIdx,
    double nearestDist,
    List<StopWithCoords> stops,
    double busLat,
    double busLng,
  ) {
    // กรณี A: รถอยู่ที่ป้ายแล้ว (≤ 80m)
    if (nearestDist <= atStopThresholdM) {
      final nextIdx = nearestIdx + 1;
      // กรณี C: เลยป้ายสุดท้ายแล้ว
      if (nextIdx >= stops.length) return -1;
      return nextIdx;
    }

    // กรณี B: รถอยู่ระหว่างทาง (> 80m)
    if (nearestIdx + 1 < stops.length) {
      final distToNext = stops[nearestIdx + 1].distanceFrom(busLat, busLng);
      final distBetween = haversine(
        stops[nearestIdx].lat,
        stops[nearestIdx].lng,
        stops[nearestIdx + 1].lat,
        stops[nearestIdx + 1].lng,
      );

      if (distToNext < distBetween) {
        // รถผ่านป้ายใกล้สุดไปแล้ว → ป้ายถัดไป = nearestIdx + 1
        final nextIdx = nearestIdx + 1;
        if (nextIdx >= stops.length) return -1;
        return nextIdx;
      } else {
        // รถยังไม่ถึงป้ายใกล้สุด → ป้ายถัดไป = nearestIdx
        return nearestIdx;
      }
    }

    // ป้ายสุดท้ายแล้ว
    return -1;
  }

  /// ขั้นตอนที่ 4: คำนวณระยะทางตามเส้นทาง (× road factor)
  static double calculateRouteDistance(
    int nearestIdx,
    int nextStopIdx,
    double nearestDist,
    List<StopWithCoords> stops,
    double busLat,
    double busLng,
  ) {
    double routeDistance;

    if (nextStopIdx == nearestIdx) {
      // รถมุ่งไปป้ายเดียวกับที่ใกล้ที่สุด (ยังไม่ถึง)
      routeDistance = nearestDist;
    } else if (nextStopIdx == nearestIdx + 1) {
      // รถผ่านป้าย nearestIdx ไปแล้ว → ใช้ระยะตรงถึง nextStop
      routeDistance = stops[nextStopIdx].distanceFrom(busLat, busLng);
    } else {
      // ข้ามหลายป้าย: ระยะตรงจากรถถึง nearestIdx+1 + ป้ายที่เหลือ
      routeDistance = stops[nearestIdx + 1].distanceFrom(busLat, busLng);
      for (int i = nearestIdx + 1; i < nextStopIdx; i++) {
        routeDistance += haversine(
          stops[i].lat,
          stops[i].lng,
          stops[i + 1].lat,
          stops[i + 1].lng,
        );
      }
    }

    // คูณ road factor เพราะถนนไม่ใช่เส้นตรง
    return routeDistance * roadFactor; // × 1.3
  }

  /// ขั้นตอนที่ 5: คำนวณ ETA
  static EtaResult calculateEta(double routeDistanceM, double gpsSpeedKmh) {
    // ถ้าอยู่ใกล้ป้ายมาก → กำลังถึง
    if (routeDistanceM <= atStopThresholdM) {
      return EtaResult(text: 'กำลังถึงป้าย', arrivalTime: DateTime.now());
    }

    // เลือกความเร็ว
    final avgSpeedKmh = (gpsSpeedKmh > movingThresholdKmh)
        ? gpsSpeedKmh
        : fallbackSpeedKmh;

    // แปลง km/h → m/s
    final avgSpeedMs = avgSpeedKmh * (1000 / 3600);

    // คำนวณเวลา (วินาที)
    final etaSeconds = routeDistanceM / avgSpeedMs;
    final etaMinutes = (etaSeconds / 60).ceil();

    // คำนวณเวลาถึงจริง
    final arrivalTime =
        DateTime.now().add(Duration(seconds: etaSeconds.round()));

    return EtaResult(
      etaMinutes: etaMinutes,
      arrivalTime: arrivalTime,
      usedFallbackSpeed: gpsSpeedKmh <= movingThresholdKmh,
    );
  }

  /// ขั้นตอนที่ 6: แสดงผล ETA
  /// คืนค่า (relativeText, absoluteText)
  /// relativeText: เช่น "~3 นาที", "< 1 นาที", "กำลังถึงป้าย"
  /// absoluteText: เช่น "(ถึง ~09:15 น.)", "" (ว่างถ้าไม่มี)
  static (String, String) formatEta(EtaResult result, {String locale = 'th'}) {
    // ถ้ามี text พิเศษ (กำลังถึงป้าย, ครบรอบ ฯลฯ)
    if (result.text != null) return (result.text!, '');

    if (result.arrivalTime == null) return ('-', '');

    final hh = result.arrivalTime!.hour.toString().padLeft(2, '0');
    final mm = result.arrivalTime!.minute.toString().padLeft(2, '0');

    if (locale == 'th') {
      final absText = '(ถึง ~$hh:$mm น.)';
      if (result.etaMinutes != null && result.etaMinutes! < 1) {
        return ('< 1 นาที', absText);
      }
      return ('~${result.etaMinutes} นาที', absText);
    } else {
      final absText = '(arrive ~$hh:$mm)';
      if (result.etaMinutes != null && result.etaMinutes! < 1) {
        return ('< 1 min', absText);
      }
      return ('~${result.etaMinutes} min', absText);
    }
  }

  /// ===== ฟังก์ชันหลัก: คำนวณ Route + ETA ทั้งหมด =====
  ///
  /// รวมขั้นตอน 1-6 ไว้ในที่เดียว เพื่อเรียกใช้จาก map_screen.dart
  static RouteEtaResult compute({
    required double busLat,
    required double busLng,
    required double speedKmh,
    required List<LocationModel> firestoreLocations,
    required Map<String, dynamic>? activeRound,
    required String boardDate,
    required String boardTime,
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
      );
    }

    // --- ขั้นตอนที่ 1: จับคู่ป้ายกับพิกัด ---
    final orderedStops = buildOrderedStops(firestoreLocations);

    if (orderedStops.isEmpty) {
      return RouteEtaResult(
        round: '${activeRound['start_time']} - ${activeRound['end_time']}',
        currentStop: '-',
        nextStop: 'รอข้อมูลป้ายรถ',
        etaText: '-',
      );
    }

    // --- ขั้นตอนที่ 2: หาป้ายใกล้สุด ---
    final (nearestIdx, nearestDist) =
        findNearestStop(busLat, busLng, orderedStops);

    // --- ขั้นตอนที่ 3: กำหนดป้ายถัดไป ---
    final nextStopIdx = determineNextStop(
      nearestIdx,
      nearestDist,
      orderedStops,
      busLat,
      busLng,
    );

    final roundText =
        '${activeRound['start_time']} - ${activeRound['end_time']}';

    // กรณี C: ครบรอบแล้ว
    if (nextStopIdx == -1) {
      return RouteEtaResult(
        round: roundText,
        currentStop: orderedStops[nearestIdx].name,
        nextStop: 'ครบรอบแล้ว',
        etaText: '-',
      );
    }

    // --- กำหนดชื่อป้ายปัจจุบัน ---
    String currentStopResult;
    if (nearestDist <= atStopThresholdM) {
      currentStopResult = orderedStops[nearestIdx].name;
    } else {
      if (nextStopIdx == nearestIdx) {
        // กำลังมุ่งไปป้ายนี้
        currentStopResult = 'กำลังไป ${orderedStops[nearestIdx].name}';
      } else {
        // อยู่ระหว่างป้าย
        currentStopResult =
            'ระหว่าง ${orderedStops[nearestIdx].name} กับ ${orderedStops[nextStopIdx].name}';
      }
    }

    // --- ขั้นตอนที่ 4: คำนวณระยะทาง ---
    final routeDistanceM = calculateRouteDistance(
      nearestIdx,
      nextStopIdx,
      nearestDist,
      orderedStops,
      busLat,
      busLng,
    );

    // --- ขั้นตอนที่ 5: คำนวณ ETA ---
    final etaResult = calculateEta(routeDistanceM, speedKmh);

    // --- ขั้นตอนที่ 6: แสดงผล ---
    final (etaText, etaAbsolute) = formatEta(etaResult, locale: locale);

    return RouteEtaResult(
      round: roundText,
      currentStop: currentStopResult,
      nextStop: orderedStops[nextStopIdx].name,
      etaText: etaText,
      etaAbsolute: etaAbsolute,
    );
  }
}
