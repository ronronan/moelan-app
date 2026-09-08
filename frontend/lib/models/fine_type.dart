class FineType {
  const FineType({
    required this.id,
    required this.code,
    required this.label,
    required this.amountCents,
    required this.active,
  });

  factory FineType.fromJson(Map<String, dynamic> json) => FineType(
    id: json['id'] as String,
    code: json['code'] as String,
    label: json['label'] as String,
    amountCents: json['amount_cents'] as int,
    active: json['active'] as bool,
  );

  final String id;
  final String code;
  final String label;
  final int amountCents;
  final bool active;
}
