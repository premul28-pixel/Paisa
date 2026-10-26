class UserModel {
  final int? id;
  final String userId;
  final String passwordHash;
  final String recoveryPin; // 6-digit recovery PIN
  final String? profileName;
  final String? dob;
  final String? email;
  final String? phone;

  const UserModel({
    this.id,
    required this.userId,
    required this.passwordHash,
    required this.recoveryPin,
    this.profileName,
    this.dob,
    this.email,
    this.phone,
  });

  /// Factory constructor to create a UserModel instance from SQLite query results.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      passwordHash: map['password_hash'] as String,
      recoveryPin: map['recovery_pin'] as String,
      profileName: map['profile_name'] as String?,
      dob: map['dob'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
    );
  }

  /// Converts the UserModel into a Map suitable for SQLite database operations.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'password_hash': passwordHash,
      'recovery_pin': recoveryPin,
      'profile_name': profileName,
      'dob': dob,
      'email': email,
      'phone': phone,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Creates a copy of this UserModel with updated fields.
  UserModel copyWith({
    int? id,
    String? userId,
    String? passwordHash,
    String? recoveryPin,
    String? profileName,
    String? dob,
    String? email,
    String? phone,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      passwordHash: passwordHash ?? this.passwordHash,
      recoveryPin: recoveryPin ?? this.recoveryPin,
      profileName: profileName ?? this.profileName,
      dob: dob ?? this.dob,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, userId: $userId, profileName: $profileName, email: $email, phone: $phone)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.userId == userId &&
        other.passwordHash == passwordHash &&
        other.recoveryPin == recoveryPin &&
        other.profileName == profileName &&
        other.dob == dob &&
        other.email == email &&
        other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        passwordHash,
        recoveryPin,
        profileName,
        dob,
        email,
        phone,
      );
}
