import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:intl/intl.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  late Future<List<OvertimeEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _entriesFuture = DataService.overtimeEntries;
  }

  void _approveEntry(String id) async {
    final entries = await _entriesFuture;
    final entry = entries.firstWhere((e) => e.id == id);
    final updated = entry.copyWith(status: 'Approved');
    await DataService.updateOvertime(updated);
    setState(() {
      _loadEntries();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry approved')),
    );
  }

  void _rejectEntry(String id) async {
    final entries = await _entriesFuture;
    final entry = entries.firstWhere((e) => e.id == id);
    final updated = entry.copyWith(status: 'Cancelled');
    await DataService.updateOvertime(updated);
    setState(() {
      _loadEntries();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry rejected')),
    );
  }

  void _sendToWages() async {
    // TODO: Implement email to wages functionality
    // This would integrate with email service or Cloud Functions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Send to Wages feature coming soon')),
    );
  }

  void _bulkApprove() async {
    final entries = await _entriesFuture;
    final pendingEntries = entries.where((e) => e.status == 'Pending').toList();
    for (var entry in pendingEntries) {
      final updated = entry.copyWith(status: 'Approved');
      await DataService.updateOvertime(updated);
    }
    setState(() {
      _loadEntries();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Approved ${pendingEntries.length} entries')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Approval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.email),
            onPressed: _sendToWages,
            tooltip: 'Send Approved to Wages',
          ),
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: _bulkApprove,
            tooltip: 'Approve All Pending',
          ),
        ],
      ),
      body: FutureBuilder<List<OvertimeEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final allEntries = snapshot.data ?? [];
          final pendingEntries = allEntries.where((e) => e.status == 'Pending').toList();
          final approvedEntries = allEntries.where((e) => e.status == 'Approved').toList();

          return Row(
            children: [
              // LEFT: Pending Approvals
              Expanded(
                flex: 3,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              'Pending Approvals (${pendingEntries.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            if (pendingEntries.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: _bulkApprove,
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Approve All'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: pendingEntries.isEmpty
                            ? const Center(child: Text('No pending approvals'))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Clock Num')),
                                    DataColumn(label: Text('Employee Name')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Shift Type')),
                                    DataColumn(label: Text('OT Type')),
                                    DataColumn(label: Text('Start Time')),
                                    DataColumn(label: Text('End Time')),
                                    DataColumn(label: Text('Hours')),
                                    DataColumn(label: Text('Department')),
                                    DataColumn(label: Text('Reason')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: pendingEntries.map((entry) {
                                    return DataRow(cells: [
                                      DataCell(Text(entry.clockNum)),
                                      DataCell(Text(entry.employeeName)),
                                      DataCell(Text(DateFormat('yyyy-MM-dd').format(entry.date))),
                                      DataCell(Text(entry.shiftType)),
                                      DataCell(Text(entry.overtimeType)),
                                      DataCell(Text(DateFormat('HH:mm').format(entry.startTime))),
                                      DataCell(Text(DateFormat('HH:mm').format(entry.endTime))),
                                      DataCell(Text(entry.hours.toStringAsFixed(1))),
                                      DataCell(Text(entry.department)),
                                      DataCell(Text(entry.reason)),
                                      DataCell(Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _approveEntry(entry.id),
                                            child: const Text('Approve'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () => _rejectEntry(entry.id),
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT: Approved & Ready to Send
              Expanded(
                flex: 2,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              'Ready to Send to Wages (${approvedEntries.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            if (approvedEntries.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: _sendToWages,
                                icon: const Icon(Icons.email),
                                label: const Text('Send to Wages'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: approvedEntries.isEmpty
                            ? const Center(child: Text('No approved entries ready to send'))
                            : ListView.builder(
                                itemCount: approvedEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = approvedEntries[index];
                                  return ListTile(
                                    title: Text('${entry.employeeName} (${entry.clockNum})'),
                                    subtitle: Text(
                                      '${DateFormat('yyyy-MM-dd').format(entry.date)} - ${entry.hours.toStringAsFixed(1)} hours - ${entry.reason}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.undo),
                                      onPressed: () async {
                                        final updated = entry.copyWith(status: 'Pending');
                                        await DataService.updateOvertime(updated);
                                        setState(() {
                                          _loadEntries();
                                        });
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Moved back to pending')),
                                        );
                                      },
                                      tooltip: 'Move back to pending',
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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
