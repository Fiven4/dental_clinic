import 'json_utils.dart';

enum PayMethod {
  cash('cash', 'Наличные'),
  card('card', 'Карта'),
  transfer('transfer', 'Перевод');

  final String value;
  final String label;

  const PayMethod(this.value, this.label);

  static PayMethod fromString(String? v) => PayMethod.values.firstWhere(
    (e) => e.value == v,
    orElse: () => PayMethod.cash,
  );
}

class Payment {
  final String id;
  final String appointmentId;
  final String patientName;
  final String doctorName;
  final DateTime? appointmentStart;
  final double appointmentTotal;
  final double amount;
  final PayMethod method;
  final DateTime? paidAt;
  final DateTime? deletedAt;

  const Payment({
    required this.id,
    required this.appointmentId,
    this.patientName = '',
    this.doctorName = '',
    this.appointmentStart,
    this.appointmentTotal = 0,
    required this.amount,
    required this.method,
    this.paidAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final appointment = mapOf(mapOf(json['expand'])['appointment']);
    final nested = mapOf(appointment['expand']);
    return Payment(
      id: stringOf(json['id']),
      appointmentId: stringOf(json['appointment']),
      patientName: stringOf(mapOf(nested['patient'])['fullName']),
      doctorName: stringOf(mapOf(nested['doctor'])['fullName']),
      appointmentStart: dateOf(appointment['startAt']),
      appointmentTotal: doubleOf(appointment['total']),
      amount: doubleOf(json['amount']),
      method: PayMethod.fromString(json['method'] as String?),
      paidAt: dateOf(json['paidAt']),
      deletedAt: dateOf(json['deletedAt']),
    );
  }

  Map<String, dynamic> toBody() => {
    'appointment': appointmentId,
    'amount': amount,
    'method': method.value,
    'paidAt': paidAt == null ? '' : pbDate(paidAt!),
  };
}
