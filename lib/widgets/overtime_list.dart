import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:intl/intl.dart';

class OvertimeList extends StatelessWidget {
  final List<OvertimeEntry> entries;
  final Function(OvertimeEntry) onSelect;
  final Function(OvertimeEntry)? onDelete;
  final String? selectedId;

  const OvertimeList({
    super.key,
    required this.entries,
    required this.onSelect,
    this.onDelete,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No overtime entries yet'));
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = entry.id == selectedId;
        final wasEdited = entry.editHistory.isNotEmpty;

        return Card(
          key: ValueKey(entry.id),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(entry),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Press avatar ──────────────────────────────
                  CircleAvatar(
                    backgroundColor: _pressColor(entry.press),
                    radius: 20,
                    child: Text(
                      entry.press.isNotEmpty ? entry.press[0] : 'G',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Main content ──────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 1: Name · Clock  |  Edited  Shift  Status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${entry.employeeName}  ·  ${entry.clockNum}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (wasEdited) _editedBadge(context, entry),
                            if (wasEdited) const SizedBox(width: 4),
                            _shiftBadge(entry.shiftType),
                            const SizedBox(width: 4),
                            _statusBadge(entry.status),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Row 2: OT# · Date · Dept · Press  |  Hours
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _buildMeta(entry),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${entry.hours.toStringAsFixed(1)}h',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),

                        // Row 3: OT type — Reason
                        if (entry.reason.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${entry.overtimeType} — ${entry.reason}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Cancel button ─────────────────────────────
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.cancel_outlined,
                          size: 18, color: Colors.grey.shade400),
                      onPressed: () => onDelete!(entry),
                      tooltip: 'Cancel Entry (audit trail – not deleted)',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildMeta(OvertimeEntry entry) {
    final parts = <String>[
      entry.overtimeNumber ?? 'N/A',
      DateFormat('dd MMM yyyy').format(entry.date),
      entry.department,
      if (entry.press.isNotEmpty) entry.press,
    ];
    return parts.join(' · ');
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

  Widget _shiftBadge(String shiftType) {
    final isNight = shiftType == 'Night';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isNight ? Colors.indigo.shade700 : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isNight ? 'Night' : 'Day',
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Color color;
    switch (status) {
      case 'Approved':
        color = Colors.green.shade700;
        break;
      case 'Pending':
        color = Colors.amber.shade800;
        break;
      default:
        color = Colors.red.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _editedBadge(BuildContext context, OvertimeEntry entry) {
    return Tooltip(
      message: _buildEditTooltip(entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          border: Border.all(color: Colors.blue.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 11, color: Colors.blue.shade700),
            const SizedBox(width: 2),
            Text(
              'Edited',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _buildEditTooltip(OvertimeEntry entry) {
    if (entry.editHistory.isEmpty) return '';
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    final last = entry.editHistory.last;
    final editedAt =
        DateTime.tryParse(last['editedAt'] as String? ?? '') ?? DateTime.now();
    final changes = (last['changes'] as Map<String, dynamic>?) ?? {};
    final lines = <String>[
      '${entry.editHistory.length} edit(s) recorded',
      'Last: ${last['editedBy']} on ${fmt.format(editedAt)}',
      if (changes.isNotEmpty)
        ...changes.entries.map((e) {
          final v = e.value as Map<String, dynamic>;
          return '${e.key}: "${v['from']}" → "${v['to']}"';
        }),
    ];
    return lines.join('\n');
  }
}
