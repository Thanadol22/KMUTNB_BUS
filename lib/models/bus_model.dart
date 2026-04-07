import 'package:cloud_firestore/cloud_firestore.dart';

class BusModel {
  final String busId;
  final String licensePlate;
  final String driverId;
  final String status;

  // From RTDB tracking
  double lat;
  double lng;
  double speed;
  int lastUpdated;

  // Joined from users collection
  String driverName;
  String driverPhone;

  BusModel({
    required this.busId,
    required this.licensePlate,
    required this.driverId,
    required this.status,
    this.lat = 0.0,
    this.lng = 0.0,
    this.speed = 0.0,
    this.lastUpdated = 0,
    this.driverName = '',
    this.driverPhone = '',
  });

  factory BusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusModel(
      busId: doc.id,
      licensePlate: data['license_plate'] ?? '',
      driverId: data['driver_id'] ?? '',
      status: data['status'] ?? 'หยุดให้บริการ',
    );
  }

  factory BusModel.fromRTDB(String busId, Map<String, dynamic> data) {
    return BusModel(
      busId: busId,
      licensePlate: '',
      driverId: data['driver_id'] ?? '',
      status: data['status'] ?? 'ไม่ทราบสถานะ',
      lat: double.tryParse(data['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(data['lng']?.toString() ?? '') ?? 0.0,
      speed: double.tryParse(data['speed']?.toString() ?? '') ?? 0.0,
      lastUpdated: int.tryParse(data['last_updated']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'license_plate': licensePlate,
      'driver_id': driverId,
      'status': status,
    };
  }
}
