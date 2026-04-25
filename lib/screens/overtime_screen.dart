import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_form.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_list.dart';

class OvertimeFormPanel extends StatefulWidget {
  final OvertimeEntry? initialEntry;
  final Function(OvertimeEntry) onSave;
  final Function(OvertimeEntry?) onEntryChanged;
  final List<String> reasonSuggestions;
  final Function(List<String>) onSuggestionsChanged;
  final String selectedDept;

  const OvertimeFormPanel({
    super.key,
    this.initialEntry,
    required this.onSave,
    required this.onEntryChanged,
    required this.reasonSuggestions,
    required this.onSuggestionsChanged,
    required this.selectedDept,
  });

  @override
  State<OvertimeFormPanel> createState() => _OvertimeFormPanelState();
}

class _OvertimeFormPanelState extends State<OvertimeFormPanel> {
  final GlobalKey<OvertimeFormState> _formKey = GlobalKey();
  OvertimeEntry? _selectedEntry;
  bool _isDuplicating = false;
  bool _isSavingDuplicating = false;
  List<String> _reasonSuggestions = [];

  @override
  void initState() {
    super.initState();
    _selectedEntry = widget.initialEntry;
    _reasonSuggestions = widget.reasonSuggestions;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReasons());
  }

  @override
  void didUpdateWidget(covariant OvertimeFormPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntry != widget.initialEntry) {
      _selectedEntry = widget.initialEntry;
    }
    if (oldWidget.reasonSuggestions != widget.reasonSuggestions) {
      _reasonSuggestions = widget.reasonSuggestions;
    }
  }

  void _loadReasons() {
    DataService.getReasonsStream().listen((reasons) {
      final newSuggestions = reasons.map((r) => r['reason']!).toList();
      setState(() {
        _reasonSuggestions = newSuggestions;
      });
      widget.onSuggestionsChanged(newSuggestions);
    }, onError: (e) {
      print('Error loading reasons: $e');
      setState(() {
        _reasonSuggestions = ['Sick Leave', 'Annual Leave', 'Run 3rd Machine'];
      });
      widget.onSuggestionsChanged(_reasonSuggestions);
    });
  }

  void _addNew() {
    setState(() {
      _selectedEntry = null;
    });
    widget.onEntryChanged(null);
  }

  void _duplicate() async {
    if (_selectedEntry != null) {
      setState(() => _isDuplicating = true);
      final newEntry = OvertimeEntry(
        duNumber: _selectedEntry!.duNumber,
        clockNum: _selectedEntry!.clockNum,
        employeeName: _selectedEntry!.employeeName,
        press: _selectedEntry!.press,
        date: _selectedEntry!.date,
        shiftType: _selectedEntry!.shiftType,
        overtimeType: _selectedEntry!.overtimeType,
        startTime: _selectedEntry!.startTime,
        endTime: _selectedEntry!.endTime,
        department: _selectedEntry!.department,
        reason: _selectedEntry!.reason,
        description: _selectedEntry!.description,
      );
      await DataService.addOvertime(newEntry);
      setState(() {
        _isDuplicating = false;
        _selectedEntry = newEntry;
      });
      widget.onEntryChanged(newEntry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry duplicated')),
      );
    }
  }

  void _saveEntry(OvertimeEntry entry) async {
    if (_selectedEntry == null) {
      await DataService.addOvertime(entry);
    } else {
      await DataService.updateOvertime(entry);
    }
    setState(() {
      _selectedEntry = null; // Clear form after save
    });
    widget.onEntryChanged(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry saved successfully')),
    );
    widget.onSave(entry);
  }

  void _saveAndDuplicate() async {
    setState(() => _isSavingDuplicating = true);
    final formState = _formKey.currentState;
    if (formState!.validateForm()) {
      final entry = formState.getCurrentEntry();
      // save
      if (_selectedEntry == null) {
        await DataService.addOvertime(entry);
      } else {
        await DataService.updateOvertime(entry);
      }
      // dup
      final dupEntry = entry.copyWith(
        id: const Uuid().v4(),
        dateEntered: null,
        enteredBy: null,
      );
      setState(() {
        _selectedEntry = dupEntry;
        _isSavingDuplicating = false;
      });
      widget.onEntryChanged(dupEntry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved and duplicated. Update employee details.')),
      );
      widget.onSave(entry);
    } else {
      setState(() => _isSavingDuplicating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _selectedEntry == null ? 'New Overtime Entry' : 'Edit Overtime Entry',
                    key: ValueKey(_selectedEntry == null),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Flexible(
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addNew,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New'),
                      ),
                      const SizedBox(width: 8),
                      _isDuplicating
                        ? ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            label: const Text('Duplicating'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _selectedEntry != null ? _duplicate : null,
                            icon: const Icon(Icons.copy),
                            label: const Text('Duplicate'),
                          ),
                      const SizedBox(width: 8),
                      _isSavingDuplicating
                        ? ElevatedButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            label: const Text('Saving & Duplicating'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _saveAndDuplicate,
                            icon: const Icon(Icons.save_as),
                            label: const Text('Save & Duplicate'),
                          ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: OvertimeForm(
                key: ValueKey(_selectedEntry?.id ?? 'new'),
                initialEntry: _selectedEntry,
                onSave: _saveEntry,
                reasonSuggestions: _reasonSuggestions,
                onSuggestionsChanged: (List<String> suggestions) => setState(() => _reasonSuggestions = suggestions),
                selectedDept: widget.selectedDept,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OvertimeListPanel extends StatefulWidget {
  final Function(OvertimeEntry) onSelect;
  final String? selectedId;
  final String selectedDept;
  final Function(String) onDeptChanged;

  const OvertimeListPanel({
    super.key,
    required this.onSelect,
    this.selectedId,
    required this.selectedDept,
    required this.onDeptChanged,
  });

  @override
  State<OvertimeListPanel> createState() => _OvertimeListPanelState();
}

class _OvertimeListPanelState extends State<OvertimeListPanel> {
  late final Stream<List<OvertimeEntry>> _stream = DataService.getRecentOvertimeStream(limit: 50);
  bool _hasLoadedInitially = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeEntry>>(
      stream: _stream,
      initialData: [],
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final hasData = entries.isNotEmpty;

        // Mark as loaded once we have data
        if (hasData && !_hasLoadedInitially) {
          _hasLoadedInitially = true;
        }

        // Show loading only on very first load
        if (snapshot.connectionState == ConnectionState.waiting && !_hasLoadedInitially) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // If we have data, show it even if connection state changes
        if (_hasLoadedInitially && hasData) {
          final filteredEntries = widget.selectedDept == 'All' ? entries : entries.where((e) => e.department == widget.selectedDept).toList();
          final depts = ['All', ...entries.map((e) => e.department).toSet().toList()..sort()];

          return Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Overtime List (${filteredEntries.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: depts.contains(widget.selectedDept) ? widget.selectedDept : 'All',
                        items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d == 'All' ? 'All Depts' : d))).toList(),
                        onChanged: (value) => widget.onDeptChanged(value!),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export feature coming soon')),
                          );
                        },
                        tooltip: 'Export CSV',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: OvertimeList(
                    entries: filteredEntries,
                    onSelect: widget.onSelect,
                    selectedId: widget.selectedId,
                  ),
                ),
              ],
            ),
          );
        }

        // Handle errors
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Center(child: Text('Error loading overtime entries: ${snapshot.error}')),
          );
        }

        // Fallback for empty state
        return const Card(
          margin: EdgeInsets.all(16),
          child: Center(child: Text('No overtime entries found')),
        );
      },
    );
  }
}

class OvertimeScreen extends StatefulWidget {
  final OvertimeEntry? initialEntry;
  const OvertimeScreen({super.key, this.initialEntry});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  OvertimeEntry? _selectedEntry;
  List<String> _reasonSuggestions = [];
  String _selectedDept = 'All';

  @override
  void initState() {
    super.initState();
    _selectedEntry = widget.initialEntry;
  }

  void _selectEntry(OvertimeEntry entry) {
    setState(() {
      _selectedEntry = entry;
    });
  }

  void _onFormEntryChanged(OvertimeEntry? entry) {
    setState(() {
      _selectedEntry = entry;
    });
  }

  void _onSuggestionsChanged(List<String> suggestions) {
    setState(() {
      _reasonSuggestions = suggestions;
    });
  }

  void _onDeptChanged(String dept) {
    setState(() {
      _selectedDept = dept;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 800;
        return isSmall ? Column(
          children: [
            Expanded(
              flex: 5,
              child: OvertimeFormPanel(
                initialEntry: _selectedEntry,
                onSave: (entry) {},
                onEntryChanged: _onFormEntryChanged,
                reasonSuggestions: _reasonSuggestions,
                onSuggestionsChanged: _onSuggestionsChanged,
                selectedDept: _selectedDept,
              ),
            ),
            Expanded(
              flex: 6,
              child: OvertimeListPanel(
                onSelect: _selectEntry,
                selectedId: _selectedEntry?.id,
                selectedDept: _selectedDept,
                onDeptChanged: _onDeptChanged,
              ),
            ),
          ],
        ) : Row(
          children: [
            Expanded(
              flex: 5,
              child: OvertimeFormPanel(
                initialEntry: _selectedEntry,
                onSave: (entry) {},
                onEntryChanged: _onFormEntryChanged,
                reasonSuggestions: _reasonSuggestions,
                onSuggestionsChanged: _onSuggestionsChanged,
                selectedDept: _selectedDept,
              ),
            ),
            Expanded(
              flex: 6,
              child: OvertimeListPanel(
                onSelect: _selectEntry,
                selectedId: _selectedEntry?.id,
                selectedDept: _selectedDept,
                onDeptChanged: _onDeptChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}
