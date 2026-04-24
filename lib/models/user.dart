class User {
  final String id;
  final String name;
  final String clockNum;
  final String department;
  final String email;
  final bool isManager;

  User({
    required this.id,
    required this.name,
    required this.clockNum,
    required this.department,
    required this.email,
    required this.isManager,
  });

  factory User.fromMap(Map<String, dynamic> map, String id) => User(
        id: id,
        name: map['name'] ?? '',
        clockNum: map['clockNo'] ?? '',
        department: map['department'] ?? '',
        email: map['email'] ?? '',
        isManager: map['position'] == 'Manager',
      );
}