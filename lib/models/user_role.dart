enum UserRole {
  alumni,
  admin,
  super_admin;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.toString().split('.').last == value.toLowerCase(),
      orElse: () => UserRole.alumni,
    );
  }

  String toDisplayString() {
    switch (this) {
      case UserRole.alumni:
        return 'Alumni';
      case UserRole.admin:
        return 'College Admin';
      case UserRole.super_admin:
        return 'Admin';
    }
  }

  bool get isAdmin => this == UserRole.admin || this == UserRole.super_admin;
  bool get isSuperAdmin => this == UserRole.super_admin;
} 