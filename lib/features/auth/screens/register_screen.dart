import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สมัครสมาชิก'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CustomTextField(
              label: 'ชื่อ-นามสกุล',
              icon: Icons.person,
            ),
            const CustomTextField(
              label: 'อีเมล',
              icon: Icons.email,
            ),
            const CustomTextField(
              label: 'รหัสผ่าน',
              icon: Icons.lock,
              isPassword: true,
            ),
            const CustomTextField(
              label: 'ยืนยันรหัสผ่าน',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // จำลองการสมัครสมาชิกเสร็จสิ้น
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('สมัครสมาชิกสำเร็จ!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context); // กลับไปหน้า Login
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ยืนยันการสมัคร', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
