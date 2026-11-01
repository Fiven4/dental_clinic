int intOf(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double doubleOf(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String stringOf(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return '$value';
}

List<String> stringListOf(Object? value) {
  if (value is List) return [for (final e in value) '$e'];
  if (value is String && value.isNotEmpty) return [value];
  return const [];
}

DateTime? dateOf(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

Map<String, dynamic> mapOf(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> mapListOf(Object? value) {
  if (value is List) return [for (final e in value) mapOf(e)];
  if (value is Map) return [mapOf(value)];
  return const [];
}

String pbDate(DateTime value) {
  final u = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)} '
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)}.000Z';
}
