class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.contactEmail,
    required this.approved,
    this.targetCents,
    this.debtAlertThresholdCents,
  });

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    contactEmail: json['contact_email'] as String,
    approved: json['approved'] as bool,
    targetCents: json['target_cents'] as int?,
    debtAlertThresholdCents: json['debt_alert_threshold_cents'] as int?,
  );

  final String id;
  final String name;
  final String slug;
  final String contactEmail;
  final bool approved;
  final int? targetCents;
  final int? debtAlertThresholdCents;
}
