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
  final List<String> _overtimeTypes = [
    'Normal Time',
    '1.5 X 10 + 2 X 2',
    '2 X 12',
    'Standby'
  ];

  // Employees loaded from Firebase
  List<Map<String, String>> _employees = [];
  bool _isLoadingEmployees = true;
  bool _isSaving = false;
  String? _previewNumber;

  // Fix: properly title-case each word in multi-word department names
  String _normalizeDepartment(String dept) {
    if (dept.isEmpty) return dept;
    return dept.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Round a minute value to the nearest 15-minute mark
  int _roundToQuarter(int minute) {
    const quarters = [0, 15, 30, 45];
    return quarters.reduce((a, b) =>
        (minute - a).abs() <= (minute - b).abs() ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadEmployeesFromFirebase();
    if (widget.initialEntry == null) {
      _generatePreviewNumber();
    }
  }

  Future<void> _generatePreviewNumber() async {
    try {
      final number = await DataService.getNextOvertimeNumber();
      if (mounted) setState(() => _previewNumber = number);
    } catch (_) {
      // Ignore; will show N/A
    }
  }

  @override
  void didUpdateWidget(OvertimeForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntry != widget.initialEntry) {
      // Fix: dispose old controllers before creating new ones to avoid leaks
      _disposeControllers();
      _initializeControllers();
    }
  }

  void _disposeControllers() {
    _duController.dispose();
    _reasonController.dispose();
    _descriptionController.dispose();
  }

  void _initializeControllers() {
    final entry = widget.initialEntry;
    _duController = TextEditingController(text: entry?.duNumber ?? '');
    _reasonController = TextEditingController(text: entry?.reason ?? '');
    _descriptionController = TextEditingController(text: entry?.description ?? '');

    if (entry != null) {
      selectedEmployees = [
        {'clock': entry.clockNum, 'name': entry.employeeName, 'department': entry.department}
      ];
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
      final snapshot = await FirebaseFirestore.instance
          .collection('employees')
          .get()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _employees = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['name']?.toString() ?? '',
            'clock': data['clockNo']?.toString() ?? '',
            'department': data['department']?.toString() ?? '',
          };
        }).where((emp) => (emp['clock'] ?? '').isNotEmpty).toList();
        _isLoadingEmployees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employees = [];
        _isLoadingEmployees = false;
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
        _startDateTime = DateTime(now.year, now.month, now.day, 8, 0);
        _endDateTime = DateTime(now.year, now.month, now.day, 16, 0);
      }
    });
  }

  void _detectShiftType() {
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
    // Fix: round initial minute to nearest quarter to match the limited picker options
    final roundedMinute = _roundToQuarter(initialDT.minute);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          DateTime selectedDate = initialDT;
          TimeOfDay selectedTime =
              TimeOfDay(hour: initialDT.hour, minute: roundedMinute);

          return AlertDialog(
            title: Text(isStart ? 'Select Start Date & Time' : 'Select End Date & Time'),
            content: SizedBox(
              height: 500,
              width: 400,
              child: Column(
                children: [
                  CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    onDateChanged: (date) =>
                        setDialogState(() => selectedDate = date),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text('Hour'),
                          DropdownButton<int>(
                            value: selectedTime.hour,
                            items: List.generate(
                              24,
                              (i) => DropdownMenuItem(
                                value: i,
                                child: Text(i.toString().padLeft(2, '0')),
                              ),
                            ),
                            onChanged: (v) => setDialogState(() =>
                                selectedTime = TimeOfDay(
                                    hour: v!, minute: selectedTime.minute)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          // Fix: only show 15-minute intervals instead of all 60
                          const Text('Minute'),
                          DropdownButton<int>(
                            value: selectedTime.minute,
                            items: const [0, 15, 30, 45]
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child:
                                          Text(m.toString().padLeft(2, '0')),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialogState(() =>
                                selectedTime = TimeOfDay(
                                    hour: selectedTime.hour, minute: v!)),
                          ),
                        ],
                      ),
                    ],
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
                  final newDT = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  Navigator.of(context).pop();
                  setState(() {
                    if (isStart) {
                      _startDateTime = newDT;
                      _detectShiftType();
                    } else {
                      _endDateTime = newDT;
                    }
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

  void _showEmployeeDialog() {
    final isEditing = widget.initialEntry != null;
    final searchNotifier = ValueNotifier<String>('');
    final selectedClocksNotifier =
        ValueNotifier<Set<String>>(Set.from(selectedEmployees.map((e) => e['clock']!)));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Change Employee' : 'Select Employees'),
            // When editing, show a note that only one employee can be assigned
            content: SizedBox(
              width: 400,
              height: isEditing ? 450 : 400,
              child: Column(
                children: [
                  if (isEditing)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        'Editing an existing entry — only one employee can be selected.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by Clock or Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => searchNotifier.value = value,
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: searchNotifier,
                    builder: (context, searchQuery, _) =>
                        ValueListenableBuilder<Set<String>>(
                      valueListenable: selectedClocksNotifier,
                      builder: (context, selectedClocks, _) => Expanded(
                        child: _isLoadingEmployees
                            ? const Center(child: CircularProgressIndicator())
                            : _employees.isEmpty
                                ? const Center(child: Text('No employees found'))
                                : Builder(
                                    builder: (context) {
                                      final filtered = _employees.where((emp) {
                                        final deptMatch =
                                            widget.selectedDept == 'All' ||
                                                emp['department'] ==
                                                    widget.selectedDept;
                                        final searchMatch =
                                            searchQuery.isEmpty ||
                                                emp['clock']!
                                                    .toLowerCase()
                                                    .contains(
                                                        searchQuery.toLowerCase()) ||
                                                emp['name']!
                                                    .toLowerCase()
                                                    .contains(
                                                        searchQuery.toLowerCase());
                                        final notManager =
                                            emp['department'] != 'Manager';
                                        return deptMatch && searchMatch && notManager;
                                      }).toList();

                                      return ListView.builder(
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final emp = filtered[index];
                                          final clock = emp['clock']!;
                                          final isSelected =
                                              selectedClocks.contains(clock);

                                          if (isEditing) {
                                            // Fix: single-select when editing to prevent
                                            // overwriting the same Firestore document.
                                            // Use ListTile+Radio instead of RadioListTile
                                            // to avoid deprecated groupValue/onChanged API.
                                            final isSel = selectedClocks.contains(clock);
                                            return ListTile(
                                              title: Text('$clock - ${emp['name']}'),
                                              subtitle: Text(emp['department']!),
                                              leading: Radio<String>(
                                                value: clock,
                                                groupValue: selectedClocks.isEmpty
                                                    ? null
                                                    : selectedClocks.first,
                                                onChanged: (v) =>
                                                    selectedClocksNotifier.value = {v!},
                                              ),
                                              selected: isSel,
                                              onTap: () =>
                                                  selectedClocksNotifier.value = {clock},
                                            );
                                          }

                                          return CheckboxListTile(
                                            title: Text('$clock - ${emp['name']}'),
                                            subtitle: Text(emp['department']!),
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              final newSet =
                                                  Set<String>.from(selectedClocks);
                                              if (value == true) {
                                                newSet.add(clock);
                                              } else {
                                                newSet.remove(clock);
                                              }
                                              selectedClocksNotifier.value =
                                                  newSet;
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                // Fix: pop first so widgets are gone before notifiers are disposed
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final selectedClocks = selectedClocksNotifier.value;
                  setState(() {
                    selectedEmployees
                        .removeWhere((s) => !selectedClocks.contains(s['clock']));
                    for (final clock in selectedClocks) {
                      if (!selectedEmployees.any((s) => s['clock'] == clock)) {
                        final emp = _employees.firstWhere(
                          (e) => e['clock'] == clock,
                          orElse: () => <String, String>{},
                        );
                        if (emp.isNotEmpty) {
                          selectedEmployees.add({
                            'clock': emp['clock']!,
                            'name': emp['name']!,
                            'department': emp['department']!,
                          });
                        }
                      }
                    }
                  });
                  // Fix: pop before disposing so the dialog tree is gone first
                  Navigator.of(context).pop();
                },
                child: const Text('Update Selection'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Compute field-level diff between the original approved entry and the
  /// current form state for a specific employee. Returns a map of
  /// { fieldLabel: { from, to } } for any field that changed.
  Map<String, Map<String, String>> _computeChanges(
      OvertimeEntry original, Map<String, String> emp) {
    final changes = <String, Map<String, String>>{};
    final fmt = DateFormat('dd MMM yyyy HH:mm');

    if (original.clockNum != emp['clock']) {
      changes['Employee'] = {
        'from': '${original.clockNum} – ${original.employeeName}',
        'to': '${emp['clock']} – ${emp['name']}',
      };
    }
    if (original.duNumber != _duController.text.trim()) {
      changes['DU Number'] = {
        'from': original.duNumber,
        'to': _duController.text.trim(),
      };
    }
    if (original.department != _department) {
      changes['Department'] = {'from': original.department, 'to': _department};
    }
    if (original.press != _press) {
      changes['Press'] = {
        'from': original.press.isEmpty ? 'None' : original.press,
        'to': _press.isEmpty ? 'None' : _press,
      };
    }
    if (original.shiftType != _shiftType) {
      changes['Shift Type'] = {'from': original.shiftType, 'to': _shiftType};
    }
    if (original.overtimeType != _overtimeType) {
      changes['Overtime Type'] = {'from': original.overtimeType, 'to': _overtimeType};
    }
    if (original.startTime != _startDateTime) {
      changes['Start Time'] = {
        'from': fmt.format(original.startTime),
        'to': fmt.format(_startDateTime),
      };
    }
    if (original.endTime != _endDateTime) {
      changes['End Time'] = {
        'from': fmt.format(original.endTime),
        'to': fmt.format(_endDateTime),
      };
    }
    if (original.reason != _reasonController.text.trim()) {
      changes['Reason'] = {
        'from': original.reason,
        'to': _reasonController.text.trim(),
      };
    }
    if ((original.description ?? '') != _descriptionController.text.trim()) {
      changes['Description'] = {
        'from': original.description ?? '',
        'to': _descriptionController.text.trim(),
      };
    }

    return changes;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    if (selectedEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one employee')),
      );
      return;
    }

    // Fix: validate end time is after start time before saving
    if (!_endDateTime.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Fix: cache UserProvider read outside the loop
    final userName = context.read<UserProvider>().currentUser?.name;
    final isEditing = widget.initialEntry != null;
    final isApproved = widget.initialEntry?.status == 'Approved';

    try {
      // Fix: when editing, only process the first employee to avoid overwriting
      // the same Firestore document with different employee data on each iteration
      final empsToProcess = isEditing ? [selectedEmployees.first] : selectedEmployees;

      // Pre-fetch overtime numbers sequentially (transaction-safe), then save in parallel
      final numbers = <String?>[];
      for (final _ in empsToProcess) {
        numbers.add(isEditing
            ? widget.initialEntry!.overtimeNumber
            : await DataService.getNextOvertimeNumber());
      }

      // Build entry objects, computing edit history for approved entries
      final entriesToSave = <OvertimeEntry>[];
      for (var i = 0; i < empsToProcess.length; i++) {
        final emp = empsToProcess[i];

        // Fix: preserve existing status instead of hardcoding 'Pending'
        String newStatus = widget.initialEntry?.status ?? 'Pending';
        List<Map<String, dynamic>> editHistory =
            List.from(widget.initialEntry?.editHistory ?? []);

        if (isEditing && isApproved) {
          final changes = _computeChanges(widget.initialEntry!, emp);
          if (changes.isNotEmpty) {
            editHistory.add({
              'editedBy': userName ?? 'Unknown',
              'editedAt': DateTime.now().toIso8601String(),
              'changes': changes,
            });
          }
          newStatus = 'Approved'; // approved entries stay approved after edits
        }

        entriesToSave.add(OvertimeEntry(
          id: isEditing ? widget.initialEntry!.id : null,
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
          status: newStatus,
          dateEntered: widget.initialEntry?.dateEntered ?? DateTime.now(),
          enteredBy: widget.initialEntry?.enteredBy ?? userName,
          overtimeNumber: numbers[i],
          editHistory: editHistory,
        ));
      }

      // Fix: save in parallel for new multi-employee entries; sequential for edits
      if (isEditing) {
        await DataService.updateOvertime(entriesToSave.first);
      } else {
        await Future.wait(
          entriesToSave.map(
            (e) => e.id.isNotEmpty
                ? DataService.updateOvertime(e)
                : DataService.addOvertime(e),
          ),
        );
      }

      // Fix: notify parent via callback (previously this was never called)
      if (entriesToSave.isNotEmpty) {
        widget.onSave(entriesToSave.first);
      }

      _clearForm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved && isEditing
                ? 'Approved entry updated — edit logged to history'
                : 'Saved successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    // Fix: refresh the preview number after clearing so it doesn't show stale value
    _generatePreviewNumber();
  }

  bool validateForm() => _formKey.currentState!.validate();

  OvertimeEntry getCurrentEntry() {
    final emp = selectedEmployees.isNotEmpty
        ? selectedEmployees.first
        : {'clock': '', 'name': ''};
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
      enteredBy: widget.initialEntry?.enteredBy ??
          context.read<UserProvider>().currentUser?.name,
      overtimeNumber: widget.initialEntry?.overtimeNumber,
      editHistory: widget.initialEntry?.editHistory ?? [],
    );
  }

  // ─── Edit History Banner ──────────────────────────────────────────────────

  Widget _buildApprovedEditBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This entry is Approved. Any changes you save will be logged '
              'to the edit history and the entry will remain Approved.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditHistorySection() {
    final history = widget.initialEntry!.editHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    final fmt = DateFormat('dd MMM yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Edit History (${history.length} ${history.length == 1 ? 'edit' : 'edits'})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.asMap().entries.map((entry) {
            final i = entry.key;
            final edit = entry.value;
            final editedAt =
                DateTime.tryParse(edit['editedAt'] as String? ?? '') ??
                    DateTime.now();
            final changes =
                (edit['changes'] as Map<String, dynamic>?) ?? {};

            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (i > 0)
                    Divider(color: Colors.blue.shade100, height: 1),
                  if (i > 0) const SizedBox(height: 8),
                  Text(
                    'Edit ${i + 1} — ${edit['editedBy']}  ·  ${fmt.format(editedAt)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...changes.entries.map((change) {
                    final val =
                        (change.value as Map<String, dynamic>);
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, left: 8),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: '${change.key}: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: '"${val['from']}"',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                            const TextSpan(text: '  →  '),
                            TextSpan(
                              text: '"${val['to']}"',
                              style:
                                  TextStyle(color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Reason Section ───────────────────────────────────────────────────────

  /// Chips are the primary way to pick a reason. The text field below is a
  /// fallback for custom reasons not yet in the chip list. The [+] button
  /// saves whatever is typed as a new persistent chip.
  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Reason Category',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),

        // Primary: chip quick-picks (FilterChip shows which is currently selected)
        if (widget.reasonSuggestions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.reasonSuggestions.map((reason) {
              final isSelected = _reasonController.text == reason;
              return FilterChip(
                label: Text(reason),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _reasonController.text = reason),
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),

        const SizedBox(height: 10),

        // Fallback: free-text field for custom / new reasons
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: widget.reasonSuggestions.isEmpty
                      ? 'Reason'
                      : 'Or type a custom reason',
                  hintText: 'Type if not listed above',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Please select or enter a reason'
                        : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Save as quick-select chip',
              onPressed: () async {
                final newReason = _reasonController.text.trim();
                if (newReason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Type a reason first')),
                  );
                  return;
                }
                // Fix: check the live local suggestion list, not the widget prop
                // which may lag by a frame
                if (widget.reasonSuggestions.contains(newReason)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('That reason already exists')),
                  );
                  return;
                }
                try {
                  final user =
                      context.read<UserProvider>().currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please log in to save reasons')),
                    );
                    return;
                  }
                  await DataService.addReason(newReason, user.name);
                  widget.onSuggestionsChanged(
                      List.from(widget.reasonSuggestions)
                        ..add(newReason));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Reason saved as quick-select chip')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save reason: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEntry != null;
    final isApproved = widget.initialEntry?.status == 'Approved';
    final hasEditHistory =
        (widget.initialEntry?.editHistory ?? []).isNotEmpty;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overtime Number preview
            if (widget.initialEntry?.overtimeNumber != null ||
                _previewNumber != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Overtime Number: ${widget.initialEntry?.overtimeNumber ?? _previewNumber ?? 'N/A'}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Theme.of(context).primaryColor),
                ),
              ),

            // Warning banner when editing an approved entry
            if (isEditing && isApproved) _buildApprovedEditBanner(),

            // Edit history section (only shown when editing an entry with history)
            if (isEditing && hasEditHistory) _buildEditHistorySection(),

            // DU Number
            TextFormField(
              controller: _duController,
              decoration: const InputDecoration(
                labelText: 'DU Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Employees chips
            if (selectedEmployees.isNotEmpty) ...[
              const Text('Selected Employees:'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: selectedEmployees
                    .map((emp) => Chip(
                          label: Text('${emp['clock']} – ${emp['name']}'),
                          onDeleted: isEditing
                              ? null // can't remove the only employee when editing
                              : () => setState(
                                  () => selectedEmployees.remove(emp)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Add / Change Employees picker
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText:
                    isEditing ? 'Change Employee' : 'Add Employees',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              onTap: _showEmployeeDialog,
            ),
            const SizedBox(height: 12),

            // Department & Press
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _departments.contains(_department)
                        ? _department
                        : 'Post Press',
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: _departments
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _department = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _press,
                    decoration: const InputDecoration(
                      labelText: 'Press',
                      border: OutlineInputBorder(),
                    ),
                    items: _presses
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                  p.isEmpty ? 'None (General)' : p),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _press = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Shift Type & Overtime Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _shiftType,
                    decoration: const InputDecoration(
                      labelText: 'Shift Type (auto-detected)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Day',
                          child: Text('Day (06:00 – 18:00)')),
                      DropdownMenuItem(
                          value: 'Night',
                          child: Text('Night (18:00 – 06:00)')),
                      DropdownMenuItem(
                          value: 'Custom',
                          child: Text('Custom / Overnight')),
                    ],
                    onChanged: (v) {
                      if (v != null) _setDefaultTimesForShift(v);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _overtimeType,
                    decoration: const InputDecoration(
                      labelText: 'Overtime Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _overtimeTypes
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _overtimeType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Start & End Date/Time
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
                      child: Text(DateFormat('dd MMM yyyy  HH:mm')
                          .format(_startDateTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDateTime(false),
                    child: InputDecorator(
                      // Fix: highlight end time field in red if it precedes start
                      decoration: InputDecoration(
                        labelText: 'End Date & Time',
                        border: const OutlineInputBorder(),
                        enabledBorder: !_endDateTime.isAfter(_startDateTime)
                            ? const OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.red, width: 1.5),
                              )
                            : null,
                        labelStyle:
                            !_endDateTime.isAfter(_startDateTime)
                                ? const TextStyle(color: Colors.red)
                                : null,
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy  HH:mm')
                            .format(_endDateTime),
                        style: !_endDateTime.isAfter(_startDateTime)
                            ? const TextStyle(color: Colors.red)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Duration preview / end-time error
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: _endDateTime.isAfter(_startDateTime)
                  ? Text(
                      'Duration: ${_endDateTime.difference(_startDateTime).inMinutes ~/ 60}h '
                      '${_endDateTime.difference(_startDateTime).inMinutes % 60}min',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    )
                  : const Text(
                      'End time must be after start time',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
            ),

            // Reason section (chips first, text fallback)
            _buildReasonSection(),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving
                          ? 'Saving…'
                          : isApproved
                              ? 'Save & Log Edit'
                              : 'Save & Submit for Approval',
                    ),
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
