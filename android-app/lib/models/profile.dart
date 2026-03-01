class Profile {
  const Profile({
    required this.fullName,
    this.className,
    this.avatarUrl,
    this.classTeacher,
    this.role,
  });

  final String fullName;
  final String? className;
  final String? avatarUrl;
  final String? classTeacher;
  final String? role;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      fullName: (json['fullName'] ?? '').toString(),
      className: json['className']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      classTeacher: json['classTeacher']?.toString(),
      role: json['role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'className': className,
      'avatarUrl': avatarUrl,
      'classTeacher': classTeacher,
      'role': role,
    };
  }
}

