class Driver {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? licenseNumber;
  final bool isActive;
  final bool mustChangePassword;
  final String? defaultTruckId;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.licenseNumber,
    required this.isActive,
    required this.mustChangePassword,
    this.defaultTruckId,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final fallbackName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final licenseNumber = json['licenseNumber']?.toString() ??
        (json['driverProfile'] as Map<String, dynamic>?)?['licenseNumber']?.toString();
    return Driver(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? fallbackName,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      licenseNumber: licenseNumber,
      isActive: json['isActive'] ?? true,
      mustChangePassword: json['mustChangePassword'] ?? false,
      defaultTruckId: json['defaultTruckId']?.toString(),
    );
  }
}
