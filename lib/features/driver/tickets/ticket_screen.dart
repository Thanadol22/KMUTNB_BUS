import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/services/firebase_database.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../models/schedule_model.dart';
import '../../../models/ticket_report.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({Key? key}) : super(key: key);

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

  class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _ticketCountController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  ScheduleModel? _selectedRound;
  String? _busId;
  bool _isSubmitting = false;
  List<ScheduleModel> _allRounds = [];
  bool _showAllReports = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final uid = await AuthService.getCurrentUserId();
      String? busId;
      if (uid != null) {
        final busQuery = await _dbService.getBusForDriver(uid);
        if (busQuery != null && busQuery.docs.isNotEmpty) {
          final busDoc = busQuery.docs.first;
          final busData = busDoc.data() as Map<String, dynamic>;
          busId = busData['bus_id'] ?? busDoc.id;
        }
      }

      final rawSchedules = await _dbService.getSchedulesList();
      
      final Map<String, ScheduleModel> deduped = {};
      for (var s in rawSchedules) {
         if (!deduped.containsKey(s.startTime)) {
           deduped[s.startTime] = s;
         }
      }
      final schedules = deduped.values.toList();
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      final now = DateTime.now();
      int nearestIndex = -1;
      int bestDiff = 999999;
      final nowMinutes = now.hour * 60 + now.minute;

      for (int i = 0; i < schedules.length; i++) {
        final startParts = schedules[i].startTime.split(':');
        if (startParts.length < 2) continue;
        final roundMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        
        final endParts = schedules[i].endTime.split(':');
        final endMinutes = endParts.length >= 2 
            ? int.parse(endParts[0]) * 60 + int.parse(endParts[1]) 
            : roundMinutes + 25;

        int diff = (roundMinutes - nowMinutes).abs();

        if (nowMinutes >= roundMinutes && nowMinutes <= endMinutes) {
          nearestIndex = i;
          break;
        }
        if (roundMinutes > nowMinutes) {
          if (diff < bestDiff) {
            bestDiff = diff;
            nearestIndex = i;
          }
        }
      }

      if (nearestIndex == -1 && schedules.isNotEmpty) {
        for (int i = schedules.length - 1; i >= 0; i--) {
          final startParts = schedules[i].startTime.split(':');
          if (startParts.length < 2) continue;
          final roundMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          if (roundMinutes <= nowMinutes) {
            nearestIndex = i;
            break;
          }
        }
        if (nearestIndex == -1) nearestIndex = 0;
      }

      if (mounted) {
        setState(() {
          _allRounds = schedules;
          _selectedRound = nearestIndex != -1 ? schedules[nearestIndex] : (schedules.isNotEmpty ? schedules[0] : null);
          _busId = busId;
        });
      }
    } catch (e) {
      // fallback
    }
  }

  Future<void> _submitTicketReport() async {
    final countText = _ticketCountController.text.trim();

    if (countText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context, 'enter_ticket_count')),
        ),
      );
      return;
    }

    final ticketCount = int.tryParse(countText);
    if (ticketCount == null || ticketCount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context, 'invalid_ticket_count')),
        ),
      );
      return;
    }

    if (_selectedRound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context, 'select_round_time')),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) throw Exception('No user logged in');

      final roundTime = _selectedRound!.startTime;

      final report = TicketReportModel(
        reportId: '',
        driverId: uid,
        busId: _busId ?? '',
        ticketCount: ticketCount,
        roundTime: roundTime,
      );

      await _dbService.submitTicketReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context, 'ticket_updated')),
            backgroundColor: Colors.green,
          ),
        );
        _ticketCountController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context, 'error_prefix')}: ${e.toString()}',
            ),
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

  void _onNumberPressed(String digit) {
    if (_ticketCountController.text.length < 5) {
      // Limit to 5 digits
      setState(() {
        _ticketCountController.text += digit;
      });
    }
  }

  void _onDeletePressed() {
    if (_ticketCountController.text.isNotEmpty) {
      setState(() {
        _ticketCountController.text = _ticketCountController.text.substring(
          0,
          _ticketCountController.text.length - 1,
        );
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _ticketCountController.clear();
    });
  }

  Widget _buildKey(
    String label, {
    IconData? icon,
    VoidCallback? onPressed,
    Color? color, // ใช้เป็นสีพื้นหลังถ้าต้องการปุ่มแบบทึบ
  }) {
    final primaryColor = const Color(0xFFFF4009);
    final isSolid = color != null;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Center(
          child: Material(
            color: isSolid ? color : Colors.transparent,
            shape: CircleBorder(
              side: BorderSide(color: primaryColor, width: 1.5),
            ),
            child: InkWell(
              onTap: onPressed ?? () => _onNumberPressed(label),
              customBorder: const CircleBorder(),
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(
                        icon,
                        size: 24,
                        color: isSolid ? Colors.white : primaryColor,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isSolid ? Colors.white : primaryColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticketCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'ticket_report')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bus info
            if (_busId != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFFFF4009),
                  ),
                  title: Text(
                    '${AppLocalizations.of(context, 'bus_label')}: $_busId',
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Auto-detected round
            Text(
              AppLocalizations.of(context, 'select_round_time'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Dropdown แสดงรอบใกล้เคียง
            DropdownButtonFormField<ScheduleModel>(
              value: _selectedRound,
              isExpanded: true,
              items: _allRounds.map((round) {
                final startTime = round.startTime;
                final endTime = round.endTime;
                final roundNum = _allRounds.indexOf(round) + 1;

                // ตรวจสอบว่าเป็นรอบปัจจุบันหรือไม่
                final startParts = startTime.split(':');
                final startMin =
                    int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                final endParts = endTime.split(':');
                final endMin = endParts.length >= 2 ?
                    int.parse(endParts[0]) * 60 + int.parse(endParts[1]) : startMin + 25;

                String label =
                    '${AppLocalizations.of(context, 'round_label_short')} $roundNum ($startTime - $endTime)';
                if (nowMinutes >= startMin && nowMinutes <= endMin) {
                  label +=
                      ' ← ${AppLocalizations.of(context, 'status_running')}';
                } else if (startMin > nowMinutes &&
                    startMin - nowMinutes <= 30) {
                  label +=
                      ' ← ${AppLocalizations.of(context, 'next_label_short')}';
                } else if (endMin < nowMinutes) {
                  label += ' (${AppLocalizations.of(context, 'round_passed')})';
                }

                return DropdownMenuItem<ScheduleModel>(
                  value: round,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: (endMin < nowMinutes) ? Colors.grey : null,
                      fontWeight:
                          (nowMinutes >= startMin && nowMinutes <= endMin)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRound = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(
                  Icons.access_time,
                  color: Color(0xFFFF4009),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // จำนวนตั๋ว
            Text(
              AppLocalizations.of(context, 'exact_passenger_count'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // ช่องแสดงจำนวนตั๋ว
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number,
                    color: Color(0xFFFF4009),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _ticketCountController.text.isEmpty
                          ? AppLocalizations.of(
                              context,
                              'enter_exact_passenger',
                            )
                          : _ticketCountController.text,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _ticketCountController.text.isEmpty
                            ? Colors.grey
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (_ticketCountController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: _onClearPressed,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // แป้นพิมพ์ตัวเลข
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
                  ),
                  Row(
                    children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
                  ),
                  Row(
                    children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
                  ),
                  Row(
                    children: [
                      _buildKey(
                        'C',
                        color: const Color(0xFFFF4009),
                        onPressed: _onClearPressed,
                      ),
                      _buildKey('0'),
                      _buildKey(
                        '⌫',
                        icon: Icons.backspace_outlined,
                        color: const Color(0xFFFF4009),
                        onPressed: _onDeletePressed,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ปุ่มบันทึก
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF4009),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSubmitting ? null : _submitTicketReport,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        AppLocalizations.of(context, 'save_ticket'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // ประวัติรายงานล่าสุด
            Text(
              AppLocalizations.of(context, 'recent_reports'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            FutureBuilder<String?>(
              future: AuthService.getCurrentUserId(),
              builder: (context, uidSnapshot) {
                if (!uidSnapshot.hasData || uidSnapshot.data == null) {
                  return const SizedBox.shrink();
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getTicketReportsForDriver(
                    uidSnapshot.data!,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context, 'no_reports'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    }

                    // เรียงลำดับจากใหม่ไปเก่า (descending) ด้วยตัวแอปเอง เพื่อเลี่ยงปัญหา Composite Index
                    final allDocs = snapshot.data!.docs.toList();
                    allDocs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final tsA = dataA['timestamp'] as Timestamp?;
                      final tsB = dataB['timestamp'] as Timestamp?;
                      if (tsA == null && tsB == null) return 0;
                      if (tsA == null) return 1;
                      if (tsB == null) return -1;
                      return tsB.compareTo(tsA);
                    });

                    final reports = _showAllReports
                        ? allDocs
                        : allDocs.take(3).toList();
                    return Column(
                      children: [
                        ...reports.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final timestamp = (data['timestamp'] as Timestamp?)
                              ?.toDate();
                          final dateStr = timestamp != null
                              ? '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                              : '-';
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.receipt_long,
                                color: Color(0xFFFF4009),
                              ),
                              title: Text(
                                '${AppLocalizations.of(context, 'ticket_count_label')}: ${data['ticket_count'] ?? 0}',
                              ),
                              subtitle: Text(
                                '${AppLocalizations.of(context, 'round_time_label')}: ${data['round_time'] ?? '-'} | $dateStr',
                              ),
                            ),
                          );
                        }).toList(),
                        if (allDocs.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllReports = !_showAllReports;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _showAllReports
                                        ? AppLocalizations.of(
                                            context,
                                            'show_less_reports',
                                          )
                                        : AppLocalizations.of(
                                            context,
                                            'view_all_reports',
                                          ),
                                    style: const TextStyle(
                                      color: Color(0xFFFF4009),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _showAllReports
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: const Color(0xFFFF4009),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
