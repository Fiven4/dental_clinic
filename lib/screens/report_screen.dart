import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/format.dart';
import '../core/report.dart';
import '../models/appointment.dart';
import '../models/list_query.dart';
import '../models/payment.dart';
import '../repositories/clinic_repositories.dart';
import '../state/reference_notifier.dart';
import '../widgets/filter_widgets.dart';
import '../widgets/state_views.dart';

class ReportScreen extends StatefulWidget {
  final DateTime from;
  final DateTime to;

  const ReportScreen({super.key, required this.from, required this.to});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Appointment>? _appointments;
  List<Payment> _payments = const [];
  bool _loading = true;
  String? _error;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from || oldWidget.to != widget.to) _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime(
        widget.from.year,
        widget.from.month,
        widget.from.day,
      );
      final to = DateTime(widget.to.year, widget.to.month, widget.to.day + 1);
      final appointments = context.read<AppointmentRepository>();
      final payments = context.read<PaymentRepository>();
      final (appointmentList, paymentList) = await (
        appointments.inRange(from, to),
        payments.inRange(from, to),
      ).wait;
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _appointments = appointmentList;
        _payments = paymentList;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _go(DateTime from, DateTime to) {
    context.go(
      buildLocation('/report', {'from': inputDate(from), 'to': inputDate(to)}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = context.watch<ReferenceNotifier>();
    final appointments = _appointments;
    final data = appointments == null
        ? null
        : buildReport(
            appointments: appointments,
            payments: _payments,
            services: {for (final s in ref.services) s.id: s},
            categoryNames: {for (final c in ref.categories) c.id: c.name},
          );
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final prevStart = DateTime(now.year, now.month - 1);
    final prevEnd = DateTime(now.year, now.month, 0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Отчёт по выручке', style: theme.textTheme.headlineSmall),
              DateFilterField(
                key: const ValueKey('report-from'),
                label: 'С даты',
                value: inputDate(widget.from),
                onChanged: (v) {
                  final d = v == null ? null : parseInputDate(v);
                  if (d != null) _go(d, widget.to.isBefore(d) ? d : widget.to);
                },
              ),
              DateFilterField(
                key: const ValueKey('report-to'),
                label: 'По дату',
                value: inputDate(widget.to),
                onChanged: (v) {
                  final d = v == null ? null : parseInputDate(v);
                  if (d != null) {
                    _go(widget.from.isAfter(d) ? d : widget.from, d);
                  }
                },
              ),
              ActionChip(
                key: const ValueKey('report-month'),
                label: const Text('Этот месяц'),
                onPressed: () => _go(monthStart, now),
              ),
              ActionChip(
                key: const ValueKey('report-prev-month'),
                label: const Text('Прошлый месяц'),
                onPressed: () => _go(prevStart, prevEnd),
              ),
              ActionChip(
                key: const ValueKey('report-30'),
                label: const Text('30 дней'),
                onPressed: () =>
                    _go(now.subtract(const Duration(days: 29)), now),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : data == null
                ? const LoadingView()
                : _ReportBody(data: data, loading: _loading),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final ReportData data;
  final bool loading;

  const _ReportBody({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final charts = [
      _BarCard(
        title: 'Выручка по врачам (проведённые приёмы)',
        values: data.byDoctor,
        keyPrefix: 'doctor',
      ),
      _BarCard(
        title: 'Выручка по категориям услуг',
        values: data.byCategory,
        keyPrefix: 'category',
      ),
      _BarCard(
        title: 'Поступления по способам оплаты',
        values: {for (final e in data.byMethod.entries) e.key.label: e.value},
        keyPrefix: 'method',
      ),
      _DayCard(values: data.byDay),
    ];
    return Stack(
      children: [
        ListView(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Kpi(
                  keyName: 'kpi-done',
                  label: 'Проведено приёмов',
                  value: '${data.done}',
                ),
                _Kpi(
                  keyName: 'kpi-billed',
                  label: 'Начислено',
                  value: formatMoney(data.billed),
                ),
                _Kpi(
                  keyName: 'kpi-received',
                  label: 'Получено оплат',
                  value: formatMoney(data.received),
                ),
                _Kpi(
                  keyName: 'kpi-check',
                  label: 'Средний чек',
                  value: formatMoney(data.averageCheck.roundToDouble()),
                ),
                _Kpi(
                  keyName: 'kpi-cancel',
                  label: 'Доля отмен',
                  value: '${data.cancelRate.toStringAsFixed(1)}%',
                ),
                _Kpi(
                  keyName: 'kpi-planned',
                  label: 'Запланировано',
                  value: '${data.planned}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        charts[0],
                        const SizedBox(height: 12),
                        charts[2],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        charts[1],
                        const SizedBox(height: 12),
                        charts[3],
                      ],
                    ),
                  ),
                ],
              )
            else
              for (final c in charts) ...[c, const SizedBox(height: 12)],
          ],
        ),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String keyName;
  final String label;
  final String value;

  const _Kpi({required this.keyName, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 190,
      child: Card(
        key: ValueKey(keyName),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarCard extends StatelessWidget {
  final String title;
  final Map<String, double> values;
  final String keyPrefix;

  const _BarCard({
    required this.title,
    required this.values,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = values.values.fold<double>(0, (m, v) => v > m ? v : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Text('Нет данных за выбранный период.')
            else
              for (final e in values.entries)
                Padding(
                  key: ValueKey('$keyPrefix-${e.key}'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(e.key, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(formatMoney(e.value.roundToDouble())),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : e.value / max,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final Map<DateTime, double> values;

  const _DayCard({required this.values});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = values.values.fold<double>(0, (m, v) => v > m ? v : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Поступления по дням', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Text('Нет данных за выбранный период.')
            else
              SizedBox(
                height: 140,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final e in values.entries)
                        Tooltip(
                          message:
                              '${formatDate(e.key)}: ${formatMoney(e.value)}',
                          child: Container(
                            width: 14,
                            height: max == 0 ? 2 : 4 + 120 * e.value / max,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
