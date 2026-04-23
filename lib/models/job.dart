import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String duNumber;
  final String jobName;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String press; // Badenia, Wifag, Aurora, etc.

  Job({
    String? id,
    required this.duNumber,
    required this.jobName,
    required this.startDateTime,
    required this.endDateTime,
    required this.press,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'duNumber': duNumber,
        'jobName': jobName,
        'startDateTime': Timestamp.fromDate(startDateTime),
        'endDateTime': Timestamp.fromDate(endDateTime),
        'press': press,
      };

  factory Job.fromMap(Map<String, dynamic> map, String id) => Job(
        id: id,
        duNumber: map['duNumber'],
        jobName: map['jobName'],
        startDateTime: (map['startDateTime'] as Timestamp).toDate(),
        endDateTime: (map['endDateTime'] as Timestamp).toDate(),
        press: map['press'],
      );
}