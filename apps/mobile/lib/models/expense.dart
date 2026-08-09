enum ExpenseCategory { fuel, fine, other }

ExpenseCategory expenseCategoryFromJson(String? value) {
  switch (value) {
    case 'FUEL':
      return ExpenseCategory.fuel;
    case 'FINE':
      return ExpenseCategory.fine;
    default:
      return ExpenseCategory.other;
  }
}

String expenseCategoryToJson(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.fuel:
      return 'FUEL';
    case ExpenseCategory.fine:
      return 'FINE';
    case ExpenseCategory.other:
      return 'OTHER';
  }
}

String expenseCategoryLabel(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.fuel:
      return 'Fuel';
    case ExpenseCategory.fine:
      return 'Fine';
    case ExpenseCategory.other:
      return 'Other';
  }
}

class Expense {
  final String id;
  final String tripId;
  final ExpenseCategory category;
  final double amount;
  final String? photoUrl;
  final int? odometer;
  final String? reason;
  final String? notes;
  final DateTime? createdAt;

  Expense({
    required this.id,
    required this.tripId,
    required this.category,
    required this.amount,
    this.photoUrl,
    this.odometer,
    this.reason,
    this.notes,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      category: expenseCategoryFromJson(json['category']?.toString()),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      photoUrl: json['photoUrl']?.toString(),
      odometer: json['odometer'] == null ? null : int.tryParse(json['odometer'].toString()),
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'].toString()),
    );
  }
}
