import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:intl/intl.dart';

class JobsListScreen extends StatefulWidget {
  const JobsListScreen({super.key});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  late Future<List<Job>> _jobsFuture;
  final Set<String> _editingIds = {};
  final Map<String, Job> _edits = {};

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  void _loadJobs() {
    _jobsFuture = DataService.jobs;
  }

  void _startEdit(Job job) {
    setState(() {
      _editingIds.add(job.id);
      _edits[job.id] = job.copyWith();
    });
  }

  void _cancelEdit(String id) {
    setState(() {
      _editingIds.remove(id);
      _edits.remove(id);
    });
  }

  void _saveEdit(String id) async {
    await DataService.updateJob(_edits[id]!);
    setState(() {
      _editingIds.remove(id);
      _edits.remove(id);
      _loadJobs();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Job updated')),
    );
  }

  void _deleteJob(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DataService.deleteJob(id);
      setState(() {
        _loadJobs();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
      ),
      body: FutureBuilder<List<Job>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final jobs = snapshot.data ?? [];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('DU Number')),
                DataColumn(label: Text('Job Name')),
                DataColumn(label: Text('Start DateTime')),
                DataColumn(label: Text('End DateTime')),
                DataColumn(label: Text('Press')),
                DataColumn(label: Text('Actions')),
              ],
              rows: jobs.map((job) {
                final isEditing = _editingIds.contains(job.id);
                final editJob = _edits[job.id] ?? job;
                return DataRow(cells: [
                  DataCell(isEditing ? TextFormField(initialValue: editJob.duNumber, onChanged: (v) => setState(() => _edits[job.id] = editJob.copyWith(duNumber: v))) : Text(job.duNumber)),
                  DataCell(isEditing ? TextFormField(initialValue: editJob.jobName, onChanged: (v) => setState(() => _edits[job.id] = editJob.copyWith(jobName: v))) : Text(job.jobName)),
                  DataCell(isEditing ? TextFormField(initialValue: DateFormat('yyyy-MM-dd HH:mm').format(editJob.startDateTime), onChanged: (v) => setState(() => _edits[job.id] = editJob.copyWith(startDateTime: DateTime.parse(v)))) : Text(DateFormat('yyyy-MM-dd HH:mm').format(job.startDateTime))),
                  DataCell(isEditing ? TextFormField(initialValue: DateFormat('yyyy-MM-dd HH:mm').format(editJob.endDateTime), onChanged: (v) => setState(() => _edits[job.id] = editJob.copyWith(endDateTime: DateTime.parse(v)))) : Text(DateFormat('yyyy-MM-dd HH:mm').format(job.endDateTime))),
                  DataCell(isEditing ? TextFormField(initialValue: editJob.press, onChanged: (v) => setState(() => _edits[job.id] = editJob.copyWith(press: v))) : Text(job.press)),
                  DataCell(Row(
                    children: [
                      if (isEditing) ...[
                        IconButton(icon: const Icon(Icons.save), onPressed: () => _saveEdit(job.id)),
                        IconButton(icon: const Icon(Icons.cancel), onPressed: () => _cancelEdit(job.id)),
                      ] else ...[
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _startEdit(job)),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteJob(job.id)),
                      ],
                    ],
                  )),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}