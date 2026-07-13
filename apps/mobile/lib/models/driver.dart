class Driver {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? licenseNumber;
  final bool isActive;
  final bool mustChangePassword;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.licenseNumber,
    required this.isActive,
    required this.mustChangePassword,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      licenseNumber: json['licenseNumber']?.toString(),
      isActive: json['isActive'] ?? true,
      mustChangePassword: json['mustChangePassword'] ?? false,
    );
  }
}
