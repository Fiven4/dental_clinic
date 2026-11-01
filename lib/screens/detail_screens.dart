import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/access.dart';
import '../core/format.dart';
import '../models/appointment.dart';
import '../models/cabinet.dart';
import '../models/doctor.dart';
import '../models/filter_query.dart';
import '../models/patient.dart';
import '../models/patient_card.dart';
import '../models/payment.dart';
import '../models/query_specs.dart';
import '../models/role.dart';
import '../models/service.dart';
import '../models/service_category.dart';
import '../models/specialization.dart';
import '../repositories/clinic_repositories.dart';
import '../repositories/entity_repository.dart';
import '../state/auth_notifier.dart';
import '../state/entity_detail_notifier.dart';
import '../widgets/cells.dart';
import '../widgets/detail_view.dart';
import '../widgets/list_permissions.dart';
import '../widgets/related_card.dart';

class DetailHost<T, R> extends StatelessWidget {
  final String id;
  final RecordStore<T> store;
  final Future<List<R>> Function(String id)? related;
  final Widget Function(RelatedDetailNotifier<T, R> notifier) builder;

  const DetailHost({
    super.key,
    required this.id,
    required this.store,
    required this.builder,
    this.related,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RelatedDetailNotifier<T, R>>(
      key: ValueKey('detail-$T-$id'),
      create: (_) =>
          RelatedDetailNotifier<T, R>(store, id, related ?? (_) async => <R>[])
            ..load(),
      child: Consumer<RelatedDetailNotifier<T, R>>(
        builder: (context, notifier, _) => builder(notifier),
      ),
    );
  }
}

ListPermissions _perm(BuildContext context, Section section) =>
    permissionsFor(context.watch<AuthNotifier>().role, section);

Future<List<R>> _page<R>(
  EntityRepository<R, FilterQuery> repo,
  QuerySpec spec,
  Map<String, String> filters, {
  int size = 25,
}) async {
  final page = await repo.find(
    FilterQuery(spec: spec, filters: filters, size: size),
  );
  return page.items;
}

class SpecializationDetailScreen extends StatelessWidget {
  final String id;

  const SpecializationDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final doctors = context.read<DoctorRepository>();
    return DetailHost<Specialization, Doctor>(
      id: id,
      store: context.read<SpecializationRepository>(),
      related: (id) => _page(doctors, doctorsSpec, {'specialization': id}),
      builder: (n) => DetailView<Specialization>(
        notifier: n,
        listPath: '/specializations',
        editPath: '/specializations/$id/edit',
        permissions: _perm(context, Section.specializations),
        titleOf: (e) => e.name,
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Название', Text(e.name)),
          ('Описание', Text(e.description.isEmpty ? '—' : e.description)),
        ],
        extra: (_) => RelatedCard(
          title: 'Врачи',
          emptyText: 'Врачей с этой специализацией нет.',
          items: [
            for (final d in n.related)
              RelatedItem(
                title: d.fullName,
                subtitle: 'Кабинет ${d.cabinetNumber}',
                path: '/doctors/${d.id}',
              ),
          ],
        ),
      ),
    );
  }
}

class CabinetDetailScreen extends StatelessWidget {
  final String id;

  const CabinetDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final doctors = context.read<DoctorRepository>();
    return DetailHost<Cabinet, Doctor>(
      id: id,
      store: context.read<CabinetRepository>(),
      related: (id) => _page(doctors, doctorsSpec, {'cabinet': id}),
      builder: (n) => DetailView<Cabinet>(
        notifier: n,
        listPath: '/cabinets',
        editPath: '/cabinets/$id/edit',
        permissions: _perm(context, Section.cabinets),
        titleOf: (e) => 'Кабинет ${e.number}',
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Номер', Text(e.number)),
          ('Этаж', Text('${e.floor}')),
          ('Оснащение', Text(e.equipment.isEmpty ? '—' : e.equipment)),
        ],
        extra: (_) => RelatedCard(
          title: 'Врач кабинета',
          emptyText: 'Кабинет свободен.',
          items: [
            for (final d in n.related)
              RelatedItem(
                title: d.fullName,
                subtitle: d.specializationName,
                path: '/doctors/${d.id}',
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  final String id;

  const CategoryDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final services = context.read<ServiceRepository>();
    return DetailHost<ServiceCategory, Service>(
      id: id,
      store: context.read<ServiceCategoryRepository>(),
      related: (id) =>
          _page(services, servicesSpec, {'category': id}, size: 50),
      builder: (n) => DetailView<ServiceCategory>(
        notifier: n,
        listPath: '/categories',
        editPath: '/categories/$id/edit',
        permissions: _perm(context, Section.categories),
        titleOf: (e) => e.name,
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Название', Text(e.name)),
          ('Описание', Text(e.description.isEmpty ? '—' : e.description)),
        ],
        extra: (_) => RelatedCard(
          title: 'Услуги категории',
          emptyText: 'В категории пока нет услуг.',
          items: [
            for (final s in n.related)
              RelatedItem(
                title: s.name,
                subtitle:
                    '${formatMoney(s.price)} · ${formatMinutes(s.durationMin)}',
                path: '/services/${s.id}',
              ),
          ],
        ),
      ),
    );
  }
}

class ServiceDetailScreen extends StatelessWidget {
  final String id;

  const ServiceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return DetailHost<Service, Object>(
      id: id,
      store: context.read<ServiceRepository>(),
      builder: (n) => DetailView<Service>(
        notifier: n,
        listPath: '/services',
        editPath: '/services/$id/edit',
        permissions: _perm(context, Section.services),
        titleOf: (e) => e.name,
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Категория', Text(e.categoryName)),
          ('Цена', Text(formatMoney(e.price))),
          ('Длительность', Text(formatMinutes(e.durationMin))),
          ('Описание', Text(e.description.isEmpty ? '—' : e.description)),
        ],
      ),
    );
  }
}

class DoctorDetailScreen extends StatelessWidget {
  final String id;

  const DoctorDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final appointments = context.read<AppointmentRepository>();
    final canSeeAppointments = canAccess(
      context.watch<AuthNotifier>().role,
      Section.appointments,
    );
    return DetailHost<Doctor, Appointment>(
      id: id,
      store: context.read<DoctorRepository>(),
      related: canSeeAppointments
          ? (id) => _page(appointments, appointmentsSpec, {
              'doctor': id,
              'status': 'planned',
            }, size: 10)
          : null,
      builder: (n) => DetailView<Doctor>(
        notifier: n,
        listPath: '/doctors',
        editPath: '/doctors/$id/edit',
        permissions: _perm(context, Section.doctors),
        titleOf: (e) => e.fullName,
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Специализация', Text(e.specializationName)),
          ('Кабинет', Text(e.cabinetNumber)),
          ('Стаж', Text('${e.experienceYears} лет')),
          ('Телефон', Text(e.phone.isEmpty ? '—' : e.phone)),
        ],
        extra: (e) => canSeeAppointments
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RelatedCard(
                    title: 'Ближайшие приёмы',
                    emptyText: 'Запланированных приёмов нет.',
                    items: [
                      for (final a in n.related)
                        RelatedItem(
                          title:
                              '${formatDateTime(a.startAt)} — ${a.patientName}',
                          subtitle: a.serviceNames.join(', '),
                          path: '/appointments/${a.id}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('doctor-schedule'),
                      onPressed: () => context.go('/schedule?doctor=${e.id}'),
                      icon: const Icon(Icons.calendar_view_week_outlined),
                      label: const Text('Открыть расписание'),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class PatientDetailScreen extends StatelessWidget {
  final String id;

  const PatientDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final appointments = context.read<AppointmentRepository>();
    final cards = context.read<PatientCardRepository>();
    final role = context.watch<AuthNotifier>().role;
    return DetailHost<Patient, Object>(
      id: id,
      store: context.read<PatientRepository>(),
      related: (id) async => <Object>[
        ...await _page(cards, cardsSpec, {'patient': id}, size: 1),
        ...await _page(appointments, appointmentsSpec, {
          'patient': id,
        }, size: 10),
      ],
      builder: (n) => DetailView<Patient>(
        notifier: n,
        listPath: '/patients',
        editPath: '/patients/$id/edit',
        permissions: _perm(context, Section.patients),
        titleOf: (e) => e.fullName,
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          (
            'Дата рождения',
            Text(
              e.birthDate == null
                  ? '—'
                  : '${formatDate(e.birthDate!)} (${e.ageOn(DateTime.now())} л.)',
            ),
          ),
          ('Телефон', Text(e.phone)),
          ('Почта', Text(e.email.isEmpty ? '—' : e.email)),
          ('Адрес', Text(e.address.isEmpty ? '—' : e.address)),
        ],
        extraButtons: (e) => [
          if (role == Role.registrar || role == Role.admin)
            FilledButton.tonalIcon(
              key: const ValueKey('patient-new-appointment'),
              onPressed: () =>
                  context.push('/appointments/new?patient=${e.id}'),
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Записать на приём'),
            ),
        ],
        extra: (e) {
          final card = n.related.whereType<PatientCard>().firstOrNull;
          final visits = n.related.whereType<Appointment>().toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RelatedCard(
                title: 'Карта пациента',
                emptyText: 'Карта не заведена.',
                items: [
                  if (card != null)
                    RelatedItem(
                      title: card.number,
                      subtitle: card.allergies.isEmpty
                          ? 'Аллергии не указаны'
                          : 'Аллергии: ${card.allergies}',
                      path: '/cards/${card.id}',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              RelatedCard(
                title: 'Последние приёмы',
                emptyText: 'Приёмов ещё не было.',
                items: [
                  for (final a in visits)
                    RelatedItem(
                      title: '${formatDateTime(a.startAt)} — ${a.doctorName}',
                      subtitle: a.serviceNames.join(', '),
                      trailing: StatusBadge(a.status),
                      path: '/appointments/${a.id}',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class CardDetailScreen extends StatelessWidget {
  final String id;

  const CardDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return DetailHost<PatientCard, Object>(
      id: id,
      store: context.read<PatientCardRepository>(),
      builder: (n) => DetailView<PatientCard>(
        notifier: n,
        listPath: '/cards',
        editPath: '/cards/$id/edit',
        permissions: _perm(context, Section.cards),
        titleOf: (e) => 'Карта ${e.number}',
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Пациент', Text(e.patientName)),
          ('Открыта', Text(e.openedOn == null ? '—' : formatDate(e.openedOn!))),
          ('Аллергии', Text(e.allergies.isEmpty ? '—' : e.allergies)),
          ('Заметки', Text(e.notes.isEmpty ? '—' : e.notes)),
        ],
        extraButtons: (e) => [
          TextButton.icon(
            key: const ValueKey('card-open-patient'),
            onPressed: () => context.push('/patients/${e.patientId}'),
            icon: const Icon(Icons.person_outline),
            label: const Text('Открыть пациента'),
          ),
        ],
      ),
    );
  }
}

class AppointmentDetailScreen extends StatelessWidget {
  final String id;

  const AppointmentDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final payments = context.read<PaymentRepository>();
    final role = context.watch<AuthNotifier>().role;
    final canSeePayments = canAccess(role, Section.cash);
    return DetailHost<Appointment, Payment>(
      id: id,
      store: context.read<AppointmentRepository>(),
      related: canSeePayments
          ? (id) => _page(payments, paymentsSpec, {'appointment': id}, size: 50)
          : null,
      builder: (n) => DetailView<Appointment>(
        notifier: n,
        listPath: '/appointments',
        editPath: '/appointments/$id/edit',
        permissions: _perm(context, Section.appointments),
        titleOf: (e) => 'Приём ${formatDateTime(e.startAt)}',
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Статус', StatusBadge(e.status)),
          ('Пациент', Text(e.patientName)),
          ('Врач', Text('${e.doctorName}, каб. ${e.cabinetNumber}')),
          (
            'Время',
            Text(
              '${formatDateTime(e.startAt)}–${formatTime(e.endAt)} (${formatMinutes(e.durationMin)})',
            ),
          ),
          ('Услуги', Text(e.serviceNames.join(', '))),
          ('Скидка', Text(formatPercent(e.discountPercent))),
          ('Сумма', Text(formatMoney(e.total))),
          ('Оплачено', Text(canSeePayments ? formatMoney(e.paid) : '—')),
          ('Жалобы', Text(e.complaints.isEmpty ? '—' : e.complaints)),
          ('Диагноз', Text(e.diagnosis.isEmpty ? '—' : e.diagnosis)),
        ],
        extraButtons: (e) => [
          if (role == Role.registrar &&
              !e.isDeleted &&
              e.status != AppointmentStatus.cancelled &&
              e.debt > 0)
            FilledButton.tonalIcon(
              key: const ValueKey('appointment-pay'),
              onPressed: () => context.push('/cash/new?appointment=${e.id}'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Принять оплату'),
            ),
        ],
        extra: (e) => canSeePayments
            ? RelatedCard(
                title: 'Платежи',
                emptyText: 'Платежей по приёму нет.',
                items: [
                  for (final p in n.related)
                    RelatedItem(
                      title: '${formatMoney(p.amount)} · ${p.method.label}',
                      subtitle: p.paidAt == null
                          ? null
                          : formatDateTime(p.paidAt!.toLocal()),
                      path: role == Role.registrar ? '/cash/${p.id}' : null,
                    ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class PaymentDetailScreen extends StatelessWidget {
  final String id;

  const PaymentDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return DetailHost<Payment, Object>(
      id: id,
      store: context.read<PaymentRepository>(),
      builder: (n) => DetailView<Payment>(
        notifier: n,
        listPath: '/cash',
        editPath: '/cash/$id/edit',
        permissions: _perm(context, Section.cash),
        titleOf: (e) => 'Платёж ${formatMoney(e.amount)}',
        isDeleted: (e) => e.isDeleted,
        fields: (e) => [
          ('Пациент', Text(e.patientName)),
          ('Врач', Text(e.doctorName)),
          (
            'Приём',
            Text(
              e.appointmentStart == null
                  ? '—'
                  : formatDateTime(e.appointmentStart!.toLocal()),
            ),
          ),
          ('Стоимость приёма', Text(formatMoney(e.appointmentTotal))),
          ('Сумма платежа', Text(formatMoney(e.amount))),
          ('Способ', Text(e.method.label)),
          (
            'Оплачен',
            Text(e.paidAt == null ? '—' : formatDateTime(e.paidAt!.toLocal())),
          ),
        ],
        extraButtons: (e) => [
          TextButton.icon(
            key: const ValueKey('payment-open-appointment'),
            onPressed: () => context.push('/appointments/${e.appointmentId}'),
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('Открыть приём'),
          ),
        ],
      ),
    );
  }
}
