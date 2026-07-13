class Trip {
  final String id;
  final String origin;
  final String destination;
  final String status;
  final String? truckId;
  final String? driverId;

  Trip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.status,
    this.truckId,
    this.driverId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      truckId: json['truckId']?.toString(),
      driverId: json['driverId']?.toString(),
    );
  }
}
