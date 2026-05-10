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

        return Card(
          key: ValueKey(entry.id),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: entry.press == 'Badenia' 
                  ? Colors.green 
                  : entry.press == 'Wifag' 
                      ? Colors.orange 
                      : Colors.blue,
              child: Text(entry.press.isNotEmpty ? entry.press[0] : 'G'),
            ),
            title: Text('${entry.employeeName} (${entry.clockNum})'),
            subtitle: Text(
              '${entry.overtimeNumber ?? 'N/A'} • ${DateFormat('yyyy-MM-dd').format(entry.date)} • ${entry.shiftType} • ${entry.department} • ${entry.hours.toStringAsFixed(1)} hrs',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.status == 'Approved' ? Colors.green.shade800 : entry.status == 'Pending' ? Colors.orange.shade800 : Colors.red.shade800,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.cancel), // was Icons.delete
                    onPressed: () => onDelete!(entry),
                    tooltip: 'Cancel Entry (audit trail - not deleted)',
                  ),
              ],
            ),
            onTap: () => onSelect(entry),
          ),
        );
      },
    );
  }
}