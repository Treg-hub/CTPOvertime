import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_form.dart';
import 'package:intl/intl.dart';

class OvertimeEntriesListScreen extends StatefulWidget {
  const OvertimeEntriesListScreen({super.key});

  @override
  State<OvertimeEntriesListScreen> createState() => _OvertimeEntriesListScreenState();
}

class _OvertimeEntriesListScreenState extends State<OvertimeEntriesListScreen> {
  late Stream<List<OvertimeEntry>> _entriesStream;
  String _selectedDept = 'All';
  final List<String> _departments = ['All', 'Pressroom', 'PostPress', 'PrePress', 'Electrical', 'Mechanical'];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      _entriesStream = DataService.getRecentOvertimeStream(limit: 25);
    });
  }

  void _deleteEntry(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this overtime entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DataService.deleteOvertime(id);
      // No need to reload - StreamBuilder auto-updates
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Entries'),
      ),
      body: StreamBuilder<List<OvertimeEntry>>(
        stream: _entriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final entries = snapshot.data ?? [];
          final filteredEntries = entries.where((e) => _selectedDept == 'All' || e.department == _selectedDept).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Filter by Department:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDept,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setState(() => _selectedDept = v!),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
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
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Entered')),
                      DataColumn(label: Text('By')),
                      DataColumn(label: SizedBox(width: 120, child: Text('Actions', textAlign: TextAlign.center))),
                    ],
                    rows: filteredEntries.map((entry) {
                      return DataRow(
                        onSelectChanged: (_) => _showEditDialog(entry),
                        cells: [
                          DataCell(SizedBox(width: 60, child: Text(entry.clockNum))),
                          DataCell(SizedBox(width: 100, child: Text(entry.employeeName, overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(width: 80, child: Text(DateFormat('MM/dd').format(entry.date)))),
                          DataCell(SizedBox(width: 50, child: Text(entry.shiftType.substring(0, 1)))),
                          DataCell(SizedBox(width: 60, child: Text(entry.overtimeType.split(' ')[0]))),
                          DataCell(SizedBox(width: 50, child: Text(DateFormat('HH:mm').format(entry.startTime)))),
                          DataCell(SizedBox(width: 50, child: Text(DateFormat('HH:mm').format(entry.endTime)))),
                          DataCell(SizedBox(width: 40, child: Text(entry.hours.toStringAsFixed(1)))),
                          DataCell(SizedBox(width: 60, child: Text(entry.department.substring(0, 3)))),
                          DataCell(SizedBox(width: 120, child: Text(entry.reason, overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(width: 60, child: Text(entry.status.substring(0, 3)))),
                          DataCell(SizedBox(width: 80, child: Text(entry.dateEntered != null ? DateFormat('MM/dd').format(entry.dateEntered!) : 'N/A'))),
                          DataCell(SizedBox(width: 80, child: Text(entry.enteredBy ?? 'N/A', overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(
                            width: 120,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showEditDialog(entry),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _deleteEntry(entry.id),
                                  tooltip: 'Delete',
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
            ],
          );
        },
      ),
    );
  }
}