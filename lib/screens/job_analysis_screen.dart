import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:intl/intl.dart';

class JobAnalysisScreen extends StatefulWidget {
  const JobAnalysisScreen({super.key});

  @override
  State<JobAnalysisScreen> createState() => _JobAnalysisScreenState();
}

class _JobAnalysisScreenState extends State<JobAnalysisScreen> {
  Job? _selectedJob;
  List<Map<String, dynamic>> _overlaps = [];
  List<Job> _allJobs = [];
  Map<String, double> _jobTotalOverlaps = {};

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final jobs = await DataService.jobs;
    setState(() {
      _allJobs = jobs;
    });
    await _computeJobTotals();
    if (jobs.isNotEmpty && _selectedJob == null) {
      setState(() {
        _selectedJob = jobs.first;
      });
      _calculateOverlaps();
    }
  }

  Future<void> _computeJobTotals() async {
    final totals = <String, double>{};
    for (final job in _allJobs) {
      final overlaps = await DataService.getOverlappingOvertime(job);
      final total = overlaps.fold<double>(0, (sum, o) => sum + (o['overlapHours'] as double));
      totals[job.id] = total;
    }
    setState(() {
      _jobTotalOverlaps = totals;
    });
  }

  Future<void> _calculateOverlaps() async {
    if (_selectedJob == null) return;
    final overlaps = await DataService.getOverlappingOvertime(_selectedJob!);
    setState(() {
      _overlaps = overlaps;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupOverlapsByDept() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final o in _overlaps) {
      final dept = (o['entry'] as OvertimeEntry).department;
      if (grouped.containsKey(dept)) {
        grouped[dept]!.add(o);
      } else {
        grouped[dept] = [o];
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Job>>(
      future: DataService.jobs,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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

              Expanded(
                child: Row(
                  children: [
                    // Left: Selected Job Analysis
                    Expanded(
                      child: Column(
                        children: [
                          if (_selectedJob != null) ...[
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
                                          '${_overlaps.fold<double>(0, (sum, o) => sum + (o['overlapHours'] as double)).toStringAsFixed(1)} hrs',
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

                            // Overlap Timeline
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overlapping Overtime Entries (${_overlaps.length})',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Column(
                                            children: [
                                              // Job Timeline
                                              Container(
                                                height: 40,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Stack(
                                                  children: _overlaps.map((o) {
                                                    final jobStart = _selectedJob!.startDateTime;
                                                    final jobEnd = _selectedJob!.endDateTime;
                                                    final totalHours = jobEnd.difference(jobStart).inMinutes / 60.0;
                                                    final overlapStart = o['overlapStart'] as DateTime;
                                                    final overlapEnd = o['overlapEnd'] as DateTime;
                                                    final overlapHours = o['overlapHours'] as double;
                                                    final left = (overlapStart.difference(jobStart).inMinutes / 60.0) / totalHours * MediaQuery.of(context).size.width * 0.6;
                                                    final width = overlapHours / totalHours * MediaQuery.of(context).size.width * 0.6;
                                                    return Positioned(
                                                      left: left,
                                                      width: width,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade300,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '${overlapHours.toStringAsFixed(1)}h',
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Grouped by Department
                                              ..._groupOverlapsByDept().entries.map((deptEntry) {
                                                final dept = deptEntry.key;
                                                final deptOverlaps = deptEntry.value;
                                                final totalPeople = deptOverlaps.length;
                                                final totalHours = deptOverlaps.fold<double>(0, (sum, o) => sum + (o['overlapHours'] as double));
                                                return ExpansionTile(
                                                  title: Text('$dept ($totalPeople people, ${totalHours.toStringAsFixed(1)}h)'),
                                                  children: deptOverlaps.map((o) {
                                                    final entry = o['entry'] as OvertimeEntry;
                                                    final overlapHours = o['overlapHours'] as double;
                                                    final overlapStart = o['overlapStart'] as DateTime;
                                                    final overlapEnd = o['overlapEnd'] as DateTime;
                                                    final matchType = o['matchType'] as String;
                                                    return ListTile(
                                                      title: Text('${entry.clockNum} - ${entry.employeeName}'),
                                                      subtitle: Text('${entry.reason}\n${overlapHours.toStringAsFixed(1)}h (${DateFormat('HH:mm').format(overlapStart)}-${DateFormat('HH:mm').format(overlapEnd)}) - $matchType'),
                                                    );
                                                  }).toList(),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right: Jobs List
                    SizedBox(
                      width: 300,
                      child: Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'All Jobs (Sorted by Start Date - Newest First)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                children: () {
                                  final sortedJobs = _allJobs.toList()..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
                                  return sortedJobs.map((job) {
                                    final total = _jobTotalOverlaps[job.id] ?? 0.0;
                                    return ListTile(
                                      title: Text('${job.duNumber} - ${job.jobName}'),
                                      subtitle: Text('${job.press} - ${total.toStringAsFixed(1)}h'),
                                      selected: job.id == _selectedJob?.id,
                                      onTap: () {
                                        setState(() {
                                          _selectedJob = job;
                                        });
                                        _calculateOverlaps();
                                      },
                                    );
                                  }).toList();
                                }(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}