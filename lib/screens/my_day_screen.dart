import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/format.dart';
import '../core/validators.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/list_query.dart';
import '../repositories/clinic_repositories.dart';
import '../state/auth_notifier.dart';
import '../widgets/cells.dart';
import '../widgets/state_views.dart';

class MyDayScreen extends StatefulWidget {
  final DateTime date;

  const MyDayScreen({super.key, required this.date});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  Doctor? _doctor;
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
  void didUpdateWidget(MyDayScreen oldWidget) {
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
      final userId = context.read<AuthNotifier>().user!.id;
      final doctor =
          _doctor ?? await context.read<DoctorRepository>().findByUser(userId);
      if (doctor == null) {
        if (!mounted || ticket != _ticket) return;
        setState(() {
          _loading = false;
          _error = 'Ваша учётная запись не привязана к карточке врача.';
        });
        return;
      }
      if (!mounted) return;
      final list = await context.read<AppointmentRepository>().forDoctorOnDay(
        doctor.id,
        widget.date,
      );
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _doctor = doctor;
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

  void _go(DateTime date) {
    context.go(buildLocation('/my-day', {'date': inputDate(date)}));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _go(picked);
  }

  Future<void> _conduct(Appointment a) async {
    final result = await showDialog<_Outcome>(
      context: context,
      builder: (context) => _OutcomeDialog(appointment: a),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<AppointmentRepository>().updateClinical(
        a.id,
        status: result.status,
        diagnosis: result.diagnosis,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись о приёме сохранена')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Мой приём', style: theme.textTheme.headlineSmall),
              IconButton(
                key: const ValueKey('day-prev'),
                tooltip: 'Предыдущий день',
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    _go(DateTime(date.year, date.month, date.day - 1)),
              ),
              OutlinedButton.icon(
                key: const ValueKey('day-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('${weekdayShort(date)}, ${formatDate(date)}'),
              ),
              IconButton(
                key: const ValueKey('day-next'),
                tooltip: 'Следующий день',
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    _go(DateTime(date.year, date.month, date.day + 1)),
              ),
              TextButton(
                key: const ValueKey('day-today'),
                onPressed: () => _go(DateTime.now()),
                child: const Text('Сегодня'),
              ),
            ],
          ),
          if (_doctor != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_doctor!.fullName} · ${_doctor!.specializationName} · каб. ${_doctor!.cabinetNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _loading && _items.isEmpty
                ? const LoadingView()
                : _items.isEmpty
                ? const EmptyView(message: 'На этот день приёмов нет.')
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _DayCard(
                      appointment: _items[i],
                      onConduct: () => _conduct(_items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onConduct;

  const _DayCard({required this.appointment, required this.onConduct});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('day-card-${a.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${formatTime(a.startAt)}–${formatTime(a.endAt)}',
                  style: theme.textTheme.titleMedium,
                ),
                StatusBadge(a.status),
                TextButton(
                  onPressed: () => context.push('/patients/${a.patientId}'),
                  child: Text(a.patientName),
                ),
              ],
            ),
            Text(a.serviceNames.join(', ')),
            if (a.complaints.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Жалобы: ${a.complaints}'),
              ),
            if (a.diagnosis.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Диагноз: ${a.diagnosis}'),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: ValueKey('conduct-${a.id}'),
                onPressed: onConduct,
                icon: const Icon(Icons.edit_note),
                label: Text(
                  a.status == AppointmentStatus.planned
                      ? 'Провести приём'
                      : 'Изменить запись',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Outcome {
  final AppointmentStatus status;
  final String diagnosis;

  const _Outcome(this.status, this.diagnosis);
}

class _OutcomeDialog extends StatefulWidget {
  final Appointment appointment;

  const _OutcomeDialog({required this.appointment});

  @override
  State<_OutcomeDialog> createState() => _OutcomeDialogState();
}

class _OutcomeDialogState extends State<_OutcomeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _diagnosis = TextEditingController(
    text: widget.appointment.diagnosis,
  );
  late AppointmentStatus _status =
      widget.appointment.status == AppointmentStatus.planned
      ? AppointmentStatus.done
      : widget.appointment.status;

  @override
  void dispose() {
    _diagnosis.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appointment.patientName),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<AppointmentStatus>(
              key: const ValueKey('outcome-status'),
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Статус приёма',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in AppointmentStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('outcome-diagnosis'),
              controller: _diagnosis,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Диагноз и назначения',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (_status == AppointmentStatus.done && text.isEmpty) {
                  return 'Для проведённого приёма укажите диагноз';
                }
                return V.length(max: 2000)(text);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('outcome-save'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, _Outcome(_status, _diagnosis.text.trim()));
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
