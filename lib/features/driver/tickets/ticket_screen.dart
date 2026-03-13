import 'package:flutter/material.dart';
import '../../../core/utils/app_localizations.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({Key? key}) : super(key: key);

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  String _passengerStatus = 'no_passenger';
  final TextEditingController _exactCountController = TextEditingController();

  @override
  void dispose() {
    _exactCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'ticket_report')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context, 'remaining_tickets'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(AppLocalizations.of(context, 'no_passenger')),
                    subtitle: const Text('0 - 10'),
                    value: 'no_passenger',
                    groupValue: _passengerStatus,
                    onChanged: (val) => setState(() => _passengerStatus = val!),
                  ),
                  RadioListTile<String>(
                    title: Text(AppLocalizations.of(context, 'some_passenger')),
                    subtitle: const Text('11 - 20'),
                    value: 'some_passenger',
                    groupValue: _passengerStatus,
                    onChanged: (val) => setState(() => _passengerStatus = val!),
                  ),
                  RadioListTile<String>(
                    title: Text(AppLocalizations.of(context, 'full_passenger')),
                    subtitle: const Text('21+'),
                    value: 'full_passenger',
                    groupValue: _passengerStatus,
                    onChanged: (val) => setState(() => _passengerStatus = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context, 'exact_passenger_count'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                child: TextField(
                  controller: _exactCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: AppLocalizations.of(
                      context,
                      'enter_exact_passenger',
                    ),
                  ),
                ),
              ),
            ),
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
                  // TODO: เตรียมสำหรับการบันทึกข้อมูลลง Database 
                  // String selectedRange = _passengerStatus;
                  // String exactAmount = _exactCountController.text;
                  // await Firebase/API.savePassengerData(selectedRange, exactAmount);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context, 'ticket_updated'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context, 'save_ticket'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
