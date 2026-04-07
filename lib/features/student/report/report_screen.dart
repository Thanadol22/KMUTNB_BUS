import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';

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
          const SnackBar(
            content: Text('ส่งรายงานความร้องเรียนสำเร็จ'),
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
        title: const Text('แจ้งปัญหาการใช้บริการ'),
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
              const Text(
                'หัวข้อปัญหา',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedIssue,
                items: const [
                  DropdownMenuItem(value: 'late', child: Text('รถไม่มาตรงเวลา')),
                  DropdownMenuItem(value: 'driver', child: Text('พฤติกรรมพนักงานขับรถ')),
                  DropdownMenuItem(value: 'app', child: Text('แอปพลิเคชันมีปัญหา')),
                  DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
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
                hint: const Text('เลือกปัญหาที่พบ'),
                validator: (value) => value == null ? 'กรุณาเลือกหัวข้อปัญหา' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'รายละเอียดเพิ่มเติม',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'อธิบายปัญหาที่พบเพิ่มเติม...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรายละเอียด';
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
                      : const Text('ส่งรายงาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

