class TripExpenseEntry {
  final double amount;
  final String category;
  final DateTime? createdAt;

  TripExpenseEntry({required this.amount, required this.category, this.createdAt});

  factory TripExpenseEntry.fromJson(Map<String, dynamic> json) {
    return TripExpenseEntry(
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      category: json['category']?.toString() ?? 'OTHER',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}

class Trip {
  final String id;
  final String origin;
  final String destination;
  final String status;
  final String? truckId;
  final String? driverId;
  final bool financiallyClosed;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<TripExpenseEntry> expenses;

  Trip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.status,
    this.truckId,
    this.driverId,
    this.financiallyClosed = false,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.expenses = const [],
  });

  double get expenseTotal => expenses.fold(0, (sum, e) => sum + e.amount);

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      truckId: json['truckId']?.toString(),
      driverId: json['driverId']?.toString(),
      financiallyClosed: json['financiallyClosed'] == true,
      scheduledAt: json['scheduledAt'] != null ? DateTime.tryParse(json['scheduledAt'].toString()) : null,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'].toString()) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'].toString()) : null,
      expenses: json['expenses'] is List
          ? (json['expenses'] as List)
              .map((e) => TripExpenseEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }
}
