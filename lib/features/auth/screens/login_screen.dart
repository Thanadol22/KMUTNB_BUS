import 'package:flutter/material.dart';
import '../../student/student_main_screen.dart';
import '../../driver/driver_main_screen.dart';
import '../widgets/custom_text_field.dart';
import 'register_screen.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/services/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

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
    } catch (e) {
      if (mounted) {
        String errorMessage = AppLocalizations.of(context, 'invalid_login');
        if (e.toString().contains('invalid_login')) {
          errorMessage = AppLocalizations.of(context, 'invalid_login');
        } else if (e.toString().contains('user_inactive')) {
          errorMessage = 'บัญชีนี้ปิดการใช้งาน หรือถูกระงับ (Inactive)';
        } else if (e.toString().contains('network_error')) {
          errorMessage = 'การเชื่อมต่ออินเทอร์เน็ตมีปัญหา';
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
                      label: AppLocalizations.of(context, 'username'),
                      icon: Icons.person,
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
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


