import 'package:flutter/material.dart';
import '../../../core/services/firebase_auth.dart';
import '../../auth/widgets/custom_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านใหม่ไม่ตรงกัน'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = AuthService();
      await authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = 'เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน';
        if (e.toString().contains('incorrect_current_password')) {
          errMsg = 'รหัสผ่านปัจจุบันไม่ถูกต้อง';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        backgroundColor: Color(0xFFFF4009),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _currentPasswordController,
                label: 'รหัสผ่านปัจจุบัน',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่านปัจจุบัน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _newPasswordController,
                label: 'รหัสผ่านใหม่',
                icon: Icons.lock,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่านใหม่';
                  }
                  if (value.length < 6) {
                    return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                label: 'ยืนยันรหัสผ่านใหม่',
                icon: Icons.lock,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณายืนยันรหัสผ่านใหม่';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4009),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving ? null : _changePassword,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('เปลี่ยนรหัสผ่าน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

