import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/services/firebase_auth.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/localization_provider.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'driver_license_screen.dart';
import '../../auth/screens/login_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String _name = '';
  String _username = '';
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      String? uid = await AuthService.getCurrentUserId();
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              _name = data['name'] ?? '';
              _username = data['username'] ?? '';
              _profileImageUrl = data['profile_image_url'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final locProvider = Provider.of<LocalizationProvider>(context);
    String currentLanguage = locProvider.locale.languageCode;

    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'account'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFF4009),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  // Profile Header
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage('assets/logo/logo.png') as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _name,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _username,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Personal Info Group
                  _buildSectionHeader(context, AppLocalizations.of(context, 'account')),
                  _buildMenuContainer(context, [
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline,
                      iconColor: Colors.green,
                      iconBgColor: Colors.green.withOpacity(0.1),
                      title: AppLocalizations.of(context, 'edit_profile'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        ).then((_) => _loadProfileData());
                      },
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      icon: Icons.card_membership_outlined,
                      iconColor: Colors.orange,
                      iconBgColor: Colors.orange.withOpacity(0.1),
                      title: AppLocalizations.of(context, 'driver_license'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DriverLicenseScreen()),
                        ).then((_) => _loadProfileData());
                      },
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      context,
                      icon: Icons.lock_outline,
                      iconColor: Colors.blue,
                      iconBgColor: Colors.blue.withOpacity(0.1),
                      title: AppLocalizations.of(context, 'change_password'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 25),

                  // App Settings Group
                  _buildSectionHeader(context, AppLocalizations.of(context, 'app_settings')),
                  _buildMenuContainer(context, [
                    _buildLanguageItem(context, locProvider, currentLanguage),
                    _buildDivider(),
                    _buildDarkModeItem(context, themeProvider),
                  ]),
                  const SizedBox(height: 25),

                  // Logout Group
                  _buildMenuContainer(context, [
                    _buildMenuItem(
                      context,
                      icon: Icons.logout,
                      iconColor: Colors.red,
                      iconBgColor: Colors.red.withOpacity(0.1),
                      title: AppLocalizations.of(context, 'logout'),
                      showTrailing: false,
                      onTap: () async {
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.grey[600]),
      ),
    );
  }

  Widget _buildMenuContainer(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black38 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    bool showTrailing = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: showTrailing ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey) : null,
      onTap: onTap,
    );
  }

  Widget _buildLanguageItem(BuildContext context, LocalizationProvider locProvider, String currentLanguage) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.g_translate, color: Colors.purple, size: 22),
      ),
      title: Text(AppLocalizations.of(context, 'change_language'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: DropdownButton<String>(
        value: currentLanguage,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'th', child: Text('ไทย')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (value) {
          if (value != null) locProvider.setLocale(Locale(value));
        },
      ),
    );
  }

  Widget _buildDarkModeItem(BuildContext context, ThemeProvider themeProvider) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.dark_mode_outlined, color: Colors.indigo, size: 22),
      ),
      title: Text(AppLocalizations.of(context, 'dark_mode'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: Switch.adaptive(
        value: themeProvider.isDarkMode,
        activeColor: const Color(0xFFFF4009),
        onChanged: (value) => themeProvider.toggleTheme(),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, indent: 65, endIndent: 20, color: Color(0xFFF1F1F1));
  }
}
