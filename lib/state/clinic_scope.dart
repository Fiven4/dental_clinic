import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/cabinet.dart';
import '../models/doctor.dart';
import '../models/filter_query.dart';
import '../models/patient.dart';
import '../models/patient_card.dart';
import '../models/payment.dart';
import '../models/query_specs.dart';
import '../models/service.dart';
import '../models/service_category.dart';
import '../models/specialization.dart';
import '../models/app_user.dart';
import '../repositories/clinic_repositories.dart';
import 'entity_list_notifier.dart';
import 'reference_notifier.dart';

typedef ListNotifier<T> = EntityListNotifier<T, FilterQuery>;

ListNotifier<T> _list<T>(
  dynamic repository,
  QuerySpec spec,
  String Function(T item) idOf,
) => EntityListNotifier<T, FilterQuery>(
  repository,
  FilterQuery(spec: spec),
  idOf,
);

class ClinicScope extends StatelessWidget {
  final Widget child;

  const ClinicScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (c) => ReferenceNotifier(
            specializations: c.read<SpecializationRepository>(),
            cabinets: c.read<CabinetRepository>(),
            categories: c.read<ServiceCategoryRepository>(),
            services: c.read<ServiceRepository>(),
            doctors: c.read<DoctorRepository>(),
          )..load(),
        ),
        ChangeNotifierProvider<ListNotifier<Specialization>>(
          create: (c) => _list<Specialization>(
            c.read<SpecializationRepository>(),
            specializationsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Cabinet>>(
          create: (c) => _list<Cabinet>(
            c.read<CabinetRepository>(),
            cabinetsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<ServiceCategory>>(
          create: (c) => _list<ServiceCategory>(
            c.read<ServiceCategoryRepository>(),
            categoriesSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Service>>(
          create: (c) => _list<Service>(
            c.read<ServiceRepository>(),
            servicesSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Doctor>>(
          create: (c) => _list<Doctor>(
            c.read<DoctorRepository>(),
            doctorsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Patient>>(
          create: (c) => _list<Patient>(
            c.read<PatientRepository>(),
            patientsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<PatientCard>>(
          create: (c) => _list<PatientCard>(
            c.read<PatientCardRepository>(),
            cardsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Appointment>>(
          create: (c) => _list<Appointment>(
            c.read<AppointmentRepository>(),
            appointmentsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Payment>>(
          create: (c) => _list<Payment>(
            c.read<PaymentRepository>(),
            paymentsSpec,
            (e) => e.id,
          ),
        ),
        ChangeNotifierProvider<ListNotifier<AppUser>>(
          create: (c) =>
              _list<AppUser>(c.read<UserRepository>(), usersSpec, (e) => e.id),
        ),
      ],
      child: child,
    );
  }
}
