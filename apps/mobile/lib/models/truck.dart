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

  /// Convention, not a real field: a Truck record represents a Hitachi
  /// machine (not a freight truck) if "hitachi" appears anywhere in its
  /// plate or brand — lets the same Trucks list double as the Hitachi
  /// vehicle roster without a separate table.
  bool get isHitachi =>
      plate.toLowerCase().contains('hitachi') || (brand?.toLowerCase().contains('hitachi') ?? false);
}
