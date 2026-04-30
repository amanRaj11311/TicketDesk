class Permission {
  final String resource;
  final String action;
  final String description;

  Permission({
    required this.resource,
    required this.action,
    required this.description,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      resource: json['resource'] ?? '',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String organizationId;
  final List<Permission> permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.organizationId,
    required this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var permsList = json['permissions'] as List? ?? [];
    List<Permission> parsedPermissions =
        permsList.map((i) => Permission.fromJson(i)).toList();

    return UserModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      organizationId: json['organizationId'] ?? '',
      permissions: parsedPermissions,
    );
  }

  bool hasPermission(String resource, String action) {
    return permissions.any((p) => p.resource == resource && p.action == action);
  }
}
