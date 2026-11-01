import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/format.dart';
import '../core/validators.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../repositories/clinic_repositories.dart';
import '../state/reference_notifier.dart';
import '../widgets/form/entity_form_view.dart';
import '../widgets/form/field_specs.dart';
import 'form_screens.dart';

const clinicOpenHour = 8;
const clinicCloseHour = 20;
const loyaltyThresholds = [(10, 15.0), (5, 10.0)];

double loyaltyDiscount(int doneCount) {
  for (final (count, percent) in loyaltyThresholds) {
    if (doneCount >= count) return percent;
  }
  return 0;
}

class AppointmentCost {
  final double base;
  final double discountPercent;
  final double total;
  final int minutes;

  const AppointmentCost({
    required this.base,
    required this.discountPercent,
    required this.total,
    required this.minutes,
  });
}

AppointmentCost calculateCost(List<Service> services, int doneCount) {
  final base = services.fold<double>(0, (sum, s) => sum + s.price);
  final minutes = services.fold<int>(0, (sum, s) => sum + s.durationMin);
  final discount = loyaltyDiscount(doneCount);
  return AppointmentCost(
    base: base,
    discountPercent: discount,
    total: (base * (100 - discount) / 100).roundToDouble(),
    minutes: minutes,
  );
}

bool overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && aEnd.isAfter(bStart);

class AppointmentFormScreen extends StatefulWidget {
  final String? id;
  final String? patientId;
  final String? doctorId;
  final String? start;

  const AppointmentFormScreen({
    super.key,
    this.id,
    this.patientId,
    this.doctorId,
    this.start,
  });

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  String _patientLabel = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final patientId = widget.patientId;
    if (patientId != null && widget.id == null) {
      try {
        final patient = await context.read<PatientRepository>().findById(
          patientId,
        );
        _patientLabel = patient?.fullName ?? '';
      } catch (_) {}
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    final ref = context.watch<ReferenceNotifier>();
    final patients = context.read<PatientRepository>();
    final appointments = context.read<AppointmentRepository>();

    List<Service> chosen(FormValues v) => [
      for (final id in (v['services'] as List?)?.cast<String>() ?? const <String>[])
        ?ref.serviceById(id),
    ];

    return FormHost<Appointment>(
      id: widget.id,
      store: appointments,
      builder: (n) => EntityFormView<Appointment>(
        notifier: n,
        createTitle: 'Новый приём',
        editTitle: (e) =>
            'Изменение приёма: ${e.patientName}, ${formatDateTime(e.startAt)}',
        listPath: '/appointments',
        initialValues: (e) => {
          'patient': e?.patientId ?? widget.patientId,
          'patientLabel': e?.patientName ?? _patientLabel,
          'doctor': e?.doctorId ?? widget.doctorId,
          'services': List<String>.of(e?.serviceIds ?? const []),
          'startAt': e != null
              ? inputDateTime(e.startAt)
              : (widget.start ?? ''),
          'status': e?.status.value ?? AppointmentStatus.planned.value,
          'complaints': e?.complaints ?? '',
          'diagnosis': e?.diagnosis ?? '',
        },
        specs: (editing) => [
          LookupSpec(
            key: 'patient',
            label: 'Пациент',
            required: true,
            requiredMessage: 'Выберите пациента',
            search: (text) async => [
              for (final p in await patients.suggest(text)) (p.id, p.fullName),
            ],
          ),
          DropdownSpec(
            key: 'doctor',
            label: 'Врач',
            required: true,
            requiredMessage: 'Выберите врача',
            options: (_) => [
              for (final d in ref.doctors)
                (d.id, '${d.fullName} — ${d.specializationName}'),
            ],
          ),
          MultiSpec(
            key: 'services',
            label: 'Услуги',
            required: true,
            requiredMessage: 'Выберите хотя бы одну услугу',
            helper: 'Длительность и стоимость приёма считаются по выбранным услугам',
            options: (_) => [
              for (final s in ref.services)
                (s.id, '${s.name} · ${formatMoney(s.price)}'),
            ],
          ),
          DateTimeSpec(
            key: 'startAt',
            label: 'Начало приёма',
            required: true,
            validator: (value, values) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Укажите дату и время начала';
              final format = V.dateTime()(text);
              if (format != null) return format;
              final start = parseInputDateTime(text)!;
              if (start.hour < clinicOpenHour || start.hour >= clinicCloseHour) {
                return 'Клиника принимает с $clinicOpenHour:00 до $clinicCloseHour:00';
              }
              final minutes = chosen(values).fold<int>(
                0,
                (sum, s) => sum + s.durationMin,
              );
              final end = start.add(Duration(minutes: minutes));
              final limit = DateTime(
                start.year,
                start.month,
                start.day,
                clinicCloseHour,
              );
              if (minutes > 0 && end.isAfter(limit)) {
                return 'Приём закончится после $clinicCloseHour:00';
              }
              if (!editing &&
                  start.isBefore(
                    DateTime.now().subtract(const Duration(minutes: 5)),
                  )) {
                return 'Нельзя записать на прошедшее время';
              }
              return null;
            },
          ),
          if (editing)
            DropdownSpec(
              key: 'status',
              label: 'Статус',
              required: true,
              options: (_) => [
                for (final s in AppointmentStatus.values) (s.value, s.label),
              ],
            ),
          TextSpec(
            key: 'complaints',
            label: 'Жалобы пациента',
            maxLines: 3,
            validator: plain(V.length(max: 1000)),
          ),
          if (editing)
            TextSpec(
              key: 'diagnosis',
              label: 'Диагноз',
              maxLines: 3,
              validator: plain(V.length(max: 2000)),
            ),
          CustomSpec(
            (context, values) => AppointmentPreview(
              repository: appointments,
              excludeId: widget.id,
              patientId: values['patient'] as String?,
              doctorId: values['doctor'] as String?,
              services: chosen(values),
              startText: (values['startAt'] as String? ?? '').trim(),
            ),
          ),
        ],
        build: (v, existing) {
          final start = parseInputDateTime((v['startAt'] as String? ?? '').trim()) ??
              DateTime.now();
          final minutes = chosen(v).fold<int>(0, (s, e) => s + e.durationMin);
          return Appointment(
            id: existing?.id ?? '',
            patientId: v['patient'] as String? ?? '',
            doctorId: v['doctor'] as String? ?? '',
            serviceIds: (v['services'] as List?)?.cast<String>() ?? const [],
            startAt: start,
            endAt: start.add(Duration(minutes: minutes < 5 ? 5 : minutes)),
            status: AppointmentStatus.fromString(v['status'] as String?),
            complaints: (v['complaints'] as String? ?? '').trim(),
            diagnosis: (v['diagnosis'] as String? ?? '').trim(),
          );
        },
      ),
    );
  }
}

class AppointmentPreview extends StatefulWidget {
  final AppointmentRepository repository;
  final String? excludeId;
  final String? patientId;
  final String? doctorId;
  final List<Service> services;
  final String startText;

  const AppointmentPreview({
    super.key,
    required this.repository,
    required this.excludeId,
    required this.patientId,
    required this.doctorId,
    required this.services,
    required this.startText,
  });

  @override
  State<AppointmentPreview> createState() => _AppointmentPreviewState();
}

class _AppointmentPreviewState extends State<AppointmentPreview> {
  List<Appointment> _busy = const [];
  int _done = 0;
  String? _error;
  String _busyKey = '';
  String _doneKey = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(AppointmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  DateTime? get _start => parseInputDateTime(widget.startText);

  void _refresh() {
    final doctor = widget.doctorId;
    final start = _start;
    final busyKey = doctor == null || start == null
        ? ''
        : '$doctor|${inputDate(start)}';
    if (busyKey != _busyKey) {
      _busyKey = busyKey;
      if (busyKey.isEmpty) {
        _busy = const [];
      } else {
        unawaited(_loadBusy(busyKey, doctor!, start!));
      }
    }
    final patient = widget.patientId;
    final doneKey = patient ?? '';
    if (doneKey != _doneKey) {
      _doneKey = doneKey;
      if (patient == null) {
        _done = 0;
      } else {
        unawaited(_loadDone(doneKey, patient));
      }
    }
  }

  Future<void> _loadBusy(String key, String doctor, DateTime day) async {
    try {
      final list = await widget.repository.forDoctorOnDay(doctor, day);
      if (!mounted || key != _busyKey) return;
      setState(() {
        _busy = [
          for (final a in list)
            if (a.status != AppointmentStatus.cancelled && a.id != widget.excludeId)
              a,
        ];
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && key == _busyKey) setState(() => _error = e.message);
    }
  }

  Future<void> _loadDone(String key, String patient) async {
    try {
      final count = await widget.repository.doneCount(
        patient,
        excludeId: widget.excludeId,
      );
      if (!mounted || key != _doneKey) return;
      setState(() => _done = count);
    } on ApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = calculateCost(widget.services, _done);
    final start = _start;
    final end = start?.add(Duration(minutes: cost.minutes));
    final conflict = start == null || end == null || cost.minutes == 0
        ? null
        : _busy
              .where((a) => overlaps(start, end, a.startAt, a.endAt))
              .firstOrNull;

    return Card(
      key: const ValueKey('appointment-preview'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Расчёт приёма', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _row('Длительность', cost.minutes == 0 ? '—' : formatMinutes(cost.minutes)),
            _row(
              'Окончание',
              end == null || cost.minutes == 0 ? '—' : formatTime(end),
            ),
            _row('Стоимость услуг', formatMoney(cost.base)),
            _row(
              'Скидка постоянного пациента',
              cost.discountPercent == 0
                  ? 'нет (завершённых приёмов: $_done)'
                  : '${formatPercent(cost.discountPercent)} (завершённых приёмов: $_done)',
            ),
            _row('Итого', formatMoney(cost.total), bold: true),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (conflict != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('preview-conflict'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Врач занят: ${formatTime(conflict.startAt)}–${formatTime(conflict.endAt)} (${conflict.patientName})',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            if (_busy.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Занятость врача в этот день', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in _busy)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${formatTime(a.startAt)}–${formatTime(a.endAt)}',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ),
      ],
    ),
  );
}
