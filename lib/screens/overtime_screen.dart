import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  // Fix: store the subscription so it can be cancelled in dispose()
  StreamSubscription<List<Map<String, String>>>? _reasonsSub;

  bool get _isReadOnly =>
      widget.initialEntry != null &&
      widget.initialEntry!.department != widget.currentUserDept;

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

  // Fix: cancel previous subscription before starting a new one, and store it
  // so it can be cancelled in dispose() — previously this leaked on every build.
  void _loadReasons() {
    _reasonsSub?.cancel();
    _reasonsSub = DataService.getReasonsStream().listen(
      (reasons) {
        if (!mounted) return;
        final newSuggestions = reasons.map((r) => r['reason']!).toList();
        setState(() => _reasonSuggestions = newSuggestions);
        widget.onSuggestionsChanged(newSuggestions);
      },
      onError: (_) {
        if (!mounted) return;
        final fallback = ['Sick Leave', 'Annual Leave', 'Run 3rd Machine'];
        setState(() => _reasonSuggestions = fallback);
        widget.onSuggestionsChanged(fallback);
      },
    );
  }

  @override
  void dispose() {
    _reasonsSub?.cancel();
    super.dispose();
  }

  void _addNew() {
    if (_isReadOnly) return;
    setState(() => _selectedEntry = null);
    widget.onEntryChanged(null);
  }

  void _duplicate() async {
    if (_selectedEntry == null || _isReadOnly) return;
    setState(() => _isDuplicating = true);
    try {
      // Fix: generate a proper overtime number for duplicated entries
      final newNumber = await DataService.getNextOvertimeNumber();
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
        department: widget.currentUserDept, // force to own dept for new entry
        reason: _selectedEntry!.reason,
        description: _selectedEntry!.description,
        status: 'Pending', // duplicates always start fresh
        overtimeNumber: newNumber,
        // editHistory intentionally not copied — this is a new entry
      );
      await DataService.addOvertime(newEntry);
      if (!mounted) return;
      setState(() {
        _isDuplicating = false;
        _selectedEntry = newEntry;
      });
      widget.onEntryChanged(newEntry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry duplicated (saved to your department)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDuplicating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicate failed: $e')),
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
    if (!mounted) return;
    setState(() => _selectedEntry = null);
    widget.onEntryChanged(null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry saved successfully')),
    );
    widget.onSave(entry);
  }

  void _saveAndDuplicate() async {
    if (_isReadOnly) return;
    setState(() => _isSavingDuplicating = true);
    final formState = _formKey.currentState;
    if (formState != null && formState.validateForm()) {
      final entry = formState.getCurrentEntry();
      if (entry.id.isNotEmpty) {
        await DataService.updateOvertime(entry);
      } else {
        await DataService.addOvertime(entry);
      }
      final dupEntry = entry.copyWith(
        id: const Uuid().v4(),
        dateEntered: null,
        enteredBy: null,
        department: widget.currentUserDept,
        status: 'Pending',
        editHistory: [], // duplicate starts with a clean history
      );
      if (!mounted) return;
      setState(() {
        _selectedEntry = dupEntry;
        _isSavingDuplicating = false;
      });
      widget.onEntryChanged(dupEntry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Entry saved and duplicated. Update employee details.')),
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
                        ? 'View Overtime Entry (Read-Only – Other Dept)'
                        : (_selectedEntry == null
                            ? 'New Overtime Entry'
                            : 'Edit Overtime Entry'),
                    key: ValueKey(_selectedEntry == null || isReadOnly),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              label: const Text('Duplicating…'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                            )
                          : OutlinedButton.icon(
                              onPressed: (_selectedEntry != null && !isReadOnly)
                                  ? _duplicate
                                  : null,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              label: const Text('Saving & Duplicating…'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
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
                  'This entry belongs to another department. '
                  'Switch the dropdown to your department to enable editing.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: OvertimeForm(
                key: ValueKey(_selectedEntry?.id ?? 'new'),
                initialEntry: _selectedEntry,
                onSave: _saveEntry,
                reasonSuggestions: _reasonSuggestions,
                onSuggestionsChanged: (suggestions) =>
                    setState(() => _reasonSuggestions = suggestions),
                selectedDept: widget.selectedDept,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
  String _selectedStatus = 'Pending';
  String _dateRangeLabel = 'Last 7 Days';
  DateTimeRange? _customDateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<OvertimeEntry>> _stream;
  late Stream<List<OvertimeEntry>> _rejectedStream;
  bool _hasLoadedInitially = false;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(covariant OvertimeListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserDept != widget.currentUserDept) {
      setState(() => _updateStream());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateStream() {
    final range = _getDateRange();
    _stream = DataService.getFilteredOvertimeStream(
      department: widget.currentUserDept,
      status: _selectedStatus,
      dateFrom: range.$1,
      dateTo: range.$2,
    );
    _rejectedStream = widget.currentUserDept.isNotEmpty && widget.currentUserDept != 'All'
        ? DataService.getRejectedUnacknowledgedStream(widget.currentUserDept)
        : const Stream.empty();
  }

  (DateTime?, DateTime?) _getDateRange() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_dateRangeLabel) {
      case 'Last 7 Days':
        return (now.subtract(const Duration(days: 7)), endOfToday);
      case 'This Month':
        return (DateTime(now.year, now.month, 1), endOfToday);
      case 'All Time':
        return (null, null);
      case 'Custom':
        if (_customDateRange != null) {
          return (
            _customDateRange!.start,
            DateTime(_customDateRange!.end.year, _customDateRange!.end.month,
                _customDateRange!.end.day, 23, 59, 59),
          );
        }
        return (null, null);
      default:
        return (now.subtract(const Duration(days: 7)), endOfToday);
    }
  }

  void _onStatusChanged(String status) {
    setState(() {
      _selectedStatus = status;
      _updateStream();
    });
  }

  Future<void> _pickCustomDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange,
    );
    if (range != null && mounted) {
      setState(() {
        _customDateRange = range;
        _dateRangeLabel = 'Custom';
        _updateStream();
      });
    }
  }

  void _exportCsv(List<OvertimeEntry> entries) {
    final fmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');
    final buffer = StringBuffer();
    buffer.writeln(
      'OT Number,Date,Employee,Clock,Department,Press,Shift Type,OT Type,Start,End,Hours,Status,Entered By,Reason,Description',
    );
    for (final e in entries) {
      final row = [
        e.overtimeNumber ?? '',
        fmt.format(e.date),
        e.employeeName,
        e.clockNum,
        e.department,
        e.press,
        e.shiftType,
        e.overtimeType,
        timeFmt.format(e.startTime),
        timeFmt.format(e.endTime),
        e.hours.toStringAsFixed(2),
        e.status,
        e.enteredBy ?? '',
        e.reason,
        e.description ?? '',
      ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(',');
      buffer.writeln(row);
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'overtime_${widget.currentUserDept}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showCancelDialog(BuildContext context, OvertimeEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Entry'),
        content: const Text(
          'Are you sure you want to CANCEL this overtime entry? '
          '(It will be marked Cancelled for audit — not deleted)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cancelled = entry.copyWith(status: 'Cancelled');
              await DataService.updateOvertime(cancelled);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Entry cancelled (moved to Cancelled for audit)')),
              );
              if (_selectedStatus != 'Cancelled') {
                _onStatusChanged('Cancelled');
              }
            },
            child: const Text('Cancel Entry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeEntry>>(
      stream: _rejectedStream,
      initialData: const [],
      builder: (context, rejectedSnapshot) {
        final rejectedEntries = rejectedSnapshot.data ?? [];

        return StreamBuilder<List<OvertimeEntry>>(
          stream: _stream,
          initialData: const [],
          builder: (context, snapshot) {
            final entries = snapshot.data ?? [];

            if (entries.isNotEmpty && !_hasLoadedInitially) {
              _hasLoadedInitially = true;
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !_hasLoadedInitially) {
              return const Card(
                margin: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Card(
                margin: const EdgeInsets.all(16),
                child: Center(
                    child: Text('Error loading entries: ${snapshot.error}')),
              );
            }

            // Client-side search filter
            final filtered = _searchQuery.isEmpty
                ? entries
                : entries.where((e) {
                    final q = _searchQuery.toLowerCase();
                    return e.employeeName.toLowerCase().contains(q) ||
                        e.clockNum.toLowerCase().contains(q) ||
                        (e.overtimeNumber ?? '').toLowerCase().contains(q) ||
                        e.reason.toLowerCase().contains(q);
                  }).toList();

            return Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Overtime – ${widget.currentUserDept} (${filtered.length})',
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Date range
                            DropdownButton<String>(
                              value: _dateRangeLabel,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Last 7 Days',
                                    child: Text('Last 7 Days')),
                                DropdownMenuItem(
                                    value: 'This Month',
                                    child: Text('This Month')),
                                DropdownMenuItem(
                                    value: 'All Time', child: Text('All Time')),
                                DropdownMenuItem(
                                    value: 'Custom', child: Text('Custom…')),
                              ],
                              onChanged: (value) {
                                if (value == 'Custom') {
                                  _pickCustomDateRange();
                                } else {
                                  setState(() {
                                    _dateRangeLabel = value!;
                                    _updateStream();
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            // Status
                            DropdownButton<String>(
                              value: _selectedStatus,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Pending', child: Text('Pending')),
                                DropdownMenuItem(
                                    value: 'Approved', child: Text('Approved')),
                                DropdownMenuItem(
                                    value: 'Cancelled',
                                    child: Text('Cancelled')),
                              ],
                              onChanged: (value) => _onStatusChanged(value!),
                            ),
                            // Export
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: filtered.isNotEmpty
                                  ? () => _exportCsv(filtered)
                                  : null,
                              tooltip: 'Export CSV',
                            ),
                          ],
                        ),
                        // Search bar
                        const SizedBox(height: 6),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search name, clock, OT#, reason…',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ],
                    ),
                  ),

                  // ── Pinned rejected section ──────────────────────
                  if (rejectedEntries.isNotEmpty)
                    _RejectedSection(
                      entries: rejectedEntries,
                      onTap: (entry) async {
                        await DataService.acknowledgeRejection(entry.id);
                        widget.onSelect(entry);
                      },
                    ),

                  // ── Main list ────────────────────────────────────
                  Expanded(
                    child: filtered.isNotEmpty
                        ? OvertimeList(
                            entries: filtered,
                            onSelect: widget.onSelect,
                            onDelete: (entry) =>
                                _showCancelDialog(context, entry),
                            selectedId: widget.selectedId,
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No results for "$_searchQuery"'
                                      : 'No ${_selectedStatus.toLowerCase()} entries for ${widget.currentUserDept}',
                                  style:
                                      TextStyle(color: Colors.grey.shade600),
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Text('Clear search'),
                                  ),
                                ] else if (_selectedStatus != 'Pending') ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () =>
                                        _onStatusChanged('Pending'),
                                    child: const Text('Switch to Pending'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Pinned rejected-entry section shown at the top of the list regardless of
// the active status/date filter. Disappears once all entries are acknowledged.

class _RejectedSection extends StatelessWidget {
  final List<OvertimeEntry> entries;
  final Future<void> Function(OvertimeEntry) onTap;

  const _RejectedSection({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Container(
          color: Colors.red.shade900.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: Colors.red),
              const SizedBox(width: 6),
              Text(
                'Rejected – tap to review & dismiss (${entries.length})',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Entries — constrained so they don't push the main list off screen
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: entries.length == 1 ? 80 : 160,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            itemBuilder: (context, i) =>
                _RejectedCard(entry: entries[i], onTap: onTap),
          ),
        ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}

class _RejectedCard extends StatefulWidget {
  final OvertimeEntry entry;
  final Future<void> Function(OvertimeEntry) onTap;

  const _RejectedCard({required this.entry, required this.onTap});

  @override
  State<_RejectedCard> createState() => _RejectedCardState();
}

class _RejectedCardState extends State<_RejectedCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final fmt = DateFormat('d MMM yyyy');
    return InkWell(
      onTap: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              await widget.onTap(e);
              if (mounted) setState(() => _loading = false);
            },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Colors.red, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        e.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (e.overtimeNumber != null) ...[
                        const SizedBox(width: 6),
                        Text(e.overtimeNumber!,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                      const SizedBox(width: 6),
                      Text(fmt.format(e.date),
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rejected: ${e.rejectionReason}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Tooltip(
                message: 'Tap row to acknowledge and open entry',
                child: Icon(Icons.chevron_right, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
      final user =
          Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user != null && user.department.isNotEmpty) {
        setState(() {
          _currentUserDept = user.department;
          _selectedDept = user.department;
        });
      }
    });
  }

  void _selectEntry(OvertimeEntry entry) =>
      setState(() => _selectedEntry = entry);

  void _onFormEntryChanged(OvertimeEntry? entry) =>
      setState(() => _selectedEntry = entry);

  void _onSuggestionsChanged(List<String> suggestions) =>
      setState(() => _reasonSuggestions = suggestions);

  void _onDeptChanged(String dept) => setState(() => _selectedDept = dept);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 800;

        final formPanel = OvertimeFormPanel(
          initialEntry: _selectedEntry,
          onSave: (_) {},
          onEntryChanged: _onFormEntryChanged,
          reasonSuggestions: _reasonSuggestions,
          onSuggestionsChanged: _onSuggestionsChanged,
          selectedDept: _selectedDept,
          currentUserDept: _currentUserDept,
        );

        final listPanel = OvertimeListPanel(
          onSelect: _selectEntry,
          selectedId: _selectedEntry?.id,
          selectedDept: _selectedDept,
          onDeptChanged: _onDeptChanged,
          currentUserDept: _currentUserDept,
        );

        if (isSmall) {
          return Column(
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: SizedBox(height: 600, child: formPanel),
                ),
              ),
              Expanded(flex: 6, child: listPanel),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 5, child: formPanel),
            Expanded(flex: 6, child: listPanel),
          ],
        );
      },
    );
  }
}
