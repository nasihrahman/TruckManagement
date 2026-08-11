class Truck {
  final String id;
  final String plate;
  final String? brand;
  final String? vin;

  Truck({
    required this.id,
    required this.plate,
    this.brand,
    this.vin,
  });

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json['id']?.toString() ?? '',
      plate: json['plate']?.toString() ?? '',
      brand: json['brand']?.toString(),
      vin: json['vin']?.toString(),
    );
  }

  String get displayName => brand != null && brand!.isNotEmpty ? '$plate · $brand' : plate;
}
