import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/access.dart';
import '../core/api_exceptions.dart';
import '../core/format.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/list_query.dart';
import '../repositories/clinic_repositories.dart';
import '../state/auth_notifier.dart';
import '../state/reference_notifier.dart';
import '../widgets/state_views.dart';
import 'appointment_form_screen.dart';

const _hourHeight = 60.0;
const _columnWidth = 190.0;
const _timeWidth = 52.0;

class ScheduleScreen extends StatefulWidget {
  final DateTime date;
  final String? doctorId;

  const ScheduleScreen({super.key, required this.date, this.doctorId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Appointment> _items = const [];
  bool _loading = true;
  String? _error;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final day = widget.date;
      final list = await context.read<AppointmentRepository>().inRange(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day + 1),
      );
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _items = list;
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

  void _go({DateTime? date, Object? doctor = #keep}) {
    final params = <String, String>{'date': inputDate(date ?? widget.date)};
    final doctorId = doctor == #keep ? widget.doctorId : doctor as String?;
    if (doctorId != null) params['doctor'] = doctorId;
    context.go(buildLocation('/schedule', params));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _go(date: picked);
  }

  void _createAt(Doctor doctor, double dy) {
    final minutes = ((dy / _hourHeight) * 60).floor();
    final snapped = (minutes ~/ 15) * 15;
    final start = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      clinicOpenHour,
    ).add(Duration(minutes: snapped));
    context.push(
      buildLocation('/appointments/new', {
        'doctor': doctor.id,
        'start': inputDateTime(start),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    final role = context.watch<AuthNotifier>().role;
    final canCreate = permissionsFor(role, Section.appointments).create;
    final doctors = [
      for (final d in ref.doctors)
        if (widget.doctorId == null || d.id == widget.doctorId) d,
    ];
    final theme = Theme.of(context);
    final date = widget.date;

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
              Text('Расписание', style: theme.textTheme.headlineSmall),
              IconButton(
                key: const ValueKey('schedule-prev'),
                tooltip: 'Предыдущий день',
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    _go(date: DateTime(date.year, date.month, date.day - 1)),
              ),
              OutlinedButton.icon(
                key: const ValueKey('schedule-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('${weekdayShort(date)}, ${formatDate(date)}'),
              ),
              IconButton(
                key: const ValueKey('schedule-next'),
                tooltip: 'Следующий день',
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    _go(date: DateTime(date.year, date.month, date.day + 1)),
              ),
              TextButton(
                key: const ValueKey('schedule-today'),
                onPressed: () => _go(date: DateTime.now()),
                child: const Text('Сегодня'),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('schedule-doctor-${widget.doctorId}'),
                  initialValue: widget.doctorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Врач',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все врачи'),
                    ),
                    for (final d in ref.doctors)
                      DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(
                          d.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => _go(doctor: v),
                ),
              ),
              IconButton(
                key: const ValueKey('schedule-refresh'),
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _loading && _items.isEmpty
                ? const LoadingView()
                : doctors.isEmpty
                ? const EmptyView(message: 'Нет врачей для отображения.')
                : _Timeline(
                    doctors: doctors,
                    items: _items,
                    date: date,
                    onCreate: canCreate ? _createAt : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<Doctor> doctors;
  final List<Appointment> items;
  final DateTime date;
  final void Function(Doctor doctor, double dy)? onCreate;

  const _Timeline({
    required this.doctors,
    required this.items,
    required this.date,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = clinicCloseHour - clinicOpenHour;
    final height = hours * _hourHeight;
    final now = DateTime.now();
    final today =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final nowOffset =
        ((now.hour - clinicOpenHour) * 60 + now.minute) / 60 * _hourHeight;

    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: _timeWidth),
                  for (final d in doctors)
                    SizedBox(
                      width: _columnWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              'каб. ${d.cabinetNumber}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _timeWidth,
                    height: height,
                    child: Stack(
                      children: [
                        for (var h = 0; h <= hours; h++)
                          Positioned(
                            top: h * _hourHeight - 8,
                            left: 0,
                            child: Text(
                              '${(clinicOpenHour + h).toString().padLeft(2, '0')}:00',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final d in doctors)
                    _DoctorColumn(
                      doctor: d,
                      height: height,
                      hours: hours,
                      items: [
                        for (final a in items)
                          if (a.doctorId == d.id) a,
                      ],
                      nowOffset: today && nowOffset >= 0 && nowOffset <= height
                          ? nowOffset
                          : null,
                      onCreate: onCreate,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorColumn extends StatelessWidget {
  final Doctor doctor;
  final double height;
  final int hours;
  final List<Appointment> items;
  final double? nowOffset;
  final void Function(Doctor doctor, double dy)? onCreate;

  const _DoctorColumn({
    required this.doctor,
    required this.height,
    required this.hours,
    required this.items,
    required this.nowOffset,
    required this.onCreate,
  });

  Color _color(ColorScheme scheme, AppointmentStatus status) =>
      switch (status) {
        AppointmentStatus.planned => scheme.secondaryContainer,
        AppointmentStatus.done => scheme.primaryContainer,
        AppointmentStatus.cancelled => scheme.errorContainer,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('column-${doctor.id}'),
      width: _columnWidth,
      height: height,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onCreate == null
            ? null
            : (d) => onCreate!(doctor, d.localPosition.dy),
        child: Stack(
          children: [
            for (var h = 0; h <= hours; h++)
              Positioned(
                top: h * _hourHeight,
                left: 0,
                right: 0,
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
            for (final a in items)
              Positioned(
                top:
                    ((a.startAt.hour - clinicOpenHour) * 60 +
                        a.startAt.minute) /
                    60 *
                    _hourHeight,
                left: 4,
                right: 4,
                height: (a.durationMin / 60 * _hourHeight).clamp(24.0, height),
                child: Material(
                  key: ValueKey('slot-${a.id}'),
                  color: _color(scheme, a.status),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push('/appointments/${a.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${formatTime(a.startAt)}–${formatTime(a.endAt)}\n${a.patientName}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 12,
                          decoration: a.status == AppointmentStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (nowOffset != null)
              Positioned(
                top: nowOffset,
                left: 0,
                right: 0,
                child: Container(height: 2, color: scheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
