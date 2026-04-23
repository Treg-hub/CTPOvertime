import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _dateRange = 'All Time';
  DateTimeRange? _customRange;

  List<OvertimeEntry> _filterEntries(List<OvertimeEntry> entries) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (_dateRange) {
      case 'Previous Week':
        start = now.subtract(const Duration(days: 7));
        end = now;
        break;
      case 'Previous Month':
        start = DateTime(now.year, now.month - 1, now.day);
        end = now;
        break;
      case 'Custom':
        if (_customRange != null) {
          start = _customRange!.start;
          end = _customRange!.end;
        } else {
          return entries;
        }
        break;
      default:
        return entries;
    }
    return entries.where((e) => e.date.isAfter(start.subtract(const Duration(days: 1))) && e.date.isBefore(end.add(const Duration(days: 1)))).toList();
  }

  void _selectCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OvertimeEntry>>(
      future: DataService.overtimeEntries,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading dashboard data: ${snapshot.error}'));
        }
        final allEntries = snapshot.data ?? [];
        final entries = _filterEntries(allEntries);
        final totalHours = entries.fold(0.0, (sum, e) => sum + e.hours);
        final totalPeople = entries.map((e) => e.employeeName).toSet().length;
        final pending = entries.where((e) => e.status == 'Pending').length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _dateRange,
                    items: const [
                      DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                      DropdownMenuItem(value: 'Previous Week', child: Text('Previous Week')),
                      DropdownMenuItem(value: 'Previous Month', child: Text('Previous Month')),
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _dateRange = value!;
                        if (value == 'Custom') {
                          _selectCustomRange();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildCard('Total Hours', totalHours.toStringAsFixed(1), Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCard('People on OT', totalPeople.toString(), Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCard('Pending', pending.toString(), Colors.orange)),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Employee Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: _getBreakdown(entries).entries.map((deptEntry) => ExpansionTile(
                      title: Text('${deptEntry.key} (${deptEntry.value.values.fold(0.0, (sum, h) => sum + h).toStringAsFixed(1)} hrs total)'),
                      children: deptEntry.value.entries.map((personEntry) => ListTile(
                        title: Text(personEntry.key),
                        trailing: Text('${personEntry.value.toStringAsFixed(1)} hrs'),
                      )).toList(),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            Text(title),
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, double>> _getBreakdown(List<OvertimeEntry> entries) {
    Map<String, Map<String, double>> deptMap = {};
    for (var e in entries) {
      deptMap[e.department] ??= {};
      deptMap[e.department]![e.employeeName] = (deptMap[e.department]![e.employeeName] ?? 0) + e.hours;
    }
    return deptMap;
  }
}