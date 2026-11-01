import 'json_utils.dart';

class Doctor {
  final String id;
  final String fullName;
  final String specializationId;
  final String specializationName;
  final String cabinetId;
  final String cabinetNumber;
  final String userId;
  final int experienceYears;
  final String phone;
  final DateTime? deletedAt;

  const Doctor({
    required this.id,
    required this.fullName,
    required this.specializationId,
    this.specializationName = '',
    this.cabinetId = '',
    this.cabinetNumber = '',
    this.userId = '',
    required this.experienceYears,
    this.phone = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    final expand = mapOf(json['expand']);
    return Doctor(
      id: stringOf(json['id']),
      fullName: stringOf(json['fullName']),
      specializationId: stringOf(json['specialization']),
      specializationName: stringOf(mapOf(expand['specialization'])['name']),
      cabinetId: stringOf(json['cabinet']),
      cabinetNumber: stringOf(mapOf(expand['cabinet'])['number']),
      userId: stringOf(json['user']),
      experienceYears: intOf(json['experienceYears']),
      phone: stringOf(json['phone']),
      deletedAt: dateOf(json['deletedAt']),
    );
  }

  Map<String, dynamic> toBody() => {
    'fullName': fullName,
    'specialization': specializationId,
    'cabinet': cabinetId,
    'user': userId,
    'experienceYears': experienceYears,
    'phone': phone,
  };
}
