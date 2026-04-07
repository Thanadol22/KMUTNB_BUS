import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/services/firebase_database.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/schedule_data.dart';
import '../../../models/ticket_report.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({Key? key}) : super(key: key);

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _ticketCountController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  int? _selectedRoundIndex;
  String? _busId;
  bool _isSubmitting = false;
  List<int> _nearbyRounds = [];

  @override
  void initState() {
    super.initState();
    _initAutoRound();
  }

  Future<void> _initAutoRound() async {
    try {
      // หารอบใกล้เคียงจากเวลาปัจจุบัน
      final now = DateTime.now();
      final nearbyRounds = ScheduleData.getNearbyRounds(now);
      final nearestRound = ScheduleData.findNearestRound(now);

      // หา bus_id ของคนขับ
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

      if (mounted) {
        setState(() {
          _nearbyRounds = nearbyRounds;
          _selectedRoundIndex = nearestRound;
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
        SnackBar(content: Text(AppLocalizations.of(context, 'enter_ticket_count'))),
      );
      return;
    }

    final ticketCount = int.tryParse(countText);
    if (ticketCount == null || ticketCount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'invalid_ticket_count'))),
      );
      return;
    }

    if (_selectedRoundIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'select_round_time'))),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uid = await AuthService.getCurrentUserId();
      if (uid == null) throw Exception('No user logged in');

      final roundTime = ScheduleData.roundStartTimes[_selectedRoundIndex!];

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
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
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
                  leading: const Icon(Icons.directions_bus, color: Color(0xFFFF4009)),
                  title: Text('${AppLocalizations.of(context, 'bus_label')}: $_busId'),
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
            DropdownButtonFormField<int>(
              value: _selectedRoundIndex,
              isExpanded: true,
              items: _nearbyRounds.map((roundIndex) {
                final startTime = ScheduleData.roundStartTimes[roundIndex];
                final endTime = ScheduleData.roundEndTimes[roundIndex];
                final roundNum = roundIndex + 1;

                // ตรวจสอบว่าเป็นรอบปัจจุบันหรือไม่
                final startParts = startTime.split(':');
                final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                final endParts = endTime.split(':');
                final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

                String label = 'รอบ $roundNum ($startTime - $endTime)';
                if (nowMinutes >= startMin && nowMinutes <= endMin) {
                  label += ' ← กำลังวิ่ง';
                } else if (startMin > nowMinutes && startMin - nowMinutes <= 30) {
                  label += ' ← ถัดไป';
                } else if (endMin < nowMinutes) {
                  label += ' (ผ่านไปแล้ว)';
                }

                return DropdownMenuItem<int>(
                  value: roundIndex,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: (endMin < nowMinutes) ? Colors.grey : null,
                      fontWeight: (nowMinutes >= startMin && nowMinutes <= endMin)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRoundIndex = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.access_time, color: Color(0xFFFF4009)),
              ),
            ),

            // ปุ่มดูทุกรอบ
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.list, size: 18),
                label: Text(AppLocalizations.of(context, 'show_all_rounds')),
                onPressed: () {
                  setState(() {
                    // แสดงทุกรอบ
                    _nearbyRounds = List.generate(
                      ScheduleData.roundStartTimes.length,
                      (i) => i,
                    );
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // จำนวนตั๋ว
            Text(
              AppLocalizations.of(context, 'exact_passenger_count'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _ticketCountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: AppLocalizations.of(context, 'enter_exact_passenger'),
                prefixIcon: const Icon(Icons.confirmation_number, color: Color(0xFFFF4009)),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  stream: _dbService.getTicketReportsForDriver(uidSnapshot.data!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
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

                    final reports = allDocs.take(5).toList();
                    return Column(
                      children: reports.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                        final dateStr = timestamp != null
                            ? '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                            : '-';
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long, color: Color(0xFFFF4009)),
                            title: Text('${AppLocalizations.of(context, 'ticket_count_label')}: ${data['ticket_count'] ?? 0}'),
                            subtitle: Text('${AppLocalizations.of(context, 'round_time_label')}: ${data['round_time'] ?? '-'} | $dateStr'),
                          ),
                        );
                      }).toList(),
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
