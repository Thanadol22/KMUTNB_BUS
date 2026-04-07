import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../auth/widgets/custom_text_field.dart';
import '../../../core/utils/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _role;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['name'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _role = data['role'];
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}')),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = AuthService();
      await authService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context, 'profile_saved')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = AppLocalizations.of(context, 'profile_save_error');
        if (e.toString().contains('username_in_use')) {
          errMsg = AppLocalizations.of(context, 'username_taken');
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
        title: Text(AppLocalizations.of(context, 'edit_profile')),
        backgroundColor: Color(0xFFFF4009),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _usernameController,
                      label: AppLocalizations.of(context,
                          _role == 'student' ? 'student_id' : 'employee_id'),
                      icon: Icons.badge,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context, 'required_field');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: AppLocalizations.of(context, 'full_name'),
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context, 'required_field');
                        }
                        return null;
                      },
                    ),
                    if (_role != 'student') ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _phoneController,
                        label: AppLocalizations.of(context, 'phone'),
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFF4009),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                AppLocalizations.of(context, 'save_profile'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
