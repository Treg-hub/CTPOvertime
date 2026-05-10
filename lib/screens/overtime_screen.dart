import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_form.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_list.dart';
import 'package:provider/provider.dart';
import 'package:ctp_overtime_tracker/main.dart';

class OvertimeFormPanel extends StatefulWidget {
  final OvertimeEntry? initialEntry;
  final Function(OvertimeEntry) onSave;
  final Function(OvertimeEntry?) onEntryChanged;
  final List<String> reasonSuggestions;
  final Function(List<String>) onSuggestionsChanged;
  final String selectedDept;
  final String currentUserDept;

  const OvertimeFormPanel({
    super.key,
    this.initialEntry,
    required this.onSave,
    required this.onEntryChanged,
    required this.reasonSuggestions,
    required this.onSuggestionsChanged,
    required this.selectedDept,
    required this.currentUserDept,
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

  bool get _isReadOnly => widget.initialEntry != null && widget.initialEntry!.department != widget.currentUserDept;

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
    if (_isReadOnly) return;
    setState(() {
      _selectedEntry = null;
    });
    widget.onEntryChanged(null);
  }

  void _duplicate() async {
    if (_selectedEntry != null && !_isReadOnly) {
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
        department: widget.currentUserDept, // force to own dept for new
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
        const SnackBar(content: Text('Entry duplicated (saved to your department)')),
      );
    }
  }

  void _saveEntry(OvertimeEntry entry) async {
    if (_isReadOnly) return;
    if (entry.id.isNotEmpty) {
      await DataService.updateOvertime(entry);
    } else {
      await DataService.addOvertime(entry);
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
    if (_isReadOnly) return;
    setState(() => _isSavingDuplicating = true);
    final formState = _formKey.currentState;
    if (formState!.validateForm()) {
      final entry = formState.getCurrentEntry();
      // save
      if (entry.id.isNotEmpty) {
        await DataService.updateOvertime(entry);
      } else {
        await DataService.addOvertime(entry);
      }
      // dup
      final dupEntry = entry.copyWith(
        id: const Uuid().v4(),
        dateEntered: null,
        enteredBy: null,
        department: widget.currentUserDept,
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
    final isReadOnly = _isReadOnly;
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
                    isReadOnly 
                      ? 'View Overtime Entry (Read-Only - Other Dept)'
                      : (_selectedEntry == null ? 'New Overtime Entry' : 'Edit Overtime Entry'),
                    key: ValueKey(_selectedEntry == null || isReadOnly),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Flexible(
                  child: Row(
                    children: [
                      if (!isReadOnly) ...[
                        ElevatedButton.icon(
                          onPressed: _addNew,
                          icon: const Icon(Icons.add),
                          label: const Text('Add New'),
                        ),
                        const SizedBox(width: 8),
                      ],
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
                            onPressed: (_selectedEntry != null && !isReadOnly) ? _duplicate : null,
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
                            onPressed: !isReadOnly ? _saveAndDuplicate : null,
                            icon: const Icon(Icons.save_as),
                            label: const Text('Save & Duplicate'),
                          ),
                    ],
                  ),
                ),
              ],
            ),
            if (isReadOnly)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  'This entry belongs to another department. Switch the dropdown to your department to enable editing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
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
  final String currentUserDept;

  const OvertimeListPanel({
    super.key,
    required this.onSelect,
    this.selectedId,
    required this.selectedDept,
    required this.onDeptChanged,
    required this.currentUserDept,
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
      initialData: const [],
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final hasData = entries.isNotEmpty;

        if (hasData && !_hasLoadedInitially) {
          _hasLoadedInitially = true;
        }

        if (snapshot.connectionState == ConnectionState.waiting && !_hasLoadedInitially) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

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
                    onDelete: (entry) {
                      if (entry.department != widget.currentUserDept) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot delete entries from other departments. Switch dropdown to your department.')),
                        );
                        return;
                      }
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Entry'),
                          content: const Text('Are you sure you want to delete this overtime entry?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await DataService.deleteOvertime(entry.id);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Entry deleted')),
                                );
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    selectedId: widget.selectedId,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Center(child: Text('Error loading overtime entries: ${snapshot.error}')),
          );
        }

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
  String _currentUserDept = 'All';

  @override
  void initState() {
    super.initState();
    _selectedEntry = widget.initialEntry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      if (user != null && user.department.isNotEmpty) {
        setState(() {
          _currentUserDept = user.department;
          _selectedDept = user.department; // Default to manager's own department for roles
        });
      }
    });
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
                currentUserDept: _currentUserDept,
              ),
            ),
            Expanded(
              flex: 6,
              child: OvertimeListPanel(
                onSelect: _selectEntry,
                selectedId: _selectedEntry?.id,
                selectedDept: _selectedDept,
                onDeptChanged: _onDeptChanged,
                currentUserDept: _currentUserDept,
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
                currentUserDept: _currentUserDept,
              ),
            ),
            Expanded(
              flex: 6,
              child: OvertimeListPanel(
                onSelect: _selectEntry,
                selectedId: _selectedEntry?.id,
                selectedDept: _selectedDept,
                onDeptChanged: _onDeptChanged,
                currentUserDept: _currentUserDept,
              ),
            ),
          ],
        );
      },
    );
  }
}
