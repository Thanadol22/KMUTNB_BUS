import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Login ด้วย username + password (query Firestore)
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('invalid_login');
      }

      final doc = querySnapshot.docs.first;
      final docData = doc.data();

      // ตรวจสอบสถานะการใช้งาน
      final rawStatus = docData.containsKey('status') ? docData['status'] : 'active';
      String status;
      if (rawStatus is bool) {
        status = rawStatus ? 'active' : 'inactive';
      } else {
        status = rawStatus?.toString() ?? 'active';
      }
      
      if (status == 'inactive') {
        throw Exception('user_inactive');
      }

      // Save uid, role, name to session
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', doc.id);

      String role = docData.containsKey('role') ? docData['role'] : 'student';
      await prefs.setString('role', role);

      String name = docData['name'] ?? '';
      await prefs.setString('name', name);

      return {
        'uid': doc.id,
        'role': role,
        'name': name,
        'username': docData['username'] ?? '',
        'status': status,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// ลงทะเบียนผู้ใช้งานใหม่ใน Firestore
  Future<void> registerUser({
    required String username,
    required String name,
    required String password,
    required String role,
  }) async {
    try {
      // ตรวจสอบ username ซ้ำ
      final checkUsername = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (checkUsername.docs.isNotEmpty) {
        throw Exception('username_in_use');
      }

      await _firestore.collection('users').add({
        'username': username,
        'name': name,
        'password': password,
        'role': role,
        'phone': '',
        'status': 'active',
        'fcm_token': '',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> getCurrentUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }

  static Future<String?> getCurrentUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<String?> getCurrentUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
    await prefs.remove('role');
    await prefs.remove('name');
  }

  /// แก้ไขข้อมูลโปรไฟล์
  Future<void> updateProfile({
    required String name,
    String? phone,
    String? username,
    String? profileImageUrl,
    String? busType,
    String? busBrand,
    int? busSeats,
    String? driverLicense,
    String? gender,
    String? dateOfBirth,
  }) async {
    try {
      String? uid = await getCurrentUserId();
      if (uid == null) throw Exception('no_user_logged_in');

      // ถ้าเปลี่ยน username ต้องตรวจสอบว่าไม่ซ้ำ
      if (username != null) {
        final checkUsername = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        for (var doc in checkUsername.docs) {
          if (doc.id != uid) {
            throw Exception('username_in_use');
          }
        }
      }

      Map<String, dynamic> updates = {
        'name': name,
      };

      if (phone != null) updates['phone'] = phone;
      if (username != null) updates['username'] = username;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      if (busType != null) updates['bus_type'] = busType;
      if (busBrand != null) updates['bus_brand'] = busBrand;
      if (busSeats != null) updates['bus_seats'] = busSeats;
      if (driverLicense != null) updates['driver_license'] = driverLicense;
      if (gender != null) updates['gender'] = gender;
      if (dateOfBirth != null) updates['date_of_birth'] = dateOfBirth;

      await _firestore.collection('users').doc(uid).update(updates);

      // อัปเดต name ใน SharedPreferences ด้วย
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', name);
    } catch (e) {
      rethrow;
    }
  }

  /// อัปโหลดรูปโปรไฟล์
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      String? uid = await getCurrentUserId();
      if (uid == null) throw Exception('no_user_logged_in');

      // Create a reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$uid.jpg');

      // Upload the file
      await storageRef.putFile(imageFile);

      // Get the download URL
      final String downloadUrl = await storageRef.getDownloadURL();

      // Update the user document with the new image URL
      await _firestore.collection('users').doc(uid).update({
        'profile_image_url': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// เปลี่ยนรหัสผ่าน
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      String? uid = await getCurrentUserId();
      if (uid == null) throw Exception('no_user_logged_in');

      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (!docSnapshot.exists) {
        throw Exception('user_not_found');
      }

      final docData = docSnapshot.data()!;
      if (docData['password'] != currentPassword) {
        throw Exception('incorrect_current_password');
      }

      await _firestore.collection('users').doc(uid).update({
        'password': newPassword,
      });
    } catch (e) {
      rethrow;
    }
  }
}
