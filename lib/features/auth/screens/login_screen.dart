import 'package:flutter/material.dart';
import '../../student/student_main_screen.dart';
import '../../driver/driver_main_screen.dart';
import '../widgets/custom_text_field.dart';
import 'register_screen.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleLogin() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'missing_input'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _authService.login(username, password);

      if (!mounted) return;

      String role = userData['role'] ?? 'student';

      // ตรวจสอบสิทธิ์การเข้าใช้งาน
      bool isAllowed = false;
      if (role == 'driver') {
        isAllowed = true; // คนขับรถเข้าได้ทุกลิขสิทธิ์อีเมล
      } else if (role == 'student') {
        // นักศึกษาต้องใช้เมล @email.kmutnb.ac.th เท่านั้น
        if (AppConstants.isStudentEmail(username)) {
          isAllowed = true;
        }
      } else if (role == 'teacher' || role == 'อาจารย์') {
        // อาจารย์ต้องใช้เมล @itm.kmutnb.ac.th หรือ @fitm.kmutnb.ac.th เท่านั้น
        if (AppConstants.isTeacherEmail(username)) {
          isAllowed = true;
        }
      }

      if (isAllowed) {
        if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverMainScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StudentMainScreen()),
          );
        }
      } else {
        // หากไม่ได้รับอนุญาต (เช่น นักศึกษาที่ใช้เมลอื่น) ให้ Logout
        await _authService.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context, 'invalid_email_domain')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = AppLocalizations.of(context, 'invalid_login');
        if (e.toString().contains('invalid_login')) {
          errorMessage = AppLocalizations.of(context, 'invalid_login');
        } else if (e.toString().contains('user_inactive')) {
          errorMessage = AppLocalizations.of(context, 'user_inactive');
        } else if (e.toString().contains('network_error')) {
          errorMessage = AppLocalizations.of(context, 'network_error');
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo/logo.png', height: 500),

              Transform.translate(
                offset: const Offset(0, -150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      label: AppLocalizations.of(context, 'email_login_label'),
                      icon: Icons.email,
                      controller: _usernameController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    CustomTextField(
                      label: AppLocalizations.of(context, 'password'),
                      icon: Icons.lock,
                      isPassword: true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              backgroundColor: const Color(0xFFFF4009),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context, 'login_btn'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(AppLocalizations.of(context, 'no_account')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


