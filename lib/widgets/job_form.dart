import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:intl/intl.dart';

class JobForm extends StatefulWidget {
  final Job? initialJob;
  final Function(Job) onSave;

  const JobForm({
    super.key,
    this.initialJob,
    required this.onSave,
  });

  @override
  State<JobForm> createState() => _JobFormState();
}

class _JobFormState extends State<JobForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _duController;
  late TextEditingController _jobNameController;

  String _press = 'Badenia';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 3));

  final List<String> _presses = ['Badenia', 'Wifag', 'Aurora'];

  @override
  void initState() {
    super.initState();
    final job = widget.initialJob;
    _duController = TextEditingController(text: job?.duNumber ?? '');
    _jobNameController = TextEditingController(text: job?.jobName ?? '');

    if (job != null) {
      _press = job.press;
      _start = job.startDateTime;
      _end = job.endDateTime;
    }
  }

  @override
  void dispose() {
    _duController.dispose();
    _jobNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _start : _end),
    );
    if (time == null) return;

    final newDateTime = DateTime(
      date.year, date.month, date.day, time.hour, time.minute,
    );

    setState(() {
      if (isStart) {
        _start = newDateTime;
      } else {
        _end = newDateTime;
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final job = Job(
        id: widget.initialJob?.id,
        duNumber: _duController.text.trim(),
        jobName: _jobNameController.text.trim(),
        startDateTime: _start,
        endDateTime: _end,
        press: _press,
      );
      widget.onSave(job);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _duController,
            decoration: const InputDecoration(
              labelText: 'DU Number',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _jobNameController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Job Name / Description',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _press,
            decoration: const InputDecoration(
              labelText: 'Press',
              border: OutlineInputBorder(),
            ),
            items: _presses.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _press = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateTime(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date & Time',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd HH:mm').format(_start)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date & Time',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd HH:mm').format(_end)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Job'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}