import '../models/json_utils.dart';

typedef FilterRule = String? Function(String value);

String pbQuote(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

DateTime? parseDay(String value) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  if (date.month != mo || date.day != d) return null;
  return date;
}

String dayParam(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
}

FilterRule equals(String field) =>
    (v) => '$field = ${pbQuote(v)}';

FilterRule anyOf(String field) =>
    (v) => '$field ?= ${pbQuote(v)}';

FilterRule dayFrom(String field) => (v) {
  final day = parseDay(v);
  return day == null ? null : '$field >= ${pbQuote(pbDate(day))}';
};

FilterRule dayTo(String field) => (v) {
  final day = parseDay(v);
  if (day == null) return null;
  final next = DateTime(day.year, day.month, day.day + 1);
  return '$field < ${pbQuote(pbDate(next))}';
};

FilterRule numberAtLeast(String field) => (v) {
  final n = double.tryParse(v);
  return n == null ? null : '$field >= $n';
};

FilterRule numberAtMost(String field) => (v) {
  final n = double.tryParse(v);
  return n == null ? null : '$field <= $n';
};

FilterRule intEquals(String field) => (v) {
  final n = int.tryParse(v);
  return n == null ? null : '$field = $n';
};
