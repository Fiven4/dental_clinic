import 'json_utils.dart';

class Cabinet {
  final String id;
  final String number;
  final int floor;
  final String equipment;
  final DateTime? deletedAt;

  const Cabinet({
    required this.id,
    required this.number,
    required this.floor,
    this.equipment = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Cabinet.fromJson(Map<String, dynamic> json) => Cabinet(
    id: stringOf(json['id']),
    number: stringOf(json['number']),
    floor: intOf(json['floor']),
    equipment: stringOf(json['equipment']),
    deletedAt: dateOf(json['deletedAt']),
  );

  Map<String, dynamic> toBody() => {
    'number': number,
    'floor': floor,
    'equipment': equipment,
  };
}
