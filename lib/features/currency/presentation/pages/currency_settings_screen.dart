import 'package:flutter/material.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  String _baseCurrency = 'INR';
  final List<Map<String, dynamic>> _rates = [
    {'code': 'USD', 'name': 'US Dollar', 'rate': 83.5, 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'rate': 89.2, 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'rate': 105.1, 'symbol': '£'},
    {'code': 'AED', 'name': 'UAE Dirham', 'rate': 22.7, 'symbol': 'د.إ'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Currency Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Base Currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _baseCurrency,
                      items: ['INR', 'USD', 'EUR', 'GBP'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _baseCurrency = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Exchange Rates (vs INR)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _rates.length,
                itemBuilder: (context, i) {
                  final rate = _rates[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(rate['symbol'])),
                      title: Text('${rate['name']} (${rate['code']})'),
                      subtitle: Text('1 ${rate['code']} = ${rate['rate']} INR'),
                      trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
