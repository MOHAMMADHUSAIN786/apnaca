import 'package:flutter/material.dart';

class EInvoiceGenerateScreen extends StatefulWidget {
  const EInvoiceGenerateScreen({super.key});

  @override
  State<EInvoiceGenerateScreen> createState() => _EInvoiceGenerateScreenState();
}

class _EInvoiceGenerateScreenState extends State<EInvoiceGenerateScreen> {
  final _billNoCtrl = TextEditingController();
  bool _isGenerating = false;
  String? _irn;

  void _generateIrn() async {
    if (_billNoCtrl.text.isEmpty) return;
    setState(() => _isGenerating = true);
    
    // Simulate API call to NIC / GSP
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isGenerating = false;
      _irn = 'a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-Invoice Generated Successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate E-Invoice')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _billNoCtrl,
              decoration: const InputDecoration(
                labelText: 'Enter Sale Bill Number',
                hintText: 'e.g. INV-1001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateIrn,
              child: _isGenerating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Generate IRN & QR Code'),
            ),
            if (_irn != null) ...[
              const SizedBox(height: 32),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 8),
                      const Text('E-Invoice Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('IRN: $_irn', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Print B2B Invoice with QR'),
                        onPressed: () {},
                      )
                    ],
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
