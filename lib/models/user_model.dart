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
  final String? profileImageUrl;
  final String? busType;
  final String? busBrand;
  final int? busSeats;
  final String? driverLicense;
  final String? gender;
  final String? dateOfBirth;

  UserModel({
    required this.uid,
    required this.username,
    required this.role,
    required this.name,
    this.phone = '',
    this.createdAt,
    this.fcmToken = '',
    this.status = 'active',
    this.profileImageUrl,
    this.busType,
    this.busBrand,
    this.busSeats,
    this.driverLicense,
    this.gender,
    this.dateOfBirth,
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
      profileImageUrl: data['profile_image_url'],
      busType: data['bus_type'],
      busBrand: data['bus_brand'],
      busSeats: data['bus_seats'] as int?,
      driverLicense: data['driver_license'],
      gender: data['gender'],
      dateOfBirth: data['date_of_birth'],
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
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      if (busType != null) 'bus_type': busType,
      if (busBrand != null) 'bus_brand': busBrand,
      if (busSeats != null) 'bus_seats': busSeats,
      if (driverLicense != null) 'driver_license': driverLicense,
      if (gender != null) 'gender': gender,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    };
  }
}
