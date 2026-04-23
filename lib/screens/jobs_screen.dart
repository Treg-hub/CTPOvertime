import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/widgets/job_form.dart';
import 'package:ctp_overtime_tracker/widgets/job_list.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  Job? _selectedJob;

  void _selectJob(Job job) {
    setState(() {
      _selectedJob = job;
    });
  }

  void _addNew() {
    setState(() {
      _selectedJob = null;
    });
  }

  void _saveJob(Job job) async {
    if (_selectedJob == null) {
      await DataService.addJob(job);
    } else {
      await DataService.updateJob(job);
    }
    setState(() {
      _selectedJob = job;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Job saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Job>>(
      future: DataService.jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading jobs: ${snapshot.error}'));
        }
        final jobs = snapshot.data ?? [];
        return Row(
          children: [
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
                        children: [
                          Text(
                            _selectedJob == null ? 'New Job Entry' : 'Edit Job',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _addNew,
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Job'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: JobForm(
                          initialJob: _selectedJob,
                          onSave: _saveJob,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Jobs List (${jobs.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: JobList(
                        jobs: jobs,
                        onSelect: _selectJob,
                        selectedId: _selectedJob?.id,
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
  }
}