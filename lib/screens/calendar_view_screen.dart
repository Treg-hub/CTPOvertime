import 'package:flutter/material.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<OvertimeEntry>> _overtimeByDate = {};
  String _filterDepartment = 'All';
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    DataService.overtimeEntries.then((entries) {
      setState(() {
        _loadOvertimeData(entries);
      });
    });
  }

  void _loadOvertimeData(List<OvertimeEntry> allEntries) {
    _overtimeByDate.clear();

    for (var entry in allEntries) {
      final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (_overtimeByDate.containsKey(dateKey)) {
        _overtimeByDate[dateKey]!.add(entry);
      } else {
        _overtimeByDate[dateKey] = [entry];
      }
    }
  }

  List<OvertimeEntry> _getEntriesForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    var entries = _overtimeByDate[dateKey] ?? [];
    if (_filterDepartment != 'All') {
      entries = entries.where((e) => e.department == _filterDepartment).toList();
    }
    return entries;
  }

  int _getTotalPeopleForDay(DateTime day) {
    return _getEntriesForDay(day).length;
  }

  double _getTotalHoursForDay(DateTime day) {
    return _getEntriesForDay(day).fold(0.0, (sum, entry) => sum + entry.hours);
  }

  Map<String, int> _getDepartmentBreakdown(DateTime day) {
    final entries = _getEntriesForDay(day);
    Map<String, int> breakdown = {};
    for (var entry in entries) {
      breakdown[entry.department] = (breakdown[entry.department] ?? 0) + 1;
    }
    return breakdown;
  }

  void _showDayDetails(DateTime day) {
    final entries = _getEntriesForDay(day);
    final breakdown = _getDepartmentBreakdown(day);
    final totalHours = _getTotalHoursForDay(day);
    final totalPeople = entries.length;

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No overtime on this day')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Overtime on ${DateFormat('EEEE, MMM dd').format(day)}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('$totalPeople people working', style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('${totalHours.toStringAsFixed(1)} total hours', style: const TextStyle(fontSize: 16)),
                ],
              ),
              const Divider(height: 24),

              // Day vs Night breakdown
              const Text('Shift Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...entries.map((entry) {
                final isNight = entry.shiftType == 'Night';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(isNight ? '🌙' : '☀️', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${entry.employeeName} (${entry.department})'),
                      ),
                      Text('${entry.hours.toStringAsFixed(1)}h'),
                    ],
                  ),
                );
              }),

              const Divider(height: 24),

              // Department breakdown
              const Text('By Department:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...breakdown.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${e.value} people', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Overtime Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: Icon(_calendarFormat == CalendarFormat.month ? Icons.calendar_view_week : Icons.calendar_view_month),
                onPressed: () => setState(() => _calendarFormat = _calendarFormat == CalendarFormat.month ? CalendarFormat.week : CalendarFormat.month),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filterDepartment,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Departments')),
                  DropdownMenuItem(value: 'Pressroom', child: Text('Pressroom')),
                  DropdownMenuItem(value: 'PostPress', child: Text('PostPress')),
                  DropdownMenuItem(value: 'PrePress', child: Text('PrePress')),
                  DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                  DropdownMenuItem(value: 'Mechanical', child: Text('Mechanical')),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterDepartment = value!;
                  });
                },
              ),
            ],
          ),
        ),

        // Calendar
        Expanded(
          child: TableCalendar(
            firstDay: DateTime(2025, 1, 1),
            lastDay: DateTime(2027, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _showDayDetails(selectedDay);
            },
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.red),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final entries = _getEntriesForDay(day);
                if (entries.isEmpty) return null;
                final totalHours = _getTotalHoursForDay(day);
                final totalPeople = entries.length;
                return Tooltip(
                  message: 'Hours: ${totalHours.toStringAsFixed(1)}, People: $totalPeople',
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(color: focusedDay ? Colors.black : Colors.grey),
                    ),
                  ),
                );
              },
              markerBuilder: (context, date, events) {
                final entries = _getEntriesForDay(date);
                if (entries.isEmpty) return null;

                final dayCount = entries.where((e) => e.shiftType == 'Day').length;
                final nightCount = entries.where((e) => e.shiftType == 'Night').length;
                final totalPeople = entries.length;
                final scale = 1 + totalPeople * 0.1;

                return Positioned(
                  bottom: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dayCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('☀️$dayCount', style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          if (nightCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('🌙$nightCount', style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700.withOpacity(0.7 + totalPeople * 0.03),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$totalPeople', style: TextStyle(fontSize: 10 * scale, color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('☀️ Day Shift'),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🌙 Night Shift'),
              ),
              const SizedBox(width: 16),
              const Text('Tap any day to see details'),
            ],
          ),
        ),
      ],
    );
  }
}