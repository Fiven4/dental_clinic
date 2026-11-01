import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/filter_query.dart';
import '../models/query_specs.dart';
import '../screens/app_shell.dart';
import '../screens/appointment_form_screen.dart';
import '../screens/detail_screens.dart';
import '../screens/forbidden_screen.dart';
import '../screens/form_screens.dart';
import '../screens/list_screens.dart';
import '../screens/login_screen.dart';
import '../screens/my_day_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/register_screen.dart';
import '../screens/report_screen.dart';
import '../screens/schedule_screen.dart';
import '../state/auth_notifier.dart';
import '../state/clinic_scope.dart';
import 'access.dart';
import 'format.dart';

String? _guard(
  AuthNotifier auth,
  Section section, {
  bool Function(AuthNotifier a)? extra,
}) {
  if (!canAccess(auth.role, section)) return '/forbidden';
  if (extra != null && !extra(auth)) return '/forbidden';
  return null;
}

List<GoRoute> _entityRoutes({
  required AuthNotifier auth,
  required Section section,
  required Widget Function(FilterQuery query) list,
  required Widget Function(GoRouterState state, String? id) form,
  required Widget Function(String id)? detail,
  required QuerySpec spec,
}) {
  final base = section.path;
  return [
    GoRoute(
      path: base,
      redirect: (c, s) => _guard(auth, section),
      builder: (c, s) =>
          list(FilterQuery.fromParams(spec, s.uri.queryParameters)),
    ),
    GoRoute(
      path: '$base/new',
      redirect: (c, s) => _guard(
        auth,
        section,
        extra: (a) => permissionsFor(a.role, section).create,
      ),
      builder: (c, s) => form(s, null),
    ),
    if (detail != null)
      GoRoute(
        path: '$base/:id',
        redirect: (c, s) => _guard(auth, section),
        builder: (c, s) => detail(s.pathParameters['id']!),
      ),
    GoRoute(
      path: '$base/:id/edit',
      redirect: (c, s) => _guard(
        auth,
        section,
        extra: (a) => permissionsFor(a.role, section).edit,
      ),
      builder: (c, s) => form(s, s.pathParameters['id']),
    ),
  ];
}

DateTime _dateParam(GoRouterState s, String key, DateTime fallback) =>
    parseInputDate(s.uri.queryParameters[key] ?? '') ?? fallback;

GoRouter createRouter({required AuthNotifier auth, String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final path = state.uri.path;
      final isLogin = path == '/login' || path == '/register';
      if (!loggedIn && !isLogin) {
        final from = Uri.encodeComponent(state.uri.toString());
        return path == '/' ? '/login' : '/login?from=$from';
      }
      if (loggedIn && isLogin) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') ? from : homeFor(auth.role);
      }
      if (loggedIn && path == '/') return homeFor(auth.role);
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/forbidden', builder: (c, s) => const ForbiddenScreen()),
      GoRoute(path: '/', builder: (c, s) => const SizedBox.shrink()),
      ShellRoute(
        builder: (context, state, child) => ClinicScope(
          key: ValueKey(auth.user?.id),
          child: AppShell(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(
            path: Section.mySchedule.path,
            redirect: (c, s) => _guard(auth, Section.mySchedule),
            builder: (c, s) =>
                MyDayScreen(date: _dateParam(s, 'date', DateTime.now())),
          ),
          GoRoute(
            path: Section.schedule.path,
            redirect: (c, s) => _guard(auth, Section.schedule),
            builder: (c, s) => ScheduleScreen(
              date: _dateParam(s, 'date', DateTime.now()),
              doctorId: s.uri.queryParameters['doctor'],
            ),
          ),
          GoRoute(
            path: Section.report.path,
            redirect: (c, s) => _guard(auth, Section.report),
            builder: (c, s) {
              final now = DateTime.now();
              final to = _dateParam(
                s,
                'to',
                DateTime(now.year, now.month, now.day),
              );
              final from = _dateParam(s, 'from', DateTime(now.year, now.month));
              return ReportScreen(from: from.isAfter(to) ? to : from, to: to);
            },
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.appointments,
            spec: appointmentsSpec,
            list: (q) => AppointmentsScreen(query: q),
            form: (s, id) => AppointmentFormScreen(
              id: id,
              patientId: s.uri.queryParameters['patient'],
              doctorId: s.uri.queryParameters['doctor'],
              start: s.uri.queryParameters['start'],
            ),
            detail: (id) => AppointmentDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.patients,
            spec: patientsSpec,
            list: (q) => PatientsScreen(query: q),
            form: (s, id) => PatientFormScreen(id: id),
            detail: (id) => PatientDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.cards,
            spec: cardsSpec,
            list: (q) => CardsScreen(query: q),
            form: (s, id) => CardFormScreen(id: id),
            detail: (id) => CardDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.doctors,
            spec: doctorsSpec,
            list: (q) => DoctorsScreen(query: q),
            form: (s, id) => DoctorFormScreen(id: id),
            detail: (id) => DoctorDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.services,
            spec: servicesSpec,
            list: (q) => ServicesScreen(query: q),
            form: (s, id) => ServiceFormScreen(id: id),
            detail: (id) => ServiceDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.categories,
            spec: categoriesSpec,
            list: (q) => CategoriesScreen(query: q),
            form: (s, id) => CategoryFormScreen(id: id),
            detail: (id) => CategoryDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.specializations,
            spec: specializationsSpec,
            list: (q) => SpecializationsScreen(query: q),
            form: (s, id) => SpecializationFormScreen(id: id),
            detail: (id) => SpecializationDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.cabinets,
            spec: cabinetsSpec,
            list: (q) => CabinetsScreen(query: q),
            form: (s, id) => CabinetFormScreen(id: id),
            detail: (id) => CabinetDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.cash,
            spec: paymentsSpec,
            list: (q) => PaymentsScreen(query: q),
            form: (s, id) => PaymentFormScreen(
              id: id,
              appointmentId: s.uri.queryParameters['appointment'],
            ),
            detail: (id) => PaymentDetailScreen(id: id),
          ),
          ..._entityRoutes(
            auth: auth,
            section: Section.users,
            spec: usersSpec,
            list: (q) => UsersScreen(query: q),
            form: (s, id) => UserFormScreen(id: id),
            detail: null,
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}
