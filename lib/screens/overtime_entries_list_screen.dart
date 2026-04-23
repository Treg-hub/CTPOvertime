import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:intl/intl.dart';

class OvertimeEntriesListScreen extends StatefulWidget {
  const OvertimeEntriesListScreen({super.key});

  @override
  State<OvertimeEntriesListScreen> createState() => _OvertimeEntriesListScreenState();
}

class _OvertimeEntriesListScreenState extends State<OvertimeEntriesListScreen> {
  late Future<List<OvertimeEntry>> _entriesFuture;
  final Set<String> _editingIds = {};
  final Map<String, OvertimeEntry> _edits = {};
  String _selectedDept = 'All';
  final List<String> _departments = ['All', 'Pressroom', 'PostPress', 'PrePress', 'Electrical', 'Mechanical'];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _entriesFuture = DataService.overtimeEntries;
  }

  void _startEdit(OvertimeEntry entry) {
    setState(() {
      _editingIds.add(entry.id);
      _edits[entry.id] = entry.copyWith();
    });
  }

  void _cancelEdit(String id) {
    setState(() {
      _editingIds.remove(id);
      _edits.remove(id);
    });
  }

  void _saveEdit(String id) async {
    await DataService.updateOvertime(_edits[id]!);
    setState(() {
      _editingIds.remove(id);
      _edits.remove(id);
      _loadEntries();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry updated')),
    );
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
      setState(() {
        _loadEntries();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime Entries'),
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
                        value: _selectedDept,
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
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: filteredEntries.map((entry) {
                final isEditing = _editingIds.contains(entry.id);
                final editEntry = _edits[entry.id] ?? entry;
                return DataRow(cells: [
                  DataCell(isEditing ? TextFormField(initialValue: editEntry.clockNum, onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(clockNum: v))) : Text(entry.clockNum)),
                  DataCell(isEditing ? TextFormField(initialValue: editEntry.employeeName, onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(employeeName: v))) : Text(entry.employeeName)),
                  DataCell(isEditing ? TextFormField(initialValue: DateFormat('yyyy-MM-dd').format(editEntry.date), onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(date: DateTime.parse(v)))) : Text(DateFormat('yyyy-MM-dd').format(entry.date))),
                  DataCell(isEditing ? DropdownButtonFormField<String>(
                    value: editEntry.shiftType,
                    items: const ['Day', 'Night', 'Custom'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(shiftType: v!)),
                  ) : Text(entry.shiftType)),
                  DataCell(isEditing ? DropdownButtonFormField<String>(
                    value: editEntry.overtimeType,
                    items: const ['Normal Time', '1.5 X 10 + 2 X 2', '2 X 12', 'Standby'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(overtimeType: v!)),
                  ) : Text(entry.overtimeType)),
                  DataCell(isEditing ? TextFormField(initialValue: DateFormat('HH:mm').format(editEntry.startTime), onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(startTime: DateTime(editEntry.date.year, editEntry.date.month, editEntry.date.day, int.parse(v.split(':')[0]), int.parse(v.split(':')[1]))))) : Text(DateFormat('HH:mm').format(entry.startTime))),
                  DataCell(isEditing ? TextFormField(initialValue: DateFormat('HH:mm').format(editEntry.endTime), onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(endTime: DateTime(editEntry.date.year, editEntry.date.month, editEntry.date.day, int.parse(v.split(':')[0]), int.parse(v.split(':')[1]))))) : Text(DateFormat('HH:mm').format(entry.endTime))),
                  DataCell(Text(entry.hours.toStringAsFixed(1))),
                  DataCell(isEditing ? TextFormField(initialValue: editEntry.department, onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(department: v))) : Text(entry.department)),
                  DataCell(isEditing ? TextFormField(initialValue: editEntry.reason, onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(reason: v))) : Text(entry.reason)),
                  DataCell(isEditing ? DropdownButtonFormField<String>(
                    value: editEntry.status,
                    items: const ['Pending', 'Approved', 'Cancelled'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _edits[entry.id] = editEntry.copyWith(status: v!)),
                  ) : Text(entry.status)),
                  DataCell(Row(
                    children: [
                      if (isEditing) ...[
                        IconButton(icon: const Icon(Icons.save), onPressed: () => _saveEdit(entry.id)),
                        IconButton(icon: const Icon(Icons.cancel), onPressed: () => _cancelEdit(entry.id)),
                      ] else ...[
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _startEdit(entry)),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteEntry(entry.id)),
                      ],
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