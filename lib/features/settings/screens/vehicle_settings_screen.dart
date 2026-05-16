import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/services/firebase_database.dart';
import '../../auth/widgets/custom_text_field.dart';
import '../../../core/utils/app_localizations.dart';

class VehicleSettingsScreen extends StatefulWidget {
  const VehicleSettingsScreen({super.key});

  @override
  State<VehicleSettingsScreen> createState() => _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState extends State<VehicleSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _busBrandController = TextEditingController();
  final _busSeatsController = TextEditingController();
  String? _busType;
  String? _busId;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _busTypeOptions = ['รถสองแถว', 'รถบัส', 'รถตู้'];

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  Future<void> _loadVehicleData() async {
    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid != null) {
        Map<String, dynamic>? userData;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        if (userDoc.exists) {
          userData = userDoc.data();
        }

        final busSnapshot = await DatabaseService().getBusForDriver(uid);
        if (busSnapshot != null && busSnapshot.docs.isNotEmpty) {
          final busDoc = busSnapshot.docs.first;
          final busData = busDoc.data() as Map<String, dynamic>;
          _busId = busDoc.id;
          
          setState(() {
            _busType = busData['bus_type'] ?? userData?['bus_type'];
            _busBrandController.text = busData['bus_brand']?.toString() ?? userData?['bus_brand']?.toString() ?? '';
            
            final seatsRaw = busData['bus_seats'] ?? userData?['bus_seats'];
            if (seatsRaw != null) {
              _busSeatsController.text = seatsRaw.toString();
            }
            
            _licensePlateController.text = busData['license_plate']?.toString() ?? '';
          });
        } else if (userData != null) {
          final data = userData;
          setState(() {
            _busType = data['bus_type'];
            _busBrandController.text = data['bus_brand']?.toString() ?? '';
            if (data['bus_seats'] != null) {
              _busSeatsController.text = data['bus_seats'].toString();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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

  Future<void> _saveVehicleSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid != null) {
        if (_busId != null) {
          await FirebaseFirestore.instance.collection('buses').doc(_busId!).update({
            'license_plate': _licensePlateController.text.trim(),
            'bus_type': _busType,
            'bus_brand': _busBrandController.text.trim(),
            'bus_seats': int.tryParse(_busSeatsController.text.trim()),
          });
        }
      }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'vehicle_settings')),
        backgroundColor: const Color(0xFFFF4009),
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
                    DropdownButtonFormField<String>(
                      initialValue: _busType,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context, 'bus_type'),
                        prefixIcon: const Icon(Icons.directions_bus, color: Color(0xFFFF4009)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _busTypeOptions.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _busType = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _busBrandController,
                      label: AppLocalizations.of(context, 'bus_brand'),
                      icon: Icons.branding_watermark,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _busSeatsController,
                      label: AppLocalizations.of(context, 'bus_seats'),
                      icon: Icons.event_seat,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _licensePlateController,
                      label: AppLocalizations.of(context, 'license_plate_label'),
                      icon: Icons.confirmation_number,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4009),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : _saveVehicleSettings,
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
