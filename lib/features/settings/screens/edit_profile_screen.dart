import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/firebase_auth.dart';
import '../../auth/widgets/custom_text_field.dart';
import '../../../core/utils/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  String? _role;
  String? _profileImageUrl;
  Uint8List? _imageBytes;
  String? _gender;
  String? _dateOfBirth;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _genderOptions = ['male', 'female', 'other_gender'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _dobController.text = _dateOfBirth!;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['name'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _role = data['role'];
          _profileImageUrl = data['profile_image_url'];
          _gender = data['gender'];
          _dateOfBirth = data['date_of_birth'];
          _dobController.text = _dateOfBirth ?? '';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}'),
          ),
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
      String? newImageUrl = _profileImageUrl;
      if (_imageBytes != null) {
        newImageUrl = await authService.uploadProfilePicture(_imageBytes!);
      }

      await authService.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
        profileImageUrl: newImageUrl,
        gender: _gender,
        dateOfBirth: _dateOfBirth,
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
        } else {
          errMsg = '$errMsg: $e';
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
                    // Profile Picture
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!) as ImageProvider
                                : (_profileImageUrl != null
                                      ? (_profileImageUrl!.startsWith('data:image') || !_profileImageUrl!.startsWith('http')
                                          ? MemoryImage(base64Decode(_profileImageUrl!.contains(',') ? _profileImageUrl!.split(',').last : _profileImageUrl!)) as ImageProvider
                                          : NetworkImage(_profileImageUrl!))
                                      : const AssetImage(
                                          'assets/logo/logo.png',
                                        )),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4009),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      controller: _usernameController,
                      label: AppLocalizations.of(
                        context,
                        _role == 'student' ? 'student_id' : 'employee_id',
                      ),
                      icon: Icons.badge,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context, 'required_field');
                        }
                        return null;
                      },
                    ),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context, 'gender'),
                          prefixIcon: const Icon(
                            Icons.people,
                            color: Color(0xFFFF4009),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF4009),
                              width: 2,
                            ),
                          ),
                        ),
                        items: _genderOptions.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(AppLocalizations.of(context, type)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _gender = newValue;
                          });
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dobController,
                          label: AppLocalizations.of(context, 'date_of_birth'),
                          icon: Icons.calendar_today,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                                'required_field',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    CustomTextField(
                      controller: _phoneController,
                      label: AppLocalizations.of(context, 'driver_phone_label'),
                      icon: Icons.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context, 'required_field');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4009),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                AppLocalizations.of(context, 'save_data'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
