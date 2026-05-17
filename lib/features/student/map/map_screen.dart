import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/localization_provider.dart';
import '../../../models/location_model.dart';
import '../../../core/services/firebase_database.dart';
import '../../../core/services/eta_service.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng centerLocation = const LatLng(14.163687, 101.3628841);

  List<LocationModel> _locations = [];

  // Cache ข้อมูลจาก Firestore
  Map<String, Map<String, dynamic>> _driverCache = {};
  Map<String, Map<String, dynamic>> _busCache = {};
  List<Map<String, dynamic>> _schedulesCache = [];

  String? _selectedBusId;
  String? _selectedLocationId;
  LatLng? _lastFollowedPos;

  // ===== Cached Streams =====
  late final Stream<DatabaseEvent> _trackingStream = _createTrackingRef()
      .onValue
      .asBroadcastStream();
  late final Stream<Map<String, dynamic>> _firestoreStream =
      _createFirestoreStream().asBroadcastStream();
  late final Stream<List<LocationModel>> _locationsStream =
      _createLocationsStream().asBroadcastStream();

  bool _receivedTrackingEvent = false;
  bool _trackingTimedOut = false;
  Timer? _trackingTimeoutTimer;

  /// สร้าง DatabaseReference ที่ชี้ไปยัง RTDB ที่ถูกต้อง (รองรับ asia-southeast1)
  DatabaseReference _createTrackingRef() {
    final app = Firebase.app();
    // ใช้ URL จาก .env แทนการ hardcode เพื่อความปลอดภัย
    return FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: dotenv.env['FIREBASE_DATABASE_URL'] ?? '',
    ).ref('tracking');
  }

  @override
  void initState() {
    super.initState();

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
    return FirebaseFirestore.instance.collection('buses').snapshots().switchMap(
      (busSnapshot) {
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
            'drivers': <String, Map<String, dynamic>>{},
          });
        }

        return Rx.combineLatest2(
          FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: driverIds.toList())
              .snapshots(),
          FirebaseFirestore.instance.collection('schedules').snapshots(),
          (userSnapshot, scheduleSnapshot) {
            final Map<String, Map<String, dynamic>> driverMap = {};
            for (var doc in userSnapshot.docs) {
              driverMap[doc.id] = doc.data();
            }
            final List<Map<String, dynamic>> scheduleList = scheduleSnapshot
                .docs
                .map((e) => e.data())
                .toList();
            return {
              'buses': busMap,
              'drivers': driverMap,
              'schedules': scheduleList,
            };
          },
        );
      },
    );
  }

  Stream<List<LocationModel>> _createLocationsStream() {
    return DatabaseService().getLocationsStream();
  }

  // ===== Load Firestore data (initial) =====
  Future<void> _loadBusAndDriverInfo() async {
    try {
      final busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .get();
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

      final scheduleSnapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .get();
      final List<Map<String, dynamic>> scheduleList = scheduleSnapshot.docs
          .map((e) => e.data())
          .toList();

      if (mounted) {
        setState(() {
          _busCache = busMap;
          _driverCache = driverMap;
          _schedulesCache = scheduleList;
        });
      }
    } catch (_) {}
  }

  // ===== Helpers =====
  String _normalizeBusId(String rawBusId) {
    final cleaned = rawBusId.replaceAll(RegExp(r'[\s_\-]+'), '').toUpperCase();
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

  Map<String, String> _calculateRouteAndETA(
    LatLng busLocation,
    double speedKmh,
    Map<String, dynamic>? activeRound,
    String boardDate,
    String boardTime,
  ) {
    // ดึง locale ปัจจุบันสำหรับ format ETA
    final locale = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    ).locale.languageCode;

    // เรียกใช้ EtaService ที่ปรับปรุงแล้ว (spatial-based)
    final result = EtaService.compute(
      busLat: busLocation.latitude,
      busLng: busLocation.longitude,
      speedKmh: speedKmh,
      firestoreLocations: _locations,
      activeRound: activeRound,
      boardDate: boardDate,
      boardTime: boardTime,
      locale: locale,
    );

    return result.toMap();
  }

  /// ดึงข้อมูลจาก push ID ล่าสุด
  Map<String, dynamic> _extractLatestBoardData(Map<String, dynamic> nodeMap) {
    bool hasNestedMap = nodeMap.values.any((v) => v is Map);
    if (hasNestedMap) {
      final mapKeys = nodeMap.keys.where((k) => nodeMap[k] is Map).toList()
        ..sort();
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<LocationModel>>(
        stream: _locationsStream,
        builder: (context, locationsSnapshot) {
          if (locationsSnapshot.hasData) {
            _locations = locationsSnapshot.data!;
          }
          return StreamBuilder<Map<String, dynamic>>(
            stream: _firestoreStream,
            builder: (context, firestoreSnapshot) {
              if (firestoreSnapshot.hasData) {
                _busCache = Map<String, Map<String, dynamic>>.from(
                  firestoreSnapshot.data!['buses'],
                );
                _driverCache = Map<String, Map<String, dynamic>>.from(
                  firestoreSnapshot.data!['drivers'],
                );
                _schedulesCache = List<Map<String, dynamic>>.from(
                  firestoreSnapshot.data!['schedules'] ?? [],
                );
              }

              return StreamBuilder<DatabaseEvent>(
                stream: _trackingStream,
                builder: (context, snapshot) {
                  List<Marker> busMarkers = [];
                  List<Widget> busCards = [];

                  if (!_receivedTrackingEvent &&
                      (snapshot.hasData ||
                          snapshot.hasError ||
                          snapshot.connectionState !=
                              ConnectionState.waiting)) {
                    _receivedTrackingEvent = true;
                    _trackingTimeoutTimer?.cancel();
                  }

                  final List<String> foundTrackingKeys = [];
                  final Object? rtdbError = snapshot.hasError
                      ? snapshot.error
                      : null;
                  bool rawWasMap = true;
                  bool hadAnyTrackingData = false;
                  final Set<String> supportedBusIdsSeen = {};
                  final Set<String> supportedBusIdsMissingCoords = {};

                  LatLng? selectedBusLocation;

                  if (snapshot.hasData &&
                      snapshot.data!.snapshot.value != null) {
                    final raw = snapshot.data!.snapshot.value;

                    Map<String, dynamic> trackingData = _safeMap(raw);
                    if (trackingData.isEmpty && raw != null) {
                      rawWasMap = false;
                    }

                    hadAnyTrackingData = trackingData.isNotEmpty;
                    foundTrackingKeys.addAll(
                      trackingData.keys.map((k) => k.toString()),
                    );

                    trackingData.forEach((rawBusId, node) {
                      final busId = _normalizeBusId(rawBusId);
                      if (supportedBusIdsSeen.contains(busId)) return;
                      supportedBusIdsSeen.add(busId);

                      final nodeMap = _safeMap(node);
                      if (nodeMap.isEmpty) return;
                      final busInfo = _extractLatestBoardData(nodeMap);
                      if (busInfo.isEmpty) return;

                      final lat = _toDouble(
                        busInfo['lat'] ?? busInfo['latitude'],
                      );
                      final lon = _toDouble(
                        busInfo['lon'] ??
                            busInfo['lng'] ??
                            busInfo['longitude'],
                      );
                      final speed = _toDouble(busInfo['speed']) ?? 0.0;

                      // เก็บตำแหน่งรถที่เลือกไว้เพื่อใช้ในการ Follow
                      if (_selectedBusId == busId &&
                          lat != null &&
                          lon != null) {
                        selectedBusLocation = LatLng(lat, lon);
                      }

                      DateTime now = DateTime.now();
                      Map<String, dynamic>? activeRound;
                      for (var s in _schedulesCache) {
                        if (s['bus_id'] != busId && s['bus_id'] != 'bus_01') {
                          continue;
                        }
                        final startStr = s['start_time']?.toString() ?? '';
                        final endStr = s['end_time']?.toString() ?? '';
                        final partsStart = startStr.split(':');
                        final partsEnd = endStr.split(':');
                        if (partsStart.length == 2 && partsEnd.length == 2) {
                          DateTime start = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            int.parse(partsStart[0]),
                            int.parse(partsStart[1]),
                          );
                          DateTime end = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            int.parse(partsEnd[0]),
                            int.parse(partsEnd[1]),
                          );

                          if (now.isAfter(
                                start.subtract(const Duration(minutes: 10)),
                              ) &&
                              now.isBefore(
                                end.add(const Duration(minutes: 10)),
                              )) {
                            if (activeRound == null) {
                              activeRound = s;
                            } else {
                              DateTime currStart = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                int.parse(
                                  activeRound['start_time'].split(':')[0],
                                ),
                                int.parse(
                                  activeRound['start_time'].split(':')[1],
                                ),
                              );
                              if ((now.difference(start).inMinutes).abs() <
                                  (now.difference(currStart).inMinutes).abs()) {
                                activeRound = s;
                              }
                            }
                          }
                        }
                      }

                      final boardStatus =
                          busInfo['status']?.toString() ??
                          AppLocalizations.of(context, 'status_unknown');
                      final boardDate = busInfo['date']?.toString() ?? '';
                      final boardTime = busInfo['time']?.toString() ?? '-';

                      Map<String, String> computedRouteInfo = {
                        'round': '-',
                        'currentStop': '-',
                        'nextStop': '-',
                        'etaText': '-',
                        'etaAbsolute': '',
                      };
                      if (lat != null && lon != null) {
                        computedRouteInfo = _calculateRouteAndETA(
                          LatLng(lat, lon),
                          speed,
                          activeRound,
                          boardDate,
                          boardTime,
                        );
                      }

                      final currentStop =
                          computedRouteInfo['currentStop'] ?? '-';
                      final nextStop = computedRouteInfo['nextStop'] ?? '-';
                      final round = computedRouteInfo['round'] ?? '-';
                      final boardEta = computedRouteInfo['etaText'] ?? '-';
                      final etaAbsolute =
                          computedRouteInfo['etaAbsolute'] ?? '';

                      final driverId = _getFirestoreDriverId(busId);
                      final firestoreStatus =
                          _busCache[busId]?['status']?.toString() ??
                          AppLocalizations.of(context, 'status_unknown');
                      final licensePlate = _getLicensePlate(busId);
                      final driverName = _getDriverName(driverId);
                      final driverPhone = _getDriverPhone(driverId);

                      if (lat != null && lon != null) {
                        final busLocation = LatLng(lat, lon);
                        final statusColor = _getFirestoreStatusColor(
                          firestoreStatus,
                        );

                        busMarkers.add(
                          Marker(
                            point: busLocation,
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedBusId = busId;
                                  _lastFollowedPos = busLocation;
                                });
                                _mapController.move(busLocation, 18.0);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: statusColor,
                                        width: 2.2,
                                      ),
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
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
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

                        String etaText = boardEta.toString();

                        busCards.add(
                          _buildBusCard(
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
                            etaAbsolute: etaAbsolute,
                          ),
                        );
                      } else {
                        supportedBusIdsMissingCoords.add(busId);
                      }
                    });
                  }

                  // ===== Camera Following Logic =====
                  if (selectedBusLocation != null &&
                      selectedBusLocation != _lastFollowedPos) {
                    _lastFollowedPos = selectedBusLocation;
                    // ใช้ addPostFrameCallback เพื่อหลีกเลี่ยงความขัดแย้งขณะ Build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_selectedBusId != null) {
                        _mapController.move(
                          selectedBusLocation!,
                          _mapController.camera.zoom,
                        );
                      }
                    });
                  }

                  return Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: centerLocation,
                          initialZoom: 16.0,
                          onTap: (_, _) {
                            if (_selectedLocationId != null) {
                              setState(() => _selectedLocationId = null);
                            }
                          },
                          onMapEvent: (event) {
                            // ถ้าเหตุการณ์เกิดจากการกระทำของผู้ใช้ (ไม่ใช่โปรแกรมสั่ง move)
                            // ให้ยกเลิกการติดตาม (Unlock)
                            if (event.source != MapEventSource.mapController &&
                                _selectedBusId != null) {
                              setState(() {
                                _selectedBusId = null;
                                _lastFollowedPos = null;
                              });
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.kmutnb_bus',
                          ),
                          MarkerLayer(
                            markers: [
                              ..._locations.map((building) {
                                final isSelected =
                                    _selectedLocationId == building.id;
                                return Marker(
                                  point: LatLng(building.lat, building.lng),
                                  width: 120,
                                  height: 80,
                                  alignment: Alignment.topCenter,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedLocationId = building.id;
                                      });
                                    },
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        // Label
                                        AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          opacity: isSelected ? 1.0 : 0.0,
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 35,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: Colors.red.withValues(
                                                  alpha: 0.5,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              building.name,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Pin Icon
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 32,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              ...busMarkers,
                            ],
                          ),
                        ],
                      ),
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
                      DraggableScrollableSheet(
                        initialChildSize: 0.30,
                        minChildSize: 0.14,
                        maxChildSize: 0.65,
                        builder: (context, scrollController) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
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
                                      top: 12,
                                      bottom: 8,
                                    ),
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
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                          'arriving_buses',
                                        ),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.color,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (busCards.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF2ECC71,
                                            ).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF2ECC71),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'LIVE ${busCards.length}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
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
                                            horizontal: 16,
                                          ),
                                          itemCount: busCards.length,
                                          itemBuilder: (context, index) =>
                                              busCards[index],
                                        )
                                      : ListView(
                                          controller: scrollController,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
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
                                                          color: Color(
                                                            0xFFFF4009,
                                                          ),
                                                        ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                      'waiting_tracking',
                                                    ),
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
                      Positioned(
                        top: 20,
                        right: 20,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          elevation: 4,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            _mapController.move(centerLocation, 16.0);
                            setState(() {
                              _selectedBusId = null;
                              _lastFollowedPos = null;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
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
    String etaAbsolute = '',
  }) {
    final isSelected = _selectedBusId == busId;
    final dynamicStatusColor = _getFirestoreStatusColor(firestoreStatus);
    final theme = Theme.of(context);
    final busData = _busCache[busId] ?? {};
    final busBrand = busData['bus_brand']?.toString() ?? '';
    final busType = busData['bus_type']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBusId = busId;
          _lastFollowedPos = busLocation;
        });
        _mapController.move(busLocation, 18.0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? dynamicStatusColor
                : dynamicStatusColor.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? dynamicStatusColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Identity Details (Avatar, Name, Vehicle & License Plate, Bus ID, Status Badge)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Driver Profile Image
                Builder(
                  builder: (context) {
                    final driverId = _getFirestoreDriverId(busId);
                    final driverData = _driverCache[driverId] ?? {};
                    final driverProfileImageUrl = driverData['profile_image_url']?.toString();

                    ImageProvider? imageProvider;
                    if (driverProfileImageUrl != null && driverProfileImageUrl.isNotEmpty) {
                      if (driverProfileImageUrl.startsWith('data:image') || !driverProfileImageUrl.startsWith('http')) {
                        try {
                          final cleanBase64 = driverProfileImageUrl.contains(',')
                              ? driverProfileImageUrl.split(',').last
                              : driverProfileImageUrl;
                          imageProvider = MemoryImage(base64Decode(cleanBase64));
                        } catch (_) {}
                      } else {
                        imageProvider = NetworkImage(driverProfileImageUrl);
                      }
                    }

                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dynamicStatusColor.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: dynamicStatusColor,
                          width: 2.2,
                        ),
                      ),
                      child: ClipOval(
                        child: imageProvider != null
                            ? Image(
                                image: imageProvider,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.person,
                                  color: dynamicStatusColor,
                                  size: 28,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: dynamicStatusColor,
                                size: 28,
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Driver & Vehicle metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (busType.isNotEmpty) busType,
                          if (busBrand.isNotEmpty) busBrand,
                          if (licensePlate.isNotEmpty) licensePlate,
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (driverPhone.isNotEmpty && driverPhone != '-') ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: driverPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('คัดลอกเบอร์โทร $driverPhone แล้ว'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4009).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 9.5,
                                  color: Color(0xFFFF4009),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  driverPhone,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF4009),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Bus ID & Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      busId,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: dynamicStatusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: dynamicStatusColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.translateDbStatus(
                          context,
                          firestoreStatus,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: dynamicStatusColor,
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Divider Line
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                color: theme.dividerColor.withValues(alpha: 0.08),
                height: 1,
                thickness: 1,
              ),
            ),

            // Bottom Section: Operations Details (Next Stop & ETA Progress)
            Row(
              children: [
                // Next Stop
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: dynamicStatusColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.near_me_rounded,
                          color: dynamicStatusColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context, 'next_stop') ?? 'ป้ายถัดไป',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.textTheme.bodyMedium?.color?.withValues(
                                  alpha: 0.5,
                                ),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              nextStop,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // ETA Status Badge
                Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: dynamicStatusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: dynamicStatusColor.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context, 'will_arrive_in') ?? 'จะถึงภายใน',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              etaText,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: dynamicStatusColor,
                              ),
                            ),
                            if (etaAbsolute.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($etaAbsolute)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: dynamicStatusColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
    Color fg = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    if (rtdbError != null) {
      message = 'Realtime DB error: ${rtdbError.toString()}';
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    } else if (connectionState == ConnectionState.waiting) {
      if (_trackingTimedOut) {
        message =
            'เชื่อมต่อระบบติดตามไม่สำเร็จ (เกินเวลา)\n'
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
        message =
            'พบข้อมูลใน tracking แต่ไม่มีข้อมูลรูปแบบที่ถูกต้อง (keys: $keysPreview)';
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: fg,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
