import 'package:dental_clinic/app.dart';
import 'package:dental_clinic/core/router.dart';
import 'package:dental_clinic/models/filter_query.dart';
import 'package:dental_clinic/models/query_specs.dart';
import 'package:dental_clinic/models/service.dart';
import 'package:dental_clinic/repositories/clinic_repositories.dart';
import 'package:dental_clinic/screens/appointment_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/demo_env.dart';

const _admin = ('admin@clinic.test', 'Admin123!');
const _registrar = ('registrar@clinic.test', 'Registrar123!');
const _doctor = ('doctor@clinic.test', 'Doctor123!');

class Harness {
  final DemoEnv env;
  final GoRouter router;

  Harness(this.env, this.router);

  String get location => router.routeInformationProvider.value.uri.toString();
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  (String, String)? login,
  String location = '/',
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final env = await DemoEnv.create();
  addTearDown(env.auth.dispose);
  if (login != null) {
    await tester.runAsync(() => env.loginAs(login.$1, login.$2));
  }
  final router = createRouter(auth: env.auth, initialLocation: location);
  await tester.pumpWidget(
    AppProviders(
      dio: env.dio,
      auth: env.auth,
      child: ClinicApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return Harness(env, router);
}

void main() {
  testWidgets('вход: пустая форма показывает ошибки полей', (tester) async {
    await pumpApp(tester, location: '/login');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Введите почту'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
  });

  testWidgets('вход: неверный пароль показывает сообщение сервера', (
    tester,
  ) async {
    await pumpApp(tester, location: '/login');
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'admin@clinic.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-error')), findsOneWidget);
    expect(find.text('Неверная почта или пароль.'), findsOneWidget);
  });

  testWidgets('роль врача: после входа открывается «Мой приём» без админских разделов', (
    tester,
  ) async {
    final h = await pumpApp(tester, location: '/login');
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      _doctor.$1,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      _doctor.$2,
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(h.location, startsWith('/my-day'));
    expect(find.byKey(const ValueKey('nav-mySchedule')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-users')), findsNothing);
    expect(find.byKey(const ValueKey('nav-report')), findsNothing);
    expect(find.byKey(const ValueKey('nav-cash')), findsNothing);
  });

  testWidgets('прямая ссылка на закрытый раздел даёт страницу 403', (
    tester,
  ) async {
    await pumpApp(tester, login: _doctor, location: '/report');
    expect(find.text('403 — доступ запрещён'), findsOneWidget);
    expect(find.textContaining('Врач'), findsWidgets);
  });

  testWidgets('прямая ссылка без входа ведёт на вход и возвращает по адресу', (
    tester,
  ) async {
    final h = await pumpApp(tester, location: '/patients?search=Иванов');
    expect(h.location, startsWith('/login'));
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      _registrar.$1,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      _registrar.$2,
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(h.location, contains('/patients'));
    expect(h.location, contains('search='));
  });

  testWidgets('список пациентов: поиск попадает в адрес и фильтрует выдачу', (
    tester,
  ) async {
    final h = await pumpApp(tester, login: _admin, location: '/patients');
    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'Николаев',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(Uri.parse(h.location).queryParameters['search'], 'Николаев');
    expect(find.textContaining('Николаев'), findsWidgets);
    expect(find.textContaining('Петров Никита'), findsNothing);
  });

  testWidgets('кнопка «Добавить» есть у регистратора и скрыта у врача', (
    tester,
  ) async {
    await pumpApp(tester, login: _registrar, location: '/patients');
    expect(find.text('Добавить'), findsOneWidget);
  });

  testWidgets('врач видит пациентов только для чтения', (tester) async {
    await pumpApp(tester, login: _doctor, location: '/patients');
    expect(find.text('Добавить'), findsNothing);
    expect(find.byKey(const ValueKey('show-deleted')), findsNothing);
  });

  testWidgets('форма пациента: пустая отправка показывает ошибки полей', (
    tester,
  ) async {
    await pumpApp(tester, login: _registrar, location: '/patients/new');
    await tester.tap(find.byKey(const ValueKey('submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('Укажите ФИО'), findsOneWidget);
    expect(find.text('Укажите дату рождения'), findsOneWidget);
    expect(find.text('Укажите телефон'), findsOneWidget);
  });

  testWidgets('удаление пациента с приёмами показывает диалог конфликта', (
    tester,
  ) async {
    final h = await pumpApp(tester, login: _admin);
    final id = h.env.db.tables['patients']!.first['id'] as String;
    h.router.go('/patients/$id');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conflict-dialog')), findsOneWidget);
    expect(find.textContaining('на неё ссылаются'), findsOneWidget);
  });

  testWidgets('предпросмотр приёма показывает итог со скидкой и конфликт', (
    tester,
  ) async {
    final env = await DemoEnv.create();
    addTearDown(env.auth.dispose);
    await tester.runAsync(() => env.loginAs(_registrar.$1, _registrar.$2));
    final repository = AppointmentRepository(env.dio);
    final busy = (await tester.runAsync(
      () => repository.find(
        FilterQuery(spec: appointmentsSpec, filters: {'status': 'planned'}),
      ),
    ))!.items.first;
    final doctor = busy.doctorId;
    final start = busy.startAt;
    final text =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    const services = [
      Service(
        id: 'a',
        name: 'Осмотр',
        categoryId: 'c',
        price: 1000,
        durationMin: 30,
      ),
      Service(
        id: 'b',
        name: 'Чистка',
        categoryId: 'c',
        price: 3000,
        durationMin: 45,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppointmentPreview(
              repository: repository,
              excludeId: null,
              patientId: null,
              doctorId: doctor,
              services: services,
              startText: text,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 ч 15 мин'), findsOneWidget);
    expect(find.textContaining('4 000'), findsWidgets);
    expect(find.byKey(const ValueKey('preview-conflict')), findsOneWidget);
  });
}
