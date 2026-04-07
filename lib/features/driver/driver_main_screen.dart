import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';
import 'status/status_screen.dart';
import 'tickets/ticket_screen.dart';
import 'notifications/notification_screen.dart';
import '../settings/screens/settings_screen.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({Key? key}) : super(key: key);

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const StatusScreen(),
    const TicketScreen(),
    const NotificationScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Color(0xFFFF4009),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.directions_bus),
            label: AppLocalizations.of(context, 'driver_status'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.confirmation_number),
            label: AppLocalizations.of(context, 'ticket_report'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notifications),
            label: AppLocalizations.of(context, 'notifications'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.of(context, 'settings'),
          ),
        ],
      ),
    );
  }
}
