import 'package:cloud_firestore/cloud_firestore.dart';

class IssueReportModel {
  final String issueId;
  final String studentId;
  final String topic;
  final String description;
  final String status;
  final DateTime? timestamp;

  IssueReportModel({
    required this.issueId,
    required this.studentId,
    required this.topic,
    required this.description,
    required this.status,
    this.timestamp,
  });

  factory IssueReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IssueReportModel(
      issueId: doc.id,
      studentId: data['student_id'] ?? '',
      topic: data['topic'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'topic': topic,
      'description': description,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
