import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/services/firebase_database.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final DatabaseService _dbService = DatabaseService();
  String? _busId;

  @override
  void initState() {
    super.initState();
    _loadBusId();
  }

  Future<void> _loadBusId() async {
    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) return;

      final busQuery = await _dbService.getBusForDriver(uid);
      if (busQuery != null && busQuery.docs.isNotEmpty) {
        final busDoc = busQuery.docs.first;
        final busData = busDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _busId = busData['bus_id'] ?? busDoc.id;
          });
        }
      }
    } catch (e) {
      // ไม่มีข้อมูลรถ
    }
  }

  /// คำนวณเวลาที่เหลือจากเวลาปัจจุบันถึงรอบวิ่ง
  String _getTimeRemaining(String startTime) {
    try {
      final parts = startTime.split(':');
      if (parts.length != 2) return '';

      final now = DateTime.now();
      final targetHour = int.parse(parts[0]);
      final targetMinute = int.parse(parts[1]);
      final target = DateTime(now.year, now.month, now.day, targetHour, targetMinute);

      final diff = target.difference(now);

      if (diff.isNegative) {
        return AppLocalizations.of(context, 'round_passed');
      }

      if (diff.inMinutes <= 15) {
        // แจ้งเตือนเมื่อเหลือไม่เกิน 15 นาที
        return '⚠️ ${AppLocalizations.of(context, 'time_remaining')}: ${diff.inMinutes} ${AppLocalizations.of(context, 'minutes')}';
      }

      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (hours > 0) {
        return '${AppLocalizations.of(context, 'time_remaining')}: $hours ${AppLocalizations.of(context, 'hours')} $minutes ${AppLocalizations.of(context, 'minutes')}';
      }
      return '${AppLocalizations.of(context, 'time_remaining')}: $minutes ${AppLocalizations.of(context, 'minutes')}';
    } catch (e) {
      return '';
    }
  }

  bool _isUpcoming(String startTime) {
    try {
      final parts = startTime.split(':');
      if (parts.length != 2) return false;

      final now = DateTime.now();
      final targetHour = int.parse(parts[0]);
      final targetMinute = int.parse(parts[1]);
      final target = DateTime(now.year, now.month, now.day, targetHour, targetMinute);

      final diff = target.difference(now);
      return diff.inMinutes >= 0 && diff.inMinutes <= 15;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'alert_queue')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notification_add),
            tooltip: AppLocalizations.of(context, 'test_notification'),
            onPressed: () {
              NotificationService().showLocalNotification(
                AppLocalizations.of(context, 'test_notification'),
                AppLocalizations.of(context, 'test_notification_body'),
              );
            },
          ),
        ],
      ),
      body: _busId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bus, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context, 'no_bus_assigned'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _dbService.getSchedulesForBus(_busId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  // ลองดึง schedules ทั้งหมด
                  return StreamBuilder<QuerySnapshot>(
                    stream: _dbService.getSchedulesStream(),
                    builder: (context, allSnapshot) {
                      if (!allSnapshot.hasData || allSnapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.schedule, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context, 'no_schedule'),
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }
                      return _buildScheduleList(allSnapshot.data!.docs);
                    },
                  );
                }

                return _buildScheduleList(snapshot.data!.docs);
              },
            ),
    );
  }

  Widget _buildScheduleList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final startTime = data['start_time'] ?? '-';
        final endTime = data['end_time'] ?? '-';
        final routeName = data['route_name'] ?? '-';
        final upcoming = _isUpcoming(startTime);
        final timeRemaining = _getTimeRemaining(startTime);

        return Card(
          color: upcoming ? Color(0x1AFF4009) : null,
          elevation: upcoming ? 3 : 1,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: upcoming
                ? const BorderSide(color: Color(0xFFFF4009), width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: Icon(
              upcoming ? Icons.warning_amber_rounded : Icons.schedule,
              color: upcoming ? Color(0xFFFF4009) : Colors.blue,
              size: 32,
            ),
            title: Text(
              '${AppLocalizations.of(context, 'time_label')}: $startTime - $endTime',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: upcoming ? Color(0xE6FF4009) : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${AppLocalizations.of(context, 'route_label')}: $routeName'),
                if (timeRemaining.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timeRemaining,
                      style: TextStyle(
                        color: upcoming ? Colors.red : Colors.grey,
                        fontWeight: upcoming ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
