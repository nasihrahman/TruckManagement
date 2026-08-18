enum HitachiPayer { m, j }

HitachiPayer? hitachiPayerFromJson(String? value) {
  switch (value) {
    case 'M':
      return HitachiPayer.m;
    case 'J':
      return HitachiPayer.j;
    default:
      return null;
  }
}

String? hitachiPayerToJson(HitachiPayer? payer) {
  switch (payer) {
    case HitachiPayer.m:
      return 'M';
    case HitachiPayer.j:
      return 'J';
    case null:
      return null;
  }
}

/// M = Muthu, J = Jamal — the two partners splitting this Hitachi business.
String hitachiPayerLabel(HitachiPayer payer) => payer == HitachiPayer.m ? 'Muthu' : 'Jamal';

class HitachiJob {
  final String id;
  final String driverId;
  final DateTime date;
  final String? customerName;
  final String? place;
  final double? totalHours;
  final double? paymentReceived;
  final HitachiPayer? paymentReceivedBy;
  final double? nDieselExpense;
  final HitachiPayer? nDieselPaidBy;
  final double? hDieselExpense;
  final HitachiPayer? hDieselPaidBy;
  final double? opBata;
  final HitachiPayer? opBataPaidBy;
  final double? otherExpenseM;
  final double? otherExpenseJ;
  final double? salaryAdvance;
  final String? photoUrl;

  HitachiJob({
    required this.id,
    required this.driverId,
    required this.date,
    this.customerName,
    this.place,
    this.totalHours,
    this.paymentReceived,
    this.paymentReceivedBy,
    this.nDieselExpense,
    this.nDieselPaidBy,
    this.hDieselExpense,
    this.hDieselPaidBy,
    this.opBata,
    this.opBataPaidBy,
    this.otherExpenseM,
    this.otherExpenseJ,
    this.salaryAdvance,
    this.photoUrl,
  });

  /// Bal amt (J) = (Payment received by Jamal + Salary in advance)
  /// minus whichever of N diesel / H diesel / OP bata were paid by Jamal,
  /// minus Other exp (J). Computed, not stored — matches the client's own
  /// hand-calculated ledger formula.
  double get balanceJ {
    double ifPaidByJ(double? amount, HitachiPayer? paidBy) =>
        paidBy == HitachiPayer.j ? (amount ?? 0) : 0;
    final receivedByJ = paymentReceivedBy == HitachiPayer.j ? (paymentReceived ?? 0) : 0;
    return receivedByJ +
        (salaryAdvance ?? 0) -
        ifPaidByJ(nDieselExpense, nDieselPaidBy) -
        ifPaidByJ(hDieselExpense, hDieselPaidBy) -
        ifPaidByJ(opBata, opBataPaidBy) -
        (otherExpenseJ ?? 0);
  }

  factory HitachiJob.fromJson(Map<String, dynamic> json) {
    double? parseDecimal(dynamic value) => value == null ? null : double.tryParse(value.toString());
    return HitachiJob(
      id: json['id']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      customerName: json['customerName']?.toString(),
      place: json['place']?.toString(),
      totalHours: parseDecimal(json['totalHours']),
      paymentReceived: parseDecimal(json['paymentReceived']),
      paymentReceivedBy: hitachiPayerFromJson(json['paymentReceivedBy']?.toString()),
      nDieselExpense: parseDecimal(json['nDieselExpense']),
      nDieselPaidBy: hitachiPayerFromJson(json['nDieselPaidBy']?.toString()),
      hDieselExpense: parseDecimal(json['hDieselExpense']),
      hDieselPaidBy: hitachiPayerFromJson(json['hDieselPaidBy']?.toString()),
      opBata: parseDecimal(json['opBata']),
      opBataPaidBy: hitachiPayerFromJson(json['opBataPaidBy']?.toString()),
      otherExpenseM: parseDecimal(json['otherExpenseM']),
      otherExpenseJ: parseDecimal(json['otherExpenseJ']),
      salaryAdvance: parseDecimal(json['salaryAdvance']),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}
