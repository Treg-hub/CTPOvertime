import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OvertimeForm extends StatefulWidget {
  final OvertimeEntry? initialEntry;
  final Function(OvertimeEntry) onSave;

  const OvertimeForm({
    super.key,
    this.initialEntry,
    required this.onSave,
  });

  @override
  State<OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends State<OvertimeForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _duController;
  late TextEditingController _clockController;
  late TextEditingController _reasonController;
  String _employeeName = '';

  String _press = 'Badenia';
  String _shiftType = 'Day';
  String _overtimeType = 'Normal Time';
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _department = 'PostPress';

  final List<String> _presses = ['Badenia', 'Wifag', 'Aurora', ''];
  final List<String> _departments = ['Pressroom', 'PostPress', 'PrePress', 'Electrical', 'Mechanical'];
  final List<String> _overtimeTypes = [
    'Normal Time',
    '1.5 X 10 + 2 X 2',
    '2 X 12',
    'Standby'
  ];

  // Employees loaded from Firebase
  List<Map<String, String>> _employees = []; // [{name: "...", clock: "..."}]
  bool _loadingEmployees = true;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _duController = TextEditingController(text: entry?.duNumber ?? '');
    _clockController = TextEditingController(text: entry?.clockNum ?? '');
    _reasonController = TextEditingController(text: entry?.reason ?? '');
    _employeeName = entry?.employeeName ?? '';

    if (entry != null) {
      _press = entry.press;
      _shiftType = entry.shiftType;
      _overtimeType = entry.overtimeType;
      _department = entry.department;
      _startDate = entry.startTime;
      _startTime = TimeOfDay.fromDateTime(entry.startTime);
      _endDate = entry.endTime;
      _endTime = TimeOfDay.fromDateTime(entry.endTime);
      _detectShiftType();
    } else {
      _setDefaultTimesForShift('Day');
    }

    _loadEmployeesFromFirebase();
  }

  Future<void> _loadEmployeesFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('employees').get();
      setState(() {
        _employees = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['name']?.toString() ?? '',
            'clock': data['clock']?.toString() ?? '',
          };
        }).toList();
        _loadingEmployees = false;
      });
    } catch (e) {
      // If Firebase not set up yet, use mock data
      setState(() {
        _employees = [
          {'name': 'Sanjeev Davarajh', 'clock': '7292'},
          {'name': 'Rav', 'clock': '4639'},
          {'name': 'John Smith', 'clock': '5422'},
          {'name': 'Maria Santos', 'clock': '19043'},
          {'name': 'Thabo Molefe', 'clock': '6095'},
          {'name': 'Priya Naidoo', 'clock': '19041'},
        ];
        _loadingEmployees = false;
      });
      print('Using mock employees (Firebase not connected): $e');
    }
  }

  void _setDefaultTimesForShift(String shift) {
    setState(() {
      _shiftType = shift;
      if (shift == 'Day') {
        _startTime = const TimeOfDay(hour: 6, minute: 0);
        _endTime = const TimeOfDay(hour: 18, minute: 0);
      } else if (shift == 'Night') {
        _startTime = const TimeOfDay(hour: 18, minute: 0);
        _endTime = const TimeOfDay(hour: 6, minute: 0);
      } else {
        // Custom - keep current or default to 8 hours
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 16, minute: 0);
      }
    });
  }

  void _detectShiftType() {
    // Simple detection based on start time
    if (_startTime.hour >= 5 && _startTime.hour < 12) {
      _shiftType = 'Day';
    } else if (_startTime.hour >= 17 || _startTime.hour < 5) {
      _shiftType = 'Night';
    } else {
      _shiftType = 'Custom';
    }
  }

  void _showEmployeeSearchDialog() {
    String searchQuery = '';
    List<Map<String, String>> filtered = List.from(_employees);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Employee'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by name or clock number',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.toLowerCase();
                          filtered = _employees.where((emp) {
                            return emp['name']!.toLowerCase().contains(searchQuery) ||
                                   emp['clock']!.toLowerCase().contains(searchQuery);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final emp = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(emp['clock']!.substring(0, 2)),
                            ),
                            title: Text(emp['name']!),
                            subtitle: Text('Clock: ${emp['clock']}'),
                            onTap: () {
                              setState(() {
                                _employeeName = emp['name']!;
                                _clockController.text = emp['clock']!;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _duController.dispose();
    _clockController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final entry = OvertimeEntry(
        id: widget.initialEntry?.id,
        duNumber: _duController.text.trim(),
        clockNum: _clockController.text.trim(),
        employeeName: _employeeName,
        press: _press,
        date: _startDate,
        shiftType: _shiftType,
        overtimeType: _overtimeType,
        startTime: DateTime(
          _startDate.year, _startDate.month, _startDate.day,
          _startTime.hour, _startTime.minute,
        ),
        endTime: DateTime(
          _endDate.year, _endDate.month, _endDate.day,
          _endTime.hour, _endTime.minute,
        ),
        department: _department,
        reason: _reasonController.text.trim(),
        status: widget.initialEntry?.status ?? 'Pending',
      );

      widget.onSave(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // DU Number & Clock
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _duController,
                    decoration: const InputDecoration(
                      labelText: 'DU Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _clockController,
                    decoration: const InputDecoration(
                      labelText: 'Clock Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Employee & Press
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showEmployeeSearchDialog,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Employee Name (tap to search)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.search),
                      ),
                      child: Text(
                        _employeeName.isNotEmpty ? _employeeName : 'Select employee...',
                        style: TextStyle(
                          color: _employeeName.isNotEmpty ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _press,
                    decoration: const InputDecoration(
                      labelText: 'Press',
                      border: OutlineInputBorder(),
                    ),
                    items: _presses.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.isEmpty ? 'None (General)' : p),
                    )).toList(),
                    onChanged: (v) => setState(() => _press = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Start Date/Time & End Date/Time (supports overnight shifts)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (picked != null) {
                        setState(() {
                          _startTime = picked;
                          _detectShiftType();
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_startTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (picked != null) setState(() => _endTime = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_endTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Shift Type + Overtime Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _shiftType,
                    decoration: const InputDecoration(
                      labelText: 'Shift Type (auto-detected)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Day', child: Text('Day (06:00 - 18:00)')),
                      DropdownMenuItem(value: 'Night', child: Text('Night (18:00 - 06:00)')),
                      DropdownMenuItem(value: 'Custom', child: Text('Custom / Overnight')),
                    ],
                    onChanged: (v) {
                      if (v != null) _setDefaultTimesForShift(v);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _overtimeType,
                    decoration: const InputDecoration(
                      labelText: 'Overtime Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _overtimeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _overtimeType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Department & Reason
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _department,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _department = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason for Overtime',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Please enter a reason' : null,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save & Submit for Approval'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {
                    // Cancel - clear form
                    setState(() {
                      _duController.clear();
                      _clockController.clear();
                      _employeeName = '';
                      _reasonController.clear();
                      _shiftType = 'Day';
                      _overtimeType = 'Normal Time';
                      _press = 'Badenia';
                      _department = 'PostPress';
                      _setDefaultTimesForShift('Day');
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}