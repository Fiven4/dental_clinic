import 'json_utils.dart';

class PatientCard {
  final String id;
  final String patientId;
  final String patientName;
  final String number;
  final String allergies;
  final String notes;
  final DateTime? openedOn;
  final DateTime? deletedAt;

  const PatientCard({
    required this.id,
    required this.patientId,
    this.patientName = '',
    required this.number,
    this.allergies = '',
    this.notes = '',
    this.openedOn,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory PatientCard.fromJson(Map<String, dynamic> json) => PatientCard(
    id: stringOf(json['id']),
    patientId: stringOf(json['patient']),
    patientName: stringOf(
      mapOf(mapOf(json['expand'])['patient'])['fullName'],
    ),
    number: stringOf(json['number']),
    allergies: stringOf(json['allergies']),
    notes: stringOf(json['notes']),
    openedOn: dateOf(json['openedOn']),
    deletedAt: dateOf(json['deletedAt']),
  );

  PatientCard copyForCreate({String? patientId, String? number}) => PatientCard(
    id: '',
    patientId: patientId ?? this.patientId,
    number: number ?? this.number,
    allergies: allergies,
    notes: notes,
    openedOn: openedOn,
  );

  Map<String, dynamic> toBody() => {
    'patient': patientId,
    'number': number,
    'allergies': allergies,
    'notes': notes,
    'openedOn': openedOn == null ? '' : pbDate(openedOn!),
  };
}
