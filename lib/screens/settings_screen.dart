import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/screens/overtime_entries_list_screen.dart';
import 'package:ctp_overtime_tracker/screens/jobs_list_screen.dart';
import 'package:ctp_overtime_tracker/screens/approval_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('View Overtime Entries'),
            subtitle: const Text('List all overtime entries with edit/delete'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OvertimeEntriesListScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.work),
            title: const Text('View Jobs'),
            subtitle: const Text('List all jobs with edit/delete'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsListScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.approval),
            title: const Text('Approval Queue'),
            subtitle: const Text('Approve pending overtime'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApprovalScreen()),
            ),
          ),
        ],
      ),
    );
  }
}