import 'json_utils.dart';

enum AppointmentStatus {
  planned('planned', 'Запланирован'),
  done('done', 'Проведён'),
  cancelled('cancelled', 'Отменён');

  final String value;
  final String label;

  const AppointmentStatus(this.value, this.label);

  static AppointmentStatus fromString(String? v) =>
      AppointmentStatus.values.firstWhere(
        (e) => e.value == v,
        orElse: () => AppointmentStatus.planned,
      );
}

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String cabinetNumber;
  final List<String> serviceIds;
  final List<String> serviceNames;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentStatus status;
  final double discountPercent;
  final double total;
  final double paid;
  final String complaints;
  final String diagnosis;
  final DateTime? deletedAt;

  const Appointment({
    required this.id,
    required this.patientId,
    this.patientName = '',
    required this.doctorId,
    this.doctorName = '',
    this.cabinetNumber = '',
    this.serviceIds = const [],
    this.serviceNames = const [],
    required this.startAt,
    required this.endAt,
    required this.status,
    this.discountPercent = 0,
    this.total = 0,
    this.paid = 0,
    this.complaints = '',
    this.diagnosis = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  double get debt => status == AppointmentStatus.cancelled ? 0 : total - paid;
  int get durationMin => endAt.difference(startAt).inMinutes;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final expand = mapOf(json['expand']);
    final doctor = mapOf(expand['doctor']);
    final doctorExpand = mapOf(doctor['expand']);
    final payments = mapListOf(expand['payments_via_appointment']);
    var paid = 0.0;
    for (final p in payments) {
      if (stringOf(p['deletedAt']).isEmpty) paid += doubleOf(p['amount']);
    }
    return Appointment(
      id: stringOf(json['id']),
      patientId: stringOf(json['patient']),
      patientName: stringOf(mapOf(expand['patient'])['fullName']),
      doctorId: stringOf(json['doctor']),
      doctorName: stringOf(doctor['fullName']),
      cabinetNumber: stringOf(mapOf(doctorExpand['cabinet'])['number']),
      serviceIds: stringListOf(json['services']),
      serviceNames: [
        for (final s in mapListOf(expand['services'])) stringOf(s['name']),
      ],
      startAt: (dateOf(json['startAt']) ?? DateTime.utc(1970)).toLocal(),
      endAt: (dateOf(json['endAt']) ?? DateTime.utc(1970)).toLocal(),
      status: AppointmentStatus.fromString(json['status'] as String?),
      discountPercent: doubleOf(json['discountPercent']),
      total: doubleOf(json['total']),
      paid: paid,
      complaints: stringOf(json['complaints']),
      diagnosis: stringOf(json['diagnosis']),
      deletedAt: dateOf(json['deletedAt']),
    );
  }

  Map<String, dynamic> toBody() => {
    'patient': patientId,
    'doctor': doctorId,
    'services': serviceIds,
    'startAt': pbDate(startAt),
    'endAt': pbDate(endAt),
    'status': status.value,
    'complaints': complaints,
    'diagnosis': diagnosis,
  };
}
