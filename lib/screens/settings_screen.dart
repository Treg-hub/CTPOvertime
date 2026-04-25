import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_form.dart';
import 'package:ctp_overtime_tracker/screens/overtime_entries_list_screen.dart';
import 'package:ctp_overtime_tracker/screens/jobs_list_screen.dart';
import 'package:ctp_overtime_tracker/main.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<OvertimeEntry>> _entriesFuture;
  late TextEditingController _newReasonController;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _newReasonController = TextEditingController();
  }

  void _loadEntries() {
    _entriesFuture = DataService.getPendingOvertime();
  }

  void _approveEntry(String id) async {
    final entries = await DataService.getPendingOvertime();
    final entry = entries.firstWhere((e) => e.id == id);
    final updated = entry.copyWith(status: 'Approved');
    await DataService.updateOvertime(updated);
    // No need to reload - StreamBuilder auto-updates
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry approved')),
    );
  }

  void _rejectEntry(String id) async {
    final entries = await DataService.getPendingOvertime();
    final entry = entries.firstWhere((e) => e.id == id);
    final updated = entry.copyWith(status: 'Cancelled');
    await DataService.updateOvertime(updated);
    // No need to reload - StreamBuilder auto-updates
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry rejected')),
    );
  }

  void _showEditDialog(OvertimeEntry entry) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Overtime Entry',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: OvertimeForm(
                  initialEntry: entry,
                  onSave: (updatedEntry) async {
                    await DataService.updateOvertime(updatedEntry);
                    Navigator.pop(context);
                    setState(() {
                      _loadEntries();
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Entry updated')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Approval Queue Section
          ExpansionTile(
            title: const Text(
              'Approval Queue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            initiallyExpanded: true,
            children: [
              FutureBuilder<List<OvertimeEntry>>(
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final pendingEntries = snapshot.data ?? [];
                  if (pendingEntries.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No pending approvals'),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: 12,
                              dataRowHeight: 48,
                              headingRowHeight: 48,
                              columns: const [
                                DataColumn(label: Text('Clock')),
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Shift')),
                                DataColumn(label: Text('OT')),
                                DataColumn(label: Text('Start')),
                                DataColumn(label: Text('End')),
                                DataColumn(label: Text('Hrs')),
                                DataColumn(label: Text('Dept')),
                                DataColumn(label: Text('Reason')),
                                DataColumn(label: SizedBox(width: 100, child: Text('Actions', textAlign: TextAlign.center))),
                              ],
                              rows: pendingEntries.map((entry) {
                                return DataRow(
                                  onSelectChanged: (_) => _showEditDialog(entry),
                                  cells: [
                                    DataCell(SizedBox(width: 60, child: Text(entry.clockNum))),
                                    DataCell(SizedBox(width: 120, child: Text(entry.employeeName, overflow: TextOverflow.ellipsis))),
                                    DataCell(SizedBox(width: 70, child: Text(DateFormat('MM/dd').format(entry.date)))),
                                    DataCell(SizedBox(width: 50, child: Text(entry.shiftType.substring(0, 1)))),
                                    DataCell(SizedBox(width: 60, child: Text(entry.overtimeType.split(' ')[0]))),
                                    DataCell(SizedBox(width: 60, child: Text(DateFormat('HH:mm').format(entry.startTime)))),
                                    DataCell(SizedBox(width: 60, child: Text(DateFormat('HH:mm').format(entry.endTime)))),
                                    DataCell(SizedBox(width: 50, child: Text(entry.hours.toStringAsFixed(1)))),
                                    DataCell(SizedBox(width: 60, child: Text(entry.department.substring(0, 3)))),
                                    DataCell(SizedBox(width: 150, child: Text(entry.reason, overflow: TextOverflow.ellipsis))),
                                    DataCell(SizedBox(
                                      width: 100,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _approveEntry(entry.id),
                                            style: ElevatedButton.styleFrom(minimumSize: const Size(40, 32), padding: EdgeInsets.zero),
                                            child: const Text('✓'),
                                          ),
                                          const SizedBox(width: 2),
                                          OutlinedButton(
                                            onPressed: () => _rejectEntry(entry.id),
                                            style: OutlinedButton.styleFrom(minimumSize: const Size(40, 32), padding: EdgeInsets.zero),
                                            child: const Text('✗'),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Reasons Section
          ExpansionTile(
            title: const Text(
              'Reasons',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            children: [
              StreamBuilder<List<Map<String, String>>>(
                stream: DataService.getReasonsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final reasons = snapshot.data ?? [];
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newReasonController,
                                decoration: const InputDecoration(
                                  labelText: 'Add new reason',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () async {
                                final newReason = _newReasonController.text.trim();
                                if (newReason.isNotEmpty) {
                                  final user = context.read<UserProvider>().currentUser;
                                  if (user != null) {
                                    await DataService.addReason(newReason, user.name);
                                    _newReasonController.clear();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      ...reasons.map((reason) => ListTile(
                        title: Text(reason['reason']!),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await DataService.deleteReason(reason['id']!);
                          },
                        ),
                      )),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Other Settings
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('View Overtime Entries'),
            subtitle: const Text('List all overtime entries with edit/delete'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OvertimeEntriesListScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.work),
            title: const Text('View Jobs'),
            subtitle: const Text('List all jobs with edit/delete'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsListScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
