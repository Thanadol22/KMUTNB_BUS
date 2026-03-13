import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  String _currentStatusCode = 'status_ready';

  final List<String> _statusCodes = [
    'status_ready',
    'status_stop',
    'status_maintain',
    'status_fuel'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'manage_status')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context, 'current_status'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statusCodes.map((code) => RadioListTile<String>(
                  title: Text(AppLocalizations.of(context, code)),
                  value: code,
                  groupValue: _currentStatusCode,
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    setState(() {
                      _currentStatusCode = value!;
                    });
                  },
                )),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final statusText = AppLocalizations.of(context, _currentStatusCode);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context, 'status_updated') + statusText),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text(AppLocalizations.of(context, 'save_status'), style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
