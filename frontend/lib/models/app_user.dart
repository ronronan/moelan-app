/// One account of the whole instance, as the super-admin listing sees it:
/// the Keycloak identity plus the space and role it holds in the app.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.enabled,
    required this.superadmin,
    this.email,
    this.firstName,
    this.lastName,
    this.orgRole,
    this.organizationId,
    this.organizationName,
    this.organizationApproved,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    username: json['username'] as String,
    enabled: json['enabled'] as bool,
    superadmin: json['superadmin'] as bool,
    email: json['email'] as String?,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    orgRole: json['org_role'] as String?,
    organizationId: json['organization_id'] as String?,
    organizationName: json['organization_name'] as String?,
    organizationApproved: json['organization_approved'] as bool?,
  );

  final String id;
  final String username;
  final bool enabled;
  final bool superadmin;
  final String? email;
  final String? firstName;
  final String? lastName;

  /// `admin`, `member` or `player` — null for an account that hasn't
  /// created or been invited into a space yet.
  final String? orgRole;
  final String? organizationId;
  final String? organizationName;
  final bool? organizationApproved;

  String get fullName {
    final parts = [
      ?firstName?.trim(),
      ?lastName?.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? username : parts.join(' ');
  }
}
