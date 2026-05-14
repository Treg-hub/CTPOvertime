import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Valid status values — use these constants everywhere instead of raw strings.
class OTStatus {
  static const pending = 'Pending';
  static const workshopApproved = 'Workshop Approved';
  static const approved = 'Approved';
  static const cancelled = 'Cancelled';
}

class OvertimeEntry {
  final String id;
  final String duNumber;
  final String clockNum;
  final String employeeName;
  final String press;
  final DateTime date;
  final String shiftType;
  final String overtimeType;
  final DateTime startTime;
  final DateTime endTime;
  final String department;
  final String reason;
  final String? description;
  final String status;
  final DateTime? dateEntered;
  final String? enteredBy;
  final String? overtimeNumber;
  final List<Map<String, dynamic>> editHistory;

  // ── Approval tracking ─────────────────────────────────────────────────────
  final String? approvedBy;      // name of whoever gave final (GM) approval
  final DateTime? approvedAt;    // timestamp of final approval

  // ── Rejection tracking ────────────────────────────────────────────────────
  final String? rejectionReason;    // set by Workshop Manager or GM on reject
  final bool rejectedAcknowledged;  // true once the dept manager opens the entry

  // ── Wages download tracking ───────────────────────────────────────────────
  final bool downloadedByWages;  // true after included in a wages download
  final DateTime? downloadedAt;  // when it was downloaded

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
    this.status = OTStatus.pending,
    this.dateEntered,
    this.enteredBy,
    this.overtimeNumber,
    this.editHistory = const [],
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.rejectedAcknowledged = false,
    this.downloadedByWages = false,
    this.downloadedAt,
  }) : id = id ?? const Uuid().v4();

  double get hours => endTime.difference(startTime).inMinutes / 60.0;

  bool get isRejectedUnacknowledged =>
      status == OTStatus.cancelled &&
      (rejectionReason?.isNotEmpty ?? false) &&
      !rejectedAcknowledged;

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
        'dateEntered': dateEntered != null
            ? Timestamp.fromDate(dateEntered!)
            : FieldValue.serverTimestamp(),
        'enteredBy': enteredBy,
        'overtimeNumber': overtimeNumber,
        'editHistory': editHistory,
        'approvedBy': approvedBy,
        'approvedAt':
            approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
        'rejectionReason': rejectionReason,
        'rejectedAcknowledged': rejectedAcknowledged,
        'downloadedByWages': downloadedByWages,
        'downloadedAt':
            downloadedAt != null ? Timestamp.fromDate(downloadedAt!) : null,
      };

  factory OvertimeEntry.fromMap(Map<String, dynamic> map, String id) =>
      OvertimeEntry(
        id: id,
        duNumber: map['duNumber'] ?? '',
        clockNum: map['clockNum'] ?? '',
        employeeName: map['employeeName'] ?? '',
        press: map['press'] ?? '',
        date: (map['date'] as Timestamp).toDate(),
        shiftType: map['shiftType'] ?? 'Day',
        overtimeType: map['overtimeType'] ?? 'Normal Time',
        startTime: (map['startTime'] as Timestamp).toDate(),
        endTime: (map['endTime'] as Timestamp).toDate(),
        department: map['department'] ?? '',
        reason: map['reason'] ?? '',
        description: map['description'],
        status: map['status'] ?? OTStatus.pending,
        dateEntered: map['dateEntered'] != null
            ? (map['dateEntered'] as Timestamp).toDate()
            : null,
        enteredBy: map['enteredBy'],
        overtimeNumber: map['overtimeNumber'],
        editHistory: (map['editHistory'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        approvedBy: map['approvedBy'],
        approvedAt: map['approvedAt'] != null
            ? (map['approvedAt'] as Timestamp).toDate()
            : null,
        rejectionReason: map['rejectionReason'],
        rejectedAcknowledged: map['rejectedAcknowledged'] as bool? ?? false,
        downloadedByWages: map['downloadedByWages'] as bool? ?? false,
        downloadedAt: map['downloadedAt'] != null
            ? (map['downloadedAt'] as Timestamp).toDate()
            : null,
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
    String? overtimeNumber,
    List<Map<String, dynamic>>? editHistory,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    bool? rejectedAcknowledged,
    bool? downloadedByWages,
    DateTime? downloadedAt,
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
      overtimeNumber: overtimeNumber ?? this.overtimeNumber,
      editHistory: editHistory ?? this.editHistory,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedAcknowledged: rejectedAcknowledged ?? this.rejectedAcknowledged,
      downloadedByWages: downloadedByWages ?? this.downloadedByWages,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }
}
