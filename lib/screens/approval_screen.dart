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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Queue'),
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
          if (pendingEntries.isEmpty) {
            return const Center(child: Text('No pending approvals'));
          }
          return SingleChildScrollView(
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
          );
        },
      ),
    );
  }
}