import '../models/role.dart';
import '../widgets/list_permissions.dart';

enum Section {
  mySchedule('/my-day', 'Мой приём'),
  schedule('/schedule', 'Расписание'),
  appointments('/appointments', 'Приёмы'),
  patients('/patients', 'Пациенты'),
  cards('/cards', 'Карты'),
  doctors('/doctors', 'Врачи'),
  services('/services', 'Услуги'),
  categories('/categories', 'Категории услуг'),
  specializations('/specializations', 'Специализации'),
  cabinets('/cabinets', 'Кабинеты'),
  cash('/cash', 'Касса'),
  report('/report', 'Отчёт'),
  users('/admin/users', 'Пользователи');

  final String path;
  final String label;

  const Section(this.path, this.label);
}

const _full = ListPermissions.all;
const _staff = ListPermissions(
  create: true,
  edit: true,
  delete: true,
  restore: true,
);

const Map<Role, Map<Section, ListPermissions>> _matrix = {
  Role.admin: {
    Section.schedule: ListPermissions.readOnly,
    Section.appointments: _full,
    Section.patients: _full,
    Section.cards: _full,
    Section.doctors: _full,
    Section.services: _full,
    Section.categories: _full,
    Section.specializations: _full,
    Section.cabinets: _full,
    Section.report: ListPermissions.readOnly,
    Section.users: ListPermissions(create: true, edit: true, hardDelete: true),
  },
  Role.registrar: {
    Section.schedule: ListPermissions.readOnly,
    Section.appointments: _staff,
    Section.patients: _staff,
    Section.cards: _staff,
    Section.doctors: ListPermissions.readOnly,
    Section.services: ListPermissions.readOnly,
    Section.cash: _staff,
  },
  Role.doctor: {
    Section.mySchedule: ListPermissions.readOnly,
    Section.appointments: ListPermissions.readOnly,
    Section.patients: ListPermissions.readOnly,
    Section.cards: ListPermissions.readOnly,
    Section.services: ListPermissions.readOnly,
  },
};

bool canAccess(Role? role, Section section) =>
    role != null && (_matrix[role]?.containsKey(section) ?? false);

ListPermissions permissionsFor(Role? role, Section section) =>
    (role == null ? null : _matrix[role]?[section]) ?? ListPermissions.readOnly;

List<Section> sectionsFor(Role? role) => [
  for (final s in Section.values)
    if (canAccess(role, s)) s,
];

Section? sectionOfPath(String path) {
  for (final s in Section.values) {
    if (path == s.path || path.startsWith('${s.path}/')) return s;
  }
  return null;
}

String homeFor(Role? role) => switch (role) {
  Role.doctor => Section.mySchedule.path,
  Role.admin => Section.report.path,
  Role.registrar => Section.schedule.path,
  null => '/login',
};
