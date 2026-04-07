import 'package:cloud_firestore/cloud_firestore.dart';

class TicketReportModel {
  final String reportId;
  final String driverId;
  final String busId;
  final int ticketCount;
  final String roundTime;
  final DateTime? timestamp;

  TicketReportModel({
    required this.reportId,
    required this.driverId,
    required this.busId,
    required this.ticketCount,
    required this.roundTime,
    this.timestamp,
  });

  factory TicketReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TicketReportModel(
      reportId: doc.id,
      driverId: data['driver_id'] ?? '',
      busId: data['bus_id'] ?? '',
      ticketCount: data['ticket_count'] ?? 0,
      roundTime: data['round_time'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driver_id': driverId,
      'bus_id': busId,
      'ticket_count': ticketCount,
      'round_time': roundTime,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
