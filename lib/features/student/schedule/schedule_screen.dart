import 'package:flutter/material.dart';
import '../../../core/utils/mock_data.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตารางเวลารถ'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: MockData.schedules.length,
        itemBuilder: (context, index) {
          final schedule = MockData.schedules[index];
          final isDeparted = schedule['status'] == 'ออกเดินทางแล้ว';

          return Card(
            child: ListTile(
              leading: Icon(
                Icons.access_time,
                color: isDeparted ? Colors.grey : Colors.orange,
              ),
              title: Text(
                'เวลาออกรถ: ${schedule['time']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('เส้นทาง: ${schedule['route']}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDeparted ? Colors.grey[200] : Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  schedule['status'] ?? '',
                  style: TextStyle(
                    color: isDeparted ? Colors.grey[600] : Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
