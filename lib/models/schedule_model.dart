import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String scheduleId;
  final String busId;
  final String startTime;
  final String endTime;
  final String routeName;

  ScheduleModel({
    required this.scheduleId,
    required this.busId,
    required this.startTime,
    required this.endTime,
    required this.routeName,
  });

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleModel(
      scheduleId: doc.id,
      busId: data['bus_id'] ?? '',
      startTime: data['start_time'] ?? '',
      endTime: data['end_time'] ?? '',
      routeName: data['route_name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bus_id': busId,
      'start_time': startTime,
      'end_time': endTime,
      'route_name': routeName,
    };
  }
}
