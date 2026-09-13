class MonthlyStat {
  const MonthlyStat({
    required this.month,
    required this.beerCount,
    required this.softCount,
    required this.fineTotalCents,
    required this.creditTotalCents,
    required this.netCents,
    required this.balanceCents,
  });

  factory MonthlyStat.fromJson(Map<String, dynamic> json) => MonthlyStat(
    month: DateTime.parse(json['month'] as String),
    beerCount: json['beer_count'] as int,
    softCount: json['soft_count'] as int,
    fineTotalCents: json['fine_total_cents'] as int,
    creditTotalCents: json['credit_total_cents'] as int,
    netCents: json['net_cents'] as int,
    balanceCents: json['balance_cents'] as int,
  );

  final DateTime month;
  final int beerCount;
  final int softCount;
  final int fineTotalCents;
  final int creditTotalCents;
  final int netCents;
  final int balanceCents;
}
