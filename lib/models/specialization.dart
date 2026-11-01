import 'json_utils.dart';

class Specialization {
  final String id;
  final String name;
  final String description;
  final DateTime? deletedAt;

  const Specialization({
    required this.id,
    required this.name,
    this.description = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Specialization.fromJson(Map<String, dynamic> json) => Specialization(
    id: stringOf(json['id']),
    name: stringOf(json['name']),
    description: stringOf(json['description']),
    deletedAt: dateOf(json['deletedAt']),
  );

  Map<String, dynamic> toBody() => {'name': name, 'description': description};
}
