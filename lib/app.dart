import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/localization_provider.dart';
import 'features/auth/screens/auth_check_screen.dart';

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocalizationProvider>(
      builder: (context, themeProvider, localizationProvider, child) {
        return MaterialApp(
          title: 'KMUTNB Bus Tracker',
          debugShowCheckedModeBanner: false,
          locale: localizationProvider.locale, // Localized
          theme: themeProvider.themeData,
          home: const AuthCheckScreen(),
        );
      },
    );
  }
}
