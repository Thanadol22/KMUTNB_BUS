import 'package:flutter/material.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedIssue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แจ้งปัญหาการใช้บริการ'),
        backgroundColor: Colors.orange,
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
                  DropdownMenuItem(value: 'late', child: Text('ช้ากว่ากำหนดมากๆ')),
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
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(
                           content: Text('ส่งรายงานสำเร็จ (จำลองข้อมูล)'),
                           backgroundColor: Colors.green,
                         ),
                      );
                      _formKey.currentState!.reset();
                      setState(() {
                        _selectedIssue = null;
                      });
                    }
                  },
                  child: const Text('ส่งรายงาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
