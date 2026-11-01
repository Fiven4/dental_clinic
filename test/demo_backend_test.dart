import 'package:dental_clinic/core/api_exceptions.dart';
import 'package:dental_clinic/demo/demo_db.dart';
import 'package:dental_clinic/models/appointment.dart';
import 'package:dental_clinic/models/filter_query.dart';
import 'package:dental_clinic/models/payment.dart';
import 'package:dental_clinic/models/query_specs.dart';
import 'package:dental_clinic/repositories/clinic_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_env.dart';

void main() {
  test('данные демо-сервера соответствуют обычному наполнению', () {
    final db = buildDemoDb();
    expect(db.tables['patients']!.length, 40);
    expect(db.tables['appointments']!.length, 463);
    expect(db.tables['doctors']!.length, 6);
    expect(db.tables['payments']!.isNotEmpty, isTrue);
  });

  test('врач видит только свои приёмы и не видит оплат', () async {
    final env = await DemoEnv.create();
    await env.loginAs('doctor@clinic.test', 'Doctor123!');
    final repo = AppointmentRepository(env.dio);
    final page = await repo.find(FilterQuery(spec: appointmentsSpec, size: 50));
    expect(page.items, isNotEmpty);
    final doctorName = page.items.first.doctorName;
    expect(page.items.every((a) => a.doctorName == doctorName), isTrue);
    expect(
      () => PaymentRepository(env.dio).find(FilterQuery(spec: paymentsSpec)),
      returnsNormally,
    );
    final payments = await PaymentRepository(
      env.dio,
    ).find(FilterQuery(spec: paymentsSpec));
    expect(payments.total, 0);
  });

  test('поиск, фильтры и сортировка выполняются на сервере', () async {
    final env = await DemoEnv.create();
    await env.loginAs('registrar@clinic.test', 'Registrar123!');
    final repo = AppointmentRepository(env.dio);
    final all = await repo.find(FilterQuery(spec: appointmentsSpec));
    final done = await repo.find(
      FilterQuery(spec: appointmentsSpec, filters: {'status': 'done'}),
    );
    expect(done.total, lessThan(all.total));
    expect(done.items.every((a) => a.status == AppointmentStatus.done), isTrue);
    final sorted = await repo.find(
      FilterQuery(
        spec: appointmentsSpec,
        sortField: 'total',
        sortAscending: false,
        size: 25,
      ),
    );
    final totals = [for (final a in sorted.items) a.total];
    expect([...totals]..sort((a, b) => b.compareTo(a)), totals);
    final patients = PatientRepository(env.dio);
    final found = await patients.find(
      FilterQuery(spec: patientsSpec, search: 'Николаев'),
    );
    expect(found.items.every((p) => p.fullName.contains('Николаев')), isTrue);
  });

  test('пересечение приёмов врача возвращает конфликт 409', () async {
    final env = await DemoEnv.create();
    await env.loginAs('registrar@clinic.test', 'Registrar123!');
    final repo = AppointmentRepository(env.dio);
    final existing = (await repo.find(
      FilterQuery(spec: appointmentsSpec, filters: {'status': 'planned'}),
    )).items.first;
    final clash = Appointment(
      id: '',
      patientId: env.db.tables['patients']!.last['id'] as String,
      doctorId: existing.doctorId,
      serviceIds: existing.serviceIds,
      startAt: existing.startAt,
      endAt: existing.endAt,
      status: AppointmentStatus.planned,
    );
    await expectLater(
      repo.create(clash),
      throwsA(isA<ConflictException>().having((e) => e.kind, 'kind', 'doctor')),
    );
  });

  test('сумма и скидка приёма считаются на сервере', () async {
    final env = await DemoEnv.create();
    await env.loginAs('registrar@clinic.test', 'Registrar123!');
    final repo = AppointmentRepository(env.dio);
    final services = env.db.tables['services']!;
    final start = DateTime(2030, 5, 6, 10);
    final created = await repo.create(
      Appointment(
        id: '',
        patientId: env.db.tables['patients']!.first['id'] as String,
        doctorId: env.db.tables['doctors']!.first['id'] as String,
        serviceIds: [services[0]['id'] as String, services[1]['id'] as String],
        startAt: start,
        endAt: start.add(const Duration(minutes: 60)),
        status: AppointmentStatus.planned,
      ),
    );
    final price = (services[0]['price'] as num) + (services[1]['price'] as num);
    final expected = price * (100 - created.discountPercent) / 100;
    expect(created.total, expected.roundToDouble());
  });

  test('удаление записи со связями отклоняется с 409', () async {
    final env = await DemoEnv.create();
    await env.loginAs('admin@clinic.test', 'Admin123!');
    final repo = PatientRepository(env.dio);
    final withVisits = (await repo.findAll()).first;
    await expectLater(
      repo.softDelete(withVisits.id),
      throwsA(isA<ConflictException>()),
    );
    await expectLater(
      repo.hardDelete(withVisits.id),
      throwsA(isA<ConflictException>()),
    );
  });

  test(
    'ошибки полей приходят как 400 и превращаются в ValidationException',
    () async {
      final env = await DemoEnv.create();
      await env.loginAs('admin@clinic.test', 'Admin123!');
      final cards = PatientCardRepository(env.dio);
      final patient = (await PatientRepository(env.dio).findAll()).first;
      final card = (await cards.find(
        FilterQuery(spec: cardsSpec, size: 1),
      )).items.first;
      await expectLater(
        cards.create(card.copyForCreate(patientId: patient.id, number: 'bad')),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors.keys,
            'fields',
            contains('number'),
          ),
        ),
      );
    },
  );

  test('платёж не может превышать остаток по приёму', () async {
    final env = await DemoEnv.create();
    await env.loginAs('registrar@clinic.test', 'Registrar123!');
    final appointments = AppointmentRepository(env.dio);
    final planned = (await appointments.find(
      FilterQuery(
        spec: appointmentsSpec,
        filters: {'status': 'planned'},
        size: 50,
      ),
    )).items.firstWhere((a) => a.total > 0 && a.paid == 0);
    await expectLater(
      PaymentRepository(env.dio).create(
        Payment(
          id: '',
          appointmentId: planned.id,
          amount: planned.total + 1,
          method: PayMethod.cash,
          paidAt: DateTime.now(),
        ),
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  test('срок жизни токена истекает, обновление выдаёт новый токен', () async {
    final env = await DemoEnv.create();
    await env.loginAs('admin@clinic.test', 'Admin123!');
    final first = env.auth.accessToken;
    expect(await env.auth.refreshTokens(), isTrue);
    expect(env.auth.accessToken, isNotNull);
    expect(env.auth.accessToken, isNot(equals('')));
    expect(first, isNotNull);
  });

  test('неверный пароль даёт UnauthorizedException', () async {
    final env = await DemoEnv.create();
    await expectLater(
      env.auth.login('admin@clinic.test', 'wrong'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('демо-ошибка сериализуется в формат PocketBase', () {
    const e = DemoError(409, 'msg', {'kind': 'doctor'});
    expect(e.toJson(), {
      'status': 409,
      'message': 'msg',
      'data': {'kind': 'doctor'},
    });
  });
}
