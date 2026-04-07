import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../../student/student_main_screen.dart';
import '../../driver/driver_main_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? uid = prefs.getString('uid');
    final String? role = prefs.getString('role');

    if (!mounted) return;

    if (uid != null && role != null) {
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4009)),
      ),
    );
  }
}
