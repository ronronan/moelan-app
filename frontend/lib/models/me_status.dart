import 'organization.dart';

/// Response of `GET /api/me` — reachable regardless of org approval status,
/// so the router can tell apart "no space yet" from "space pending" from
/// "all good" and send the user to the right screen.
class MeStatus {
  const MeStatus({required this.organization});

  factory MeStatus.fromJson(Map<String, dynamic> json) => MeStatus(
    organization: json['organization'] == null
        ? null
        : Organization.fromJson(json['organization'] as Map<String, dynamic>),
  );

  final Organization? organization;
}
