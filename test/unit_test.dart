import 'dart:convert';

import 'package:dental_clinic/core/access.dart';
import 'package:dental_clinic/core/api_exceptions.dart';
import 'package:dental_clinic/core/format.dart';
import 'package:dental_clinic/core/report.dart';
import 'package:dental_clinic/core/validators.dart';
import 'package:dental_clinic/demo/pb_filter.dart';
import 'package:dental_clinic/models/appointment.dart';
import 'package:dental_clinic/models/filter_query.dart';
import 'package:dental_clinic/models/payment.dart';
import 'package:dental_clinic/models/query_specs.dart';
import 'package:dental_clinic/models/role.dart';
import 'package:dental_clinic/models/service.dart';
import 'package:dental_clinic/repositories/clinic_repositories.dart';
import 'package:dental_clinic/screens/appointment_form_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilterQuery', () {
    test('разбирает параметры адреса и собирает их обратно', () {
      final query = FilterQuery.fromParams(appointmentsSpec, {
        'search': ' Иванов ',
        'status': 'done',
        'doctor': 'abc',
        'unknown': 'x',
        'sort': 'total,desc',
        'page': '3',
        'size': '25',
      });
      expect(query.search, 'Иванов');
      expect(query.filters, {'status': 'done', 'doctor': 'abc'});
      expect(query.sortField, 'total');
      expect(query.sortAscending, isFalse);
      expect(query.page, 3);
      expect(query.size, 25);
      expect(FilterQuery.fromParams(appointmentsSpec, query.toParams()), query);
    });

    test('неизвестное поле сортировки и неверная страница заменяются', () {
      final query = FilterQuery.fromParams(patientsSpec, {
        'sort': 'password,desc',
        'page': '-4',
        'size': '999',
      });
      expect(query.sortField, patientsSpec.defaultSort);
      expect(query.page, 1);
      expect(query.size, 10);
    });

    test('смена фильтра сбрасывает страницу', () {
      final query = FilterQuery(spec: patientsSpec, page: 4);
      expect(query.withFilter('hasCard', 'yes').page, 1);
      expect(query.withFilter('hasCard', null).filters, isEmpty);
    });
  });

  group('PbRepository', () {
    final repo = PatientRepository(Dio());

    test('строит фильтр поиска и экранирует кавычки', () {
      final filter = repo.buildFilter(
        FilterQuery(spec: patientsSpec, search: 'О"Брайен'),
      );
      expect(filter, contains(r'fullName ~ "О\"Брайен"'));
      expect(filter, startsWith('deletedAt = ""'));
    });

    test('показ удалённых убирает условие deletedAt', () {
      final filter = repo.buildFilter(
        FilterQuery(spec: patientsSpec, includeDeleted: true),
      );
      expect(filter, isEmpty);
    });

    test('сортировка по убыванию получает префикс и запасной ключ', () {
      expect(
        repo.buildSort(
          FilterQuery(
            spec: patientsSpec,
            sortField: 'birthDate',
            sortAscending: false,
          ),
        ),
        '-birthDate,id',
      );
    });

    test('неизвестное значение фильтра по дате игнорируется', () {
      final appointments = AppointmentRepository(Dio());
      final filter = appointments.buildFilter(
        FilterQuery(
          spec: appointmentsSpec,
          filters: {'from': 'не дата', 'status': 'done'},
        ),
      );
      expect(filter, contains('status = "done"'));
      expect(filter, isNot(contains('startAt >=')));
    });
  });

  group('Ошибки API', () {
    test('400 с полями превращается в ValidationException', () {
      final e = mapHttpError(400, {
        'message': 'Failed',
        'data': {
          'email': {'code': 'validation_not_unique', 'message': 'x'},
        },
      });
      expect(e, isA<ValidationException>());
      expect((e as ValidationException).errors['email'], contains('использ'));
    });

    test('409 сохраняет вид конфликта', () {
      final e = mapHttpError(409, {
        'message': 'Врач занят',
        'data': {'kind': 'doctor'},
      });
      expect(e, isA<ConflictException>());
      expect((e as ConflictException).kind, 'doctor');
    });

    test('401, 403 и 404 имеют собственные типы', () {
      expect(mapHttpError(401, null), isA<UnauthorizedException>());
      expect(mapHttpError(403, null), isA<ForbiddenException>());
      expect(mapHttpError(404, null), isA<NotFoundException>());
      expect(mapHttpError(500, null), isA<ServerException>());
    });

    test('таймаут и обрыв соединения дают NetworkException', () {
      final options = RequestOptions(path: '/x');
      expect(
        mapDioError(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isA<NetworkException>(),
      );
      expect(
        mapDioError(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<NetworkException>(),
      );
    });
  });

  group('Права доступа', () {
    test('у каждой роли есть собственный раздел', () {
      expect(canAccess(Role.admin, Section.users), isTrue);
      expect(canAccess(Role.admin, Section.cash), isFalse);
      expect(canAccess(Role.registrar, Section.cash), isTrue);
      expect(canAccess(Role.registrar, Section.users), isFalse);
      expect(canAccess(Role.doctor, Section.mySchedule), isTrue);
      expect(canAccess(Role.doctor, Section.report), isFalse);
    });

    test('права на действия не наследуются от роли к роли', () {
      expect(permissionsFor(Role.admin, Section.patients).hardDelete, isTrue);
      expect(
        permissionsFor(Role.registrar, Section.patients).hardDelete,
        isFalse,
      );
      expect(permissionsFor(Role.doctor, Section.patients).create, isFalse);
      expect(permissionsFor(null, Section.patients).edit, isFalse);
    });

    test('домашняя страница зависит от роли', () {
      expect(homeFor(Role.doctor), '/my-day');
      expect(homeFor(Role.admin), '/report');
      expect(homeFor(Role.registrar), '/schedule');
    });
  });

  group('Расчёт приёма', () {
    final services = [
      const Service(
        id: 'a',
        name: 'Осмотр',
        categoryId: 'c',
        price: 1000,
        durationMin: 30,
      ),
      const Service(
        id: 'b',
        name: 'Чистка',
        categoryId: 'c',
        price: 3000,
        durationMin: 45,
      ),
    ];

    test('скидка зависит от числа проведённых приёмов', () {
      expect(loyaltyDiscount(0), 0);
      expect(loyaltyDiscount(4), 0);
      expect(loyaltyDiscount(5), 10);
      expect(loyaltyDiscount(10), 15);
    });

    test('стоимость и длительность суммируются по услугам', () {
      final cost = calculateCost(services, 5);
      expect(cost.base, 4000);
      expect(cost.minutes, 75);
      expect(cost.discountPercent, 10);
      expect(cost.total, 3600);
    });

    test('пересечение интервалов не считает касание границ конфликтом', () {
      final a = DateTime(2026, 1, 1, 10);
      final b = DateTime(2026, 1, 1, 11);
      expect(overlaps(a, b, b, b.add(const Duration(hours: 1))), isFalse);
      expect(
        overlaps(a, b, a.add(const Duration(minutes: 30)), b),
        isTrue,
      );
    });
  });

  group('Отчёт', () {
    test('агрегирует выручку по врачам, категориям и способам оплаты', () {
      final service = const Service(
        id: 's1',
        name: 'Осмотр',
        categoryId: 'c1',
        price: 1000,
        durationMin: 30,
      );
      Appointment make(String id, AppointmentStatus status, double total) =>
          Appointment(
            id: id,
            patientId: 'p',
            doctorId: 'd',
            doctorName: 'Иванов',
            serviceIds: const ['s1'],
            startAt: DateTime(2026, 1, 1, 10),
            endAt: DateTime(2026, 1, 1, 11),
            status: status,
            total: total,
          );
      final report = buildReport(
        appointments: [
          make('1', AppointmentStatus.done, 900),
          make('2', AppointmentStatus.done, 1100),
          make('3', AppointmentStatus.cancelled, 500),
          make('4', AppointmentStatus.planned, 700),
        ],
        payments: [
          Payment(
            id: 'x',
            appointmentId: '1',
            amount: 900,
            method: PayMethod.card,
            paidAt: DateTime(2026, 1, 1, 12),
          ),
          Payment(
            id: 'y',
            appointmentId: '2',
            amount: 500,
            method: PayMethod.cash,
            paidAt: DateTime(2026, 1, 2, 12),
          ),
        ],
        services: {'s1': service},
        categoryNames: {'c1': 'Диагностика'},
      );
      expect(report.done, 2);
      expect(report.cancelled, 1);
      expect(report.billed, 2000);
      expect(report.received, 1400);
      expect(report.debt, 600);
      expect(report.averageCheck, 1000);
      expect(report.byDoctor['Иванов'], 2000);
      expect(report.byCategory['Диагностика'], 2000);
      expect(report.byMethod[PayMethod.card], 900);
      expect(report.byDay.length, 2);
      expect(report.cancelRate, 25);
    });
  });

  group('Проверки ввода и формат', () {
    test('телефон, почта и номер карты проверяются по шаблону', () {
      expect(V.phone()('+7 900 000-00-00'), isNull);
      expect(V.phone()('abc'), isNotNull);
      expect(V.email()('a@b.ru'), isNull);
      expect(V.email()('a@b'), isNotNull);
      expect(V.cardNumber()('K-000123'), isNull);
      expect(V.cardNumber()('K-123'), isNotNull);
    });

    test('дата и время проверяются на существование', () {
      expect(V.dateTime()('2026-02-30 10:00'), isNotNull);
      expect(V.dateTime()('2026-02-20 24:10'), isNotNull);
      expect(V.dateTime()('2026-02-20 10:15'), isNull);
      expect(V.money()('0'), isNotNull);
      expect(V.money()('1500,50'), isNull);
    });

    test('деньги и минуты форматируются по-русски', () {
      expect(formatMoney(1234567), '1 234 567 ₽');
      expect(formatMinutes(90), '1 ч 30 мин');
      expect(formatMinutes(45), '45 мин');
      expect(parseInputDateTime('2026-11-02 09:05'), DateTime(2026, 11, 2, 9, 5));
      expect(parseInputDateTime('2026-13-02 09:05'), isNull);
    });
  });

  group('Фильтры сервера', () {
    final rows = [
      {'id': '1', 'name': 'Анна', 'age': 30, 'tag': 'a'},
      {'id': '2', 'name': 'Борис', 'age': 41, 'tag': ''},
      {'id': '3', 'name': 'анатолий', 'age': 25, 'tag': 'b'},
    ];

    List<String> run(String filter) {
      final p = compileFilter(
        filter,
        (r, path) => [r[path]],
      );
      return [for (final r in rows) if (p(r)) r['id'] as String];
    }

    test('сравнения, регистронезависимый поиск и скобки', () {
      expect(run('age >= 30'), ['1', '2']);
      expect(run('name ~ "АН"'), ['1', '3']);
      expect(run('(age < 30 || age > 40) && tag != ""'), ['3']);
      expect(run(''), ['1', '2', '3']);
    });

    test('некорректный фильтр вызывает исключение', () {
      expect(() => run('age >>'), throwsA(isA<FilterSyntaxException>()));
      expect(() => run('name ~ "x'), throwsA(isA<FilterSyntaxException>()));
    });
  });

  test('разбор приёма берёт оплаты из вложенных данных', () {
    final a = Appointment.fromJson(
      jsonDecode('''
{
 "id":"a1","patient":"p1","doctor":"d1","services":["s1"],
 "startAt":"2026-11-02 07:00:00.000Z","endAt":"2026-11-02 08:00:00.000Z",
 "status":"done","total":3000,"discountPercent":10,
 "expand":{
  "patient":{"fullName":"Петров"},
  "doctor":{"fullName":"Сидоров","expand":{"cabinet":{"number":"101"}}},
  "services":[{"name":"Осмотр"}],
  "payments_via_appointment":[
    {"amount":1000,"deletedAt":""},
    {"amount":500,"deletedAt":""},
    {"amount":900,"deletedAt":"2026-01-01 00:00:00.000Z"}
  ]
 }
}''')
          as Map<String, dynamic>,
    );
    expect(a.patientName, 'Петров');
    expect(a.cabinetNumber, '101');
    expect(a.paid, 1500);
    expect(a.debt, 1500);
    expect(a.durationMin, 60);
  });
}
