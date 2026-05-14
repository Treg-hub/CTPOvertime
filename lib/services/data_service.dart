import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ctp_overtime_tracker/models/job.dart';
import 'package:ctp_overtime_tracker/models/overtime_entry.dart';

class DataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Jobs ──────────────────────────────────────────────────────────────────

  static Future<List<Job>> get jobs async {
    final snapshot = await _firestore.collection('jobs').limit(100).get();
    return snapshot.docs
        .map((doc) => Job.fromMap(doc.data(), doc.id))
        .toList();
  }

  static Future<void> addJob(Job job) async {
    await _firestore.collection('jobs').add(job.toMap());
  }

  static Future<void> updateJob(Job job) async {
    await _firestore.collection('jobs').doc(job.id).update(job.toMap());
  }

  static Future<void> deleteJob(String id) async {
    await _firestore.collection('jobs').doc(id).delete();
  }

  // ── Overtime — general ────────────────────────────────────────────────────

  static Future<List<OvertimeEntry>> get overtimeEntries async {
    final snapshot = await _firestore
        .collection('overtime_entries')
        .limit(1000)
        .get();
    return snapshot.docs
        .map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id))
        .toList();
  }

  static Future<List<OvertimeEntry>> getRecentOvertime(
      {int limit = 25}) async {
    final snapshot = await _firestore
        .collection('overtime_entries')
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id))
        .toList();
  }

  static Stream<List<OvertimeEntry>> getRecentOvertimeStream(
      {int limit = 25}) {
    return _firestore
        .collection('overtime_entries')
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => OvertimeEntry.fromMap(d.data(), d.id)).toList());
  }

  // ── Overtime — dept list (main screen) ────────────────────────────────────
  // Composite index: department ASC, status ASC, date DESC

  static Stream<List<OvertimeEntry>> getFilteredOvertimeStream({
    String? department,
    String status = OTStatus.pending,
    int limit = 200,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection('overtime_entries');

    if (department != null && department.isNotEmpty && department != 'All') {
      query = query.where('department', isEqualTo: department);
    }
    if (status.isNotEmpty && status != 'All') {
      query = query.where('status', isEqualTo: status);
    }
    if (dateFrom != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFrom));
    }
    if (dateTo != null) {
      query =
          query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(dateTo));
    }

    query = query.orderBy('date', descending: true).limit(limit);

    return query.snapshots().map((s) =>
        s.docs.map((d) => OvertimeEntry.fromMap(d.data(), d.id)).toList());
  }

  // ── Overtime — rejection badge ─────────────────────────────────────────────
  // Count of entries in a dept that were rejected via the approval screen and
  // haven't been acknowledged by the dept manager yet.
  // Index: department ASC, status ASC, rejectedAcknowledged ASC

  static Stream<int> getRejectedUnacknowledgedCount(String department) {
    return _firestore
        .collection('overtime_entries')
        .where('department', isEqualTo: department)
        .where('status', isEqualTo: OTStatus.cancelled)
        .where('rejectedAcknowledged', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs
            .where((d) =>
                (d.data()['rejectionReason'] as String?)?.isNotEmpty == true)
            .length);
  }

  // ── Overtime — approval screens ───────────────────────────────────────────

  // Workshop Manager: Pending entries from the configured workshop departments
  // (Mechanical + Electrical by default). Ordered by date desc.
  // Index: status ASC, department ASC, date DESC
  static Stream<List<OvertimeEntry>> getWorkshopApprovalStream(
      List<String> workshopDepts) {
    if (workshopDepts.isEmpty) return const Stream.empty();
    return _firestore
        .collection('overtime_entries')
        .where('status', isEqualTo: OTStatus.pending)
        .where('department', whereIn: workshopDepts)
        .orderBy('date', descending: true)
        .limit(200)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => OvertimeEntry.fromMap(d.data(), d.id)).toList());
  }

  // General Manager: Pending (non-workshop depts) + Workshop Approved (all).
  // Uses whereIn so one query covers both statuses.
  // Client-side strips out Pending entries that belong to workshop depts
  // (those should go through the workshop manager first).
  // Index: status ASC, date DESC
  static Stream<List<OvertimeEntry>> getGMApprovalStream(
      List<String> workshopDepts) {
    return _firestore
        .collection('overtime_entries')
        .where('status',
            whereIn: [OTStatus.pending, OTStatus.workshopApproved])
        .orderBy('date', descending: true)
        .limit(300)
        .snapshots()
        .map((s) {
          final all = s.docs
              .map((d) => OvertimeEntry.fromMap(d.data(), d.id))
              .toList();
          // Filter out Pending entries from workshop depts — they haven't been
          // approved by the workshop manager yet so shouldn't appear here.
          return all
              .where((e) =>
                  e.status == OTStatus.workshopApproved ||
                  !workshopDepts.contains(e.department))
              .toList();
        });
  }

  // Legacy: used by settings screen duplicate approval queue.
  static Future<List<OvertimeEntry>> getPendingOvertime() async {
    final snapshot = await _firestore
        .collection('overtime_entries')
        .where('status', isEqualTo: OTStatus.pending)
        .limit(500)
        .get();
    return snapshot.docs
        .map((doc) => OvertimeEntry.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ── Overtime — wages download ─────────────────────────────────────────────
  // Index: status ASC, downloadedByWages ASC, date DESC

  static Stream<List<OvertimeEntry>> getWagesPendingDownloadStream() {
    return _firestore
        .collection('overtime_entries')
        .where('status', isEqualTo: OTStatus.approved)
        .where('downloadedByWages', isEqualTo: false)
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => OvertimeEntry.fromMap(d.data(), d.id)).toList());
  }

  static Stream<List<OvertimeEntry>> getWagesAllApprovedStream(
      {DateTime? dateFrom, DateTime? dateTo}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('overtime_entries')
        .where('status', isEqualTo: OTStatus.approved);

    if (dateFrom != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFrom));
    }
    if (dateTo != null) {
      query =
          query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(dateTo));
    }

    return query
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => OvertimeEntry.fromMap(d.data(), d.id)).toList());
  }

  // ── Approval write operations ─────────────────────────────────────────────

  // Workshop-level approval: Pending → Workshop Approved
  static Future<void> workshopApprove(
      OvertimeEntry entry, String approvedBy) async {
    await _firestore
        .collection('overtime_entries')
        .doc(entry.id)
        .update({
      'status': OTStatus.workshopApproved,
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
      'rejectedAcknowledged': false,
    });
  }

  // GM final approval: Pending or Workshop Approved → Approved
  static Future<void> gmApprove(
      OvertimeEntry entry, String approvedBy) async {
    await _firestore
        .collection('overtime_entries')
        .doc(entry.id)
        .update({
      'status': OTStatus.approved,
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
      'rejectedAcknowledged': false,
    });
  }

  // Bulk workshop approval via batch write.
  static Future<void> workshopApproveAll(
      List<OvertimeEntry> entries, String approvedBy) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    for (final entry in entries) {
      batch.update(
        _firestore.collection('overtime_entries').doc(entry.id),
        {
          'status': OTStatus.workshopApproved,
          'approvedBy': approvedBy,
          'approvedAt': now,
          'rejectionReason': null,
          'rejectedAcknowledged': false,
        },
      );
    }
    await batch.commit();
  }

  // Bulk GM approval via batch write.
  static Future<void> gmApproveAll(
      List<OvertimeEntry> entries, String approvedBy) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    for (final entry in entries) {
      batch.update(
        _firestore.collection('overtime_entries').doc(entry.id),
        {
          'status': OTStatus.approved,
          'approvedBy': approvedBy,
          'approvedAt': now,
          'rejectionReason': null,
          'rejectedAcknowledged': false,
        },
      );
    }
    await batch.commit();
  }

  // Reject at any approval level — moves to Cancelled with reason.
  static Future<void> rejectEntry(
      OvertimeEntry entry, String rejectionReason) async {
    await _firestore
        .collection('overtime_entries')
        .doc(entry.id)
        .update({
      'status': OTStatus.cancelled,
      'rejectionReason': rejectionReason,
      'rejectedAcknowledged': false,
    });
  }

  // Stream of rejected-and-unacknowledged entries for a dept — used to render
  // the pinned "Rejected" section at the top of the Overtime list.
  // Index: department ASC, status ASC, rejectedAcknowledged ASC, date DESC
  static Stream<List<OvertimeEntry>> getRejectedUnacknowledgedStream(
      String department) {
    return _firestore
        .collection('overtime_entries')
        .where('department', isEqualTo: department)
        .where('status', isEqualTo: OTStatus.cancelled)
        .where('rejectedAcknowledged', isEqualTo: false)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => OvertimeEntry.fromMap(d.data(), d.id))
            .where((e) => e.rejectionReason?.isNotEmpty == true)
            .toList());
  }

  // Called when the dept manager opens a rejected entry — clears the badge.
  static Future<void> acknowledgeRejection(String entryId) async {
    await _firestore
        .collection('overtime_entries')
        .doc(entryId)
        .update({'rejectedAcknowledged': true});
  }

  // ── Wages download write ──────────────────────────────────────────────────

  // Marks every entry in the list as downloaded. Called after a successful
  // PDF or CSV download so they won't appear in the wages pending view again.
  static Future<void> markAsDownloadedByWages(List<String> entryIds) async {
    const batchSize = 500; // Firestore batch limit
    final now = FieldValue.serverTimestamp();
    for (var i = 0; i < entryIds.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = entryIds.skip(i).take(batchSize);
      for (final id in chunk) {
        batch.update(
          _firestore.collection('overtime_entries').doc(id),
          {'downloadedByWages': true, 'downloadedAt': now},
        );
      }
      await batch.commit();
    }
  }

  // ── General overtime CRUD ────────────────────────────────────────────────

  static Future<void> addOvertime(OvertimeEntry entry) async {
    await _firestore.collection('overtime_entries').add(entry.toMap());
  }

  static Future<void> updateOvertime(OvertimeEntry entry) async {
    if (entry.id.isEmpty) {
      await addOvertime(entry.copyWith(id: null));
      return;
    }
    try {
      await _firestore
          .collection('overtime_entries')
          .doc(entry.id)
          .update(entry.toMap());
    } catch (e) {
      throw Exception('Failed to update overtime entry: $e');
    }
  }

  static Future<void> deleteOvertime(String id) async {
    await _firestore.collection('overtime_entries').doc(id).delete();
  }

  static Future<String> getNextOvertimeNumber() async {
    final docRef = _firestore.collection('counters').doc('overtime');
    return await _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current;
      if (snapshot.exists) {
        current = snapshot.data()?['current'] ?? 0;
      } else {
        current = 0;
      }
      final next = current + 1;
      transaction.update(docRef, {'current': next});
      return '#${next.toString().padLeft(4, '0')}';
    });
  }

  // ── Reasons ───────────────────────────────────────────────────────────────

  static Stream<List<Map<String, String>>> getReasonsStream() {
    return _firestore
        .collection('reasons')
        .orderBy('reason')
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, 'reason': d['reason'] as String})
            .toList());
  }

  static Future<void> addReason(String reason, String createdBy) async {
    await _firestore.collection('reasons').add({
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateReason(String id, String newReason) async {
    await _firestore
        .collection('reasons')
        .doc(id)
        .update({'reason': newReason});
  }

  static Future<void> deleteReason(String id) async {
    await _firestore.collection('reasons').doc(id).delete();
  }

  // ── Approval config (Settings) ─────────────────────────────────────────────

  static const _approvalConfigDoc = 'approval_config';

  // Returns the departments that route through the Workshop Manager.
  // Defaults to ['Mechanical', 'Electrical'] if not yet configured.
  static Stream<List<String>> getWorkshopDepartmentsStream() {
    return _firestore
        .collection('settings')
        .doc(_approvalConfigDoc)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return ['Mechanical', 'Electrical'];
      return List<String>.from(
          doc.data()?['workshopDepartments'] ?? ['Mechanical', 'Electrical']);
    });
  }

  static Future<List<String>> getWorkshopDepartments() async {
    final doc = await _firestore
        .collection('settings')
        .doc(_approvalConfigDoc)
        .get();
    if (!doc.exists) return ['Mechanical', 'Electrical'];
    return List<String>.from(
        doc.data()?['workshopDepartments'] ?? ['Mechanical', 'Electrical']);
  }

  static Future<void> saveWorkshopDepartments(List<String> depts) async {
    await _firestore
        .collection('settings')
        .doc(_approvalConfigDoc)
        .set({'workshopDepartments': depts}, SetOptions(merge: true));
  }

  // ── Job overlap analysis ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getOverlappingOvertime(
      Job job) async {
    final List<Map<String, dynamic>> overlaps = [];
    final entries = await overtimeEntries;

    for (final ot in entries) {
      final pressMatch = ot.press.isNotEmpty && ot.press == job.press;
      final jobMatch =
          ot.duNumber.isNotEmpty && ot.duNumber == job.duNumber;
      if (!pressMatch && !jobMatch) continue;

      final overlapStart =
          ot.startTime.isAfter(job.startDateTime) ? ot.startTime : job.startDateTime;
      final overlapEnd =
          ot.endTime.isBefore(job.endDateTime) ? ot.endTime : job.endDateTime;

      if (overlapStart.isBefore(overlapEnd)) {
        final overlapHours =
            overlapEnd.difference(overlapStart).inMinutes / 60.0;
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
