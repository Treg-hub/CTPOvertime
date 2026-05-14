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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: entry.press == 'Badenia'
                  ? Colors.green
                  : entry.press == 'Wifag'
                      ? Colors.orange
                      : Colors.blue,
              child: Text(entry.press.isNotEmpty ? entry.press[0] : 'G'),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.employeeName} (${entry.clockNum})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge shown when the entry has been edited after approval
                if (wasEdited)
                  Tooltip(
                    message: _buildEditTooltip(entry),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note,
                              size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 3),
                          Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${entry.overtimeNumber ?? 'N/A'} • '
              '${DateFormat('yyyy-MM-dd').format(entry.date)} • '
              '${entry.shiftType} • '
              '${entry.department} • '
              '${entry.hours.toStringAsFixed(1)} hrs',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.status == 'Approved'
                        ? Colors.green.shade800
                        : entry.status == 'Pending'
                            ? Colors.orange.shade800
                            : Colors.red.shade800,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => onDelete!(entry),
                    tooltip: 'Cancel Entry (audit trail – not deleted)',
                  ),
              ],
            ),
            onTap: () => onSelect(entry),
          ),
        );
      },
    );
  }

  /// Build a hover tooltip summarising the most recent edit.
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
