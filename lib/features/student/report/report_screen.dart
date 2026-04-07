import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/utils/app_localizations.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();
  String? _selectedIssue;
  bool _isSubmitting = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? studentId = await AuthService.getCurrentUserId();
      if (studentId == null) {
        throw Exception('User UID not found. Please relogin.');
      }

      // Convert enum/value to topic based on database.md spec
      String topicName = '';
      if (_selectedIssue == 'late') topicName = 'รถไม่มาตรงเวลา';
      else if (_selectedIssue == 'driver') topicName = 'พฤติกรรมพนักงานขับรถ';
      else if (_selectedIssue == 'app') topicName = 'แอปพลิเคชันมีปัญหา';
      else topicName = 'อื่นๆ';

      await _firestore.collection('issue_reports').add({
        'student_id': studentId,
        'topic': topicName,
        'description': _descController.text.trim(),
        'status': 'pending', // (รอดำเนินการ)
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context, 'report_success')),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _descController.clear();
        setState(() {
          _selectedIssue = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'report_issue_title')),
        backgroundColor: Color(0xFFFF4009),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context, 'issue_topic'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedIssue,
                items: [
                  DropdownMenuItem(value: 'late', child: Text(AppLocalizations.of(context, 'issue_late'))),
                  DropdownMenuItem(value: 'driver', child: Text(AppLocalizations.of(context, 'issue_driver'))),
                  DropdownMenuItem(value: 'app', child: Text(AppLocalizations.of(context, 'issue_app'))),
                  DropdownMenuItem(value: 'other', child: Text(AppLocalizations.of(context, 'issue_other'))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedIssue = value;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                hint: Text(AppLocalizations.of(context, 'select_issue_hint')),
                validator: (value) => value == null ? AppLocalizations.of(context, 'issue_required') : null,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context, 'additional_details'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: AppLocalizations.of(context, 'details_hint'),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context, 'details_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4009),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(AppLocalizations.of(context, 'submit_report'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

