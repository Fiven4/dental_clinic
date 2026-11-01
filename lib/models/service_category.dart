import 'json_utils.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String description;
  final DateTime? deletedAt;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
    id: stringOf(json['id']),
    name: stringOf(json['name']),
    description: stringOf(json['description']),
    deletedAt: dateOf(json['deletedAt']),
  );

  Map<String, dynamic> toBody() => {'name': name, 'description': description};
}
