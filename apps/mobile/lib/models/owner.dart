class Owner {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool isActive;
  final bool mustChangePassword;

  Owner({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.isActive,
    required this.mustChangePassword,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final name = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    return Owner(
      id: json['id']?.toString() ?? '',
      name: name,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      isActive: json['isActive'] ?? true,
      mustChangePassword: json['mustChangePassword'] ?? false,
    );
  }
}
