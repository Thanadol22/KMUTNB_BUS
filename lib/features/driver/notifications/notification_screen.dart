import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/services/notification_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ข้อมูลจำลองการแจ้งเตือน (สามารถปรับให้ใช้ AppLocalizations เพิ่มได้ถ้าต้องการ)
    final List<Map<String, String>> notifications = [
      {
        'title': 'เตรียมตัวออกรถ',
        'message': 'เหลือเวลาอีก 15 นาที ก่อนถึงรอบรถ 12:00 น.',
        'time': '11:45 น.',
        'type': 'alert',
      },
      {
        'title': 'แจ้งเตือนรอบถัดไป',
        'message': 'คิวต่อไปของคุณคือรอบ 14:00 น.',
        'time': '12:05 น.',
        'type': 'info',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'alert_queue')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_add),
            tooltip: 'ทดสอบแจ้งเตือน (Local)',
            onPressed: () {
              NotificationService().showLocalNotification(
                'ทดสอบแจ้งเตือน',
                'นี่คือข้อความแจ้งเตือนจำลอง เพื่อเตรียมพร้อมสำหรับ Push Notification!',
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final isAlert = notif['type'] == 'alert';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                isAlert ? Icons.warning_amber_rounded : Icons.info_outline,
                color: isAlert ? Colors.red : Colors.blue,
                size: 32,
              ),
              title: Text(
                notif['title']!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isAlert ? Colors.red : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notif['message']!),
                  const SizedBox(height: 8),
                  Text(
                    notif['time']!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
