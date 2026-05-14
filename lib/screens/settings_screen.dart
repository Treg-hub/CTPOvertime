import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ctp_overtime_tracker/main.dart';
import 'package:ctp_overtime_tracker/models/user.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/theme/app_theme.dart';

// Known departments — used to build the approval lines checkboxes.
// Add new ones here if the org grows.
const _kAllDepartments = [
  'Mechanical',
  'Electrical',
  'Pressroom',
  'Pre-press',
  'Post-press',
  'General',
  'Workshop',
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final role = user?.role ?? AppRole.deptManager;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Approval lines (GM only) ─────────────────────────────
        if (role == AppRole.generalManager) ...[
          const _SectionHeader(
            icon: Icons.account_tree_outlined,
            title: 'Approval Lines',
            subtitle:
                'Departments that route through the Workshop Manager before reaching the General Manager.',
          ),
          const SizedBox(height: 12),
          const _ApprovalLinesCard(),
          const SizedBox(height: 32),
        ],

        // ── Reasons ──────────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.list_alt_outlined,
          title: 'Overtime Reasons',
          subtitle: 'Manage the reason suggestions shown in the overtime form.',
        ),
        const SizedBox(height: 12),
        const _ReasonsCard(),
        const SizedBox(height: 32),

        // ── Account info ─────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.person_outline,
          title: 'Account',
          subtitle: 'Your current session details.',
        ),
        const SizedBox(height: 12),
        _AccountCard(user: user, role: role),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approval lines config card (GM only)
// ─────────────────────────────────────────────────────────────────────────────

class _ApprovalLinesCard extends StatefulWidget {
  const _ApprovalLinesCard();

  @override
  State<_ApprovalLinesCard> createState() => _ApprovalLinesCardState();
}

class _ApprovalLinesCardState extends State<_ApprovalLinesCard> {
  List<String> _workshopDepts = [];
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<List<String>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DataService.getWorkshopDepartmentsStream().listen((depts) {
      if (mounted) {
        setState(() {
          _workshopDepts = List<String>.from(depts);
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DataService.saveWorkshopDepartments(_workshopDepts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approval lines saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workshop Manager approval required for:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _kAllDepartments.map((dept) {
                final checked = _workshopDepts.contains(dept);
                return FilterChip(
                  label: Text(dept),
                  selected: checked,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _workshopDepts.add(dept);
                      } else {
                        _workshopDepts.remove(dept);
                      }
                    });
                  },
                  selectedColor:
                      AppTheme.primaryOrange.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryOrange,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'All other departments go directly to the General Manager.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reasons card
// ─────────────────────────────────────────────────────────────────────────────

class _ReasonsCard extends StatefulWidget {
  const _ReasonsCard();

  @override
  State<_ReasonsCard> createState() => _ReasonsCardState();
}

class _ReasonsCardState extends State<_ReasonsCard> {
  final _controller = TextEditingController();
  String? _editingId;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user =
        Provider.of<UserProvider>(context, listen: false).currentUser;
    await DataService.addReason(text, user?.name ?? '');
    _controller.clear();
  }

  Future<void> _saveEdit(String id) async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    await DataService.updateReason(id, text);
    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add new
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'New reason…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List
            StreamBuilder<List<Map<String, String>>>(
              stream: DataService.getReasonsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reasons = snapshot.data ?? [];
                if (reasons.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No reasons yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return Column(
                  children: reasons.map((r) {
                    final id = r['id']!;
                    final isEditing = _editingId == id;
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      title: isEditing
                          ? TextField(
                              controller: _editController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                              ),
                              onSubmitted: (_) => _saveEdit(id),
                            )
                          : Text(r['reason']!),
                      trailing: isEditing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green, size: 20),
                                  onPressed: () => _saveEdit(id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 20),
                                  onPressed: () =>
                                      setState(() => _editingId = null),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  onPressed: () {
                                    _editController.text = r['reason']!;
                                    setState(() => _editingId = id);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red.shade400),
                                  onPressed: () =>
                                      _confirmDelete(context, id, r['reason']!),
                                ),
                              ],
                            ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String id, String reason) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reason'),
        content: Text('Delete "$reason"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await DataService.deleteReason(id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account card
// ─────────────────────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final dynamic user;
  final AppRole role;

  const _AccountCard({required this.user, required this.role});

  @override
  Widget build(BuildContext context) {
    final roleLabel = _roleLabel(role);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
              child: Text(
                user?.name?.isNotEmpty == true ? user!.name[0] : 'U',
                style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${user?.department ?? ''}  ·  $roleLabel',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (user?.clockNum?.isNotEmpty == true)
                    Text(
                      'Clock: ${user!.clockNum}',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.generalManager:
        return 'General Manager';
      case AppRole.workshopManager:
        return 'Workshop Manager';
      case AppRole.wages:
        return 'Wages';
      case AppRole.deptManager:
        return 'Department Manager';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header helper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryOrange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
