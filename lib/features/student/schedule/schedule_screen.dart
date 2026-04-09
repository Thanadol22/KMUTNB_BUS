import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/schedule_data.dart';
import '../../../core/services/firebase_database.dart';
import '../../../models/schedule_model.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  List<String> _getStopTimes(String startTime) {
    if (startTime.isEmpty) return [];
    final startParts = startTime.split(':');
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);

    return ScheduleData.stopOffsets.map((offset) {
      int totalMinutes = startHour * 60 + startMinute + offset;
      int hour = (totalMinutes ~/ 60) % 24;
      int minute = totalMinutes % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }).toList();
  }

  int _findCurrentRoundIndex(List<ScheduleModel> schedules, DateTime now) {
    if (schedules.isEmpty) return -1;
    final nowMinutes = now.hour * 60 + now.minute;

    for (int i = 0; i < schedules.length; i++) {
      final startTime = schedules[i].startTime;
      final endTime = schedules[i].endTime;

      if (startTime.isEmpty || endTime.isEmpty) continue;

      final startParts = startTime.split(':');
      final roundMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      
      final endParts = endTime.split(':');
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (nowMinutes >= roundMinutes && nowMinutes <= endMinutes) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'schedule_title')),
        backgroundColor: Color(0xFFFF4009),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0x1AFF4009),
              border: Border(bottom: BorderSide(color: Color(0x4DFF4009))),
            ),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context, 'schedule_header'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xE6FF4009),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context, 'campus_name'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xCCFF4009),
                  ),
                ),
              ],
            ),
          ),

          // ตารางเวลา
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: dbService.getSchedulesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4009)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No schedules found', 
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Map docs to ScheduleModel and sort by start_time
                final schedules = snapshot.data!.docs
                    .map((doc) => ScheduleModel.fromFirestore(doc))
                    .toList();
                
                // Deduplicate by startTime in case db returns multiple overlapping schedules
                final Map<String, ScheduleModel> deduped = {};
                for (var s in schedules) {
                   if (!deduped.containsKey(s.startTime)) {
                     deduped[s.startTime] = s;
                   }
                }
                final uniqueSchedules = deduped.values.toList();
                uniqueSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

                final currentRound = _findCurrentRoundIndex(uniqueSchedules, now);

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Color(0x33FF4009)),
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 44,
                      columns: [
                        DataColumn(
                          label: Text(
                            AppLocalizations.of(context, 'round'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF4009)),
                          ),
                        ),
                        ...List.generate(ScheduleData.stopNamesShort.length, (index) => DataColumn(
                          label: Text(
                            AppLocalizations.of(context, 'stop_short_${index + 1}'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFF4009)),
                          ),
                        )),
                      ],
                      rows: List.generate(uniqueSchedules.length, (index) {
                        final schedule = uniqueSchedules[index];
                        final stopTimes = _getStopTimes(schedule.startTime);
                        final isCurrentRound = index == currentRound;

                        // ตรวจว่ารอบนี้ผ่านไปแล้วหรือยัง
                        bool isPassed = false;
                        if (schedule.endTime.isNotEmpty) {
                          final endParts = schedule.endTime.split(':');
                          final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                          final nowMinutes = now.hour * 60 + now.minute;
                          isPassed = endMinutes < nowMinutes;
                        }

                        return DataRow(
                          color: WidgetStateProperty.all(
                            isCurrentRound
                                ? Color(0x26FF4009)
                                : isPassed
                                    ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                                    : Colors.transparent,
                          ),
                          cells: [
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: isCurrentRound
                                    ? BoxDecoration(
                                        color: Color(0xFFFF4009),
                                        borderRadius: BorderRadius.circular(10),
                                      )
                                    : null,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isCurrentRound ? Colors.white : (isPassed ? Colors.grey : null),
                                  ),
                                ),
                              ),
                            ),
                            ...stopTimes.map((time) => DataCell(
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isPassed ? Colors.grey : (isCurrentRound ? Color(0xE6FF4009) : null),
                                  fontWeight: isCurrentRound ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            )),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),

          // ผู้รับผิดชอบ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context, 'responsible_person'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xE6FF4009)),
                ),
                const SizedBox(height: 4),
                ...ScheduleData.drivers.map((driver) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${driver['name']?.replaceAll('นาย', AppLocalizations.of(context, 'driver_prefix'))}  ${AppLocalizations.of(context, 'driver_phone')}. ${driver['phone']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
