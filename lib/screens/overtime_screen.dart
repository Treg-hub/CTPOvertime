import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_form.dart';
import 'package:ctp_overtime_tracker/widgets/overtime_list.dart';

class OvertimeScreen extends StatefulWidget {
  final OvertimeEntry? initialEntry;
  const OvertimeScreen({super.key, this.initialEntry});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> {
  OvertimeEntry? _selectedEntry;
  bool _isDuplicating = false;

  @override
  void initState() {
    super.initState();
    _selectedEntry = widget.initialEntry;
  }

  void _selectEntry(OvertimeEntry entry) {
    print('Selected entry: ${entry.employeeName} id: ${entry.id}');
    setState(() {
      _selectedEntry = entry;
    });
  }

  void _addNew() {
    setState(() {
      _selectedEntry = null;
    });
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
      );
      await DataService.addOvertime(newEntry);
      setState(() {
        _isDuplicating = false;
        _selectedEntry = newEntry;
      });
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
      _selectedEntry = entry;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OvertimeEntry>>(
      future: DataService.getRecentOvertime(limit: 100), // Show more in main screen, sorted newest first
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
                // TOP: Form
                Expanded(
                  flex: 5,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedEntry == null ? 'New Overtime Entry' : 'Edit Overtime Entry',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Row(
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
                                        icon: SizedBox(
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
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: OvertimeForm(
                              initialEntry: _selectedEntry,
                              onSave: _saveEntry,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // BOTTOM: List
                Expanded(
                  flex: 6,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                'Overtime List (${entries.length})',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              // Department filter (for logged-in user's department)
                              DropdownButton<String>(
                                value: 'All',
                                items: const [
                                  DropdownMenuItem(value: 'All', child: Text('All Depts')),
                                  DropdownMenuItem(value: 'PostPress', child: Text('PostPress')),
                                  DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                                ],
                                onChanged: (value) {
                                  // TODO: Filter the list based on logged-in user's department
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Filtered to $value (demo)')),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () {
                                  // TODO: Export CSV
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
                            entries: entries,
                            onSelect: _selectEntry,
                            selectedId: _selectedEntry?.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ) : Row(
              children: [
                // LEFT: Form
                Expanded(
                  flex: 5,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedEntry == null ? 'New Overtime Entry' : 'Edit Overtime Entry',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Row(
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
                                        icon: SizedBox(
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
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: OvertimeForm(
                              initialEntry: _selectedEntry,
                              onSave: _saveEntry,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // RIGHT: List
                Expanded(
                  flex: 6,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                'Overtime List (${entries.length})',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              // Department filter (for logged-in user's department)
                              DropdownButton<String>(
                                value: 'All',
                                items: const [
                                  DropdownMenuItem(value: 'All', child: Text('All Depts')),
                                  DropdownMenuItem(value: 'PostPress', child: Text('PostPress')),
                                  DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                                ],
                                onChanged: (value) {
                                  // TODO: Filter the list based on logged-in user's department
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Filtered to $value (demo)')),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () {
                                  // TODO: Export CSV
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
                            entries: entries,
                            onSelect: _selectEntry,
                            selectedId: _selectedEntry?.id,
                          ),
                        ),
                      ],
                    ),
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