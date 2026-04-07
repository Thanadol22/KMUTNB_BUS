import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/utils/app_localizations.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  String _currentStatusCode = 'status_ready';
  bool _isSaving = false;
  String? _currentBusId;
  String? _busDocId;

  final List<String> _statusCodes = [
    'status_ready',
    'status_stop',
    'status_maintain',
    'status_fuel',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) return;

      final busQuery = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: uid)
          .limit(1)
          .get();

      if (busQuery.docs.isNotEmpty) {
        final busDoc = busQuery.docs.first;
        final busData = busDoc.data();
        final status = busData['status'] ?? 'พร้อมให้บริการ';

        String statusCode;
        switch (status) {
          case 'พร้อมให้บริการ': statusCode = 'status_ready'; break;
          case 'หยุดให้บริการ': statusCode = 'status_stop'; break;
          case 'ซ่อมบำรุง': statusCode = 'status_maintain'; break;
          case 'เติมน้ำมัน': statusCode = 'status_fuel'; break;
          default: statusCode = 'status_ready';
        }

        if (mounted) {
          setState(() {
            _currentStatusCode = statusCode;
            _busDocId = busDoc.id;
            _currentBusId = busData['bus_id'] ?? busDoc.id;
          });
        }
      }
    } catch (e) {
      // ไม่สามารถโหลดสถานะได้
    }
  }

  Future<void> _saveStatus() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) throw Exception('No user logged in');

      // Map status code → Thai text
      String statusThai;
      switch (_currentStatusCode) {
        case 'status_ready': statusThai = 'พร้อมให้บริการ'; break;
        case 'status_stop': statusThai = 'หยุดให้บริการ'; break;
        case 'status_maintain': statusThai = 'ซ่อมบำรุง'; break;
        case 'status_fuel': statusThai = 'เติมน้ำมัน'; break;
        default: statusThai = 'ไม่ทราบสถานะ';
      }

      String busId = _currentBusId ?? '';
      String? docId = _busDocId;

      // Update Firestore only
      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('buses').doc(docId).update({
          'status': statusThai,
        });
      } else {
        // Need to find or create the bus first
        final busQuery = await FirebaseFirestore.instance
            .collection('buses')
            .where('driver_id', isEqualTo: uid)
            .limit(1)
            .get();

        if (busQuery.docs.isNotEmpty) {
          final busDoc = busQuery.docs.first;
          docId = busDoc.id;
          busId = busDoc.data()['bus_id'] ?? busDoc.id;
          await busDoc.reference.update({'status': statusThai});
        } else {
          // Create new bus entry
          final newDoc = FirebaseFirestore.instance.collection('buses').doc();
          docId = newDoc.id;
          busId = newDoc.id;

          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final licensePlate = userDoc.data()?['Tag'] ?? '';

          await newDoc.set({
            'bus_id': busId,
            'driver_id': uid,
            'license_plate': licensePlate,
            'status': statusThai,
          });
        }
      }

      if (mounted) {
        setState(() {
          _currentBusId = busId;
          _busDocId = docId;
        });

        final statusText = AppLocalizations.of(context, _currentStatusCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context, 'status_updated')} $statusText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1), // Faster response
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context, 'error_prefix')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        title: Text(AppLocalizations.of(context, 'manage_status')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentBusId != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_bus, color: Color(0xFFFF4009)),
                  title: Text('${AppLocalizations.of(context, 'bus_label')}: $_currentBusId'),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context, 'current_status'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statusCodes.map((code) {
              IconData statusIcon;
              Color statusColor;
              switch (code) {
                case 'status_ready': statusIcon = Icons.check_circle; statusColor = Colors.green; break;
                case 'status_stop': statusIcon = Icons.pause_circle; statusColor = Colors.grey; break;
                case 'status_maintain': statusIcon = Icons.build; statusColor = Colors.red; break;
                case 'status_fuel': statusIcon = Icons.local_gas_station; statusColor = Colors.blue; break;
                default: statusIcon = Icons.help; statusColor = Colors.grey;
              }

              return Card(
                child: RadioListTile<String>(
                  secondary: Icon(statusIcon, color: statusColor),
                  title: Text(AppLocalizations.of(context, code)),
                  value: code,
                  groupValue: _currentStatusCode,
                  activeColor: Color(0xFFFF4009),
                  onChanged: (value) {
                    setState(() {
                      _currentStatusCode = value!;
                    });
                  },
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF4009),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _saveStatus,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(AppLocalizations.of(context, 'save_status'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
