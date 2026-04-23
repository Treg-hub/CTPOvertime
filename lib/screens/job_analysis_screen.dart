import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:intl/intl.dart';

class JobAnalysisScreen extends StatefulWidget {
  const JobAnalysisScreen({super.key});

  @override
  State<JobAnalysisScreen> createState() => _JobAnalysisScreenState();
}

class _JobAnalysisScreenState extends State<JobAnalysisScreen> {
  Job? _selectedJob;
  Future<List<Map<String, dynamic>>>? _overlapsFuture;

  @override
  void initState() {
    super.initState();
    DataService.jobs.then((jobsList) {
      if (jobsList.isNotEmpty) {
        setState(() {
          _selectedJob = jobsList.first;
          _calculateOverlaps();
        });
      }
    });
  }

  void _calculateOverlaps() {
    if (_selectedJob == null) return;
    setState(() {
      _overlapsFuture = DataService.getOverlappingOvertime(_selectedJob!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<Job>>(
        future: DataService.jobs,
        builder: (context, jobsSnapshot) {
          if (jobsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (jobsSnapshot.hasError) {
            return Center(child: Text('Error loading jobs: ${jobsSnapshot.error}'));
          }
          final jobs = jobsSnapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job Overtime Analysis',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Shows overtime that overlaps with job run time on the same press, or same job number if no press assigned',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Job Selector
              DropdownButtonFormField<Job>(
                initialValue: _selectedJob,
                decoration: const InputDecoration(
                  labelText: 'Select Job',
                  border: OutlineInputBorder(),
                ),
                items: jobs.toSet().toList().map((job) => DropdownMenuItem(
                  value: job,
                  child: Text('${job.duNumber} - ${job.jobName} (${job.press})'),
                )).toList(),
                onChanged: (job) {
                  setState(() {
                    _selectedJob = job;
                  });
                  _calculateOverlaps();
                },
              ),
              const SizedBox(height: 24),

              if (_selectedJob != null && _overlapsFuture != null) ...[
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _overlapsFuture,
                  builder: (context, overlapsSnapshot) {
                    if (overlapsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (overlapsSnapshot.hasError) {
                      return Center(child: Text('Error calculating overlaps: ${overlapsSnapshot.error}'));
                    }
                    final overlaps = overlapsSnapshot.data ?? [];
                    return Column(
                      children: [
                        // Summary Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedJob!.duNumber} ${_selectedJob!.jobName}',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${DateFormat('yyyy-MM-dd HH:mm').format(_selectedJob!.startDateTime)} → ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedJob!.endDateTime)} on ${_selectedJob!.press}',
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      'Total Overlapping Overtime: ',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${overlaps.fold<double>(0, (sum, o) => sum + (o['overlapHours'] as double)).toStringAsFixed(1)} hrs',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Overlap Table
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Overlapping Overtime Entries (${overlaps.length})',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Date')),
                                          DataColumn(label: Text('Employee')),
                                          DataColumn(label: Text('Original Shift')),
                                          DataColumn(label: Text('Overlap Period')),
                                          DataColumn(label: Text('Overlap Hrs')),
                                          DataColumn(label: Text('Match')),
                                        ],
                                        rows: overlaps.map((o) {
                                          final entry = o['entry'];
                                          return DataRow(cells: [
                                            DataCell(Text(DateFormat('MMM dd').format(entry.date))),
                                            DataCell(Text(entry.employeeName)),
                                            DataCell(Text('${DateFormat('HH:mm').format(entry.startTime)}-${DateFormat('HH:mm').format(entry.endTime)}')),
                                            DataCell(Text(
                                              '${DateFormat('HH:mm').format(o['overlapStart'])}-${DateFormat('HH:mm').format(o['overlapEnd'])}',
                                            )),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  (o['overlapHours'] as double).toStringAsFixed(1),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(o['matchType'])),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}