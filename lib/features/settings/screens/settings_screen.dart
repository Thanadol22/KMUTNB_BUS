import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/localization_provider.dart';
import '../../../core/utils/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // เรียกใช้ Provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final locProvider = Provider.of<LocalizationProvider>(context);

    // ดึงรหัสภาษาปัจจุบันเพื่อใช้กับ Dropdown
    String currentLanguage = locProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            AppLocalizations.of(context, 'account'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(AppLocalizations.of(context, 'edit_profile')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(AppLocalizations.of(context, 'change_password')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(height: 32),
          Text(
            AppLocalizations.of(context, 'app_settings'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.g_translate),
            title: Text(AppLocalizations.of(context, 'change_language')),
            trailing: DropdownButton<String>(
              value: currentLanguage,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'th', child: Text('ไทย')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) {
                  locProvider.setLocale(Locale(value));
                }
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text(AppLocalizations.of(context, 'dark_mode')),
            value: themeProvider.isDarkMode,
            activeColor: Colors.orange,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              AppLocalizations.of(context, 'logout'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
