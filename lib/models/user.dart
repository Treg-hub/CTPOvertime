class User {
  final String id;
  final String name;
  final String clockNum;
  final String department;
  final String email;
  final bool isManager;
  final List<String> hiddenReasons;

  User({
    required this.id,
    required this.name,
    required this.clockNum,
    required this.department,
    required this.email,
    required this.isManager,
    this.hiddenReasons = const [],
  });

  factory User.fromMap(Map<String, dynamic> map, String id) => User(
         id: id,
         name: map['name'] ?? '',
         clockNum: map['clockNo'] ?? '',
         department: map['department'] ?? '',
         email: map['email'] ?? '',
         isManager: map['position'] == 'Manager',
         hiddenReasons: List<String>.from(map['hiddenReasons'] ?? []),
       );

  Map<String, dynamic> toMap() => {
        'name': name,
        'clockNo': clockNum,
        'department': department,
        'email': email,
        'position': isManager ? 'Manager' : 'Employee',
        'hiddenReasons': hiddenReasons,
      };
}