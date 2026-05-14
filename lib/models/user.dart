enum AppRole {
  deptManager,     // standard dept manager — enters own dept's overtime
  workshopManager, // Workshop dept + Manager — approves Mechanical & Electrical
  generalManager,  // General dept + Manager — final approval for all depts
  wages,           // Wages position — read-only download of approved OT
}

class User {
  final String id;
  final String name;
  final String clockNum;
  final String department;
  final String email;
  final AppRole role;
  final List<String> hiddenReasons;

  User({
    required this.id,
    required this.name,
    required this.clockNum,
    required this.department,
    required this.email,
    required this.role,
    this.hiddenReasons = const [],
  });

  // Convenience getters so existing code doesn't need changing right away.
  bool get isManager => role != AppRole.wages;
  bool get isWorkshopManager => role == AppRole.workshopManager;
  bool get isGeneralManager => role == AppRole.generalManager;
  bool get isWages => role == AppRole.wages;
  bool get canApprove =>
      role == AppRole.workshopManager || role == AppRole.generalManager;

  factory User.fromMap(Map<String, dynamic> map, String id) {
    final dept = map['department'] as String? ?? '';
    final position = map['position'] as String? ?? '';
    return User(
      id: id,
      name: map['name'] ?? '',
      clockNum: map['clockNo'] ?? '',
      department: dept,
      email: map['email'] ?? '',
      role: _deriveRole(dept, position),
      hiddenReasons: List<String>.from(map['hiddenReasons'] ?? []),
    );
  }

  static AppRole _deriveRole(String department, String position) {
    if (position == 'Wages') return AppRole.wages;
    if (position == 'Manager') {
      if (department == 'General') return AppRole.generalManager;
      if (department == 'Workshop') return AppRole.workshopManager;
    }
    return AppRole.deptManager;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'clockNo': clockNum,
        'department': department,
        'email': email,
        'position': isWages ? 'Wages' : 'Manager',
        'hiddenReasons': hiddenReasons,
      };
}
