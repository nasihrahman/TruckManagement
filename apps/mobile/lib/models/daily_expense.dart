import 'expense.dart';

/// A lump expense for a whole day, not tied to any single trip — most
/// drivers don't want to split fuel/fines across individual deliveries.
/// Reuses ExpenseCategory (Fuel/Fine/Other) from the per-trip Expense model.
class DailyExpense {
  final String id;
  final String driverId;
  final String? driverName;
  final String? truckId;
  final String? truckPlate;
  final DateTime date;
  final ExpenseCategory category;
  final double amount;
  final String? reason;
  final String? notes;
  final String? photoUrl;

  DailyExpense({
    required this.id,
    required this.driverId,
    this.driverName,
    this.truckId,
    this.truckPlate,
    required this.date,
    required this.category,
    required this.amount,
    this.reason,
    this.notes,
    this.photoUrl,
  });

  factory DailyExpense.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final name = driver == null
        ? null
        : [driver['firstName'], driver['lastName']]
            .where((p) => p != null && p.toString().trim().isNotEmpty)
            .join(' ');
    final truck = json['truck'] as Map<String, dynamic>?;
    return DailyExpense(
      id: json['id']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      driverName: (name == null || name.isEmpty) ? null : name,
      truckId: json['truckId']?.toString(),
      truckPlate: truck?['plate']?.toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      category: expenseCategoryFromJson(json['category']?.toString()),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}
