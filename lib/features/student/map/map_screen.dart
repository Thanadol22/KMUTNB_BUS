import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import '../../../core/utils/app_localizations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng centerLocation = const LatLng(14.163687, 101.3628841);

  final List<Map<String, dynamic>> targetBuildings = [
    {'name': 'อาคารบริหาร (จุดจอด)', 'lat': 14.163687, 'lng': 101.362884},
    {'name': 'คณะวิศวกรรมศาสตร์', 'lat': 14.164300, 'lng': 101.364400},
    {'name': 'หอพักนักศึกษา', 'lat': 14.162000, 'lng': 101.361000},
  ];

  // Cache ข้อมูลจาก Firestore
  Map<String, Map<String, dynamic>> _driverCache = {};
  Map<String, Map<String, dynamic>> _busCache = {};

  String? _selectedBusId;

  // ===== Cached Streams (สร้างครั้งเดียวใน initState) =====
  late final Stream<DatabaseEvent> _trackingStream;
  late final Stream<Map<String, dynamic>> _firestoreStream;

  bool _receivedTrackingEvent = false;
  bool _trackingTimedOut = false;
  Timer? _trackingTimeoutTimer;

  /// สร้าง DatabaseReference ที่ชี้ไปยัง RTDB ที่ถูกต้อง (รองรับ asia-southeast1)
  DatabaseReference _createTrackingRef() {
    final app = Firebase.app();
    final url = app.options.databaseURL;
    if (url != null && url.isNotEmpty) {
      return FirebaseDatabase.instanceFor(app: app, databaseURL: url)
          .ref('tracking');
    }
    return FirebaseDatabase.instance.ref('tracking');
  }

  @override
  void initState() {
    super.initState();

    // สร้าง stream ครั้งเดียว — ใช้ URL จาก Firebase options (asia-southeast1)
    _trackingStream = _createTrackingRef()
        .onValue
        .asBroadcastStream();

    _firestoreStream = _createFirestoreStream().asBroadcastStream();

    _loadBusAndDriverInfo();

    _trackingTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_receivedTrackingEvent) return;
      setState(() => _trackingTimedOut = true);
    });
  }

  @override
  void dispose() {
    _trackingTimeoutTimer?.cancel();
    super.dispose();
  }

  // ===== Firestore Stream =====
  Stream<Map<String, dynamic>> _createFirestoreStream() {
    return FirebaseFirestore.instance
        .collection('buses')
        .snapshots()
        .switchMap((busSnapshot) {
      final Map<String, Map<String, dynamic>> busMap = {};
      final Set<String> driverIds = {};

      for (var doc in busSnapshot.docs) {
        final data = doc.data();
        final busId = _normalizeBusId(data['bus_id']?.toString() ?? doc.id);
        busMap[busId] = {...data, '_docId': doc.id};
        final driverId = data['driver_id']?.toString() ?? '';
        if (driverId.isNotEmpty) driverIds.add(driverId);
      }

      if (driverIds.isEmpty) {
        return Stream.value({
          'buses': busMap,
          'drivers': <String, Map<String, dynamic>>{}
        });
      }

      return FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: driverIds.toList())
          .snapshots()
          .map((userSnapshot) {
        final Map<String, Map<String, dynamic>> driverMap = {};
        for (var doc in userSnapshot.docs) {
          driverMap[doc.id] = doc.data();
        }
        return {'buses': busMap, 'drivers': driverMap};
      });
    });
  }

  // ===== Load Firestore data (initial) =====
  Future<void> _loadBusAndDriverInfo() async {
    try {
      final busSnapshot =
          await FirebaseFirestore.instance.collection('buses').get();
      final Map<String, Map<String, dynamic>> busMap = {};
      final Set<String> driverIds = {};

      for (var doc in busSnapshot.docs) {
        final data = doc.data();
        final busId = _normalizeBusId(data['bus_id']?.toString() ?? doc.id);
        busMap[busId] = {...data, '_docId': doc.id};
        final driverId = data['driver_id']?.toString() ?? '';
        if (driverId.isNotEmpty) driverIds.add(driverId);
      }

      final Map<String, Map<String, dynamic>> driverMap = {};
      for (String driverId in driverIds) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .get();
        if (driverDoc.exists) driverMap[driverId] = driverDoc.data()!;
      }

      if (mounted) {
        setState(() {
          _busCache = busMap;
          _driverCache = driverMap;
        });
      }
    } catch (_) {}
  }

  // ===== Helpers =====
  String _normalizeBusId(String rawBusId) {
    final cleaned =
        rawBusId.replaceAll(RegExp(r'[\s_\-]+'), '').toUpperCase();
    return cleaned.replaceFirst(RegExp(r'^BUSO(?=\d)'), 'BUS0');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _getDriverName(String driverId) =>
      _driverCache[driverId]?['name'] ?? '-';

  String _getDriverPhone(String driverId) =>
      _driverCache[driverId]?['phone'] ?? '-';

  String _getLicensePlate(String busId) =>
      _busCache[busId]?['license_plate'] ?? '-';

  String _getFirestoreDriverId(String busId) =>
      _busCache[busId]?['driver_id']?.toString() ?? '';

  Color _getBoardStatusColor(String boardStatus) {
    switch (boardStatus) {
      case 'กำลังวิ่ง':
      case 'กำลังเดินทาง':
      case 'วิ่งอยู่':
        return const Color(0xFF2ECC71);
      case 'จอดอยู่':
      case 'จอดรอ':
        return const Color(0xFFF39C12);
      case 'หยุดให้บริการ':
        return Colors.grey;
      default:
        return const Color(0xFFFF4009);
    }
  }

  IconData _getBoardStatusIcon(String boardStatus) {
    switch (boardStatus) {
      case 'กำลังวิ่ง':
      case 'กำลังเดินทาง':
      case 'วิ่งอยู่':
        return Icons.directions_bus;
      case 'จอดอยู่':
      case 'จอดรอ':
        return Icons.local_parking;
      default:
        return Icons.directions_bus;
    }
  }

  Color _getFirestoreStatusColor(String status) {
    switch (status) {
      case 'พร้อมให้บริการ':
      case 'กำลังวิ่ง':
      case 'รับส่งตรงป้าย':
        return const Color(0xFF2ECC71); // Green matching the image
      case 'หยุดให้บริการ':
        return Colors.grey;
      case 'ซ่อมบำรุง':
        return Colors.red;
      case 'เติมน้ำมัน':
        return Colors.blue;
      default:
        return const Color(0xFF2ECC71);
    }
  }

  String _calculateETA(LatLng busLocation) {
    double minDistance = double.infinity;
    for (var building in targetBuildings) {
      final stopLocation = LatLng(building['lat'], building['lng']);
      const distance = Distance();
      final meter = distance.as(LengthUnit.Meter, busLocation, stopLocation);
      if (meter < minDistance) minDistance = meter;
    }
    if (minDistance == double.infinity) return '-';
    const double avgSpeed = 333.0;
    int minutes = (minDistance / avgSpeed).round();
    if (minutes <= 0) return 'ถึงแล้ว';
    return '$minutes นาที';
  }

  /// ดึงข้อมูลจาก push ID ล่าสุด
  Map<String, dynamic> _extractLatestBoardData(Map<String, dynamic> nodeMap) {
    bool hasNestedMap = nodeMap.values.any((v) => v is Map);
    if (hasNestedMap) {
      final mapKeys =
          nodeMap.keys.where((k) => nodeMap[k] is Map).toList()..sort();
      if (mapKeys.isNotEmpty) {
        return Map<String, dynamic>.from(nodeMap[mapKeys.last] as Map);
      }
    } else {
      return nodeMap;
    }
    return {};
  }

  /// แปลง Data จาก RTDB ให้อยู่ในรูปแบบ Map เสมอ (แก้ปัญหาบน Android ที่ Firebase แปลง sequential keys เป็น List)
  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      final map = <String, dynamic>{};
      raw.forEach((k, v) => map[k.toString()] = v);
      return map;
    }
    if (raw is List) {
      final map = <String, dynamic>{};
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] != null) {
          map[i.toString()] = raw[i];
        }
      }
      return map;
    }
    return {};
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'map_title')),
        backgroundColor: const Color(0xFFFF4009),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _firestoreStream,
        builder: (context, firestoreSnapshot) {
          if (firestoreSnapshot.hasData) {
            _busCache = Map<String, Map<String, dynamic>>.from(
                firestoreSnapshot.data!['buses']);
            _driverCache = Map<String, Map<String, dynamic>>.from(
                firestoreSnapshot.data!['drivers']);
          }

          return StreamBuilder<DatabaseEvent>(
            stream: _trackingStream,
            builder: (context, snapshot) {
              List<Marker> busMarkers = [];
              List<Widget> busCards = [];

              if (!_receivedTrackingEvent &&
                  (snapshot.hasData ||
                      snapshot.hasError ||
                      snapshot.connectionState != ConnectionState.waiting)) {
                _receivedTrackingEvent = true;
                _trackingTimeoutTimer?.cancel();
              }

              final List<String> foundTrackingKeys = [];
              final Object? rtdbError =
                  snapshot.hasError ? snapshot.error : null;
              bool rawWasMap = true;
              bool hadAnyTrackingData = false;
              final Set<String> supportedBusIdsSeen = {};
              final Set<String> supportedBusIdsMissingCoords = {};

              if (snapshot.hasData &&
                  snapshot.data!.snapshot.value != null) {
                final raw = snapshot.data!.snapshot.value;

                Map<String, dynamic> trackingData = _safeMap(raw);
                if (trackingData.isEmpty && raw != null) {
                  rawWasMap = false;
                }

                hadAnyTrackingData = trackingData.isNotEmpty;
                foundTrackingKeys
                    .addAll(trackingData.keys.map((k) => k.toString()));

                trackingData.forEach((rawBusId, node) {

                  final busId = _normalizeBusId(rawBusId);
                  // ป้องกันการแสดงข้อมูลรถซ้ำ หากมีหลาย key ใน RTDB ที่ใช้ชื่ออ้างอิงเดียวกัน
                  if (supportedBusIdsSeen.contains(busId)) return;
                  supportedBusIdsSeen.add(busId);

                  final nodeMap = _safeMap(node);
                  if (nodeMap.isEmpty) return;
                  final busInfo = _extractLatestBoardData(nodeMap);
                  if (busInfo.isEmpty) return;

                  // ===== ข้อมูลจากบอร์ด (RTDB) =====
                  final lat =
                      _toDouble(busInfo['lat'] ?? busInfo['latitude']);
                  final lon = _toDouble(
                      busInfo['lon'] ?? busInfo['lng'] ?? busInfo['longitude']);
                  final speed = _toDouble(busInfo['speed']) ?? 0.0;
                  final boardStatus =
                      busInfo['status']?.toString() ?? 'ไม่ทราบ';
                  final currentStop =
                      busInfo['current_stop']?.toString() ?? '-';
                  final nextStop =
                      busInfo['next_stop']?.toString() ?? '-';
                  final round = busInfo['round']?.toString() ?? '-';
                  final boardEta = busInfo['eta'];
                  final boardTime =
                      busInfo['time']?.toString() ?? '-';

                  // ===== ข้อมูลจาก Firestore =====
                  final driverId = _getFirestoreDriverId(busId);
                  final firestoreStatus =
                      _busCache[busId]?['status']?.toString() ??
                          'ไม่ทราบสถานะ';
                  final licensePlate = _getLicensePlate(busId);
                  final driverName = _getDriverName(driverId);
                  final driverPhone = _getDriverPhone(driverId);

                  if (lat != null && lon != null) {
                    final busLocation = LatLng(lat, lon);
                    final statusColor = _getBoardStatusColor(boardStatus);

                    // ===== Marker =====
                    busMarkers.add(
                      Marker(
                        point: busLocation,
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedBusId = busId);
                            _mapController.move(busLocation, 18.0);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(
                                      color: statusColor, width: 2.5),
                                ),
                                child: Icon(
                                  _getBoardStatusIcon(boardStatus),
                                  color: statusColor,
                                  size: 22,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  busId,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    // ===== ETA =====
                    String etaText;
                    if (boardEta != null &&
                        boardEta != -1 &&
                        boardEta.toString() != '-1') {
                      final etaNum = _toDouble(boardEta);
                      if (etaNum != null && etaNum >= 0) {
                        etaText = '${etaNum.round()} นาที';
                      } else {
                        etaText = _calculateETA(busLocation);
                      }
                    } else {
                      etaText = _calculateETA(busLocation);
                    }

                    // ===== Bus Card =====
                    busCards.add(_buildBusCard(
                      busId: busId,
                      busLocation: busLocation,
                      statusColor: statusColor,
                      boardStatus: boardStatus,
                      licensePlate: licensePlate,
                      currentStop: currentStop,
                      nextStop: nextStop,
                      round: round,
                      speed: speed,
                      boardTime: boardTime,
                      driverName: driverName,
                      driverPhone: driverPhone,
                      firestoreStatus: firestoreStatus,
                      etaText: etaText,
                    ));
                  } else {
                    supportedBusIdsMissingCoords.add(busId);
                  }
                });
              }

              return Stack(
                children: [
                  // ===== Map =====
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: centerLocation,
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.kmutnb_bus',
                      ),
                      MarkerLayer(
                        markers: [
                          ...targetBuildings.map(
                            (building) => Marker(
                              point:
                                  LatLng(building['lat'], building['lng']),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ),
                          ),
                          ...busMarkers,
                        ],
                      ),
                    ],
                  ),

                  // ===== Status Banner =====
                  _buildTrackingStatusBanner(
                    rtdbError: rtdbError,
                    connectionState: snapshot.connectionState,
                    rawWasMap: rawWasMap,
                    hadAnyTrackingData: hadAnyTrackingData,
                    busCardsEmpty: busCards.isEmpty,
                    supportedBusIdsSeen: supportedBusIdsSeen,
                    supportedBusIdsMissingCoords:
                        supportedBusIdsMissingCoords,
                    foundTrackingKeys: foundTrackingKeys,
                  ),

                  // ===== Bottom Sheet =====
                  DraggableScrollableSheet(
                    initialChildSize: 0.30,
                    minChildSize: 0.14,
                    maxChildSize: 0.65,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(
                                    top: 12, bottom: 8),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_bus,
                                      color: Color(0xFFFF4009), size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'รถที่กำลังมาถึง (คลิกเพื่อดูตำแหน่ง)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (busCards.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2ECC71)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2ECC71),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'LIVE ${busCards.length} คัน',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: busCards.isNotEmpty
                                  ? ListView.builder(
                                      controller: scrollController,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      itemCount: busCards.length,
                                      itemBuilder: (context, index) =>
                                          busCards[index],
                                    )
                                  : ListView(
                                      controller: scrollController,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      children: [
                                        const SizedBox(height: 20),
                                        Center(
                                          child: Column(
                                            children: [
                                              const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFFFF4009),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'กำลังรอข้อมูลรถจากระบบติดตาม…',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ===== ปุ่มกลับตำแหน่ง =====
                  Positioned(
                    top: 20,
                    right: 20,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      elevation: 4,
                      child: const Icon(Icons.my_location,
                          color: Colors.black),
                      onPressed: () {
                        _mapController.move(centerLocation, 16.0);
                        setState(() => _selectedBusId = null);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ===== Bus Card Widget =====
  Widget _buildBusCard({
    required String busId,
    required LatLng busLocation,
    required Color statusColor,
    required String boardStatus,
    required String licensePlate,
    required String currentStop,
    required String nextStop,
    required String round,
    required double speed,
    required String boardTime,
    required String driverName,
    required String driverPhone,
    required String firestoreStatus,
    required String etaText,
  }) {
    final isSelected = _selectedBusId == busId;
    return GestureDetector(
      onTap: () {
        _mapController.move(busLocation, 18.0);
        setState(() => _selectedBusId = busId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF8F5)
              : const Color(0xFFFAF9F6), // Light cream color matching image
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4009).withValues(alpha: 0.5) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ===== Icon =====
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getBoardStatusIcon(boardStatus),
                color: statusColor,
                size: 24,
              ),
            ),
            
            // ===== Info Column =====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ป้ายทะเบียน: $licensePlate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ปราจีนบุรี',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'คนขับ: $driverName',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '($driverPhone)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        text: 'สถานะ: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _getFirestoreStatusColor(firestoreStatus).withValues(alpha: 0.8),
                        ),
                        children: [
                          TextSpan(
                            text: firestoreStatus,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _getFirestoreStatusColor(firestoreStatus),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== ETA =====
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ETA',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etaText,
                  style: const TextStyle(
                    color: Color(0xFFFF4009), // Orange matching the image
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ===== Status Banner =====
  Widget _buildTrackingStatusBanner({
    required Object? rtdbError,
    required ConnectionState connectionState,
    required bool rawWasMap,
    required bool hadAnyTrackingData,
    required bool busCardsEmpty,
    required Set<String> supportedBusIdsSeen,
    required Set<String> supportedBusIdsMissingCoords,
    required List<String> foundTrackingKeys,
  }) {
    String? message;
    Color bg = Colors.white;
    Color fg = Colors.black87;

    if (rtdbError != null) {
      message =
          'Realtime DB error: ${rtdbError.toString()}';
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    } else if (connectionState == ConnectionState.waiting) {
      if (_trackingTimedOut) {
        message = 'เชื่อมต่อระบบติดตามไม่สำเร็จ (เกินเวลา)\n'
            'ตรวจสอบ: RTDB Rules, Database URL, สถานะล็อกอิน';
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
      } else {
        message = 'กำลังเชื่อมต่อระบบติดตาม…';
      }
    } else if (!rawWasMap) {
      message = 'โครงสร้าง tracking ไม่ใช่ Map';
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else if (!hadAnyTrackingData) {
      message = 'ยังไม่มีข้อมูลรถใน Realtime DB (path: tracking)';
    } else if (busCardsEmpty) {
      if (supportedBusIdsSeen.isNotEmpty) {
        final ids = supportedBusIdsSeen.join(', ');
        if (supportedBusIdsMissingCoords.isNotEmpty) {
          final missing = supportedBusIdsMissingCoords.join(', ');
          message = 'พบ $ids แต่ไม่มีพิกัด lat/lon ($missing)';
        } else {
          message = 'พบ $ids แต่ยังไม่สามารถแสดงได้';
        }
      } else {
        final keysPreview = foundTrackingKeys.take(6).join(', ');
        message = 'พบข้อมูลใน tracking แต่ไม่มีข้อมูลรูปแบบที่ถูกต้อง (keys: $keysPreview)';
      }
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    }

    if (message == null) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      left: 12,
      right: 72,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6),
          ],
        ),
        child: Text(
          message,
          style: TextStyle(
              fontSize: 12, color: fg, fontWeight: FontWeight.w600),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
