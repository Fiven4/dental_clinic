import 'json_utils.dart';

class Service {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final double price;
  final int durationMin;
  final String description;
  final DateTime? deletedAt;

  const Service({
    required this.id,
    required this.name,
    required this.categoryId,
    this.categoryName = '',
    required this.price,
    required this.durationMin,
    this.description = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory Service.fromJson(Map<String, dynamic> json) {
    final category = mapOf(mapOf(json['expand'])['category']);
    return Service(
      id: stringOf(json['id']),
      name: stringOf(json['name']),
      categoryId: stringOf(json['category']),
      categoryName: stringOf(category['name']),
      price: doubleOf(json['price']),
      durationMin: intOf(json['durationMin']),
      description: stringOf(json['description']),
      deletedAt: dateOf(json['deletedAt']),
    );
  }

  Map<String, dynamic> toBody() => {
    'name': name,
    'category': categoryId,
    'price': price,
    'durationMin': durationMin,
    'description': description,
  };
}
