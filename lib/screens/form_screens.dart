import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/validators.dart';
import '../models/app_user.dart';
import '../models/cabinet.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/patient_card.dart';
import '../models/payment.dart';
import '../models/role.dart';
import '../models/service.dart';
import '../models/service_category.dart';
import '../models/specialization.dart';
import '../repositories/clinic_repositories.dart';
import '../repositories/entity_repository.dart';
import '../state/entity_form_notifier.dart';
import '../state/reference_notifier.dart';
import '../widgets/form/entity_form_view.dart';
import '../widgets/form/field_specs.dart';

String _text(FormValues v, String key) => (v[key] as String? ?? '').trim();

double _number(FormValues v, String key) =>
    double.tryParse(_text(v, key).replaceAll(',', '.')) ?? 0;

int _int(FormValues v, String key) => int.tryParse(_text(v, key)) ?? 0;

DateTime? _utcDay(FormValues v, String key) {
  final day = parseInputDate(_text(v, key));
  return day == null ? null : DateTime.utc(day.year, day.month, day.day);
}

String _dayText(DateTime? d) => d == null ? '' : inputDate(d);

class FormHost<T> extends StatelessWidget {
  final String? id;
  final RecordStore<T> store;
  final Widget Function(EntityFormNotifier<T> notifier) builder;

  const FormHost({
    super.key,
    required this.id,
    required this.store,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EntityFormNotifier<T>>(
      key: ValueKey('form-$T-$id'),
      create: (_) => EntityFormNotifier<T>(store, id)..load(),
      child: Consumer<EntityFormNotifier<T>>(
        builder: (context, notifier, _) => builder(notifier),
      ),
    );
  }
}

class SpecializationFormScreen extends StatelessWidget {
  final String? id;

  const SpecializationFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return FormHost<Specialization>(
      id: id,
      store: context.read<SpecializationRepository>(),
      builder: (n) => EntityFormView<Specialization>(
        notifier: n,
        createTitle: 'Новая специализация',
        editTitle: (e) => 'Изменение: ${e.name}',
        listPath: '/specializations',
        initialValues: (e) => {
          'name': e?.name ?? '',
          'description': e?.description ?? '',
        },
        specs: (_) => [
          TextSpec(
            key: 'name',
            label: 'Название',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите название'),
                V.length(min: 2, max: 60),
              ]),
            ),
          ),
          TextSpec(
            key: 'description',
            label: 'Описание',
            maxLines: 3,
            validator: plain(V.length(max: 255)),
          ),
        ],
        build: (v, existing) => Specialization(
          id: existing?.id ?? '',
          name: _text(v, 'name'),
          description: _text(v, 'description'),
        ),
      ),
    );
  }
}

class CabinetFormScreen extends StatelessWidget {
  final String? id;

  const CabinetFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return FormHost<Cabinet>(
      id: id,
      store: context.read<CabinetRepository>(),
      builder: (n) => EntityFormView<Cabinet>(
        notifier: n,
        createTitle: 'Новый кабинет',
        editTitle: (e) => 'Изменение: кабинет ${e.number}',
        listPath: '/cabinets',
        initialValues: (e) => {
          'number': e?.number ?? '',
          'floor': e == null ? '' : '${e.floor}',
          'equipment': e?.equipment ?? '',
        },
        specs: (_) => [
          TextSpec(
            key: 'number',
            label: 'Номер',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите номер'),
                V.length(min: 1, max: 10),
              ]),
            ),
          ),
          TextSpec(
            key: 'floor',
            label: 'Этаж',
            required: true,
            keyboard: TextInputType.number,
            digitsOnly: true,
            validator: plain(
              V.combine([
                V.required('Укажите этаж'),
                V.integer(min: 1, max: 10),
              ]),
            ),
          ),
          TextSpec(
            key: 'equipment',
            label: 'Оснащение',
            maxLines: 3,
            validator: plain(V.length(max: 255)),
          ),
        ],
        build: (v, existing) => Cabinet(
          id: existing?.id ?? '',
          number: _text(v, 'number'),
          floor: _int(v, 'floor'),
          equipment: _text(v, 'equipment'),
        ),
      ),
    );
  }
}

class CategoryFormScreen extends StatelessWidget {
  final String? id;

  const CategoryFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return FormHost<ServiceCategory>(
      id: id,
      store: context.read<ServiceCategoryRepository>(),
      builder: (n) => EntityFormView<ServiceCategory>(
        notifier: n,
        createTitle: 'Новая категория',
        editTitle: (e) => 'Изменение: ${e.name}',
        listPath: '/categories',
        initialValues: (e) => {
          'name': e?.name ?? '',
          'description': e?.description ?? '',
        },
        specs: (_) => [
          TextSpec(
            key: 'name',
            label: 'Название',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите название'),
                V.length(min: 2, max: 60),
              ]),
            ),
          ),
          TextSpec(
            key: 'description',
            label: 'Описание',
            maxLines: 3,
            validator: plain(V.length(max: 255)),
          ),
        ],
        build: (v, existing) => ServiceCategory(
          id: existing?.id ?? '',
          name: _text(v, 'name'),
          description: _text(v, 'description'),
        ),
      ),
    );
  }
}

class ServiceFormScreen extends StatelessWidget {
  final String? id;

  const ServiceFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    return FormHost<Service>(
      id: id,
      store: context.read<ServiceRepository>(),
      builder: (n) => EntityFormView<Service>(
        notifier: n,
        createTitle: 'Новая услуга',
        editTitle: (e) => 'Изменение: ${e.name}',
        listPath: '/services',
        initialValues: (e) => {
          'name': e?.name ?? '',
          'category': e?.categoryId,
          'price': e == null
              ? ''
              : e.price.toStringAsFixed(
                  e.price == e.price.roundToDouble() ? 0 : 2,
                ),
          'durationMin': e == null ? '' : '${e.durationMin}',
          'description': e?.description ?? '',
        },
        specs: (_) => [
          TextSpec(
            key: 'name',
            label: 'Название',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите название'),
                V.length(min: 2, max: 120),
              ]),
            ),
          ),
          DropdownSpec(
            key: 'category',
            label: 'Категория',
            required: true,
            requiredMessage: 'Выберите категорию',
            options: (_) => [for (final c in ref.categories) (c.id, c.name)],
          ),
          TextSpec(
            key: 'price',
            label: 'Цена, ₽',
            required: true,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validator: plain(
              V.combine([V.required('Укажите цену'), V.money(max: 1000000)]),
            ),
          ),
          TextSpec(
            key: 'durationMin',
            label: 'Длительность, мин',
            required: true,
            keyboard: TextInputType.number,
            digitsOnly: true,
            validator: plain(
              V.combine([
                V.required('Укажите длительность'),
                V.integer(min: 10, max: 480),
              ]),
            ),
          ),
          TextSpec(
            key: 'description',
            label: 'Описание',
            maxLines: 3,
            validator: plain(V.length(max: 500)),
          ),
        ],
        build: (v, existing) => Service(
          id: existing?.id ?? '',
          name: _text(v, 'name'),
          categoryId: v['category'] as String? ?? '',
          price: _number(v, 'price'),
          durationMin: _int(v, 'durationMin'),
          description: _text(v, 'description'),
        ),
      ),
    );
  }
}

class DoctorFormScreen extends StatefulWidget {
  final String? id;

  const DoctorFormScreen({super.key, this.id});

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  List<AppUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final all = await context.read<UserRepository>().findAll();
      if (!mounted) return;
      setState(
        () => _users = [
          for (final u in all)
            if (u.role == Role.doctor) u,
        ],
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferenceNotifier>();
    return FormHost<Doctor>(
      id: widget.id,
      store: context.read<DoctorRepository>(),
      builder: (n) => EntityFormView<Doctor>(
        notifier: n,
        createTitle: 'Новый врач',
        editTitle: (e) => 'Изменение: ${e.fullName}',
        listPath: '/doctors',
        initialValues: (e) => {
          'fullName': e?.fullName ?? '',
          'specialization': e?.specializationId,
          'cabinet': e?.cabinetId.isEmpty ?? true ? null : e!.cabinetId,
          'user': e?.userId.isEmpty ?? true ? null : e!.userId,
          'experienceYears': e == null ? '' : '${e.experienceYears}',
          'phone': e?.phone ?? '',
        },
        specs: (_) => [
          TextSpec(
            key: 'fullName',
            label: 'ФИО',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите ФИО'),
                V.length(min: 2, max: 100),
              ]),
            ),
          ),
          DropdownSpec(
            key: 'specialization',
            label: 'Специализация',
            required: true,
            requiredMessage: 'Выберите специализацию',
            options: (_) => [
              for (final s in ref.specializations) (s.id, s.name),
            ],
          ),
          DropdownSpec(
            key: 'cabinet',
            label: 'Кабинет',
            required: true,
            requiredMessage: 'Выберите кабинет',
            options: (_) => [
              for (final c in ref.cabinets)
                (c.id, '${c.number} (этаж ${c.floor})'),
            ],
          ),
          DropdownSpec(
            key: 'user',
            label: 'Учётная запись врача',
            options: (_) => [
              for (final u in _users) (u.id, '${u.name} — ${u.email}'),
            ],
          ),
          TextSpec(
            key: 'experienceYears',
            label: 'Стаж, лет',
            required: true,
            keyboard: TextInputType.number,
            digitsOnly: true,
            validator: plain(
              V.combine([
                V.required('Укажите стаж'),
                V.integer(min: 0, max: 60),
              ]),
            ),
          ),
          TextSpec(
            key: 'phone',
            label: 'Телефон',
            keyboard: TextInputType.phone,
            validator: plain(V.phone()),
          ),
        ],
        build: (v, existing) => Doctor(
          id: existing?.id ?? '',
          fullName: _text(v, 'fullName'),
          specializationId: v['specialization'] as String? ?? '',
          cabinetId: v['cabinet'] as String? ?? '',
          userId: v['user'] as String? ?? '',
          experienceYears: _int(v, 'experienceYears'),
          phone: _text(v, 'phone'),
        ),
      ),
    );
  }
}

class PatientFormScreen extends StatelessWidget {
  final String? id;

  const PatientFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return FormHost<Patient>(
      id: id,
      store: context.read<PatientRepository>(),
      builder: (n) => EntityFormView<Patient>(
        notifier: n,
        createTitle: 'Новый пациент',
        editTitle: (e) => 'Изменение: ${e.fullName}',
        listPath: '/patients',
        initialValues: (e) => {
          'fullName': e?.fullName ?? '',
          'birthDate': _dayText(e?.birthDate),
          'phone': e?.phone ?? '',
          'email': e?.email ?? '',
          'address': e?.address ?? '',
        },
        specs: (_) => [
          TextSpec(
            key: 'fullName',
            label: 'ФИО',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите ФИО'),
                V.length(min: 2, max: 100),
              ]),
            ),
          ),
          DateSpec(
            key: 'birthDate',
            label: 'Дата рождения',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите дату рождения'),
                V.date(),
                (value) {
                  final d = parseInputDate(value ?? '');
                  if (d != null && d.isAfter(DateTime.now())) {
                    return 'Дата рождения в будущем';
                  }
                  return null;
                },
              ]),
            ),
          ),
          TextSpec(
            key: 'phone',
            label: 'Телефон',
            required: true,
            keyboard: TextInputType.phone,
            hint: '+7 900 000-00-00',
            validator: plain(
              V.combine([V.required('Укажите телефон'), V.phone()]),
            ),
          ),
          TextSpec(
            key: 'email',
            label: 'Электронная почта',
            keyboard: TextInputType.emailAddress,
            validator: plain(V.email()),
          ),
          TextSpec(
            key: 'address',
            label: 'Адрес',
            maxLines: 2,
            validator: plain(V.length(max: 255)),
          ),
        ],
        build: (v, existing) => Patient(
          id: existing?.id ?? '',
          fullName: _text(v, 'fullName'),
          birthDate: _utcDay(v, 'birthDate'),
          phone: _text(v, 'phone'),
          email: normalizeEmail(_text(v, 'email')),
          address: _text(v, 'address'),
        ),
      ),
    );
  }
}

class CardFormScreen extends StatelessWidget {
  final String? id;

  const CardFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    final patients = context.read<PatientRepository>();
    return FormHost<PatientCard>(
      id: id,
      store: context.read<PatientCardRepository>(),
      builder: (n) => EntityFormView<PatientCard>(
        notifier: n,
        createTitle: 'Новая карта пациента',
        editTitle: (e) => 'Изменение: карта ${e.number}',
        listPath: '/cards',
        initialValues: (e) => {
          'patient': e?.patientId,
          'patientLabel': e?.patientName ?? '',
          'number': e?.number ?? '',
          'allergies': e?.allergies ?? '',
          'notes': e?.notes ?? '',
          'openedOn': _dayText(e?.openedOn ?? DateTime.now()),
        },
        specs: (_) => [
          LookupSpec(
            key: 'patient',
            label: 'Пациент',
            required: true,
            requiredMessage: 'Выберите пациента',
            search: (text) async => [
              for (final p in await patients.suggest(text)) (p.id, p.fullName),
            ],
          ),
          TextSpec(
            key: 'number',
            label: 'Номер карты',
            required: true,
            hint: 'K-000001',
            validator: plain(
              V.combine([V.required('Укажите номер'), V.cardNumber()]),
            ),
          ),
          DateSpec(
            key: 'openedOn',
            label: 'Дата открытия',
            required: true,
            validator: plain(V.combine([V.required('Укажите дату'), V.date()])),
          ),
          TextSpec(
            key: 'allergies',
            label: 'Аллергии',
            maxLines: 2,
            validator: plain(V.length(max: 500)),
          ),
          TextSpec(
            key: 'notes',
            label: 'Заметки',
            maxLines: 3,
            validator: plain(V.length(max: 2000)),
          ),
        ],
        build: (v, existing) => PatientCard(
          id: existing?.id ?? '',
          patientId: v['patient'] as String? ?? '',
          number: _text(v, 'number').toUpperCase(),
          allergies: _text(v, 'allergies'),
          notes: _text(v, 'notes'),
          openedOn: _utcDay(v, 'openedOn'),
        ),
      ),
    );
  }
}

class PaymentFormScreen extends StatefulWidget {
  final String? id;
  final String? appointmentId;

  const PaymentFormScreen({super.key, this.id, this.appointmentId});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  String _presetLabel = '';
  double _presetDebt = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadPreset();
  }

  Future<void> _loadPreset() async {
    final appointmentId = widget.appointmentId;
    if (appointmentId != null && widget.id == null) {
      try {
        final a = await context.read<AppointmentRepository>().findById(
          appointmentId,
        );
        if (a != null) {
          _presetLabel = '${formatDateTime(a.startAt)} — ${a.patientName}';
          _presetDebt = a.debt;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    final appointments = context.read<AppointmentRepository>();
    return FormHost<Payment>(
      id: widget.id,
      store: context.read<PaymentRepository>(),
      builder: (n) => EntityFormView<Payment>(
        notifier: n,
        createTitle: 'Новый платёж',
        editTitle: (e) => 'Изменение платежа: ${e.patientName}',
        listPath: '/cash',
        initialValues: (e) => {
          'appointment': e?.appointmentId ?? widget.appointmentId,
          'appointmentLabel': e == null
              ? _presetLabel
              : '${e.appointmentStart == null ? '' : formatDateTime(e.appointmentStart!.toLocal())} — ${e.patientName}',
          'amount': e != null
              ? e.amount.toStringAsFixed(
                  e.amount == e.amount.roundToDouble() ? 0 : 2,
                )
              : (_presetDebt > 0
                    ? _presetDebt.toStringAsFixed(
                        _presetDebt == _presetDebt.roundToDouble() ? 0 : 2,
                      )
                    : ''),
          'method': e?.method.value ?? PayMethod.card.value,
          'paidAt': inputDateTime(e?.paidAt?.toLocal() ?? DateTime.now()),
        },
        specs: (_) => [
          LookupSpec(
            key: 'appointment',
            label: 'Приём',
            required: true,
            requiredMessage: 'Выберите приём',
            search: (text) async => [
              for (final a in await appointments.suggest(text))
                if (a.debt > 0 || a.id == widget.appointmentId)
                  (
                    a.id,
                    '${formatDateTime(a.startAt)} — ${a.patientName} (долг ${formatMoney(a.debt)})',
                  ),
            ],
          ),
          TextSpec(
            key: 'amount',
            label: 'Сумма, ₽',
            required: true,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validator: plain(
              V.combine([V.required('Укажите сумму'), V.money()]),
            ),
          ),
          DropdownSpec(
            key: 'method',
            label: 'Способ оплаты',
            required: true,
            options: (_) => [
              for (final m in PayMethod.values) (m.value, m.label),
            ],
          ),
          DateTimeSpec(
            key: 'paidAt',
            label: 'Дата и время оплаты',
            required: true,
            validator: plain(
              V.combine([V.required('Укажите дату оплаты'), V.dateTime()]),
            ),
          ),
        ],
        build: (v, existing) => Payment(
          id: existing?.id ?? '',
          appointmentId: v['appointment'] as String? ?? '',
          amount: _number(v, 'amount'),
          method: PayMethod.fromString(v['method'] as String?),
          paidAt: parseInputDateTime(_text(v, 'paidAt')),
        ),
      ),
    );
  }
}

class UserFormScreen extends StatelessWidget {
  final String? id;

  const UserFormScreen({super.key, this.id});

  @override
  Widget build(BuildContext context) {
    return FormHost<AppUser>(
      id: id,
      store: context.read<UserRepository>(),
      builder: (n) => EntityFormView<AppUser>(
        notifier: n,
        createTitle: 'Новый пользователь',
        editTitle: (e) => 'Изменение: ${e.name}',
        listPath: '/admin/users',
        initialValues: (e) => {
          'name': e?.name ?? '',
          'email': e?.email ?? '',
          'role': e?.role.value ?? Role.registrar.value,
          'password': '',
        },
        specs: (editing) => [
          TextSpec(
            key: 'name',
            label: 'Имя',
            required: true,
            validator: plain(
              V.combine([
                V.required('Укажите имя'),
                V.length(min: 2, max: 100),
              ]),
            ),
          ),
          TextSpec(
            key: 'email',
            label: 'Электронная почта',
            required: true,
            keyboard: TextInputType.emailAddress,
            validator: plain(
              V.combine([V.required('Укажите почту'), V.email()]),
            ),
          ),
          DropdownSpec(
            key: 'role',
            label: 'Роль',
            required: true,
            options: (_) => [for (final r in Role.values) (r.value, r.label)],
          ),
          TextSpec(
            key: 'password',
            label: editing ? 'Новый пароль (необязательно)' : 'Пароль',
            required: !editing,
            validator: (value, _) {
              final text = value ?? '';
              if (!editing && text.isEmpty) return 'Укажите пароль';
              if (text.isNotEmpty && text.length < 8) {
                return 'Минимум 8 символов';
              }
              return null;
            },
          ),
        ],
        build: (v, existing) => AppUser(
          id: existing?.id ?? '',
          email: normalizeEmail(_text(v, 'email')),
          name: _text(v, 'name'),
          role: Role.fromString(v['role'] as String?),
          password: _text(v, 'password'),
        ),
      ),
    );
  }
}
