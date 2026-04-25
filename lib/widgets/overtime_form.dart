import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/main.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class OvertimeForm extends StatefulWidget {
  final OvertimeEntry? initialEntry;
  final Function(OvertimeEntry) onSave;
  final List<String> reasonSuggestions;
  final Function(List<String>) onSuggestionsChanged;
  final String selectedDept;

  const OvertimeForm({
    super.key,
    this.initialEntry,
    required this.onSave,
    this.reasonSuggestions = const [],
    this.onSuggestionsChanged = _defaultOnChanged,
    this.selectedDept = 'All',
  });

  static void _defaultOnChanged(List<String> s) {}

  @override
  State<OvertimeForm> createState() => OvertimeFormState();
}

class OvertimeFormState extends State<OvertimeForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _duController;
  late TextEditingController _reasonController;
  late TextEditingController _descriptionController;
  late TextEditingController _newReasonController;
  List<Map<String, String>> selectedEmployees = [];

  String _press = '';
  String _shiftType = 'Day';
  String _overtimeType = 'Normal Time';
  DateTime _startDateTime = DateTime.now();
  DateTime _endDateTime = DateTime.now().add(const Duration(hours: 12));
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



  // Employees loaded from Firebase
  List<Map<String, String>> _employees = []; // [{name: "...", clock: "...", department: "..."}]

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
      _descriptionController.text = widget.initialEntry?.description ?? '';
    }
  }

  void _initializeControllers() {
    final entry = widget.initialEntry;
    _duController = TextEditingController(text: entry?.duNumber ?? '');
    _reasonController = TextEditingController(text: entry?.reason ?? '');
    _descriptionController = TextEditingController(text: entry?.description ?? '');
    _newReasonController = TextEditingController();

    if (entry != null) {
      selectedEmployees = [{'clock': entry.clockNum, 'name': entry.employeeName, 'department': entry.department}];
      _press = entry.press;
      _shiftType = entry.shiftType;
      _overtimeType = entry.overtimeType;
      _department = _normalizeDepartment(entry.department);
      _startDateTime = entry.startTime;
      _endDateTime = entry.endTime;
      _detectShiftType();
    } else {
      selectedEmployees = [];
      _setDefaultTimesForShift('Day');
    }
  }

  Future<void> _loadEmployeesFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('employees').get().timeout(const Duration(seconds: 5));
      setState(() {
        _employees = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['name']?.toString() ?? '',
            'clock': data['clockNo']?.toString() ?? '',
            'department': data['department']?.toString() ?? '',
          };
        }).where((emp) => (emp['clock'] ?? '').isNotEmpty).toList();
      });
    } catch (e) {
      setState(() {
        _employees = [];
      });
    }
  }



  void _setDefaultTimesForShift(String shift) {
    setState(() {
      _shiftType = shift;
      final now = DateTime.now();
      if (shift == 'Day') {
        _startDateTime = DateTime(now.year, now.month, now.day, 6, 0);
        _endDateTime = DateTime(now.year, now.month, now.day, 18, 0);
      } else if (shift == 'Night') {
        _startDateTime = DateTime(now.year, now.month, now.day, 18, 0);
        _endDateTime = DateTime(now.year, now.month, now.day + 1, 6, 0);
      } else {
        // Custom - keep current or default to 8 hours
        _startDateTime = DateTime(now.year, now.month, now.day, 8, 0);
        _endDateTime = DateTime(now.year, now.month, now.day, 16, 0);
      }
    });
  }

  void _detectShiftType() {
    // Simple detection based on start time
    if (_startDateTime.hour >= 5 && _startDateTime.hour < 12) {
      _shiftType = 'Day';
    } else if (_startDateTime.hour >= 17 || _startDateTime.hour < 5) {
      _shiftType = 'Night';
    } else {
      _shiftType = 'Custom';
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDateTime : _endDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDateTime : _endDateTime),
      );
      if (time != null) {
        final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
          if (isStart) _startDateTime = dateTime;
          else _endDateTime = dateTime;
          if (isStart) _detectShiftType();
        });
      }
    }
  }



  @override
  void dispose() {
    _duController.dispose();
    _reasonController.dispose();
    _descriptionController.dispose();
    _newReasonController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (selectedEmployees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one employee')));
        return;
      }
      for (var emp in selectedEmployees) {
        final entry = OvertimeEntry(
          duNumber: _duController.text.trim(),
          clockNum: emp['clock']!,
          employeeName: emp['name']!,
          press: _press,
          date: _startDateTime,
          shiftType: _shiftType,
          overtimeType: _overtimeType,
          startTime: _startDateTime,
          endTime: _endDateTime,
          department: _department,
          reason: _reasonController.text.trim(),
          description: _descriptionController.text.trim(),
          status: 'Pending',
          dateEntered: DateTime.now(),
          enteredBy: context.read<UserProvider>().currentUser?.name,
        );
        widget.onSave(entry);
      }
      _clearForm();
    }
  }

  void _clearForm() {
    setState(() {
      _duController.clear();
      selectedEmployees.clear();
      _reasonController.clear();
      _descriptionController.clear();
      _shiftType = 'Day';
      _overtimeType = 'Normal Time';
      _press = '';
      _department = 'Post Press';
      _setDefaultTimesForShift('Day');
    });
  }

  bool validateForm() => _formKey.currentState!.validate();

  OvertimeEntry getCurrentEntry() {
    final emp = selectedEmployees.isNotEmpty ? selectedEmployees.first : {'clock': '', 'name': ''};
    return OvertimeEntry(
      id: widget.initialEntry?.id,
      duNumber: _duController.text.trim(),
      clockNum: emp['clock']!,
      employeeName: emp['name']!,
      press: _press,
      date: _startDateTime,
      shiftType: _shiftType,
      overtimeType: _overtimeType,
      startTime: _startDateTime,
      endTime: _endDateTime,
      department: _department,
      reason: _reasonController.text.trim(),
      description: _descriptionController.text.trim(),
      status: widget.initialEntry?.status ?? 'Pending',
      dateEntered: widget.initialEntry?.dateEntered ?? DateTime.now(),
      enteredBy: widget.initialEntry?.enteredBy ?? context.read<UserProvider>().currentUser?.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // DU Number
            TextFormField(
              controller: _duController,
              decoration: const InputDecoration(
                labelText: 'DU Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Employees
            const Text('Selected Employees:'),
            Wrap(
              spacing: 8,
              children: selectedEmployees.map((emp) => Chip(
                label: Text('${emp['clock']} - ${emp['name']}'),
                onDeleted: () => setState(() => selectedEmployees.remove(emp)),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // Add Employee
            Autocomplete<String>(
              optionsMaxHeight: 200,
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Add Employee (Clock or Name)',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) => onFieldSubmitted(),
                );
              },
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return [];
                return _employees.where((emp) =>
                  (emp['department'] == widget.selectedDept || widget.selectedDept == 'All') &&
                  !selectedEmployees.any((s) => s['clock'] == emp['clock']) &&
                  (emp['clock']!.contains(textEditingValue.text) ||
                   emp['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                ).map((emp) => '${emp['clock']} - ${emp['name']} - ${emp['department']}');
              },
              onSelected: (String selection) {
                final parts = selection.split(' - ');
                final clock = parts[0];
                final name = parts[1];
                final dept = parts[2];
                setState(() => selectedEmployees.add({'clock': clock, 'name': name, 'department': dept}));
              },
            ),
            const SizedBox(height: 12),

            // Department & Press
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _departments.contains(_department) ? _department : 'Post Press',
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _department = v!),
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
            const SizedBox(height: 12),

            // Start Date & Time
            InkWell(
              onTap: () => _pickDateTime(true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start Date & Time',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('dd MMM yyyy  hh:mm a').format(_startDateTime)),
              ),
            ),
            const SizedBox(height: 12),

            // End Date & Time
            InkWell(
              onTap: () => _pickDateTime(false),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'End Date & Time',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('dd MMM yyyy  hh:mm a').format(_endDateTime)),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _reasonController,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Reason Category',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Please enter a reason category' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: widget.reasonSuggestions.map((reason) => InkWell(
                onTap: () => setState(() => _reasonController.text = reason),
                child: Chip(
                  label: Text(reason),
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Add new reason category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final newReason = _newReasonController.text.trim();
                    if (newReason.isNotEmpty && !widget.reasonSuggestions.contains(newReason)) {
                      final user = context.read<UserProvider>().currentUser;
                      if (user != null) {
                        await DataService.addReason(newReason, user.name);
                        widget.onSuggestionsChanged(List.from(widget.reasonSuggestions)..add(newReason));
                        _newReasonController.clear();
                      }
                    }
                  },
                ),
              ],
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
                  onPressed: _clearForm,
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