import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/access.dart';
import '../core/format.dart';
import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/cabinet.dart';
import '../models/doctor.dart';
import '../models/filter_query.dart';
import '../models/patient.dart';
import '../models/patient_card.dart';
import '../models/payment.dart';
import '../models/role.dart';
import '../models/service.dart';
import '../models/service_category.dart';
import '../models/specialization.dart';
import '../state/auth_notifier.dart';
import '../state/clinic_scope.dart';
import '../state/reference_notifier.dart';
import '../widgets/cells.dart';
import '../widgets/entity_list_view.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_widgets.dart';
import '../widgets/list_permissions.dart';

ListPermissions _permissions(BuildContext context, Section section) =>
    permissionsFor(context.watch<AuthNotifier>().role, section);

int? _intFilter(FilterQuery q, String key) => int.tryParse(q.filter(key) ?? '');

class SpecializationsScreen extends StatelessWidget {
  final FilterQuery query;

  const SpecializationsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EntityListView<Specialization, FilterQuery>(
      title: 'Специализации',
      basePath: '/specializations',
      notifier: context.read<ListNotifier<Specialization>>(),
      query: query,
      permissions: _permissions(context, Section.specializations),
      searchHint: 'Поиск по названию',
      emptyMessage: 'Специализации не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/specializations/${e.id}',
      createPath: '/specializations/new',
      editPath: (e) => '/specializations/${e.id}/edit',
      itemTitle: (e) => 'Специализация «${e.name}»',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<Specialization>(
          label: 'Название',
          sortField: 'name',
          build: (e) => TitleCell(title: e.name, deleted: e.isDeleted),
        ),
        TableColumnSpec<Specialization>(
          label: 'Описание',
          build: (e) => CellText(e.description, maxWidth: 380),
        ),
      ],
    );
  }
}

class CabinetsScreen extends StatelessWidget {
  final FilterQuery query;

  const CabinetsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EntityListView<Cabinet, FilterQuery>(
      title: 'Кабинеты',
      basePath: '/cabinets',
      notifier: context.read<ListNotifier<Cabinet>>(),
      query: query,
      permissions: _permissions(context, Section.cabinets),
      searchHint: 'Поиск по номеру или оснащению',
      emptyMessage: 'Кабинеты не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/cabinets/${e.id}',
      createPath: '/cabinets/new',
      editPath: (e) => '/cabinets/${e.id}/edit',
      itemTitle: (e) => 'Кабинет ${e.number}',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<Cabinet>(
          label: 'Номер',
          sortField: 'number',
          build: (e) => TitleCell(title: e.number, deleted: e.isDeleted),
        ),
        TableColumnSpec<Cabinet>(
          label: 'Этаж',
          sortField: 'floor',
          numeric: true,
          build: (e) => Text('${e.floor}'),
        ),
        TableColumnSpec<Cabinet>(
          label: 'Оснащение',
          build: (e) => CellText(e.equipment, maxWidth: 360),
        ),
      ],
      filters: (s) => [
        NumberFilterField(
          key: const ValueKey('floor-filter'),
          label: 'Этаж',
          value: _intFilter(s.query, 'floor'),
          onChanged: (v) =>
              s.applyDebounced((q) => q.withFilter('floor', v?.toString())),
        ),
      ],
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  final FilterQuery query;

  const CategoriesScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EntityListView<ServiceCategory, FilterQuery>(
      title: 'Категории услуг',
      basePath: '/categories',
      notifier: context.read<ListNotifier<ServiceCategory>>(),
      query: query,
      permissions: _permissions(context, Section.categories),
      searchHint: 'Поиск по названию',
      emptyMessage: 'Категории не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/categories/${e.id}',
      createPath: '/categories/new',
      editPath: (e) => '/categories/${e.id}/edit',
      itemTitle: (e) => 'Категория «${e.name}»',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<ServiceCategory>(
          label: 'Название',
          sortField: 'name',
          build: (e) => TitleCell(title: e.name, deleted: e.isDeleted),
        ),
        TableColumnSpec<ServiceCategory>(
          label: 'Описание',
          build: (e) => CellText(e.description, maxWidth: 380),
        ),
      ],
    );
  }
}

class ServicesScreen extends StatelessWidget {
  final FilterQuery query;

  const ServicesScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    return EntityListView<Service, FilterQuery>(
      title: 'Услуги',
      basePath: '/services',
      notifier: context.read<ListNotifier<Service>>(),
      query: query,
      permissions: _permissions(context, Section.services),
      searchHint: 'Поиск по названию или категории',
      emptyMessage: 'Услуги не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/services/${e.id}',
      createPath: '/services/new',
      editPath: (e) => '/services/${e.id}/edit',
      itemTitle: (e) => 'Услуга «${e.name}»',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<Service>(
          label: 'Название',
          sortField: 'name',
          build: (e) => TitleCell(title: e.name, deleted: e.isDeleted),
        ),
        TableColumnSpec<Service>(
          label: 'Категория',
          sortField: 'category',
          build: (e) => CellText(e.categoryName),
        ),
        TableColumnSpec<Service>(
          label: 'Цена',
          sortField: 'price',
          numeric: true,
          build: (e) => Text(formatMoney(e.price)),
        ),
        TableColumnSpec<Service>(
          label: 'Длительность',
          sortField: 'durationMin',
          numeric: true,
          build: (e) => Text(formatMinutes(e.durationMin)),
        ),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Категория',
          value: s.query.filter('category'),
          options: [for (final c in ref.categories) (c.id, c.name)],
          onChanged: (v) => s.apply((q) => q.withFilter('category', v)),
        ),
        NumberFilterField(
          key: const ValueKey('price-min'),
          label: 'Цена от',
          value: _intFilter(s.query, 'priceMin'),
          onChanged: (v) =>
              s.applyDebounced((q) => q.withFilter('priceMin', v?.toString())),
        ),
        NumberFilterField(
          key: const ValueKey('price-max'),
          label: 'Цена до',
          value: _intFilter(s.query, 'priceMax'),
          onChanged: (v) =>
              s.applyDebounced((q) => q.withFilter('priceMax', v?.toString())),
        ),
        NumberFilterField(
          key: const ValueKey('duration-max'),
          label: 'До, мин',
          value: _intFilter(s.query, 'durationMax'),
          onChanged: (v) => s.applyDebounced(
            (q) => q.withFilter('durationMax', v?.toString()),
          ),
        ),
      ],
    );
  }
}

class DoctorsScreen extends StatelessWidget {
  final FilterQuery query;

  const DoctorsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    return EntityListView<Doctor, FilterQuery>(
      title: 'Врачи',
      basePath: '/doctors',
      notifier: context.read<ListNotifier<Doctor>>(),
      query: query,
      permissions: _permissions(context, Section.doctors),
      searchHint: 'Поиск по ФИО, телефону или специализации',
      emptyMessage: 'Врачи не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/doctors/${e.id}',
      createPath: '/doctors/new',
      editPath: (e) => '/doctors/${e.id}/edit',
      itemTitle: (e) => 'Врач ${e.fullName}',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<Doctor>(
          label: 'ФИО',
          sortField: 'fullName',
          build: (e) => TitleCell(title: e.fullName, deleted: e.isDeleted),
        ),
        TableColumnSpec<Doctor>(
          label: 'Специализация',
          sortField: 'specialization',
          build: (e) => CellText(e.specializationName),
        ),
        TableColumnSpec<Doctor>(
          label: 'Кабинет',
          sortField: 'cabinet',
          build: (e) => Text(e.cabinetNumber),
        ),
        TableColumnSpec<Doctor>(
          label: 'Стаж, лет',
          sortField: 'experienceYears',
          numeric: true,
          build: (e) => Text('${e.experienceYears}'),
        ),
        TableColumnSpec<Doctor>(label: 'Телефон', build: (e) => Text(e.phone)),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Специализация',
          value: s.query.filter('specialization'),
          options: [for (final c in ref.specializations) (c.id, c.name)],
          onChanged: (v) => s.apply((q) => q.withFilter('specialization', v)),
        ),
        DropdownFilter<String>(
          label: 'Кабинет',
          value: s.query.filter('cabinet'),
          options: [for (final c in ref.cabinets) (c.id, c.number)],
          width: 150,
          onChanged: (v) => s.apply((q) => q.withFilter('cabinet', v)),
        ),
        NumberFilterField(
          key: const ValueKey('experience-min'),
          label: 'Стаж от',
          value: _intFilter(s.query, 'experienceMin'),
          onChanged: (v) => s.applyDebounced(
            (q) => q.withFilter('experienceMin', v?.toString()),
          ),
        ),
      ],
    );
  }
}

class PatientsScreen extends StatelessWidget {
  final FilterQuery query;

  const PatientsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return EntityListView<Patient, FilterQuery>(
      title: 'Пациенты',
      basePath: '/patients',
      notifier: context.read<ListNotifier<Patient>>(),
      query: query,
      permissions: _permissions(context, Section.patients),
      searchHint: 'Поиск по ФИО, телефону или почте',
      emptyMessage: 'Пациенты не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/patients/${e.id}',
      createPath: '/patients/new',
      editPath: (e) => '/patients/${e.id}/edit',
      itemTitle: (e) => 'Пациент ${e.fullName}',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<Patient>(
          label: 'ФИО',
          sortField: 'fullName',
          build: (e) => TitleCell(title: e.fullName, deleted: e.isDeleted),
        ),
        TableColumnSpec<Patient>(
          label: 'Дата рождения',
          sortField: 'birthDate',
          build: (e) => Text(
            e.birthDate == null
                ? '—'
                : '${formatDate(e.birthDate!)} (${e.ageOn(now)} л.)',
          ),
        ),
        TableColumnSpec<Patient>(label: 'Телефон', build: (e) => Text(e.phone)),
        TableColumnSpec<Patient>(
          label: 'Почта',
          build: (e) => CellText(e.email.isEmpty ? '—' : e.email),
        ),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Возраст',
          value: s.query.filter('ageGroup'),
          options: const [
            ('child', 'Дети до 18'),
            ('adult', '18–59 лет'),
            ('senior', '60 и старше'),
          ],
          width: 170,
          onChanged: (v) => s.apply((q) => q.withFilter('ageGroup', v)),
        ),
        DropdownFilter<String>(
          label: 'Карта',
          value: s.query.filter('hasCard'),
          options: const [('yes', 'Есть'), ('no', 'Нет')],
          width: 130,
          onChanged: (v) => s.apply((q) => q.withFilter('hasCard', v)),
        ),
        DropdownFilter<String>(
          label: 'Почта',
          value: s.query.filter('hasEmail'),
          options: const [('yes', 'Указана'), ('no', 'Не указана')],
          width: 150,
          onChanged: (v) => s.apply((q) => q.withFilter('hasEmail', v)),
        ),
      ],
    );
  }
}

class CardsScreen extends StatelessWidget {
  final FilterQuery query;

  const CardsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EntityListView<PatientCard, FilterQuery>(
      title: 'Карты пациентов',
      basePath: '/cards',
      notifier: context.read<ListNotifier<PatientCard>>(),
      query: query,
      permissions: _permissions(context, Section.cards),
      searchHint: 'Поиск по номеру, пациенту или аллергиям',
      emptyMessage: 'Карты не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/cards/${e.id}',
      createPath: '/cards/new',
      editPath: (e) => '/cards/${e.id}/edit',
      itemTitle: (e) => 'Карта ${e.number}',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<PatientCard>(
          label: 'Номер',
          sortField: 'number',
          build: (e) => TitleCell(title: e.number, deleted: e.isDeleted),
        ),
        TableColumnSpec<PatientCard>(
          label: 'Пациент',
          sortField: 'patient',
          build: (e) => CellText(e.patientName),
        ),
        TableColumnSpec<PatientCard>(
          label: 'Открыта',
          sortField: 'openedOn',
          build: (e) =>
              Text(e.openedOn == null ? '—' : formatDate(e.openedOn!)),
        ),
        TableColumnSpec<PatientCard>(
          label: 'Аллергии',
          build: (e) => CellText(e.allergies.isEmpty ? '—' : e.allergies),
        ),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Аллергии',
          value: s.query.filter('hasAllergies'),
          options: const [('yes', 'Есть'), ('no', 'Нет')],
          width: 140,
          onChanged: (v) => s.apply((q) => q.withFilter('hasAllergies', v)),
        ),
        DateFilterField(
          key: const ValueKey('opened-from'),
          label: 'Открыта с',
          value: s.query.filter('openedFrom'),
          onChanged: (v) => s.apply((q) => q.withFilter('openedFrom', v)),
        ),
        DateFilterField(
          key: const ValueKey('opened-to'),
          label: 'Открыта по',
          value: s.query.filter('openedTo'),
          onChanged: (v) => s.apply((q) => q.withFilter('openedTo', v)),
        ),
      ],
    );
  }
}

class AppointmentsScreen extends StatelessWidget {
  final FilterQuery query;

  const AppointmentsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    final role = context.watch<AuthNotifier>().role;
    return EntityListView<Appointment, FilterQuery>(
      title: 'Приёмы',
      basePath: '/appointments',
      notifier: context.read<ListNotifier<Appointment>>(),
      query: query,
      permissions: _permissions(context, Section.appointments),
      searchHint: 'Поиск по пациенту, врачу или диагнозу',
      emptyMessage: 'Приёмы не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/appointments/${e.id}',
      createPath: '/appointments/new',
      editPath: (e) => '/appointments/${e.id}/edit',
      itemTitle: (e) => 'Приём ${formatDateTime(e.startAt)} — ${e.patientName}',
      isDeleted: (e) => e.isDeleted,
      extraActions: (e) => [
        if (role == Role.registrar &&
            !e.isDeleted &&
            e.status != AppointmentStatus.cancelled &&
            e.debt > 0)
          IconButton(
            key: ValueKey('pay-${e.id}'),
            tooltip: 'Принять оплату',
            icon: const Icon(Icons.payments_outlined),
            onPressed: () => context.push('/cash/new?appointment=${e.id}'),
          ),
      ],
      columns: [
        TableColumnSpec<Appointment>(
          label: 'Дата и время',
          sortField: 'startAt',
          build: (e) =>
              Text('${formatDateTime(e.startAt)}–${formatTime(e.endAt)}'),
        ),
        TableColumnSpec<Appointment>(
          label: 'Пациент',
          sortField: 'patient',
          build: (e) => TitleCell(title: e.patientName, deleted: e.isDeleted),
        ),
        TableColumnSpec<Appointment>(
          label: 'Врач',
          sortField: 'doctor',
          build: (e) => CellText(e.doctorName),
        ),
        TableColumnSpec<Appointment>(
          label: 'Услуги',
          build: (e) => CellText(e.serviceNames.join(', '), maxWidth: 240),
        ),
        TableColumnSpec<Appointment>(
          label: 'Статус',
          sortField: 'status',
          build: (e) => StatusBadge(e.status),
        ),
        TableColumnSpec<Appointment>(
          label: 'Сумма',
          sortField: 'total',
          numeric: true,
          build: (e) => Text(formatMoney(e.total)),
        ),
        TableColumnSpec<Appointment>(
          label: 'Оплачено',
          numeric: true,
          build: (e) => Text(formatMoney(e.paid)),
        ),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Статус',
          value: s.query.filter('status'),
          options: [
            for (final st in AppointmentStatus.values) (st.value, st.label),
          ],
          width: 170,
          onChanged: (v) => s.apply((q) => q.withFilter('status', v)),
        ),
        DropdownFilter<String>(
          label: 'Врач',
          value: s.query.filter('doctor'),
          options: [for (final d in ref.doctors) (d.id, d.fullName)],
          width: 220,
          onChanged: (v) => s.apply((q) => q.withFilter('doctor', v)),
        ),
        DropdownFilter<String>(
          label: 'Категория услуг',
          value: s.query.filter('category'),
          options: [for (final c in ref.categories) (c.id, c.name)],
          onChanged: (v) => s.apply((q) => q.withFilter('category', v)),
        ),
        DateFilterField(
          key: const ValueKey('date-from'),
          label: 'С даты',
          value: s.query.filter('from'),
          onChanged: (v) => s.apply((q) => q.withFilter('from', v)),
        ),
        DateFilterField(
          key: const ValueKey('date-to'),
          label: 'По дату',
          value: s.query.filter('to'),
          onChanged: (v) => s.apply((q) => q.withFilter('to', v)),
        ),
      ],
    );
  }
}

class PaymentsScreen extends StatelessWidget {
  final FilterQuery query;

  const PaymentsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    return EntityListView<Payment, FilterQuery>(
      title: 'Касса',
      basePath: '/cash',
      notifier: context.read<ListNotifier<Payment>>(),
      query: query,
      permissions: _permissions(context, Section.cash),
      searchHint: 'Поиск по пациенту или врачу',
      emptyMessage: 'Платежи не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/cash/${e.id}',
      createPath: '/cash/new',
      editPath: (e) => '/cash/${e.id}/edit',
      itemTitle: (e) => 'Платёж ${formatMoney(e.amount)} — ${e.patientName}',
      isDeleted: (e) => e.isDeleted,
      columns: [
        TableColumnSpec<Payment>(
          label: 'Дата оплаты',
          sortField: 'paidAt',
          build: (e) => Text(
            e.paidAt == null ? '—' : formatDateTime(e.paidAt!.toLocal()),
          ),
        ),
        TableColumnSpec<Payment>(
          label: 'Пациент',
          build: (e) => TitleCell(title: e.patientName, deleted: e.isDeleted),
        ),
        TableColumnSpec<Payment>(
          label: 'Врач',
          build: (e) => CellText(e.doctorName),
        ),
        TableColumnSpec<Payment>(
          label: 'Приём',
          build: (e) => Text(
            e.appointmentStart == null
                ? '—'
                : formatDateTime(e.appointmentStart!.toLocal()),
          ),
        ),
        TableColumnSpec<Payment>(
          label: 'Сумма',
          sortField: 'amount',
          numeric: true,
          build: (e) => Text(formatMoney(e.amount)),
        ),
        TableColumnSpec<Payment>(
          label: 'Способ',
          sortField: 'method',
          build: (e) => Text(e.method.label),
        ),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Способ',
          value: s.query.filter('method'),
          options: [for (final m in PayMethod.values) (m.value, m.label)],
          width: 160,
          onChanged: (v) => s.apply((q) => q.withFilter('method', v)),
        ),
        DropdownFilter<String>(
          label: 'Врач',
          value: s.query.filter('doctor'),
          options: [for (final d in ref.doctors) (d.id, d.fullName)],
          width: 220,
          onChanged: (v) => s.apply((q) => q.withFilter('doctor', v)),
        ),
        DateFilterField(
          key: const ValueKey('pay-from'),
          label: 'С даты',
          value: s.query.filter('from'),
          onChanged: (v) => s.apply((q) => q.withFilter('from', v)),
        ),
        DateFilterField(
          key: const ValueKey('pay-to'),
          label: 'По дату',
          value: s.query.filter('to'),
          onChanged: (v) => s.apply((q) => q.withFilter('to', v)),
        ),
      ],
    );
  }
}

class UsersScreen extends StatelessWidget {
  final FilterQuery query;

  const UsersScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EntityListView<AppUser, FilterQuery>(
      title: 'Пользователи',
      basePath: '/admin/users',
      notifier: context.read<ListNotifier<AppUser>>(),
      query: query,
      permissions: _permissions(context, Section.users),
      searchHint: 'Поиск по имени или почте',
      emptyMessage: 'Пользователи не найдены.',
      idOf: (e) => e.id,
      itemPath: (e) => '/admin/users/${e.id}/edit',
      createPath: '/admin/users/new',
      editPath: (e) => '/admin/users/${e.id}/edit',
      itemTitle: (e) => 'Пользователь ${e.name}',
      isDeleted: (e) => false,
      columns: [
        TableColumnSpec<AppUser>(
          label: 'Имя',
          sortField: 'name',
          build: (e) => TitleCell(title: e.name, deleted: false),
        ),
        TableColumnSpec<AppUser>(
          label: 'Почта',
          sortField: 'email',
          build: (e) => CellText(e.email),
        ),
        TableColumnSpec<AppUser>(
          label: 'Роль',
          sortField: 'role',
          build: (e) => Text(e.role.label),
        ),
      ],
      filters: (s) => [
        DropdownFilter<String>(
          label: 'Роль',
          value: s.query.filter('role'),
          options: [for (final r in Role.values) (r.value, r.label)],
          width: 180,
          onChanged: (v) => s.apply((q) => q.withFilter('role', v)),
        ),
      ],
    );
  }
}
