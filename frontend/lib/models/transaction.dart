enum TransactionKind { beer, soft, fine, credit, manualAdjustment }

TransactionKind _kindFromJson(String value) => switch (value) {
  'beer' => TransactionKind.beer,
  'soft' => TransactionKind.soft,
  'fine' => TransactionKind.fine,
  'credit' => TransactionKind.credit,
  'manual_adjustment' => TransactionKind.manualAdjustment,
  _ => throw ArgumentError('unknown transaction kind: $value'),
};

class Transaction {
  const Transaction({
    required this.id,
    required this.playerId,
    required this.kind,
    required this.amountCents,
    required this.quantity,
    required this.note,
    required this.createdBy,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    playerId: json['player_id'] as String,
    kind: _kindFromJson(json['kind'] as String),
    amountCents: json['amount_cents'] as int,
    quantity: json['quantity'] as int,
    note: json['note'] as String?,
    createdBy: json['created_by'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String playerId;
  final TransactionKind kind;
  final int amountCents;
  final int quantity;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
}
