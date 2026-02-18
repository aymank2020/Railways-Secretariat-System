class UserModel {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String email;
  final String phone;
  final String role; // admin, user, viewer
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  // Fine-grained permissions
  final bool canManageUsers;
  final bool canManageWarid;
  final bool canManageSadir;
  final bool canImportExcel;

  UserModel({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.lastLogin,
    bool? canManageUsers,
    bool? canManageWarid,
    bool? canManageSadir,
    bool? canImportExcel,
  })  : canManageUsers = canManageUsers ?? _defaultCanManageUsers(role),
        canManageWarid = canManageWarid ?? _defaultCanManageWarid(role),
        canManageSadir = canManageSadir ?? _defaultCanManageSadir(role),
        canImportExcel = canImportExcel ?? _defaultCanImportExcel(role);

  Map<String, dynamic> toMap({bool includePassword = true}) {
    final map = <String, dynamic>{
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'can_manage_users': canManageUsers ? 1 : 0,
      'can_manage_warid': canManageWarid ? 1 : 0,
      'can_manage_sadir': canManageSadir ? 1 : 0,
      'can_import_excel': canImportExcel ? 1 : 0,
    };

    if (includePassword) {
      map['password'] = password;
    }

    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final role = map['role'] as String? ?? 'user';
    return UserModel(
      id: map['id'] as int?,
      username: (map['username'] ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      fullName: (map['full_name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: role,
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'].toString()),
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'].toString())
          : null,
      canManageUsers: map['can_manage_users'] != null
          ? map['can_manage_users'] == 1
          : _defaultCanManageUsers(role),
      canManageWarid: map['can_manage_warid'] != null
          ? map['can_manage_warid'] == 1
          : _defaultCanManageWarid(role),
      canManageSadir: map['can_manage_sadir'] != null
          ? map['can_manage_sadir'] == 1
          : _defaultCanManageSadir(role),
      canImportExcel: map['can_import_excel'] != null
          ? map['can_import_excel'] == 1
          : _defaultCanImportExcel(role),
    );
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? canManageUsers,
    bool? canManageWarid,
    bool? canManageSadir,
    bool? canImportExcel,
  }) {
    final resolvedRole = role ?? this.role;
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: resolvedRole,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      canManageWarid: canManageWarid ?? this.canManageWarid,
      canManageSadir: canManageSadir ?? this.canManageSadir,
      canImportExcel: canImportExcel ?? this.canImportExcel,
    );
  }

  static bool _defaultCanManageUsers(String role) => role == 'admin';
  static bool _defaultCanManageWarid(String role) => role != 'viewer';
  static bool _defaultCanManageSadir(String role) => role != 'viewer';
  static bool _defaultCanImportExcel(String role) => role == 'admin';

  static List<UserModel> getDefaultUsers() {
    final now = DateTime.now();
    return [
      UserModel(
        id: 1,
        username: 'admin',
        password: 'admin123',
        fullName: 'مدير النظام',
        email: 'admin@railway.gov',
        phone: '0123456789',
        role: 'admin',
        createdAt: now,
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
      ),
      UserModel(
        id: 2,
        username: 'user',
        password: 'user123',
        fullName: 'مستخدم النظام',
        email: 'user@railway.gov',
        phone: '0987654321',
        role: 'user',
        createdAt: now,
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      ),
      UserModel(
        id: 3,
        username: 'aymankamel24',
        password: 'Ak@123456*',
        fullName: 'Ayman Kamel',
        email: 'aymankamel24@railway.gov',
        phone: '01000000000',
        role: 'admin',
        createdAt: now,
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
      ),
    ];
  }
}

