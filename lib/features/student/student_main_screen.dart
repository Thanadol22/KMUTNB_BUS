import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';
import 'map/map_screen.dart';
import 'schedule/schedule_screen.dart';
import 'report/report_screen.dart';
import '../settings/screens/settings_screen.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({Key? key}) : super(key: key);

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const MapScreen(),
    const ScheduleScreen(),
    const ReportScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.map), label: AppLocalizations.of(context, 'map')),
          BottomNavigationBarItem(icon: const Icon(Icons.schedule), label: AppLocalizations.of(context, 'schedule')),
          BottomNavigationBarItem(icon: const Icon(Icons.report_problem), label: AppLocalizations.of(context, 'report')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: AppLocalizations.of(context, 'settings')),
        ],
      ),
    );
  }
}

