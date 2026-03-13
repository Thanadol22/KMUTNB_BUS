import 'package:flutter/material.dart';
import '../../student/student_main_screen.dart';
import '../../driver/driver_main_screen.dart';
import '../widgets/custom_text_field.dart';
import 'register_screen.dart';
import '../../../core/utils/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'missing_input'))),
      );
      return;
    }

    if (email == 'student@gmail.com' && password == '111111') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const StudentMainScreen()),
      );
    } else if (email == 'driver@gmail.com' && password == '111111') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverMainScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'invalid_login'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.directions_bus,
                  size: 100,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context, 'login_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),

                CustomTextField(
                  label: AppLocalizations.of(context, 'email'),
                  icon: Icons.email,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                CustomTextField(
                  label: AppLocalizations.of(context, 'password'),
                  icon: Icons.lock,
                  isPassword: true,
                  controller: _passwordController,
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context, 'login_btn'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: Text(AppLocalizations.of(context, 'no_account')),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
