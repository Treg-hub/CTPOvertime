import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OvertimeEntry {
  final String id;
  final String duNumber; // Job DU or empty for general
  final String clockNum;
  final String employeeName;
  final String press; // Badenia, Wifag, Aurora, or empty
  final DateTime date;
  final String shiftType; // Day, Night, Custom
  final String overtimeType; // Normal Time, 1.5 X 10 + 2 X 2, 2 X 12, Standby
  final DateTime startTime;
  final DateTime endTime;
  final String department;
  final String reason;
  final String? description;
  final String status; // Pending, Approved, Cancelled
  final DateTime? dateEntered; // When entry was created
  final String? enteredBy; // Who created the entry

  OvertimeEntry({
    String? id,
    required this.duNumber,
    required this.clockNum,
    required this.employeeName,
    required this.press,
    required this.date,
    required this.shiftType,
    required this.overtimeType,
    required this.startTime,
    required this.endTime,
    required this.department,
    required this.reason,
    this.description,
    this.status = 'Pending',
    this.dateEntered,
    this.enteredBy,
  }) : id = id ?? const Uuid().v4();

  double get hours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  Map<String, dynamic> toMap() => {
        'duNumber': duNumber,
        'clockNum': clockNum,
        'employeeName': employeeName,
        'press': press,
        'date': Timestamp.fromDate(date),
        'shiftType': shiftType,
        'overtimeType': overtimeType,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'department': department,
        'reason': reason,
        'description': description,
        'status': status,
        'dateEntered': dateEntered != null ? Timestamp.fromDate(dateEntered!) : FieldValue.serverTimestamp(),
        'enteredBy': enteredBy,
      };

  factory OvertimeEntry.fromMap(Map<String, dynamic> map, String id) => OvertimeEntry(
        id: id,
        duNumber: map['duNumber'] ?? '',
        clockNum: map['clockNum'],
        employeeName: map['employeeName'],
        press: map['press'] ?? '',
        date: (map['date'] as Timestamp).toDate(),
        shiftType: map['shiftType'],
        overtimeType: map['overtimeType'] ?? 'Normal Time',
        startTime: (map['startTime'] as Timestamp).toDate(),
        endTime: (map['endTime'] as Timestamp).toDate(),
        department: map['department'],
        reason: map['reason'],
        description: map['description'],
        status: map['status'] ?? 'Pending',
        dateEntered: map['dateEntered'] != null ? (map['dateEntered'] as Timestamp).toDate() : null,
        enteredBy: map['enteredBy'],
      );

  OvertimeEntry copyWith({
    String? id,
    String? duNumber,
    String? clockNum,
    String? employeeName,
    String? press,
    DateTime? date,
    String? shiftType,
    String? overtimeType,
    DateTime? startTime,
    DateTime? endTime,
    String? department,
    String? reason,
    String? description,
    String? status,
    DateTime? dateEntered,
    String? enteredBy,
  }) {
    return OvertimeEntry(
      id: id ?? this.id,
      duNumber: duNumber ?? this.duNumber,
      clockNum: clockNum ?? this.clockNum,
      employeeName: employeeName ?? this.employeeName,
      press: press ?? this.press,
      date: date ?? this.date,
      shiftType: shiftType ?? this.shiftType,
      overtimeType: overtimeType ?? this.overtimeType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      department: department ?? this.department,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      dateEntered: dateEntered ?? this.dateEntered,
      enteredBy: enteredBy ?? this.enteredBy,
    );
  }
}