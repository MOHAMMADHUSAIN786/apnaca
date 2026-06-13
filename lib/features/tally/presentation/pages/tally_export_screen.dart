import 'package:flutter/material.dart';

class TallyExportScreen extends StatefulWidget {
  const TallyExportScreen({super.key});

  @override
  State<TallyExportScreen> createState() => _TallyExportScreenState();
}

class _TallyExportScreenState extends State<TallyExportScreen> {
  final _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  String _selectedMonth = 'June';
  bool _isExporting = false;

  void _exportToTally() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isExporting = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tally XML Exported! Download started.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tally Export')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 48, color: Colors.blueAccent),
                    const SizedBox(height: 16),
                    const Text('Export to Tally ERP 9 / Prime', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Export your sales, purchases, and ledger entries as XML format directly compatible with Tally.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(labelText: 'Select Month to Export'),
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMonth = v);
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _isExporting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download),
                      label: Text(_isExporting ? 'Exporting XML...' : 'Download Tally XML'),
                      onPressed: _isExporting ? null : _exportToTally,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
