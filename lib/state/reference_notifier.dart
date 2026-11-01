import 'package:flutter/foundation.dart';

import '../models/cabinet.dart';
import '../models/doctor.dart';
import '../models/service.dart';
import '../models/service_category.dart';
import '../models/specialization.dart';
import '../repositories/clinic_repositories.dart';
import '../repositories/entity_repository.dart';
import 'load_status.dart';

class ReferenceNotifier extends ChangeNotifier {
  ReferenceNotifier({
    required SpecializationRepository specializations,
    required CabinetRepository cabinets,
    required ServiceCategoryRepository categories,
    required ServiceRepository services,
    required DoctorRepository doctors,
  }) : _specializations = specializations,
       _cabinets = cabinets,
       _categories = categories,
       _services = services,
       _doctors = doctors {
    for (final r in _sources) {
      r.changes.addListener(_scheduleReload);
    }
  }

  final SpecializationRepository _specializations;
  final CabinetRepository _cabinets;
  final ServiceCategoryRepository _categories;
  final ServiceRepository _services;
  final DoctorRepository _doctors;

  List<EntityRepository<Object?, Object?>> get _sources => [
    _specializations,
    _cabinets,
    _categories,
    _services,
    _doctors,
  ];

  List<Specialization> specializations = const [];
  List<Cabinet> cabinets = const [];
  List<ServiceCategory> categories = const [];
  List<Service> services = const [];
  List<Doctor> doctors = const [];
  LoadStatus status = LoadStatus.idle;
  String? error;
  bool _disposed = false;
  bool _reloadQueued = false;

  Future<void> load() async {
    status = LoadStatus.loading;
    error = null;
    _safeNotify();
    try {
      final results = await Future.wait<Object>([
        _specializations.findAll(),
        _cabinets.findAll(),
        _categories.findAll(),
        _services.findAll(),
        _doctors.findAll(),
      ]);
      specializations = results[0] as List<Specialization>;
      cabinets = results[1] as List<Cabinet>;
      categories = results[2] as List<ServiceCategory>;
      services = results[3] as List<Service>;
      doctors = results[4] as List<Doctor>;
      status = LoadStatus.success;
    } catch (e) {
      error = 'Не удалось загрузить справочники: $e';
      status = LoadStatus.error;
    }
    _safeNotify();
  }

  void _scheduleReload() {
    if (_reloadQueued || _disposed) return;
    _reloadQueued = true;
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      _reloadQueued = false;
      if (!_disposed) load();
    });
  }

  String specializationName(String id) => specializations
      .firstWhere(
        (e) => e.id == id,
        orElse: () => const Specialization(id: '', name: '—'),
      )
      .name;

  String categoryName(String id) => categories
      .firstWhere(
        (e) => e.id == id,
        orElse: () => const ServiceCategory(id: '', name: '—'),
      )
      .name;

  String cabinetNumber(String id) => cabinets
      .firstWhere(
        (e) => e.id == id,
        orElse: () => const Cabinet(id: '', number: '—', floor: 0),
      )
      .number;

  Doctor? doctorById(String id) {
    for (final d in doctors) {
      if (d.id == id) return d;
    }
    return null;
  }

  Service? serviceById(String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final r in _sources) {
      r.changes.removeListener(_scheduleReload);
    }
    super.dispose();
  }
}
