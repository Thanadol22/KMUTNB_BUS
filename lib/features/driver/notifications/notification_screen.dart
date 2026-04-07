import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/services/firebase_database.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/driver_schedule_notifier.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final DatabaseService _dbService = DatabaseService();
  final DriverScheduleNotifier _notifier = DriverScheduleNotifier();
  String? _busId;
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBusId();

    // รีเฟรช UI ทุก 30 วินาที เพื่ออัปเดตเวลาเหลือ
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    super.dispose();
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
      final target = DateTime(
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      final diff = target.difference(now);

      if (diff.isNegative) {
        return AppLocalizations.of(context, 'round_passed');
      }

      if (diff.inMinutes <= 5) {
        return '🔴 ${AppLocalizations.of(context, 'time_remaining')}: ${diff.inMinutes} ${AppLocalizations.of(context, 'minutes')}';
      }

      if (diff.inMinutes <= 15) {
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

  /// ตรวจว่ายังไม่ถึงเวลา และเหลือน้อยกว่า 15 นาที
  bool _isUpcoming(String startTime) {
    try {
      final parts = startTime.split(':');
      if (parts.length != 2) return false;

      final now = DateTime.now();
      final targetHour = int.parse(parts[0]);
      final targetMinute = int.parse(parts[1]);
      final target = DateTime(
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      final diff = target.difference(now);
      return diff.inMinutes >= 0 && diff.inMinutes <= 15;
    } catch (e) {
      return false;
    }
  }

  /// ตรวจว่าเหลือน้อยกว่า 5 นาที (urgently soon)
  bool _isUrgent(String startTime) {
    try {
      final parts = startTime.split(':');
      if (parts.length != 2) return false;

      final now = DateTime.now();
      final targetHour = int.parse(parts[0]);
      final targetMinute = int.parse(parts[1]);
      final target = DateTime(
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      final diff = target.difference(now);
      return diff.inMinutes >= 0 && diff.inMinutes <= 5;
    } catch (e) {
      return false;
    }
  }

  /// ตรวจว่ารอบนี้ผ่านไปแล้ว
  bool _isPassed(String startTime) {
    try {
      final parts = startTime.split(':');
      if (parts.length != 2) return false;

      final now = DateTime.now();
      final targetHour = int.parse(parts[0]);
      final targetMinute = int.parse(parts[1]);
      final target = DateTime(
        now.year,
        now.month,
        now.day,
        targetHour,
        targetMinute,
      );

      return target.difference(now).isNegative;
    } catch (e) {
      return false;
    }
  }

  // ไม่ต้องใช้ _toggleNotifier อีกต่อไป เนื่องจากแจ้งเตือนอัตโนมัติแล้ว

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      body: Column(
        children: [
          // ======= การ์ดสถานะแจ้งเตือนอัตโนมัติ =======
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4009), Color(0xFFFF6B3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4009).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                            'auto_notification_toggle',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(
                            context,
                            'notification_active_desc',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.white),
                ],
              ),
            ),
          ),

          // ======= ข้อมูลการแจ้งเตือน =======
          if (_notifier.isRunning)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.shade900.withOpacity(0.3)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.shade300.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context, 'notification_info'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.orange.shade200
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // ======= รายการรอบรถ =======
          Expanded(
            child: _busId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions_bus,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context, 'no_bus_assigned'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
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
                        return StreamBuilder<QuerySnapshot>(
                          stream: _dbService.getSchedulesStream(),
                          builder: (context, allSnapshot) {
                            if (!allSnapshot.hasData ||
                                allSnapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                        'no_schedule',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(List<QueryDocumentSnapshot> docs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // เรียงลำดับคิว: คิวที่ใกล้จะถึง (เวลาในอนาคต) ขึ้นก่อน และคิวที่ผ่านไปแล้วไว้ล่างสุด
    final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
    sortedDocs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aStart = aData['start_time'] ?? '';
      final bStart = bData['start_time'] ?? '';

      try {
        final aParts = aStart.split(':');
        final bParts = bStart.split(':');

        if (aParts.length == 2 && bParts.length == 2) {
          final now = DateTime.now();
          final aTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(aParts[0]),
            int.parse(aParts[1]),
          );
          final bTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(bParts[0]),
            int.parse(bParts[1]),
          );

          final aPassed = aTime.isBefore(now);
          final bPassed = bTime.isBefore(now);

          if (aPassed && !bPassed) return 1;
          if (!aPassed && bPassed) return -1;
          return aTime.compareTo(bTime);
        }
      } catch (e) {
        return 0;
      }
      return 0;
    });

    // ค้นหารอบที่กำลังจะมาถึงเป็นอันดับแรก (index ของรอบที่ยังไม่ผ่าน)
    int nextRoundIndex = -1;
    for (int i = 0; i < sortedDocs.length; i++) {
      final data = sortedDocs[i].data() as Map<String, dynamic>;
      if (!_isPassed(data['start_time'] ?? '')) {
        nextRoundIndex = i;
        break;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        final data = sortedDocs[index].data() as Map<String, dynamic>;
        final startTime = data['start_time'] ?? '-';
        final endTime = data['end_time'] ?? '-';
        final routeName = data['route_name'] ?? '-';
        final upcoming = _isUpcoming(startTime);
        final urgent = _isUrgent(startTime);
        final passed = _isPassed(startTime);
        final timeRemaining = _getTimeRemaining(startTime);
        final isNextRound = index == nextRoundIndex;

        bool is15MinPassed = false;
        bool isDepartPassed = false;
        try {
          final p = startTime.split(':');
          if (p.length == 2) {
            final now = DateTime.now();
            final target = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(p[0]),
              int.parse(p[1]),
            );
            is15MinPassed = now.isAfter(
              target.subtract(const Duration(minutes: 15)),
            );
            isDepartPassed = now.isAfter(target);
          }
        } catch (_) {}

        // ไอคอนและสีตามสถานะ
        IconData icon;
        Color iconColor;
        Color? cardColor;
        BorderSide borderSide;

        if (isNextRound) {
          icon = urgent ? Icons.alarm_on : Icons.stars;
          iconColor = urgent ? Colors.red : const Color(0xFFFF4009);
          cardColor = isDark
              ? const Color(0xFFFF4009).withOpacity(0.1)
              : const Color(0xFFFF4009).withOpacity(0.05);
          borderSide = const BorderSide(color: Color(0xFFFF4009), width: 2.5);
        } else if (urgent) {
          icon = Icons.alarm_on;
          iconColor = Colors.red;
          cardColor = Colors.red.withOpacity(0.08);
          borderSide = const BorderSide(color: Colors.red, width: 2);
        } else if (upcoming) {
          icon = Icons.warning_amber_rounded;
          iconColor = const Color(0xFFFF4009);
          cardColor = const Color(0x1AFF4009);
          borderSide = const BorderSide(color: Color(0xFFFF4009), width: 1.5);
        } else if (passed) {
          icon = Icons.check_circle_outline;
          iconColor = Colors.grey;
          cardColor = null;
          borderSide = BorderSide.none;
        } else {
          icon = Icons.schedule;
          iconColor = Colors.blue;
          cardColor = null;
          borderSide = BorderSide.none;
        }

        return Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                color: cardColor,
                elevation: isNextRound ? 5 : ((upcoming || urgent) ? 3 : 1),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: borderSide,
                ),
                child: ListTile(
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      icon,
                      key: ValueKey(icon),
                      color: iconColor,
                      size: isNextRound ? 38 : 32,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        '${AppLocalizations.of(context, 'time_label')}: $startTime - $endTime',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isNextRound ? 17 : 16,
                          color: isNextRound || urgent
                              ? (isNextRound
                                    ? const Color(0xFFFF4009)
                                    : Colors.red)
                              : upcoming
                              ? const Color(0xE6FF4009)
                              : passed
                              ? Colors.grey
                              : null,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context, 'route_label')}: $routeName',
                      ),
                      if (timeRemaining.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            timeRemaining,
                            style: TextStyle(
                              color: isNextRound || urgent
                                  ? (isNextRound
                                        ? const Color(0xFFFF4009)
                                        : Colors.red)
                                  : upcoming
                                  ? Colors.deepOrange
                                  : Colors.grey,
                              fontWeight: (isNextRound || upcoming || urgent)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      // แสดงแท็กสถานะการแจ้งเตือน
                      if (_notifier.isRunning && (upcoming || urgent))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              _buildNotifBadge(
                                '15 ${AppLocalizations.of(context, 'minutes')}',
                                is15MinPassed,
                              ),
                              const SizedBox(width: 6),
                              _buildNotifBadge(
                                AppLocalizations.of(context, 'depart_now'),
                                isDepartPassed,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (isNextRound)
              Positioned(
                top: 0,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4009),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    AppLocalizations.of(context, 'next_round'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Badge แสดงว่า notification ส่งไปแล้วหรือยัง
  Widget _buildNotifBadge(String label, bool sent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sent
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sent ? Colors.green : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sent ? Icons.check_circle : Icons.access_time,
            size: 14,
            color: sent ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: sent ? Colors.green.shade700 : Colors.grey,
              fontWeight: sent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
