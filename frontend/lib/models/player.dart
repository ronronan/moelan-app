class Player {
  const Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.balanceCents,
    required this.active,
    this.email,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    balanceCents: json['balance_cents'] as int,
    active: json['active'] as bool,
    email: json['email'] as String?,
  );

  final String id;
  final String firstName;
  final String lastName;
  final int balanceCents;
  final bool active;
  final String? email;

  String get fullName => '$firstName $lastName';
}
