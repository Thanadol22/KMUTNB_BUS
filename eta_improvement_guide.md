# คู่มือปรับปรุงระบบ ETA สำหรับแอปพลิเคชัน KMUTNB Bus

> เอกสารนี้อธิบายขั้นตอนการปรับปรุงระบบ ETA (Estimated Time of Arrival) และการแสดงป้ายสถานีถัดไป  
> เพื่อนำไปใช้พัฒนา/ปรับปรุง Mobile App ให้สอดคล้องกับ Web Admin  
> **ปรับปรุงล่าสุด:** 20 เมษายน 2569

---

## สารบัญ

1. [สูตร ETA ที่ใช้](#1-สูตร-eta-ที่ใช้)
2. [ค่าคงที่ที่สำคัญ](#2-ค่าคงที่ที่สำคัญ)
3. [แหล่งข้อมูลที่ต้องใช้](#3-แหล่งข้อมูลที่ต้องใช้)
4. [ลำดับป้ายในเส้นทาง](#4-ลำดับป้ายในเส้นทาง)
5. [ขั้นตอนที่ 1: จับคู่ป้ายกับพิกัด GPS](#5-ขั้นตอนที่-1-จับคู่ป้ายกับพิกัด-gps)
6. [ขั้นตอนที่ 2: หาป้ายที่ใกล้รถที่สุด](#6-ขั้นตอนที่-2-หาป้ายที่ใกล้รถที่สุด-nearest-stop)
7. [ขั้นตอนที่ 3: กำหนดป้ายถัดไป](#7-ขั้นตอนที่-3-กำหนดป้ายถัดไป-next-stop)
8. [ขั้นตอนที่ 4: คำนวณระยะทางตามเส้นทาง](#8-ขั้นตอนที่-4-คำนวณระยะทางตามเส้นทาง)
9. [ขั้นตอนที่ 5: คำนวณ ETA ด้วยสูตร](#9-ขั้นตอนที่-5-คำนวณ-eta-ด้วยสูตร)
10. [ขั้นตอนที่ 6: แสดงผล ETA](#10-ขั้นตอนที่-6-แสดงผล-eta)
11. [การจัดการ Edge Cases](#11-การจัดการ-edge-cases)
12. [สูตร Haversine สำหรับคำนวณระยะทาง](#12-สูตร-haversine-สำหรับคำนวณระยะทาง)
13. [ตัวอย่างผลลัพธ์ที่ถูกต้อง](#13-ตัวอย่างผลลัพธ์ที่ถูกต้อง)
14. [ข้อแตกต่าง: ระบบเดิม vs ระบบใหม่](#14-ข้อแตกต่าง-ระบบเดิม-vs-ระบบใหม่)

---

## 1. สูตร ETA ที่ใช้

```
ETA (เวลาถึงโดยประมาณ) = เวลาปัจจุบัน + (ระยะทางตามเส้นทาง ÷ ความเร็วเฉลี่ย)
```

**อธิบาย:**
- **เวลาปัจจุบัน** = เวลาจริง ณ ตอนที่คำนวณ
- **ระยะทางตามเส้นทาง** = ผลรวมระยะทาง Haversine ตามลำดับป้ายที่เหลือ × ตัวคูณถนน (1.3)
- **ความเร็วเฉลี่ย** = ความเร็ว GPS ปัจจุบัน ถ้ามากกว่า 3 km/h, ถ้าไม่ใช้ fallback 20 km/h

---

## 2. ค่าคงที่ที่สำคัญ

| ค่าคงที่ | ค่า | อธิบาย |
|---|---|---|
| `FALLBACK_SPEED_KMH` | 20 | ความเร็วเฉลี่ยที่ใช้เมื่อรถหยุดหรือช้ามาก (km/h) |
| `ROAD_FACTOR` | 1.3 | ตัวคูณชดเชยเพราะถนนไม่ใช่เส้นตรง (เส้นทางจริง ≈ เส้นตรง × 1.3) |
| `AT_STOP_THRESHOLD_M` | 80 | ระยะ (เมตร) ที่ถือว่ารถถึงป้ายแล้ว |
| `MOVING_THRESHOLD_KMH` | 3 | ความเร็วขั้นต่ำ (km/h) ที่ถือว่ารถกำลังเคลื่อนที่ |

---

## 3. แหล่งข้อมูลที่ต้องใช้

| ข้อมูล | แหล่งที่มา | ตัวอย่าง |
|---|---|---|
| **ตำแหน่งรถ (lat, lon)** | Realtime Database → `tracking/{bus_id}` | `lat: 14.1637, lon: 101.3629` |
| **ความเร็วรถ (speed)** | Realtime Database → `tracking/{bus_id}` → `speed` | `25.5` (km/h) |
| **พิกัดป้ายรถ (lat, lng)** | Firestore → Collection `locations` | `{name: "หอพักฯ", lat: 14.165, lng: 101.361}` |
| **ลำดับป้ายในเส้นทาง** | กำหนดเป็น constant ในโค้ด (ดูหัวข้อ 4) | `[หอพักฯ, หน้า ม., บริหารฯ, ...]` |

---

## 4. ลำดับป้ายในเส้นทาง

รถวิ่งตามลำดับป้ายดังนี้ (เป็นวงกลม 1 รอบ):

```
ป้ายที่ 1: หอพักฯ       (id: dorm)
ป้ายที่ 2: หน้า ม.       (id: front)
ป้ายที่ 3: บริหารฯ      (id: admin)
ป้ายที่ 4: อุตฯ         (id: industry)
ป้ายที่ 5: อาคาร        (id: building)
ป้ายที่ 6: เทคโนฯ       (id: tech)
ป้ายที่ 7: วิศวะฯ       (id: eng)
```

> **สำคัญ:** ลำดับนี้ต้องตรงกับเส้นทางจริงของรถ ถ้าเส้นทางเปลี่ยน ต้องอัปเดตค่านี้ด้วย

**ตัวอย่างการกำหนดใน Dart:**
```dart
const List<Map<String, String>> BUS_STOPS_SEQUENCE = [
  {'id': 'dorm', 'name': 'หอพักฯ'},
  {'id': 'front', 'name': 'หน้า ม.'},
  {'id': 'admin', 'name': 'บริหารฯ'},
  {'id': 'industry', 'name': 'อุตฯ'},
  {'id': 'building', 'name': 'อาคาร'},
  {'id': 'tech', 'name': 'เทคโนฯ'},
  {'id': 'eng', 'name': 'วิศวะฯ'},
];
```

---

## 5. ขั้นตอนที่ 1: จับคู่ป้ายกับพิกัด GPS

**เป้าหมาย:** สร้างรายการป้ายที่มีทั้งชื่อ + พิกัด GPS เรียงตามลำดับเส้นทาง

**วิธีทำ:**
1. อ่านพิกัดป้ายทั้งหมดจาก Firestore Collection `locations`
2. วนลูป `BUS_STOPS_SEQUENCE` จับคู่กับพิกัดจาก Firestore ด้วย fuzzy match ชื่อ
3. ถ้าชื่อตรงกัน หรือมีชื่อที่เป็น substring ของอีกชื่อ → จับคู่สำเร็จ

**Pseudocode:**
```
function buildOrderedStops():
    orderedStops = []
    
    for each stop in BUS_STOPS_SEQUENCE:
        matched = locations.find(loc =>
            loc.name == stop.name OR
            loc.name.contains(stop.name) OR
            stop.name.contains(loc.name) OR
            loc.id == stop.id
        )
        
        if matched:
            orderedStops.add({
                id: stop.id,
                name: stop.name,
                lat: matched.lat,
                lng: matched.lng
            })
    
    return orderedStops
```

**Dart:**
```dart
List<StopWithCoords> buildOrderedStops(
  List<Map<String, String>> sequence,
  List<LocationDoc> firestoreLocations,
) {
  final result = <StopWithCoords>[];
  
  for (final stop in sequence) {
    final matched = firestoreLocations.firstWhereOrNull((loc) =>
      loc.name == stop['name'] ||
      loc.name.contains(stop['name']!) ||
      stop['name']!.contains(loc.name) ||
      loc.id == stop['id']
    );
    
    if (matched != null) {
      result.add(StopWithCoords(
        id: stop['id']!,
        name: stop['name']!,
        lat: matched.lat,
        lng: matched.lng,
      ));
    }
  }
  
  return result;
}
```

---

## 6. ขั้นตอนที่ 2: หาป้ายที่ใกล้รถที่สุด (Nearest Stop)

**เป้าหมาย:** หาว่ารถอยู่ใกล้ป้ายไหนที่สุด โดยใช้สูตร Haversine

**วิธีทำ:**
1. วนลูปทุกป้ายใน orderedStops
2. คำนวณระยะทาง Haversine จากตำแหน่งรถถึงแต่ละป้าย
3. เก็บป้ายที่มีระยะน้อยที่สุด → `nearestIdx`, `nearestDist`

**Pseudocode:**
```
nearestIdx = 0
nearestDist = INFINITY

for i = 0 to orderedStops.length:
    dist = haversine(bus.lat, bus.lng, orderedStops[i].lat, orderedStops[i].lng)
    if dist < nearestDist:
        nearestDist = dist
        nearestIdx = i
```

---

## 7. ขั้นตอนที่ 3: กำหนดป้ายถัดไป (Next Stop)

**เป้าหมาย:** กำหนดว่าป้ายถัดไปที่รถจะไปถึงคือป้ายไหน

**เงื่อนไข:**

### กรณี A: รถอยู่ที่ป้ายแล้ว (`nearestDist ≤ 80 เมตร`)
→ ป้ายถัดไป = ป้ายลำดับถัดไปในเส้นทาง (`nearestIdx + 1`)

### กรณี B: รถอยู่ระหว่างทาง (`nearestDist > 80 เมตร`)
ต้องตรวจสอบว่ารถ **ผ่าน** ป้ายใกล้ที่สุดไปแล้วหรือยัง:

```
distToNext      = haversine(bus, orderedStops[nearestIdx + 1])
distBetweenStops = haversine(orderedStops[nearestIdx], orderedStops[nearestIdx + 1])

ถ้า distToNext < distBetweenStops:
    → รถผ่านป้ายไปแล้ว → ป้ายถัดไป = nearestIdx + 1
ถ้าไม่:
    → รถยังไม่ถึงป้าย → ป้ายถัดไป = nearestIdx
```

### กรณี C: เลยป้ายสุดท้ายแล้ว (`nextStopIdx ≥ จำนวนป้ายทั้งหมด`)
→ แสดง "ครบรอบแล้ว"

**แผนภาพ:**
```
ป้าย A ──────── รถ 🚌 ──────── ป้าย B
  nearestIdx              nearestIdx + 1

ถ้ารถใกล้ B มากกว่าระยะ A→B → รถผ่าน A ไปแล้ว → ป้ายถัดไป = B
ถ้ารถไกลจาก B มากกว่าระยะ A→B → รถยังไม่ถึง A → ป้ายถัดไป = A
```

**Dart:**
```dart
int determineNextStop(int nearestIdx, double nearestDist, 
                       List<StopWithCoords> stops, double busLat, double busLng) {
  if (nearestDist <= AT_STOP_THRESHOLD_M) {
    // กรณี A: อยู่ที่ป้ายแล้ว
    return nearestIdx + 1;
  }
  
  if (nearestIdx + 1 < stops.length) {
    // กรณี B: อยู่ระหว่างทาง
    final distToNext = haversine(busLat, busLng, 
                                  stops[nearestIdx + 1].lat, stops[nearestIdx + 1].lng);
    final distBetween = haversine(stops[nearestIdx].lat, stops[nearestIdx].lng,
                                   stops[nearestIdx + 1].lat, stops[nearestIdx + 1].lng);
    return (distToNext < distBetween) ? nearestIdx + 1 : nearestIdx;
  }
  
  return nearestIdx;
}
```

---

## 8. ขั้นตอนที่ 4: คำนวณระยะทางตามเส้นทาง

**เป้าหมาย:** คำนวณระยะทางจากตำแหน่งรถถึงป้ายถัดไป **ตามลำดับป้าย** (ไม่ใช่เส้นตรง)

**วิธีทำ:**

```
routeDistance = 0

ถ้า nextStopIdx == nearestIdx:
    # รถมุ่งไปป้ายเดียวกับที่ใกล้ที่สุด
    routeDistance = nearestDist

ถ้าไม่:
    # ระยะจากรถถึงป้ายใกล้ที่สุด
    routeDistance = nearestDist
    
    # บวกระยะระหว่างป้ายที่เหลือ
    for i = nearestIdx to nextStopIdx - 1:
        routeDistance += haversine(stops[i], stops[i+1])

# คูณ road factor เพราะถนนไม่ใช่เส้นตรง
routeDistance = routeDistance × 1.3
```

**ทำไมต้องคูณ 1.3?**  
สูตร Haversine คำนวณระยะ **เส้นตรง** ระหว่าง 2 จุด แต่เส้นทางจริงมีทางโค้ง ทางเลี้ยว  
ค่า 1.3 เป็นค่าประมาณที่เหมาะสมสำหรับถนนภายในมหาวิทยาลัย

**Dart:**
```dart
double calculateRouteDistance(int nearestIdx, int nextStopIdx, 
                               double nearestDist, List<StopWithCoords> stops) {
  double routeDistance;
  
  if (nextStopIdx == nearestIdx) {
    routeDistance = nearestDist;
  } else {
    routeDistance = nearestDist;
    for (int i = nearestIdx; i < nextStopIdx; i++) {
      routeDistance += haversine(
        stops[i].lat, stops[i].lng,
        stops[i + 1].lat, stops[i + 1].lng,
      );
    }
  }
  
  return routeDistance * ROAD_FACTOR; // × 1.3
}
```

---

## 9. ขั้นตอนที่ 5: คำนวณ ETA ด้วยสูตร

**สูตรหลัก:**
```
ความเร็วเฉลี่ย = ถ้า GPS speed > 3 km/h → ใช้ GPS speed
                 ถ้าไม่ → ใช้ fallback 20 km/h

ความเร็ว (m/s)  = ความเร็วเฉลี่ย × (1000 ÷ 3600)
ETA (วินาที)    = ระยะทางตามเส้นทาง (เมตร) ÷ ความเร็ว (m/s)
เวลาถึงจริง     = เวลาปัจจุบัน + ETA (วินาที)
```

**Dart:**
```dart
EtaResult calculateEta(double routeDistanceM, double gpsSpeedKmh) {
  // ถ้าอยู่ใกล้ป้ายมาก → กำลังถึง
  if (routeDistanceM <= AT_STOP_THRESHOLD_M) {
    return EtaResult(text: 'กำลังถึงป้าย', arrivalTime: DateTime.now());
  }
  
  // เลือกความเร็ว
  final avgSpeedKmh = (gpsSpeedKmh > MOVING_THRESHOLD_KMH) 
      ? gpsSpeedKmh 
      : FALLBACK_SPEED_KMH;
  
  // แปลง km/h → m/s
  final avgSpeedMs = avgSpeedKmh * (1000 / 3600);
  
  // คำนวณเวลา (วินาที)
  final etaSeconds = routeDistanceM / avgSpeedMs;
  final etaMinutes = (etaSeconds / 60).ceil();
  
  // คำนวณเวลาถึงจริง
  final arrivalTime = DateTime.now().add(Duration(seconds: etaSeconds.round()));
  
  return EtaResult(
    etaMinutes: etaMinutes,
    arrivalTime: arrivalTime,
    usedFallbackSpeed: gpsSpeedKmh <= MOVING_THRESHOLD_KMH,
  );
}
```

---

## 10. ขั้นตอนที่ 6: แสดงผล ETA

**รูปแบบการแสดงผล:**

| สถานการณ์ | สิ่งที่แสดง |
|---|---|
| ETA < 1 นาที | `< 1 นาที (ถึง ~09:15 น.)` |
| ETA ≥ 1 นาที | `~3 นาที (ถึง ~09:18 น.)` |
| รถอยู่ที่ป้ายแล้ว (< 80m) | `กำลังถึงป้าย` |
| ครบรอบ | `ครบรอบแล้ว` → ETA = `-` |
| ไม่มีข้อมูลป้าย | `รอข้อมูลป้ายรถ` → ETA = `-` |

**Dart:**
```dart
String formatEta(EtaResult result) {
  if (result.text != null) return result.text!;
  
  final hh = result.arrivalTime.hour.toString().padLeft(2, '0');
  final mm = result.arrivalTime.minute.toString().padLeft(2, '0');
  
  if (result.etaMinutes < 1) {
    return '< 1 นาที (ถึง ~$hh:$mm น.)';
  }
  return '~${result.etaMinutes} นาที (ถึง ~$hh:$mm น.)';
}
```

---

## 11. การจัดการ Edge Cases

| กรณี | วิธีจัดการ |
|---|---|
| **รถหยุดนิ่ง** (speed = 0) | ใช้ fallback speed 20 km/h แทน |
| **GPS ไม่มีค่า speed** | ใช้ fallback speed 20 km/h |
| **รถอยู่ใกล้ป้ายมาก** (< 80m) | แสดง "กำลังถึงป้าย" |
| **รถเลยป้ายสุดท้าย** | แสดง "ครบรอบแล้ว" |
| **ไม่มีข้อมูล locations** | แสดง "รอข้อมูลป้ายรถ" |
| **ไม่มีข้อมูล RTDB** | ไม่แสดง bus card (ซ่อนรถคันนั้น) |
| **จับคู่ชื่อป้ายไม่ได้** | ใช้ลำดับจาก Firestore locations โดยตรง |

---

## 12. สูตร Haversine สำหรับคำนวณระยะทาง

สูตรคำนวณระยะทาง (เมตร) ระหว่าง 2 จุดพิกัดบนพื้นโลก:

```
R = 6371000  (รัศมีโลก เป็นเมตร)

φ1 = lat1 × π / 180
φ2 = lat2 × π / 180
Δφ = (lat2 - lat1) × π / 180
Δλ = (lon2 - lon1) × π / 180

a = sin²(Δφ/2) + cos(φ1) × cos(φ2) × sin²(Δλ/2)
c = 2 × atan2(√a, √(1−a))

distance = R × c   ← ผลลัพธ์เป็นเมตร
```

**Dart:**
```dart
import 'dart:math';

double haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // รัศมีโลก (เมตร)
  
  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final deltaPhi = (lat2 - lat1) * pi / 180;
  final deltaLambda = (lon2 - lon1) * pi / 180;
  
  final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
            cos(phi1) * cos(phi2) *
            sin(deltaLambda / 2) * sin(deltaLambda / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  
  return R * c; // ระยะทาง (เมตร)
}
```

---

## 13. ตัวอย่างผลลัพธ์ที่ถูกต้อง

### ตัวอย่างที่ 1: รถกำลังวิ่งปกติ
```
ตำแหน่งรถ:     [14.1637, 101.3629]
ความเร็ว GPS:   25 km/h
ป้ายใกล้สุด:     อุตฯ (nearestDist = 120m)
ป้ายถัดไป:      อาคาร (nextStopIdx = 4)
ระยะทาง:       350m × 1.3 = 455m
ETA:           455m ÷ 6.94 m/s = 65.6 วินาที ≈ 2 นาที
แสดง:          "~2 นาที (ถึง ~09:19 น.)"
```

### ตัวอย่างที่ 2: รถหยุดอยู่
```
ตำแหน่งรถ:     [14.1640, 101.3625]
ความเร็ว GPS:   0 km/h  →  ใช้ fallback 20 km/h
ป้ายใกล้สุด:    บริหารฯ (nearestDist = 45m → ≤ 80m = อยู่ที่ป้าย!)
ป้ายถัดไป:     อุตฯ (nearestIdx + 1)
ระยะทาง:      200m × 1.3 = 260m
ETA:          260m ÷ 5.56 m/s = 46.8 วินาที ≈ 1 นาที
แสดง:         "~1 นาที (ถึง ~09:20 น.)"
```

### ตัวอย่างที่ 3: กำลังถึงป้าย
```
ตำแหน่งรถ:     [14.1650, 101.3620]
ป้ายใกล้สุด:     หอพักฯ (nearestDist = 30m → ≤ 80m)
ป้ายถัดไป:      หน้า ม. (nearestIdx + 1)
ระยะทาง:       50m × 1.3 = 65m  →  ≤ 80m!
แสดง:          "กำลังถึงป้าย"
```

---

## 14. ข้อแตกต่าง: ระบบเดิม vs ระบบใหม่

| หัวข้อ | ระบบเดิม ❌ | ระบบใหม่ ✅ |
|---|---|---|
| **หาป้ายถัดไป** | เทียบจากเวลาตาราง (time-based) | ตรวจจาก GPS จริง (spatial-based) |
| **ปัญหารถล่าช้า** | ป้ายกระโดดข้ามเพราะเวลาเลย | ไม่มีปัญหา เพราะดูจากตำแหน่งจริง |
| **สูตร ETA** | `ระยะทาง ÷ ความเร็ว` (relative only) | `เวลาปัจจุบัน + (ระยะทาง ÷ ความเร็ว)` |
| **แสดง ETA** | `"3 นาที"` | `"~3 นาที (ถึง ~09:15 น.)"` |
| **ระยะทาง** | เส้นตรง Haversine | ตามลำดับป้าย × road factor 1.3 |
| **รถหยุด** | แสดง "กำลังคำนวณ..." | ใช้ fallback speed 20 km/h |
| **BUS_STOPS_SEQUENCE** | ประกาศแต่ไม่ใช้ | ใช้จริงผ่าน `buildOrderedStops()` |
| **Edge cases** | ไม่ครอบคลุม | จัดการครบทุกกรณี |

---

## Flowchart ภาพรวม

```
          ┌─────────────────────┐
          │  รับตำแหน่ง GPS รถ    │
          │  + ความเร็วจาก RTDB   │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ ขั้นตอน 1:           │
          │ จับคู่ป้ายกับพิกัด    │
          │ (buildOrderedStops) │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ ขั้นตอน 2:           │
          │ หาป้ายใกล้สุด        │
          │ (Haversine loop)    │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ ขั้นตอน 3:           │
          │ กำหนดป้ายถัดไป       │
          │ (≤80m? → ข้ามไป)    │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ ขั้นตอน 4:           │
          │ คำนวณระยะทาง × 1.3  │
          │ (route distance)    │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ ขั้นตอน 5:           │
          │ ETA = dist ÷ speed  │
          │ (fallback=20 km/h)  │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ ขั้นตอน 6:           │
          │ แสดง relative +     │
          │ absolute time       │
          └─────────────────────┘
```

---

> **หมายเหตุ:** ไฟล์นี้เป็นคู่มือสำหรับนำไปปรับปรุงแอปมือถือ (Flutter/Dart) ให้ระบบ ETA ทำงานสอดคล้องกับ Web Admin  
> อ้างอิงจากการปรับปรุงที่ทำใน `assets/js/live_tracking.js` ของ Web Admin
