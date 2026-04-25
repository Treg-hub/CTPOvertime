import 'package:flutter/material.dart';
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

  const OvertimeFormPanel({
    super.key,
    this.initialEntry,
    required this.onSave,
    required this.onEntryChanged,
    required this.reasonSuggestions,
    required this.onSuggestionsChanged,
  });

  @override
  State<OvertimeFormPanel> createState() => _OvertimeFormPanelState();
}

class _OvertimeFormPanelState extends State<OvertimeFormPanel> {
  OvertimeEntry? _selectedEntry;
  bool _isDuplicating = false;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OvertimeListPanel extends StatelessWidget {
  final List<OvertimeEntry> entries;
  final Function(OvertimeEntry) onSelect;
  final String? selectedId;
  final String selectedDept;
  final Function(String) onDeptChanged;

  const OvertimeListPanel({
    super.key,
    required this.entries,
    required this.onSelect,
    this.selectedId,
    required this.selectedDept,
    required this.onDeptChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filteredEntries = selectedDept == 'All' ? entries : entries.where((e) => e.department == selectedDept).toList();
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
                  value: selectedDept,
                  items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d == 'All' ? 'All Depts' : d))).toList(),
                  onChanged: (value) => onDeptChanged(value!),
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
              onSelect: onSelect,
              selectedId: selectedId,
            ),
          ),
        ],
      ),
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
  String _selectedDept = 'All';
  List<String> _reasonSuggestions = [];

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

  void _onDeptChanged(String dept) {
    setState(() {
      _selectedDept = dept;
    });
  }

  void _onSuggestionsChanged(List<String> suggestions) {
    setState(() {
      _reasonSuggestions = suggestions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeEntry>>(
      stream: DataService.getRecentOvertimeStream(limit: 50), // Live recent overtime (50 newest by startTime desc)
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading overtime entries: ${snapshot.error}'));
        }
        final entries = snapshot.data ?? [];
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
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: OvertimeListPanel(
                    entries: entries,
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
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: OvertimeListPanel(
                    entries: entries,
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
      },
    );
  }
}