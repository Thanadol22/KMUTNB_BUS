import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/schedule_data.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentRound = ScheduleData.findNearestRound(now);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  'ตารางเวลาวิ่งรถสองแถว',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xE6FF4009),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'มจพ. วิทยาเขตปราจีนบุรี',
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
            child: SingleChildScrollView(
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
                        'รอบ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF4009)),
                      ),
                    ),
                    ...ScheduleData.stopNamesShort.map((name) => DataColumn(
                      label: Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFF4009)),
                      ),
                    )),
                  ],
                  rows: List.generate(ScheduleData.roundStartTimes.length, (index) {
                    final stopTimes = ScheduleData.getStopTimes(index);
                    final isCurrentRound = index == currentRound;

                    // ตรวจว่ารอบนี้ผ่านไปแล้วหรือยัง
                    final endParts = ScheduleData.roundEndTimes[index].split(':');
                    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                    final nowMinutes = now.hour * 60 + now.minute;
                    final isPassed = endMinutes < nowMinutes;

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
                  'ผู้รับผิดชอบ',
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
                          '${driver['name']}  โทร. ${driver['phone']}',
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
