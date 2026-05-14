import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ctp_overtime_tracker/main.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/models/user.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  List<String> _workshopDepts = ['Mechanical', 'Electrical'];
  StreamSubscription<List<String>>? _configSub;

  @override
  void initState() {
    super.initState();
    _configSub = DataService.getWorkshopDepartmentsStream().listen((depts) {
      if (mounted) setState(() => _workshopDepts = depts);
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final role = user?.role ?? AppRole.deptManager;

    switch (role) {
      case AppRole.workshopManager:
        return _WorkshopApprovalView(
          workshopDepts: _workshopDepts,
          approverName: user!.name,
        );
      case AppRole.generalManager:
        return _GMApprovalView(
          workshopDepts: _workshopDepts,
          approverName: user!.name,
        );
      default:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'You do not have approval permissions.',
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ],
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Workshop Manager View
// ─────────────────────────────────────────────────────────────────────────────

class _WorkshopApprovalView extends StatelessWidget {
  final List<String> workshopDepts;
  final String approverName;

  const _WorkshopApprovalView({
    required this.workshopDepts,
    required this.approverName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeEntry>>(
      stream: DataService.getWorkshopApprovalStream(workshopDepts),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final entries = snapshot.data ?? [];
        return _buildContent(context, entries);
      },
    );
  }

  Widget _buildContent(BuildContext context, List<OvertimeEntry> entries) {
    final totalHours = entries.fold(0.0, (sum, e) => sum + e.hours);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workshop Approval',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${workshopDepts.join(' & ')} — '
                      '${entries.length} pending · '
                      '${totalHours.toStringAsFixed(1)}h total',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _approveAll(context, entries),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve All'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── List ──────────────────────────────────────────────
          Expanded(
            child: entries.isEmpty
                ? _EmptyApprovalState(
                    message: 'No pending entries from '
                        '${workshopDepts.join(' or ')}')
                : Card(
                    child: ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 12, endIndent: 12),
                      itemBuilder: (context, i) => _EntryRow(
                        entry: entries[i],
                        approverName: approverName,
                        isWorkshopLevel: true,
                        showCheckbox: false,
                        isSelected: false,
                        onToggleSelect: null,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveAll(
      BuildContext context, List<OvertimeEntry> entries) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve All'),
        content: Text(
            'Approve all ${entries.length} pending entries from '
            '${workshopDepts.join(' & ')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await DataService.workshopApproveAll(entries, approverName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${entries.length} entries forwarded to General Manager')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// General Manager View
// ─────────────────────────────────────────────────────────────────────────────

class _GMApprovalView extends StatefulWidget {
  final List<String> workshopDepts;
  final String approverName;

  const _GMApprovalView({
    required this.workshopDepts,
    required this.approverName,
  });

  @override
  State<_GMApprovalView> createState() => _GMApprovalViewState();
}

class _GMApprovalViewState extends State<_GMApprovalView> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OvertimeEntry>>(
      stream: DataService.getGMApprovalStream(widget.workshopDepts),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final entries = snapshot.data ?? [];
        // Drop stale selections for entries no longer in the stream.
        _selectedIds.retainWhere((id) => entries.any((e) => e.id == id));
        return _buildContent(context, entries);
      },
    );
  }

  Widget _buildContent(BuildContext context, List<OvertimeEntry> entries) {
    final totalHours = entries.fold(0.0, (sum, e) => sum + e.hours);
    final grouped = _groupByDept(entries);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Approval',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entries.length} entries · '
                      '${totalHours.toStringAsFixed(1)}h total',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              if (_selectedIds.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => _approveSelected(context, entries),
                  icon: const Icon(Icons.check),
                  label: Text('Approve Selected (${_selectedIds.length})'),
                ),
                const SizedBox(width: 8),
              ],
              if (entries.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _approveAll(context, entries),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve All'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Grouped dept list ──────────────────────────────────
          Expanded(
            child: entries.isEmpty
                ? const _EmptyApprovalState(
                    message: 'All clear — nothing pending final approval')
                : ListView(
                    children: grouped.entries.map((deptGroup) {
                      final deptEntries = deptGroup.value;
                      final deptHours = deptEntries.fold(
                          0.0, (sum, e) => sum + e.hours);
                      final allSelected = deptEntries
                          .every((e) => _selectedIds.contains(e.id));
                      final someSelected = !allSelected &&
                          deptEntries.any((e) => _selectedIds.contains(e.id));
                      final hasWorkshopApproved = deptEntries.any(
                          (e) => e.status == OTStatus.workshopApproved);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Checkbox(
                            value: someSelected ? null : allSelected,
                            tristate: true,
                            onChanged: (_) => setState(() {
                              if (allSelected) {
                                _selectedIds.removeAll(
                                    deptEntries.map((e) => e.id));
                              } else {
                                _selectedIds.addAll(
                                    deptEntries.map((e) => e.id));
                              }
                            }),
                          ),
                          title: Row(
                            children: [
                              Text(
                                deptGroup.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (hasWorkshopApproved) ...[
                                const SizedBox(width: 8),
                                const _WorkshopBadge(),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${deptEntries.length} entries · '
                            '${deptHours.toStringAsFixed(1)}h',
                            style:
                                TextStyle(color: Colors.grey.shade600),
                          ),
                          children: deptEntries
                              .map((entry) => _EntryRow(
                                    entry: entry,
                                    approverName: widget.approverName,
                                    isWorkshopLevel: false,
                                    showCheckbox: true,
                                    isSelected:
                                        _selectedIds.contains(entry.id),
                                    onToggleSelect: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedIds.add(entry.id);
                                        } else {
                                          _selectedIds.remove(entry.id);
                                        }
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, List<OvertimeEntry>> _groupByDept(
      List<OvertimeEntry> entries) {
    final map = <String, List<OvertimeEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.department, () => []).add(e);
    }
    return map;
  }

  Future<void> _approveSelected(
      BuildContext context, List<OvertimeEntry> all) async {
    final toApprove =
        all.where((e) => _selectedIds.contains(e.id)).toList();
    if (toApprove.isEmpty) return;
    await DataService.gmApproveAll(toApprove, widget.approverName);
    if (!context.mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${toApprove.length} entries approved')),
    );
  }

  Future<void> _approveAll(
      BuildContext context, List<OvertimeEntry> entries) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve All'),
        content:
            Text('Approve all ${entries.length} pending entries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await DataService.gmApproveAll(entries, widget.approverName);
    if (!context.mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entries.length} entries approved')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared entry row — used by both views
// ─────────────────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final OvertimeEntry entry;
  final String approverName;
  final bool isWorkshopLevel;
  final bool showCheckbox;
  final bool isSelected;
  final ValueChanged<bool>? onToggleSelect;

  const _EntryRow({
    required this.entry,
    required this.approverName,
    required this.isWorkshopLevel,
    required this.showCheckbox,
    required this.isSelected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Checkbox (GM view only)
          if (showCheckbox)
            Checkbox(
              value: isSelected,
              onChanged: (v) => onToggleSelect?.call(v ?? false),
            ),

          // Press avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: _pressColor(entry.press),
            child: Text(
              entry.press.isNotEmpty ? entry.press[0] : 'G',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),

          // Employee + details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${entry.employeeName}  ·  ${entry.clockNum}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (entry.status == OTStatus.workshopApproved) ...[
                      const SizedBox(width: 8),
                      const _WorkshopBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    DateFormat('dd MMM yyyy').format(entry.date),
                    entry.shiftType,
                    entry.overtimeType,
                    entry.department,
                    if (entry.press.isNotEmpty) entry.press,
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                if (entry.reason.isNotEmpty)
                  Text(
                    entry.reason,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Hours
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${entry.hours.toStringAsFixed(1)}h',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          // Approve button
          _ApproveButton(
            entry: entry,
            approverName: approverName,
            isWorkshopLevel: isWorkshopLevel,
          ),
          const SizedBox(width: 8),

          // Reject button
          _RejectButton(entry: entry),
        ],
      ),
    );
  }

  Color _pressColor(String press) {
    switch (press) {
      case 'Badenia':
        return const Color(0xFF4CAF50);
      case 'Wifag':
        return const Color(0xFFFF9800);
      case 'Aurora':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey.shade500;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approve button — shows spinner while in-flight
// ─────────────────────────────────────────────────────────────────────────────

class _ApproveButton extends StatefulWidget {
  final OvertimeEntry entry;
  final String approverName;
  final bool isWorkshopLevel;

  const _ApproveButton({
    required this.entry,
    required this.approverName,
    required this.isWorkshopLevel,
  });

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _approve,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(90, 36),
      ),
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text('Approve'),
    );
  }

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      if (widget.isWorkshopLevel) {
        await DataService.workshopApprove(
            widget.entry, widget.approverName);
      } else {
        await DataService.gmApprove(widget.entry, widget.approverName);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isWorkshopLevel
              ? 'Forwarded to General Manager'
              : 'Entry approved'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reject button — opens reason dialog before writing
// ─────────────────────────────────────────────────────────────────────────────

class _RejectButton extends StatefulWidget {
  final OvertimeEntry entry;
  const _RejectButton({required this.entry});

  @override
  State<_RejectButton> createState() => _RejectButtonState();
}

class _RejectButtonState extends State<_RejectButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _loading ? null : () => _showRejectDialog(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade700),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(90, 36),
      ),
      child: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.red.shade700),
              ),
            )
          : const Text('Reject'),
    );
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    String? validationError;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Reject Entry'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Entry summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.entry.employeeName} (${widget.entry.clockNum})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM yyyy').format(widget.entry.date)} · '
                        '${widget.entry.shiftType} · '
                        '${widget.entry.hours.toStringAsFixed(1)}h · '
                        '${widget.entry.department}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (widget.entry.reason.isNotEmpty)
                        Text(
                          widget.entry.reason,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reason input
                TextField(
                  controller: reasonController,
                  autofocus: true,
                  maxLines: 3,
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialog(() => validationError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Rejection reason (required)',
                    hintText:
                        'e.g. Incorrect times — please resubmit',
                    border: const OutlineInputBorder(),
                    errorText: validationError,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  setDialog(
                      () => validationError = 'Reason is required');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject Entry'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }

    setState(() => _loading = true);
    try {
      await DataService.rejectEntry(
          widget.entry, reasonController.text.trim());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Entry rejected — department manager notified')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WorkshopBadge extends StatelessWidget {
  const _WorkshopBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Workshop ✓',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyApprovalState extends StatelessWidget {
  final String message;
  const _EmptyApprovalState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
