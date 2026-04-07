import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String role;
  final String name;
  final String phone;
  final DateTime? createdAt;
  final String fcmToken;
  final String status;

  UserModel({
    required this.uid,
    required this.username,
    required this.role,
    required this.name,
    this.phone = '',
    this.createdAt,
    this.fcmToken = '',
    this.status = 'active',
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      username: data['username'] ?? '',
      role: data['role'] ?? 'student',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      fcmToken: data['fcm_token'] ?? '',
      status: data['status'] is bool
          ? (data['status'] == true ? 'active' : 'inactive')
          : (data['status'] ?? 'active'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'role': role,
      'name': name,
      'phone': phone,
      'created_at': FieldValue.serverTimestamp(),
      'fcm_token': fcmToken,
      'status': status,
    };
  }
}
