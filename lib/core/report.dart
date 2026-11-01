import '../models/appointment.dart';
import '../models/payment.dart';
import '../models/service.dart';

class ReportData {
  final int planned;
  final int done;
  final int cancelled;
  final double billed;
  final double received;
  final Map<String, double> byDoctor;
  final Map<String, double> byCategory;
  final Map<PayMethod, double> byMethod;
  final Map<DateTime, double> byDay;

  const ReportData({
    required this.planned,
    required this.done,
    required this.cancelled,
    required this.billed,
    required this.received,
    required this.byDoctor,
    required this.byCategory,
    required this.byMethod,
    required this.byDay,
  });

  int get total => planned + done + cancelled;
  double get averageCheck => done == 0 ? 0 : billed / done;
  double get cancelRate => total == 0 ? 0 : cancelled / total * 100;
  double get debt => billed - received;
}

Map<K, double> sortedDesc<K>(Map<K, double> source) {
  final entries = source.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in entries) e.key: e.value};
}

ReportData buildReport({
  required List<Appointment> appointments,
  required List<Payment> payments,
  required Map<String, Service> services,
  required Map<String, String> categoryNames,
}) {
  var planned = 0, done = 0, cancelled = 0;
  var billed = 0.0;
  final byDoctor = <String, double>{};
  final byCategory = <String, double>{};

  for (final a in appointments) {
    switch (a.status) {
      case AppointmentStatus.planned:
        planned++;
      case AppointmentStatus.cancelled:
        cancelled++;
      case AppointmentStatus.done:
        done++;
        billed += a.total;
        byDoctor.update(
          a.doctorName,
          (v) => v + a.total,
          ifAbsent: () => a.total,
        );
        for (final id in a.serviceIds) {
          final service = services[id];
          final name = service == null
              ? 'Прочее'
              : categoryNames[service.categoryId] ?? 'Прочее';
          final share = (service?.price ?? 0) * (100 - a.discountPercent) / 100;
          byCategory.update(name, (v) => v + share, ifAbsent: () => share);
        }
    }
  }

  var received = 0.0;
  final byMethod = <PayMethod, double>{};
  final byDay = <DateTime, double>{};
  for (final p in payments) {
    received += p.amount;
    byMethod.update(p.method, (v) => v + p.amount, ifAbsent: () => p.amount);
    final at = p.paidAt?.toLocal();
    if (at != null) {
      final day = DateTime(at.year, at.month, at.day);
      byDay.update(day, (v) => v + p.amount, ifAbsent: () => p.amount);
    }
  }

  return ReportData(
    planned: planned,
    done: done,
    cancelled: cancelled,
    billed: billed,
    received: received,
    byDoctor: sortedDesc(byDoctor),
    byCategory: sortedDesc(byCategory),
    byMethod: sortedDesc(byMethod),
    byDay: Map.fromEntries(
      byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  );
}
