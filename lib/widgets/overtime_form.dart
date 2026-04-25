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
  String? _selectedReasonCategory;

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
    _selectedReasonCategory = widget.reasonSuggestions.contains(_reasonController.text) ? _reasonController.text : null;
    _loadEmployeesFromFirebase();

  }

  @override
  void didUpdateWidget(OvertimeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntry != widget.initialEntry) {
      _initializeControllers();
      _descriptionController.text = widget.initialEntry?.description ?? '';
    }
    if (oldWidget.reasonSuggestions != widget.reasonSuggestions) {
      _selectedReasonCategory = widget.reasonSuggestions.contains(_reasonController.text) ? _reasonController.text : null;
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
    final initialDT = isStart ? _startDateTime : _endDateTime;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          DateTime selectedDate = initialDT;
          TimeOfDay selectedTime = TimeOfDay.fromDateTime(initialDT);
          return AlertDialog(
            title: Text(isStart ? 'Select Start Date & Time' : 'Select End Date & Time'),
            content: SizedBox(
              height: 400,
              width: 400,
              child: Row(
                children: [
                  Expanded(
                    child: CalendarDatePicker(
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      onDateChanged: (date) => setDialogState(() => selectedDate = date),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Hour'),
                        DropdownButton<int>(
                          value: selectedTime.hour,
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                          onChanged: (v) => setDialogState(() => selectedTime = TimeOfDay(hour: v!, minute: selectedTime.minute)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Minute'),
                        DropdownButton<int>(
                          value: selectedTime.minute,
                          items: List.generate(60, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                          onChanged: (v) => setDialogState(() => selectedTime = TimeOfDay(hour: selectedTime.hour, minute: v!)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newDT = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                  Navigator.of(context).pop();
                  setState(() {
                    if (isStart) _startDateTime = newDT;
                    else _endDateTime = newDT;
                    if (isStart) _detectShiftType();
                  });
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReasonDialog() {
    String tempCategory = _selectedReasonCategory ?? '';
    String tempDescription = _descriptionController.text;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reason Details'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempCategory.isNotEmpty && widget.reasonSuggestions.contains(tempCategory) ? tempCategory : null,
                  decoration: const InputDecoration(
                    labelText: 'Reason Category',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.reasonSuggestions.map((reason) => DropdownMenuItem(value: reason, child: Text(reason))).toList(),
                  onChanged: (value) => setDialogState(() => tempCategory = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: tempDescription,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => tempDescription = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tempCategory.isNotEmpty) {
                  setState(() {
                    _selectedReasonCategory = tempCategory;
                    _reasonController.text = tempCategory;
                    _descriptionController.text = tempDescription;
                  });
                  // Add new category if not exists
                  if (!widget.reasonSuggestions.contains(tempCategory)) {
                    final user = context.read<UserProvider>().currentUser;
                    if (user != null) {
                      await DataService.addReason(tempCategory, user.name);
                      widget.onSuggestionsChanged(List.from(widget.reasonSuggestions)..add(tempCategory));
                    }
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String searchQuery = '';
          Set<String> selectedClocks = Set.from(selectedEmployees.map((e) => e['clock']!));
          List<Map<String, String>> filteredEmployees = _employees.where((emp) {
            final deptMatch = widget.selectedDept == 'All' || emp['department'] == widget.selectedDept;
            final searchMatch = searchQuery.isEmpty ||
              emp['clock']!.contains(searchQuery) ||
              emp['name']!.toLowerCase().contains(searchQuery.toLowerCase());
            final notSelected = !selectedEmployees.any((s) => s['clock'] == emp['clock']);
            return deptMatch && searchMatch && notSelected;
          }).toList();
          return AlertDialog(
            title: const Text('Select Employees'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by Clock or Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setDialogState(() => searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final emp = filteredEmployees[index];
                        return CheckboxListTile(
                          title: Text('${emp['clock']} - ${emp['name']}'),
                          subtitle: Text(emp['department']!),
                          value: selectedClocks.contains(emp['clock']),
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedClocks.add(emp['clock']!);
                              } else {
                                selectedClocks.remove(emp['clock']);
                              }
                            });
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    for (final clock in selectedClocks) {
                      final emp = _employees.firstWhere((e) => e['clock'] == clock);
                      selectedEmployees.add({
                        'clock': emp['clock']!,
                        'name': emp['name']!,
                        'department': emp['department']!,
                      });
                    }
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Add Selected'),
              ),
            ],
          );
        },
      ),
    );
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

            // Add Employees
            TextFormField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Add Employees',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              onTap: _showEmployeeDialog,
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

            // Start & End Date & Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDateTime(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date & Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd MMM yyyy  hh:mm a').format(_startDateTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDateTime(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date & Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd MMM yyyy  hh:mm a').format(_endDateTime)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedReasonCategory,
                    decoration: const InputDecoration(
                      labelText: 'Reason Category',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.reasonSuggestions.map((reason) => DropdownMenuItem(value: reason, child: Text(reason))).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedReasonCategory = value;
                        _reasonController.text = value ?? '';
                      });
                    },
                    validator: (value) => (value == null || value.isEmpty) ? 'Please select a reason category' : null,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showReasonDialog,
                  tooltip: 'Add/Edit Reason Details',
                ),
              ],
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