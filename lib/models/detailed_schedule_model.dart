import 'package:cloud_firestore/cloud_firestore.dart';

class DetailedStopModel {
  final int order;
  final String locationId;
  final String name;
  final String time;
  final double lat;
  final double lng;

  DetailedStopModel({
    required this.order,
    required this.locationId,
    required this.name,
    required this.time,
    required this.lat,
    required this.lng,
  });

  factory DetailedStopModel.fromMap(Map<String, dynamic> map) {
    return DetailedStopModel(
      order: map['order']?.toInt() ?? 0,
      locationId: map['location_id'] ?? '',
      name: map['name'] ?? '',
      time: map['time'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
    );
  }
}

class DetailedScheduleModel {
  final String id;
  final String startTime;
  final String endTime;
  final int round;
  final List<DetailedStopModel> stops;

  DetailedScheduleModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.round,
    required this.stops,
  });

  factory DetailedScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final stopsList = data['stops'] as List<dynamic>? ?? [];
    return DetailedScheduleModel(
      id: doc.id,
      startTime: data['start_time'] ?? '',
      endTime: data['end_time'] ?? '',
      round: data['round']?.toInt() ?? 0,
      stops: stopsList
          .map((e) => DetailedStopModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
