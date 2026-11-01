import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/cabinet.dart';
import '../models/doctor.dart';
import '../models/json_utils.dart';
import '../models/patient.dart';
import '../models/patient_card.dart';
import '../models/payment.dart';
import '../models/service.dart';
import '../models/service_category.dart';
import '../models/specialization.dart';
import 'pb_filters.dart';
import 'pb_repository.dart';

class SpecializationRepository extends PbRepository<Specialization> {
  SpecializationRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'specializations',
        fromJson: Specialization.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        searchFields: const ['name', 'description'],
        listSort: 'name',
      );
}

class CabinetRepository extends PbRepository<Cabinet> {
  CabinetRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'cabinets',
        fromJson: Cabinet.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        searchFields: const ['number', 'equipment'],
        rules: {'floor': intEquals('floor')},
        listSort: 'number',
      );
}

class ServiceCategoryRepository extends PbRepository<ServiceCategory> {
  ServiceCategoryRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'service_categories',
        fromJson: ServiceCategory.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        searchFields: const ['name', 'description'],
        listSort: 'name',
      );
}

class ServiceRepository extends PbRepository<Service> {
  ServiceRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'services',
        fromJson: Service.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        expand: 'category',
        searchFields: const ['name', 'description', 'category.name'],
        sortMap: const {'category': 'category.name'},
        rules: {
          'category': equals('category'),
          'priceMin': numberAtLeast('price'),
          'priceMax': numberAtMost('price'),
          'durationMax': numberAtMost('durationMin'),
        },
        listSort: 'name',
      );
}

class DoctorRepository extends PbRepository<Doctor> {
  DoctorRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'doctors',
        fromJson: Doctor.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        expand: 'specialization,cabinet',
        searchFields: const ['fullName', 'phone', 'specialization.name'],
        sortMap: const {
          'specialization': 'specialization.name',
          'cabinet': 'cabinet.number',
        },
        rules: {
          'specialization': equals('specialization'),
          'cabinet': equals('cabinet'),
          'experienceMin': numberAtLeast('experienceYears'),
        },
        listSort: 'fullName',
      );

  Future<Doctor?> findByUser(String userId) async {
    final response = await guard(
      () => dio.get<dynamic>(
        '/api/collections/doctors/records',
        queryParameters: {
          'perPage': 1,
          'filter': 'user = ${pbQuote(userId)} && deletedAt = ""',
          'expand': 'specialization,cabinet',
        },
      ),
    );
    final items = mapListOf(mapOf(response.data)['items']);
    return items.isEmpty ? null : Doctor.fromJson(items.first);
  }
}

class PatientRepository extends PbRepository<Patient> {
  PatientRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'patients',
        fromJson: Patient.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        searchFields: const ['fullName', 'phone', 'email'],
        rules: {
          'ageGroup': _ageGroup,
          'hasCard': _hasCard,
          'hasEmail': (v) => v == 'yes' ? 'email != ""' : 'email = ""',
        },
        listSort: 'fullName',
      );

  static String? _ageGroup(String value) {
    final now = DateTime.now();
    String born(int years) =>
        pbQuote(pbDate(DateTime(now.year - years, now.month, now.day)));
    return switch (value) {
      'child' => 'birthDate > ${born(18)}',
      'adult' => 'birthDate <= ${born(18)} && birthDate > ${born(60)}',
      'senior' => 'birthDate <= ${born(60)}',
      _ => null,
    };
  }

  static String? _hasCard(String value) => value == 'yes'
      ? 'patient_cards_via_patient.id ?!= ""'
      : 'patient_cards_via_patient.id = ""';
}

class PatientCardRepository extends PbRepository<PatientCard> {
  PatientCardRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'patient_cards',
        fromJson: PatientCard.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        expand: 'patient',
        searchFields: const ['number', 'patient.fullName', 'allergies'],
        sortMap: const {'patient': 'patient.fullName'},
        rules: {
          'patient': equals('patient'),
          'hasAllergies': (v) =>
              v == 'yes' ? 'allergies != ""' : 'allergies = ""',
          'openedFrom': dayFrom('openedOn'),
          'openedTo': dayTo('openedOn'),
        },
        listSort: 'number',
      );
}

class AppointmentRepository extends PbRepository<Appointment> {
  AppointmentRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'appointments',
        fromJson: Appointment.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        expand: _expand,
        searchFields: const [
          'patient.fullName',
          'doctor.fullName',
          'complaints',
          'diagnosis',
        ],
        sortMap: const {
          'patient': 'patient.fullName',
          'doctor': 'doctor.fullName',
        },
        rules: {
          'status': equals('status'),
          'doctor': equals('doctor'),
          'patient': equals('patient'),
          'category': anyOf('services.category'),
          'from': dayFrom('startAt'),
          'to': dayTo('startAt'),
        },
        listSort: '-startAt',
      );

  static const _expand =
      'patient,doctor.cabinet,services,payments_via_appointment';

  Future<List<Appointment>> forDoctorOnDay(
    String doctorId,
    DateTime day,
  ) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    final response = await guard(
      () => dio.get<dynamic>(
        '/api/collections/appointments/records',
        queryParameters: {
          'page': 1,
          'perPage': 200,
          'sort': 'startAt',
          'filter':
              'deletedAt = "" && doctor = ${pbQuote(doctorId)} && '
              'startAt >= ${pbQuote(pbDate(from))} && '
              'startAt < ${pbQuote(pbDate(to))}',
          'expand': _expand,
        },
      ),
    );
    return [
      for (final json in mapListOf(mapOf(response.data)['items']))
        Appointment.fromJson(json),
    ];
  }

  Future<List<Appointment>> inRange(
    DateTime from,
    DateTime to, {
    String filter = '',
  }) async {
    final result = <Appointment>[];
    var page = 1;
    while (true) {
      final response = await guard(
        () => dio.get<dynamic>(
          '/api/collections/appointments/records',
          queryParameters: {
            'page': page,
            'perPage': 200,
            'sort': 'startAt',
            'filter':
                'deletedAt = "" && '
                'startAt >= ${pbQuote(pbDate(from))} && '
                'startAt < ${pbQuote(pbDate(to))}'
                '${filter.isEmpty ? '' : ' && $filter'}',
            'expand': _expand,
          },
        ),
      );
      final data = mapOf(response.data);
      result.addAll([
        for (final json in mapListOf(data['items'])) Appointment.fromJson(json),
      ]);
      if (page >= intOf(data['totalPages'], 1)) break;
      page++;
    }
    return result;
  }

  Future<int> doneCount(String patientId, {String? excludeId}) async {
    final response = await guard(
      () => dio.get<dynamic>(
        '/api/collections/appointments/records',
        queryParameters: {
          'page': 1,
          'perPage': 1,
          'filter':
              'deletedAt = "" && status = "done" && '
              'patient = ${pbQuote(patientId)}'
              '${excludeId == null ? '' : ' && id != ${pbQuote(excludeId)}'}',
        },
      ),
    );
    return intOf(mapOf(response.data)['totalItems']);
  }

  Future<Appointment> updateClinical(
    String id, {
    required AppointmentStatus status,
    required String diagnosis,
  }) async {
    await patch(id, {'status': status.value, 'diagnosis': diagnosis});
    final fresh = await findById(id);
    if (fresh == null) throw const NotFoundException();
    return fresh;
  }
}

class PaymentRepository extends PbRepository<Payment> {
  PaymentRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'payments',
        fromJson: Payment.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        expand: 'appointment.patient,appointment.doctor',
        searchFields: const [
          'appointment.patient.fullName',
          'appointment.doctor.fullName',
        ],
        sortMap: const {},
        rules: {
          'method': equals('method'),
          'doctor': equals('appointment.doctor'),
          'appointment': equals('appointment'),
          'from': dayFrom('paidAt'),
          'to': dayTo('paidAt'),
        },
        listSort: '-paidAt',
      );

  Future<List<Payment>> inRange(DateTime from, DateTime to) async {
    final result = <Payment>[];
    var page = 1;
    while (true) {
      final response = await guard(
        () => dio.get<dynamic>(
          '/api/collections/payments/records',
          queryParameters: {
            'page': page,
            'perPage': 200,
            'sort': 'paidAt',
            'filter':
                'deletedAt = "" && '
                'paidAt >= ${pbQuote(pbDate(from))} && '
                'paidAt < ${pbQuote(pbDate(to))}',
            'expand': 'appointment.patient,appointment.doctor',
          },
        ),
      );
      final data = mapOf(response.data);
      result.addAll([
        for (final json in mapListOf(data['items'])) Payment.fromJson(json),
      ]);
      if (page >= intOf(data['totalPages'], 1)) break;
      page++;
    }
    return result;
  }
}

class UserRepository extends PbRepository<AppUser> {
  UserRepository(Dio dio)
    : super(
        dio: dio,
        collection: 'users',
        fromJson: AppUser.fromJson,
        toBody: (e) => e.toBody(),
        idOf: (e) => e.id,
        searchFields: const ['name', 'email'],
        rules: {'role': equals('role')},
        listSort: 'name',
        softDeletable: false,
      );
}
