import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/utils/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleRegister() async {
    final username = _usernameController.text.trim().toLowerCase();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty ||
        name.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context, 'fill_all_fields')),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context, 'password_mismatch')),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.registerStudent(
        username: username,
        name: name,
        password: password,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context, 'register_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorString = e.toString();
        String message = AppLocalizations.of(context, 'register_error');

        if (errorString.contains('username_in_use')) {
          message = AppLocalizations.of(context, 'username_taken');
        } else if (errorString.contains('Permission denied')) {
          message =
              'ไม่สามารถบันทึกข้อมูลได้ (Permission denied) - กรุณาตรวจสอบ Rules ของ Firestore';
        } else {
          message = 'Error: $errorString';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'register_title')),
        backgroundColor: Color(0xFFFF4009),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              label: AppLocalizations.of(context, 'student_id'),
              icon: Icons.badge,
              controller: _usernameController,
            ),
            CustomTextField(
              label: AppLocalizations.of(context, 'full_name'),
              icon: Icons.person,
              controller: _nameController,
            ),
            CustomTextField(
              label: AppLocalizations.of(context, 'password'),
              icon: Icons.lock,
              isPassword: true,
              controller: _passwordController,
            ),
            CustomTextField(
              label: AppLocalizations.of(context, 'confirm_password'),
              icon: Icons.lock_outline,
              isPassword: true,
              controller: _confirmPasswordController,
            ),

            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleRegister,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Color(0xFFFF4009),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context, 'register_btn'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
