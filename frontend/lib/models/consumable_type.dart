class ConsumableType {
  const ConsumableType({
    required this.id,
    required this.code,
    required this.label,
    required this.priceCents,
    required this.active,
  });

  factory ConsumableType.fromJson(Map<String, dynamic> json) => ConsumableType(
    id: json['id'] as String,
    code: json['code'] as String,
    label: json['label'] as String,
    priceCents: json['price_cents'] as int,
    active: json['active'] as bool,
  );

  final String id;
  final String code;
  final String label;
  final int priceCents;
  final bool active;
}
