import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        final entries = snapshot.data ?? [];
        final totalHours = entries.fold(0.0, (sum, e) => sum + e.hours);
        final totalPeople = entries.map((e) => e.employeeName).toSet().length;
        final pending = entries.where((e) => e.status == 'Pending').length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
              const Text('Department Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._getBreakdown(entries).entries.map((e) => Card(
                child: ListTile(
                  title: Text(e.key),
                  trailing: Text('${e.value.toStringAsFixed(1)} hrs'),
                ),
              )),
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

  Map<String, double> _getBreakdown(List entries) {
    Map<String, double> map = {};
    for (var e in entries) {
      map[e.department] = (map[e.department] ?? 0) + e.hours;
    }
    return map;
  }
}