String _two(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime date) =>
    '${_two(date.day)}.${_two(date.month)}.${date.year}';

String formatTime(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${formatTime(date)}';

String formatMoney(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(
    value == value.roundToDouble() ? 0 : 2,
  );
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  final tail = parts.length > 1 ? ',${parts[1]}' : '';
  return '${negative ? '-' : ''}$buffer$tail ₽';
}

String formatPercent(num value) =>
    '${value == value.roundToDouble() ? value.toInt() : value}%';

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

String inputDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

String inputDateTime(DateTime date) =>
    '${inputDate(date)} ${_two(date.hour)}:${_two(date.minute)}';

DateTime? parseInputDateTime(String text) {
  final m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$',
  ).firstMatch(text.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final h = int.parse(m[4]!), mi = int.parse(m[5]!);
  final date = DateTime(y, mo, d, h, mi);
  if (date.year != y ||
      date.month != mo ||
      date.day != d ||
      h > 23 ||
      mi > 59) {
    return null;
  }
  return date;
}

DateTime? parseInputDate(String text) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) return null;
  return date;
}

const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

String weekdayShort(DateTime date) => weekdays[date.weekday - 1];
