import 'package:flutter/material.dart';
import '../../../../database/app_database.dart';

class CreateRepairJobScreen extends StatefulWidget {
  const CreateRepairJobScreen({super.key});

  @override
  State<CreateRepairJobScreen> createState() => _CreateRepairJobScreenState();
}

class _CreateRepairJobScreenState extends State<CreateRepairJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deviceTypeCtrl = TextEditingController();
  final _deviceModelCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _chargesCtrl = TextEditingController(text: '0');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final jobNumber = 'JOB-${DateTime.now().millisecondsSinceEpoch}';
    final data = {
      'job_number': jobNumber,
      'customer_name': _customerNameCtrl.text.trim(),
      'customer_phone': _phoneCtrl.text.trim(),
      'device_type': _deviceTypeCtrl.text.trim(),
      'device_model': _deviceModelCtrl.text.trim(),
      'issue_reported': _issueCtrl.text.trim(),
      'service_charges': double.tryParse(_chargesCtrl.text.trim()) ?? 0.0,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    await AppDatabase.instance.insertRepairJob(data);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job Card Created')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Job Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _customerNameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deviceTypeCtrl,
                decoration: const InputDecoration(labelText: 'Device Type (e.g. Mobile, AC)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deviceModelCtrl,
                decoration: const InputDecoration(labelText: 'Device Model/Brand'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _issueCtrl,
                decoration: const InputDecoration(labelText: 'Reported Issue'),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _chargesCtrl,
                decoration: const InputDecoration(labelText: 'Estimated Service Charges'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Job Card'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
