import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:intl/intl.dart';

class JobList extends StatelessWidget {
  final List<Job> jobs;
  final Function(Job) onSelect;
  final String? selectedId;

  const JobList({
    super.key,
    required this.jobs,
    required this.onSelect,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isSelected = job.id == selectedId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: job.press == 'Badenia' 
                  ? Colors.green 
                  : job.press == 'Wifag' 
                      ? Colors.orange 
                      : Colors.blue,
              child: Text(job.press[0]),
            ),
            title: Text(job.duNumber),
            subtitle: Text(
              '${job.jobName}\n${DateFormat('MMM dd HH:mm').format(job.startDateTime)} → ${DateFormat('MMM dd HH:mm').format(job.endDateTime)}',
            ),
            isThreeLine: true,
            trailing: Chip(
              label: Text(job.press),
              backgroundColor: job.press == 'Badenia' 
                  ? Colors.green.shade100 
                  : Colors.orange.shade100,
            ),
            onTap: () => onSelect(job),
          ),
        );
      },
    );
  }
}