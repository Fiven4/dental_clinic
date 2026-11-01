import 'json_utils.dart';

class Patient {
  final String id;
  final String fullName;
  final DateTime? birthDate;
  final String phone;
  final String email;
  final String address;
  final DateTime? deletedAt;

  const Patient({
    required this.id,
    required this.fullName,
    this.birthDate,
    required this.phone,
    this.email = '',
    this.address = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  int? ageOn(DateTime now) {
    final b = birthDate;
    if (b == null) return null;
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: stringOf(json['id']),
    fullName: stringOf(json['fullName']),
    birthDate: dateOf(json['birthDate']),
    phone: stringOf(json['phone']),
    email: stringOf(json['email']),
    address: stringOf(json['address']),
    deletedAt: dateOf(json['deletedAt']),
  );

  Map<String, dynamic> toBody() => {
    'fullName': fullName,
    'birthDate': birthDate == null ? '' : pbDate(birthDate!),
    'phone': phone,
    'email': email,
    'address': address,
  };
}
