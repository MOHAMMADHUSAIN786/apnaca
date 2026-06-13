import 'package:flutter/material.dart';
import '../../../../database/app_database.dart';
import 'create_repair_job_screen.dart';

class RepairJobListScreen extends StatefulWidget {
  const RepairJobListScreen({super.key});

  @override
  State<RepairJobListScreen> createState() => _RepairJobListScreenState();
}

class _RepairJobListScreenState extends State<RepairJobListScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    final status = _filter == 'All' ? null : _filter.toLowerCase();
    final jobs = await AppDatabase.instance.getAllRepairJobs(status: status);
    setState(() {
      _jobs = jobs;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    await AppDatabase.instance.updateRepairJob({'status': newStatus}, id);
    _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repair Jobs'),
        actions: [
          DropdownButton<String>(
            value: _filter,
            dropdownColor: Theme.of(context).cardColor,
            items: ['All', 'pending', 'in progress', 'ready', 'delivered']
                .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _filter = v);
                _loadJobs();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(child: Text('No repair jobs found.'))
              : ListView.builder(
                  itemCount: _jobs.length,
                  itemBuilder: (ctx, i) {
                    final job = _jobs[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text('${job['job_number']} - ${job['customer_name']}'),
                        subtitle: Text('${job['device_type']} (${job['device_model']})\nIssue: ${job['issue_reported']}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) => _updateStatus(job['id'], val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'pending', child: Text('Pending')),
                            const PopupMenuItem(value: 'in progress', child: Text('In Progress')),
                            const PopupMenuItem(value: 'ready', child: Text('Ready')),
                            const PopupMenuItem(value: 'delivered', child: Text('Delivered')),
                          ],
                          child: Chip(
                            label: Text(
                              (job['status'] ?? 'pending').toString().toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRepairJobScreen()),
          );
          _loadJobs();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
