import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/company_theme_manager.dart';

class CompanySwitcher extends StatefulWidget {
  const CompanySwitcher({super.key});

  @override
  State<CompanySwitcher> createState() => _CompanySwitcherState();
}

class _CompanySwitcherState extends State<CompanySwitcher> {
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final list = await CompanyService.getAllCompanies();
    setState(() {
      _companies = list;
      _loading = false;
    });
  }

  Future<void> _createCompanyDialog() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Create company'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Company name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create'))
        ],
      );
    });
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await CompanyService.createCompany(nameCtrl.text.trim());
      await _loadCompanies();
    }
  }

  Future<void> _editBranding(Map<String,dynamic> company) async {
    final ctrl = TextEditingController(text: company['branding'] ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Edit Branding (JSON)'),
        content: SizedBox(height: 200, child: TextField(controller: ctrl, maxLines: 20, decoration: const InputDecoration(hintText: '{"primaryColor":"#FF0000"}'))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save'))
        ],
      );
    });
    if (ok == true) {
      try {
        final parsed = ctrl.text.trim().isEmpty ? null : jsonDecode(ctrl.text.trim()) as Map<String,dynamic>;
        await CompanyService.updateBranding(company['id'] as int, parsed ?? {});
        await _loadCompanies();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branding updated')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid JSON: $e')));
      }
    }
  }

  Future<void> _switch(String dbName) async {
    await CompanyService.switchCompany(dbName);
    await CompanyThemeManager.instance.reload();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company switched')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Companies')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _companies.length,
        itemBuilder: (context, i) {
          final c = _companies[i];
          return ListTile(
            title: Text(c['name'] ?? 'Unnamed'),
            subtitle: Text(c['db_name'] ?? ''),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _editBranding(c), icon: const Icon(Icons.palette)),
              ElevatedButton(onPressed: () => _switch(c['db_name']), child: const Text('Switch')),
            ],),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _createCompanyDialog, child: const Icon(Icons.add)),
    );
  }
}
