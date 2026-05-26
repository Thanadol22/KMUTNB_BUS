import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../../../core/services/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/widgets/custom_text_field.dart';
import '../../../core/utils/app_localizations.dart';
import 'package:intl/intl.dart';

class DriverLicenseScreen extends StatefulWidget {
  const DriverLicenseScreen({super.key});

  @override
  State<DriverLicenseScreen> createState() => _DriverLicenseScreenState();
}

class _DriverLicenseScreenState extends State<DriverLicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  String? _licenseType;
  DateTime? _expiryDate;
  String? _licenseImageUrl;
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _licenseTypes = AppConstants.licenseTypes;

  @override
  void initState() {
    super.initState();
    _loadLicenseData();
  }

  Future<void> _loadLicenseData() async {
    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid != null) {
        // First try to load from driver_licenses table
        final licenseDoc = await FirebaseFirestore.instance.collection('driver_licenses').doc(uid).get();
        Map<String, dynamic>? data;
        
        if (licenseDoc.exists) {
          data = licenseDoc.data();
        } else {
          // Fallback to users table if not found
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (userDoc.exists) {
            data = userDoc.data();
          }
        }

        if (data != null && mounted) {
          setState(() {
            _licenseNumberController.text = data!['license_number'] ?? '';
            _licenseType = data['license_type'];
            if (data['license_expiry_date'] != null) {
              _expiryDate = (data['license_expiry_date'] as Timestamp).toDate();
            }
            _licenseImageUrl = data['license_image_url'];
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF4009),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Widget _buildStatusBadge() {
    if (_expiryDate == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final difference = _expiryDate!.difference(now).inDays;
    
    String status;
    Color color;
    IconData icon;
    
    if (_expiryDate!.isBefore(now)) {
      status = AppLocalizations.of(context, 'expired');
      color = Colors.red;
      icon = Icons.cancel;
    } else if (difference <= 30) {
      status = AppLocalizations.of(context, 'expiring_soon');
      color = Colors.orange;
      icon = Icons.warning;
    } else {
      status = AppLocalizations.of(context, 'valid');
      color = Colors.green;
      icon = Icons.check_circle;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _maskLicenseNumber(String number) {
    if (number.length < 4) return number;
    final masked = '*' * (number.length - 4);
    final lastFour = number.substring(number.length - 4);
    return '$masked$lastFour';
  }

  Future<void> _saveLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid == null) return;

      final authService = AuthService();
      String? finalImageUrl = _licenseImageUrl;
      if (_imageBytes != null) {
        finalImageUrl = await authService.uploadLicenseImage(_imageBytes!);
      }

      await FirebaseFirestore.instance.collection('driver_licenses').doc(uid).set({
        'driver_id': uid,
        'license_number': _licenseNumberController.text.trim(),
        'license_type': _licenseType,
        'license_expiry_date': _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        'license_image_url': finalImageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'driver_license'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // License Image Section
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _imageBytes != null
                              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                              : (_licenseImageUrl != null && !_licenseImageUrl!.contains('via.placeholder.com')
                                  ? (_licenseImageUrl!.startsWith('data:image') || !_licenseImageUrl!.startsWith('http')
                                      ? Image.memory(
                                          base64Decode(_licenseImageUrl!.contains(',') ? _licenseImageUrl!.split(',').last : _licenseImageUrl!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.broken_image, size: 50, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                                const SizedBox(height: 12),
                                                Text('โหลดรูปภาพไม่สำเร็จ แตะเพื่ออัปโหลดใหม่', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                              ],
                                            );
                                          },
                                        )
                                      : Image.network(
                                          _licenseImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.broken_image, size: 50, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                                const SizedBox(height: 12),
                                                Text('โหลดรูปภาพไม่สำเร็จ แตะเพื่ออัปโหลดใหม่', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                              ],
                                            );
                                          },
                                        ))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, size: 50, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                        const SizedBox(height: 12),
                                        Text(AppLocalizations.of(context, 'upload_license_image'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                      ],
                                    )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatusBadge(),
                    const SizedBox(height: 30),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context, 'license_details'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 20),
                          
                          // License Number
                          CustomTextField(
                            controller: _licenseNumberController,
                            label: AppLocalizations.of(context, 'license_number'),
                            icon: Icons.badge,
                            keyboardType: TextInputType.number,
                          ),
                          if (_licenseNumberController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16, left: 12),
                              child: Text(
                                '${AppLocalizations.of(context, 'display_format')}: ${_maskLicenseNumber(_licenseNumberController.text)}',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic),
                              ),
                            ),

                          // License Type
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: DropdownButtonFormField<String>(
                              initialValue: _licenseTypes.contains(_licenseType) ? _licenseType : null,
                              items: _licenseTypes.map((type) => DropdownMenuItem(value: type, child: Text(AppLocalizations.of(context, type)))).toList(),
                              onChanged: (val) => setState(() => _licenseType = val),
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context, 'license_type'),
                                prefixIcon: const Icon(Icons.category, color: Color(0xFFFF4009)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFFF4009), width: 2),
                                ),
                              ),
                            ),
                          ),

                          // Expiry Date
                          InkWell(
                            onTap: _selectExpiryDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available, color: Color(0xFFFF4009)),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(AppLocalizations.of(context, 'expiry_date'), style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                      const SizedBox(height: 2),
                                      Text(
                                        _expiryDate != null ? DateFormat('dd MMMM yyyy').format(_expiryDate!) : AppLocalizations.of(context, 'select_date'),
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4009),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: const Color(0xFFFF4009).withOpacity(0.4),
                        ),
                        onPressed: _isSaving ? null : _saveLicense,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(AppLocalizations.of(context, 'save_data'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
