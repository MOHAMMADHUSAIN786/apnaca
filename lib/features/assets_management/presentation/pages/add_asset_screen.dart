import 'package:flutter/material.dart';
import '../../../../database/app_database.dart';

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _usefulLifeCtrl = TextEditingController(text: '5');
  final _depreciationCtrl = TextEditingController(text: '10');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final data = {
      'name': _nameCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'purchase_price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'current_value': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'useful_life_yrs': int.tryParse(_usefulLifeCtrl.text.trim()) ?? 5,
      'depreciation_pct': double.tryParse(_depreciationCtrl.text.trim()) ?? 10.0,
      'purchase_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    await AppDatabase.instance.insertAsset(data);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset Added')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Business Asset')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Asset Name (e.g. Printer, AC, Truck)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category (Electronics, Vehicles, Furniture)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Purchase Price'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _usefulLifeCtrl,
                      decoration: const InputDecoration(labelText: 'Useful Life (Years)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _depreciationCtrl,
                      decoration: const InputDecoration(labelText: 'Depreciation % per year'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Asset'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
