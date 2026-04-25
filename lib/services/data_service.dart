import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';

class DataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Job>> get jobs async {
    final snapshot = await _firestore.collection('jobs').get();
    return snapshot.docs.map((doc) => Job.fromMap(doc.data(), doc.id)).toList();
  }

  static Future<List<OvertimeEntry>> get overtimeEntries async {
    final snapshot = await _firestore.collection('overtime_entries').get();
    return snapshot.docs.map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id)).toList();
  }

  static Future<List<OvertimeEntry>> getPendingOvertime() async {
    final snapshot = await _firestore
        .collection('overtime_entries')
        .where('status', isEqualTo: 'Pending')
        .get();
    return snapshot.docs.map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id)).toList();
  }

  static Future<List<OvertimeEntry>> getRecentOvertime({int limit = 25}) async {
    final snapshot = await _firestore
        .collection('overtime_entries')
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id)).toList();
  }

  static Stream<List<OvertimeEntry>> getRecentOvertimeStream({int limit = 25}) {
    return _firestore
        .collection('overtime_entries')
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id)).toList());
  }

  static Future<void> addJob(Job job) async {
    await _firestore.collection('jobs').add(job.toMap());
  }

  static Future<void> updateJob(Job job) async {
    await _firestore.collection('jobs').doc(job.id).update(job.toMap());
  }

  static Future<void> addOvertime(OvertimeEntry entry) async {
    await _firestore.collection('overtime_entries').add(entry.toMap());
  }

  static Future<void> updateOvertime(OvertimeEntry entry) async {
    await _firestore.collection('overtime_entries').doc(entry.id).update(entry.toMap());
  }

  static Future<void> deleteOvertime(String id) async {
    await _firestore.collection('overtime_entries').doc(id).delete();
  }

  static Future<void> deleteJob(String id) async {
    await _firestore.collection('jobs').doc(id).delete();
  }

  static Stream<List<Map<String, String>>> getReasonsStream() {
    return _firestore.collection('reasons').orderBy('reason').snapshots().map((s) => s.docs.map((d) => {'id': d.id, 'reason': d['reason'] as String}).toList());
  }

  static Future<void> addReason(String reason, String createdBy) async {
    await _firestore.collection('reasons').add({
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateReason(String id, String newReason) async {
    await _firestore.collection('reasons').doc(id).update({'reason': newReason});
  }

  static Future<void> deleteReason(String id) async {
    await _firestore.collection('reasons').doc(id).delete();
  }

  static Future<List<Map<String, String>>> getEmployees() async {
    final entries = await overtimeEntries;
    final unique = <String, String>{};
    for (var e in entries) {
      unique[e.clockNum] = e.employeeName;
    }
    return unique.entries.map((e) => {'clockNum': e.key, 'name': e.value}).toList();
  }

  // Smart overlap calculation
  static Future<List<Map<String, dynamic>>> getOverlappingOvertime(Job job) async {
    List<Map<String, dynamic>> overlaps = [];
    final overtimeEntries = await DataService.overtimeEntries;

    for (var ot in overtimeEntries) {
      // Check if same press OR same job number
      bool pressMatch = ot.press.isNotEmpty && ot.press == job.press;
      bool jobMatch = ot.duNumber.isNotEmpty && ot.duNumber == job.duNumber;

      if (!pressMatch && !jobMatch) continue;

      // Calculate overlap
      DateTime otStart = ot.startTime;
      DateTime otEnd = ot.endTime;
      DateTime jobStart = job.startDateTime;
      DateTime jobEnd = job.endDateTime;

      DateTime overlapStart = otStart.isAfter(jobStart) ? otStart : jobStart;
      DateTime overlapEnd = otEnd.isBefore(jobEnd) ? otEnd : jobEnd;

      if (overlapStart.isBefore(overlapEnd)) {
        double overlapHours = overlapEnd.difference(overlapStart).inMinutes / 60.0;

        overlaps.add({
          'entry': ot,
          'overlapHours': overlapHours,
          'overlapStart': overlapStart,
          'overlapEnd': overlapEnd,
          'matchType': pressMatch ? 'Press' : 'Job Number',
        });
      }
    }

    return overlaps;
  }
}