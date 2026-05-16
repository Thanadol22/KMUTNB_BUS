import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';
import 'status/status_screen.dart';
import 'tickets/ticket_screen.dart';
import 'notifications/notification_screen.dart';
import '../settings/screens/driver_profile_screen.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const StatusScreen(),
    const TicketScreen(),
    const NotificationScreen(),
    const DriverProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 14,
        unselectedFontSize: 12,
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
