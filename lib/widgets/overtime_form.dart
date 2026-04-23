import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

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
  late TextEditingController _newReasonController;
  late TextEditingController _clockFieldController;
  String _employeeName = '';

  String _press = 'Badenia';
  String _shiftType = 'Day';
  String _overtimeType = 'Normal Time';
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _department = 'Post Press';

  final List<String> _presses = ['Badenia', 'Wifag', 'Aurora', ''];
  final List<String> _departments = [
    'Pressroom',
    'Post Press',
    'Pre Press',
    'Electrical',
    'Mechanical',
    'Workshop',
    'Stores',
    'Lurgi',
    'Ink Factory',
    'General'
  ];

  String _normalizeDepartment(String dept) {
    // Convert to title case for consistency
    if (dept.isEmpty) return dept;
    return dept[0].toUpperCase() + dept.substring(1).toLowerCase();
  }
  final List<String> _overtimeTypes = [
    'Normal Time',
    '1.5 X 10 + 2 X 2',
    '2 X 12',
    'Standby'
  ];

  final List<String> _reasonPresets = [
    'Sick Leave',
    'Annual Leave',
    'Run 3rd Machine',
  ];

  // Employees loaded from Firebase
  List<Map<String, String>> _employees = []; // [{name: "...", clock: "...", department: "..."}]
  bool _loadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadEmployeesFromFirebase();
  }

  @override
  void didUpdateWidget(OvertimeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntry != widget.initialEntry) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    final entry = widget.initialEntry;
    _duController = TextEditingController(text: entry?.duNumber ?? '');
    _clockController = TextEditingController(text: entry?.clockNum ?? '');
    _reasonController = TextEditingController(text: entry?.reason ?? '');
    _newReasonController = TextEditingController();
    _clockFieldController = TextEditingController(text: entry?.clockNum ?? '');
    _employeeName = entry?.employeeName ?? '';

    if (entry != null) {
      _press = entry.press;
      _shiftType = entry.shiftType;
      _overtimeType = entry.overtimeType;
      _department = _normalizeDepartment(entry.department);
      _startDate = entry.startTime;
      _startTime = TimeOfDay.fromDateTime(entry.startTime);
      _endDate = entry.endTime;
      _endTime = TimeOfDay.fromDateTime(entry.endTime);
      _detectShiftType();
    } else {
      _setDefaultTimesForShift('Day');
    }
  }

  Future<void> _loadEmployeesFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('employees').get();
      setState(() {
        _employees = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['name']?.toString() ?? '',
            'clock': data['clockNo']?.toString() ?? '',
            'department': data['department']?.toString() ?? '',
          };
        }).where((emp) => (emp['clock'] ?? '').isNotEmpty).toList();
        _loadingEmployees = false;
        if (widget.initialEntry != null && _clockController.text.isNotEmpty) {
          final emp = _employees.firstWhereOrNull((e) => e['clock'] == _clockController.text);
          if (emp == null) {
            _employeeName = '';
            _department = 'Post Press'; // Reset to default if not found
          } else {
            _employeeName = emp['name']!;
            _department = _normalizeDepartment(emp['department']!);
          }
        }
        print('Loaded ${_employees.length} employees (filtered): $_employees');
      });
    } catch (e) {
      // If Firebase not set up yet, use mock data
      setState(() {
        _employees = [
          {'name': 'Sanjeev Davarajh', 'clock': '7292', 'department': 'PostPress'},
          {'name': 'Rav', 'clock': '4639', 'department': 'Electrical'},
          {'name': 'John Smith', 'clock': '5422', 'department': 'Pressroom'},
          {'name': 'Maria Santos', 'clock': '19043', 'department': 'PrePress'},
          {'name': 'Thabo Molefe', 'clock': '6095', 'department': 'Mechanical'},
          {'name': 'Priya Naidoo', 'clock': '19041', 'department': 'PostPress'},
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
        _endDate = _startDate;
      } else if (shift == 'Night') {
        _startTime = const TimeOfDay(hour: 18, minute: 0);
        _endTime = const TimeOfDay(hour: 6, minute: 0);
        _endDate = _startDate.add(const Duration(days: 1));
      } else {
        // Custom - keep current or default to 8 hours
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 16, minute: 0);
        _endDate = _startDate;
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



  @override
  void dispose() {
    _duController.dispose();
    _clockController.dispose();
    _reasonController.dispose();
    _newReasonController.dispose();
    _clockFieldController.dispose();
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
                  child: Autocomplete<String>(
                    optionsMaxHeight: 200,
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Sync the Autocomplete's controller with our _clockController
                      textEditingController.addListener(() {
                        _clockController.text = textEditingController.text;
                      });
                      // Set initial value if editing
                      if (_clockController.text.isNotEmpty && textEditingController.text.isEmpty) {
                        textEditingController.text = _clockController.text;
                      }
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Clock Number',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (value) => onFieldSubmitted(),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      );
                    },
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return [];
                      return _employees.where((emp) =>
                        emp['clock']!.contains(textEditingValue.text) ||
                        emp['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase())
                      ).map((emp) => '${emp['clock']} - ${emp['name']} - ${emp['department']}');
                    },
                    onSelected: (String selection) {
                      final parts = selection.split(' - ');
                      final clock = parts[0];
                      final name = parts[1];
                      final dept = parts[2];
                      setState(() {
                        _clockController.text = clock;
                        _employeeName = name;
                        _department = _normalizeDepartment(dept);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Press
            Row(
              children: [
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
                          _shiftType = 'Custom';
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
                      if (picked != null) {
                        setState(() {
                          _endTime = picked;
                          _shiftType = 'Custom';
                        });
                      }
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
            const SizedBox(height: 16),

            // Department & Reason
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _departments.contains(_department) ? _department : 'Post Press',
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

            Wrap(
              spacing: 8,
              children: _reasonPresets.map((reason) => FilterChip(
                label: Text(reason),
                selected: _reasonController.text == reason,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _reasonController.text = reason;
                    });
                  }
                },
              )).toList(),
            ),
            const SizedBox(height: 8),
            Row(
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
                  onPressed: () {
                    final newReason = _newReasonController.text.trim();
                    if (newReason.isNotEmpty && !_reasonPresets.contains(newReason)) {
                      setState(() {
                        _reasonPresets.add(newReason);
                        _newReasonController.clear();
                      });
                    }
                  },
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
                      _department = 'Post Press';
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