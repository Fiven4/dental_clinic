import 'dart:convert';

import '../models/json_utils.dart';
import 'pb_filter.dart';

class DemoError implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic> data;

  const DemoError(this.status, this.message, [this.data = const {}]);

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data,
  };
}

num? _numOrNull(Object? v) => v is num ? v : null;

class FieldDef {
  final String name;
  final String type;
  final bool required;
  final num? min;
  final num? max;
  final String? pattern;
  final List<String>? values;
  final bool multiple;
  final String? collection;
  final bool onlyInt;

  FieldDef.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      type = json['type'] as String,
      required = json['required'] as bool? ?? false,
      min = _numOrNull(json['min']),
      max = _numOrNull(json['max']),
      pattern = json['pattern'] as String?,
      values = (json['values'] as List?)?.cast<String>(),
      multiple = json['multiple'] as bool? ?? false,
      collection = json['collection'] as String?,
      onlyInt = json['onlyInt'] as bool? ?? false;
}

class UniqueDef {
  final List<String> columns;
  final bool nonEmpty;

  UniqueDef(Map<String, dynamic> json)
    : columns = [
        for (final c in (json['columns'] as List).cast<String>())
          c.split(' ').first,
      ],
      nonEmpty = json['nonEmpty'] as bool? ?? false;
}

class CollectionDef {
  final String name;
  final List<FieldDef> fields;
  final List<UniqueDef> unique;

  CollectionDef(this.name, Map<String, dynamic> json)
    : fields = [
        for (final f in mapListOf(json['fields'])) FieldDef.fromJson(f),
      ],
      unique = [for (final u in mapListOf(json['unique'])) UniqueDef(u)];

  FieldDef? field(String name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }
}

class DemoAuth {
  final String id;
  final String role;

  const DemoAuth(this.id, this.role);

  bool get isAdmin => role == 'admin';
  bool get isRegistrar => role == 'registrar';
  bool get isDoctor => role == 'doctor';
}

const Map<String, List<(String, String, String)>> _dependents = {
  'specializations': [('doctors', 'specialization', 'врачи')],
  'cabinets': [('doctors', 'cabinet', 'врачи')],
  'service_categories': [('services', 'category', 'услуги')],
  'services': [('appointments', 'services', 'приёмы')],
  'patients': [('appointments', 'patient', 'приёмы')],
  'doctors': [('appointments', 'doctor', 'приёмы')],
  'appointments': [('payments', 'appointment', 'оплаты')],
};

const _referenceCollections = {
  'specializations',
  'cabinets',
  'service_categories',
  'services',
  'doctors',
};

const _clinicalForbidden = [
  'patient',
  'doctor',
  'services',
  'startAt',
  'endAt',
  'total',
  'discountPercent',
];

const _prefix = {
  'users': 'u',
  'specializations': 's',
  'cabinets': 'c',
  'service_categories': 'k',
  'services': 'v',
  'doctors': 'd',
  'patients': 'p',
  'patient_cards': 'r',
  'appointments': 'a',
  'payments': 'y',
};

String _stamp(DateTime moment) => pbDate(moment);

class DemoDb {
  DemoDb._(this.schema, this.tables, this._counter, this.seededOn);

  final Map<String, CollectionDef> schema;
  final Map<String, List<Map<String, dynamic>>> tables;
  int _counter;
  final String seededOn;
  DateTime Function() clock = DateTime.now;

  factory DemoDb.seed(
    Map<String, dynamic> schemaJson,
    Map<String, dynamic> seed,
    DateTime today,
  ) {
    final schema = {
      for (final e in schemaJson.entries)
        e.key: CollectionDef(e.key, e.value as Map<String, dynamic>),
    };
    final db = DemoDb._(schema, {
      for (final name in schema.keys) name: <Map<String, dynamic>>[],
    }, 0, _day(today));
    db._load(seed, today);
    return db;
  }

  factory DemoDb.restore(
    Map<String, dynamic> schemaJson,
    Map<String, dynamic> state,
  ) {
    final schema = {
      for (final e in schemaJson.entries)
        e.key: CollectionDef(e.key, e.value as Map<String, dynamic>),
    };
    final raw = mapOf(state['tables']);
    return DemoDb._(schema, {
      for (final name in schema.keys) name: mapListOf(raw[name]),
    }, intOf(state['counter']), stringOf(state['seededOn']));
  }

  Map<String, dynamic> snapshot() => {
    'counter': _counter,
    'seededOn': seededOn,
    'tables': tables,
  };

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _newId(String collection) {
    _counter++;
    return '${_prefix[collection]}${_counter.toString().padLeft(14, '0')}';
  }

  void _load(Map<String, dynamic> seed, DateTime today) {
    final base = DateTime(today.year, today.month, today.day);
    DateTime at(int dayOffset, [int minutes = 0]) => DateTime(
      base.year,
      base.month,
      base.day + dayOffset,
    ).add(Duration(minutes: minutes + 180));
    DateTime utcDay(int dayOffset) =>
        DateTime.utc(base.year, base.month, base.day + dayOffset);

    final userIds = <String, String>{};
    for (final u in mapListOf(seed['users'])) {
      final record = _insert('users', {
        'email': u['email'],
        'password': u['password'],
        'name': u['name'],
        'role': u['role'],
        'emailVisibility': true,
        'verified': true,
      }, validate: false);
      userIds['${u['email']}'] = record['id'] as String;
    }
    List<String> insertAll(String collection, List<Map<String, dynamic>> list) =>
        [
          for (final item in list)
            _insert(collection, item, validate: false)['id'] as String,
        ];
    final specs = insertAll('specializations', mapListOf(seed['specializations']));
    final cabs = insertAll('cabinets', mapListOf(seed['cabinets']));
    final cats = insertAll('service_categories', mapListOf(seed['categories']));
    final svcs = [
      for (final s in mapListOf(seed['services']))
        _insert('services', {
          ...s,
          'category': cats[intOf(s['category'])],
        }, validate: false)['id'] as String,
    ];
    final docs = [
      for (final d in mapListOf(seed['doctors']))
        _insert('doctors', {
          'fullName': d['fullName'],
          'specialization': specs[intOf(d['specialization'])],
          'cabinet': cabs[intOf(d['cabinet'])],
          'user': userIds['${d['userEmail']}'] ?? '',
          'experienceYears': d['experienceYears'],
          'phone': d['phone'],
        }, validate: false)['id'] as String,
    ];
    final pats = [
      for (final p in mapListOf(seed['patients']))
        _insert('patients', {
          ...p,
          'birthDate': '${p['birthDate']} 00:00:00.000Z',
        }, validate: false)['id'] as String,
    ];
    for (final c in mapListOf(seed['patientCards'])) {
      _insert('patient_cards', {
        'patient': pats[intOf(c['patient'])],
        'number': c['number'],
        'allergies': c['allergies'],
        'notes': c['notes'],
        'openedOn': _stamp(utcDay(intOf(c['openedDayOffset']))),
      }, validate: false);
    }

    final source = mapListOf(seed['appointments']);
    final order = [for (var i = 0; i < source.length; i++) i]
      ..sort((x, y) {
        final a = source[x], b = source[y];
        final byDay = intOf(a['dayOffset']).compareTo(intOf(b['dayOffset']));
        return byDay != 0
            ? byDay
            : intOf(a['startMin']).compareTo(intOf(b['startMin']));
      });
    final created = <int, Map<String, dynamic>>{};
    for (final index in order) {
      final a = source[index];
      final start = at(intOf(a['dayOffset']), intOf(a['startMin']));
      created[index] = _insert('appointments', {
        'patient': pats[intOf(a['patient'])],
        'doctor': docs[intOf(a['doctor'])],
        'services': [for (final i in (a['services'] as List)) svcs[intOf(i)]],
        'startAt': _stamp(start),
        'endAt': _stamp(start.add(Duration(minutes: intOf(a['durationMin'])))),
        'status': a['status'],
        'complaints': a['complaints'],
        'diagnosis': a['diagnosis'],
      });
    }
    for (final p in mapListOf(seed['payments'])) {
      final index = intOf(p['appointment']);
      final appointment = created[index];
      final original = source[index];
      if (appointment == null || doubleOf(appointment['total']) <= 0) continue;
      final amount = (doubleOf(appointment['total']) * doubleOf(p['share']))
          .round()
          .clamp(1, 1 << 30);
      final paid = at(
        intOf(original['dayOffset']),
        intOf(original['startMin']) + intOf(original['durationMin']),
      );
      _insert('payments', {
        'appointment': appointment['id'],
        'amount': amount,
        'method': p['method'],
        'paidAt': _stamp(paid),
      });
    }
  }

  Map<String, dynamic> _insert(
    String collection,
    Map<String, dynamic> body, {
    bool validate = true,
  }) {
    final now = _stamp(clock());
    final record = <String, dynamic>{
      'id': _newId(collection),
      'collectionName': collection,
    };
    for (final f in schema[collection]!.fields) {
      if (f.name == 'id') continue;
      record[f.name] = _blank(f);
    }
    if (collection == 'users') {
      record
        ..['email'] = ''
        ..['emailVisibility'] = false
        ..['verified'] = false;
    }
    record.addAll(body);
    record['created'] = now;
    record['updated'] = now;
    if (validate) {
      _validate(collection, record, null);
      _beforeSave(collection, record, null);
    } else if (collection == 'appointments' || collection == 'payments') {
      _beforeSave(collection, record, null);
    }
    tables[collection]!.add(record);
    return record;
  }

  Object? _blank(FieldDef f) => switch (f.type) {
    'number' => 0,
    'relation' || 'select' => f.multiple ? <String>[] : '',
    _ => '',
  };

  List<Map<String, dynamic>> _rows(String collection) => tables[collection]!;

  Map<String, dynamic>? byId(String collection, String id) {
    for (final r in _rows(collection)) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  List<String> _ids(Object? value) => stringListOf(value);

  void _validate(
    String collection,
    Map<String, dynamic> record,
    Map<String, dynamic>? original,
  ) {
    final def = schema[collection]!;
    final errors = <String, dynamic>{};
    void fail(String field, String code, String message) =>
        errors.putIfAbsent(field, () => {'code': code, 'message': message});

    if (collection == 'users') {
      final email = stringOf(record['email']).trim();
      if (email.isEmpty) {
        fail('email', 'validation_required', 'Cannot be blank.');
      } else if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
        fail('email', 'validation_is_email', 'Must be a valid email address.');
      } else if (_rows('users').any(
        (u) =>
            u['id'] != record['id'] &&
            stringOf(u['email']).toLowerCase() == email.toLowerCase(),
      )) {
        fail('email', 'validation_not_unique', 'Value must be unique.');
      }
      final password = record['password'];
      if (original == null && (password == null || '$password'.isEmpty)) {
        fail('password', 'validation_required', 'Cannot be blank.');
      } else if (password != null && '$password'.isNotEmpty && '$password'.length < 8) {
        fail('password', 'validation_min_text_constraint', 'Must be at least 8 character(s).');
      }
    }

    for (final f in def.fields) {
      if (const {'id', 'created', 'updated', 'file', 'autodate'}.contains(f.type) ||
          f.name == 'id') {
        continue;
      }
      final value = record[f.name];
      final isEmpty = switch (value) {
        null => true,
        String s => s.isEmpty,
        List l => l.isEmpty,
        _ => false,
      };
      if (f.type == 'number') {
        final n = value is num ? value : num.tryParse('$value');
        if (f.required && (value == null || value == '' || n == 0)) {
          fail(f.name, 'validation_required', 'Cannot be blank.');
          continue;
        }
        if (n == null) {
          fail(f.name, 'validation_invalid_value', 'Must be a number.');
          continue;
        }
        if (f.min != null && n < f.min!) {
          fail(f.name, 'validation_min_number_constraint', 'Must be no less than ${f.min}.');
        }
        if (f.max != null && n > f.max!) {
          fail(f.name, 'validation_max_number_constraint', 'Must be no greater than ${f.max}.');
        }
        if (f.onlyInt && n != n.roundToDouble()) {
          fail(f.name, 'validation_invalid_value', 'Must be an integer.');
        }
        continue;
      }
      if (f.required && isEmpty) {
        fail(f.name, 'validation_required', 'Cannot be blank.');
        continue;
      }
      if (isEmpty) continue;
      switch (f.type) {
        case 'text':
        case 'email':
          final text = '$value';
          if (f.min != null && text.length < f.min!) {
            fail(f.name, 'validation_min_text_constraint', 'Must be at least ${f.min} character(s).');
          }
          if (f.max != null && f.max! > 0 && text.length > f.max!) {
            fail(f.name, 'validation_max_text_constraint', 'Must be no more than ${f.max} character(s).');
          }
          if (f.pattern != null && !RegExp(f.pattern!).hasMatch(text)) {
            fail(f.name, 'validation_invalid_format', 'Invalid value format.');
          }
          if (f.type == 'email' &&
              !RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text)) {
            fail(f.name, 'validation_is_email', 'Must be a valid email address.');
          }
        case 'select':
          if (!(f.values ?? const []).contains('$value')) {
            fail(f.name, 'validation_invalid_value', 'Invalid value.');
          }
        case 'relation':
          for (final id in _ids(value)) {
            if (byId(f.collection!, id) == null) {
              fail(f.name, 'validation_missing_rel_records', 'Failed to find all relation records.');
            }
          }
        case 'date':
          if (DateTime.tryParse('$value') == null) {
            fail(f.name, 'validation_invalid_date', 'Must be a valid date.');
          }
      }
    }

    for (final u in def.unique) {
      if (u.columns.any((c) => schema[collection]!.field(c) == null)) continue;
      final values = [for (final c in u.columns) '${record[c] ?? ''}'.toLowerCase()];
      if (u.nonEmpty && values.every((v) => v.isEmpty)) continue;
      final clash = _rows(collection).any(
        (other) =>
            other['id'] != record['id'] &&
            [for (final c in u.columns) '${other[c] ?? ''}'.toLowerCase()]
                    .join('|') ==
                values.join('|'),
      );
      if (clash) fail(u.columns.first, 'validation_not_unique', 'Value must be unique.');
    }

    if (errors.isNotEmpty) {
      throw DemoError(400, 'Failed to create record.', errors);
    }
  }

  bool canView(DemoAuth? auth, String collection, Map<String, dynamic> r) {
    if (auth == null) return false;
    switch (collection) {
      case 'users':
        return true;
      case 'payments':
        return auth.isAdmin || auth.isRegistrar;
      case 'appointments':
        if (auth.isAdmin || auth.isRegistrar) return true;
        return auth.isDoctor && byId('doctors', '${r['doctor']}')?['user'] == auth.id;
      case 'patients':
        if (auth.isAdmin || auth.isRegistrar) return true;
        return auth.isDoctor && _doctorHasPatient(auth, '${r['id']}');
      case 'patient_cards':
        if (auth.isAdmin || auth.isRegistrar) return true;
        return auth.isDoctor && _doctorHasPatient(auth, '${r['patient']}');
      default:
        return true;
    }
  }

  bool _doctorHasPatient(DemoAuth auth, String patientId) => _rows(
    'appointments',
  ).any(
    (a) =>
        a['patient'] == patientId &&
        byId('doctors', '${a['doctor']}')?['user'] == auth.id,
  );

  bool canList(DemoAuth? auth, String collection, Map<String, dynamic> r) {
    if (collection == 'users') {
      return auth != null && (auth.isAdmin || r['id'] == auth.id);
    }
    return canView(auth, collection, r);
  }

  void _requireWrite(
    DemoAuth? auth,
    String collection,
    String action,
    Map<String, dynamic>? existing,
    Map<String, dynamic> body,
  ) {
    if (collection == 'users' && action == 'create') return;
    if (auth == null) {
      throw const DemoError(
        401,
        'The request requires valid record authorization token.',
      );
    }
    final bool ok;
    switch (collection) {
      case 'users':
        ok = auth.isAdmin ||
            (action == 'update' &&
                existing?['id'] == auth.id &&
                !body.containsKey('role'));
      case 'payments':
        ok = action == 'delete' ? auth.isAdmin : auth.isRegistrar;
      case 'appointments':
        if (action == 'delete') {
          ok = auth.isAdmin;
        } else if (action == 'create') {
          ok = auth.isAdmin || auth.isRegistrar;
        } else {
          ok = auth.isAdmin ||
              auth.isRegistrar ||
              (auth.isDoctor &&
                  existing != null &&
                  canView(auth, collection, existing) &&
                  _clinicalForbidden.every((f) => !body.containsKey(f)));
        }
      case 'patients' || 'patient_cards':
        ok = action == 'delete'
            ? auth.isAdmin
            : auth.isAdmin || auth.isRegistrar;
      default:
        ok = auth.isAdmin;
    }
    if (!ok) {
      throw const DemoError(
        403,
        'Only superusers can perform this action.',
      );
    }
  }

  Map<String, dynamic> _present(
    DemoAuth? auth,
    String collection,
    Map<String, dynamic> record,
    String expand,
  ) {
    final out = Map<String, dynamic>.from(record)
      ..remove('password')
      ..remove('tokenKey');
    if (collection == 'users' && !(auth?.isAdmin ?? false) && out['id'] != auth?.id) {
      out['email'] = '';
    }
    if (expand.trim().isNotEmpty) {
      final groups = <String, List<String>>{};
      for (final part in expand.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final dot = trimmed.indexOf('.');
        final head = dot < 0 ? trimmed : trimmed.substring(0, dot);
        groups.putIfAbsent(head, () => []);
        if (dot >= 0) groups[head]!.add(trimmed.substring(dot + 1));
      }
      final expanded = <String, dynamic>{};
      groups.forEach((head, rest) {
        final nested = rest.join(',');
        final via = RegExp(r'^(\w+)_via_(\w+)$').firstMatch(head);
        if (via != null) {
          final other = via[1]!;
          final field = via[2]!;
          if (!tables.containsKey(other)) return;
          final items = [
            for (final o in _rows(other))
              if (_ids(o[field]).contains(record['id']) &&
                  canView(auth, other, o))
                _present(auth, other, o, nested),
          ];
          if (items.isNotEmpty) expanded[head] = items;
          return;
        }
        final f = schema[collection]!.field(head);
        if (f == null || f.type != 'relation') return;
        final items = [
          for (final id in _ids(record[head]))
            if (byId(f.collection!, id) case final target?)
              if (canView(auth, f.collection!, target))
                _present(auth, f.collection!, target, nested),
        ];
        if (items.isEmpty) return;
        expanded[head] = f.multiple ? items : items.first;
      });
      if (expanded.isNotEmpty) out['expand'] = expanded;
    }
    return out;
  }

  List<Object?> _resolve(String collection, Map<String, dynamic> record, String path) {
    var nodes = <(String, Map<String, dynamic>)>[(collection, record)];
    final parts = path.split('.');
    final values = <Object?>[];
    for (var i = 0; i < parts.length; i++) {
      final segment = parts[i];
      final last = i == parts.length - 1;
      final next = <(String, Map<String, dynamic>)>[];
      for (final (col, row) in nodes) {
        final via = RegExp(r'^(\w+)_via_(\w+)$').firstMatch(segment);
        if (via != null && tables.containsKey(via[1])) {
          for (final o in _rows(via[1]!)) {
            if (_ids(o[via[2]!]).contains(row['id'])) next.add((via[1]!, o));
          }
          continue;
        }
        final f = schema[col]?.field(segment);
        if (f != null && f.type == 'relation') {
          final ids = _ids(row[segment]);
          if (last) {
            values.addAll(ids);
          } else {
            for (final id in ids) {
              final target = byId(f.collection!, id);
              if (target != null) next.add((f.collection!, target));
            }
          }
        } else if (last) {
          final value = row[segment];
          if (value is List) {
            values.addAll(value);
          } else {
            values.add(value);
          }
        }
      }
      if (last && values.isEmpty && nodes.isNotEmpty && parts.length == 1) {
        values.add('');
      }
      nodes = next;
    }
    if (parts.length > 1 && values.isEmpty) {
      return [''];
    }
    return values.isEmpty ? [''] : values;
  }

  Map<String, dynamic> list(
    DemoAuth? auth,
    String collection, {
    int page = 1,
    int perPage = 30,
    String sort = '',
    String filter = '',
    String expand = '',
  }) {
    _requireCollection(collection);
    if (auth == null) {
      throw const DemoError(
        401,
        'The request requires valid record authorization token.',
      );
    }
    final RecordPredicate predicate;
    try {
      predicate = compileFilter(
        filter,
        (record, path) => _resolve(collection, record, path),
      );
    } on FilterSyntaxException catch (e) {
      throw DemoError(400, 'Something went wrong while processing your request. Invalid filter. ${e.message}');
    }
    var items = [
      for (final r in _rows(collection))
        if (canList(auth, collection, r) && predicate(r)) r,
    ];
    final keys = [
      for (final part in sort.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    if (keys.isNotEmpty) {
      int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
        for (final key in keys) {
          final desc = key.startsWith('-');
          final field = key.replaceFirst(RegExp(r'^[-+]'), '');
          final x = _resolve(collection, a, field).first;
          final y = _resolve(collection, b, field).first;
          int order;
          if (x is num && y is num) {
            order = x.compareTo(y);
          } else {
            order = '${x ?? ''}'.toLowerCase().compareTo('${y ?? ''}'.toLowerCase());
          }
          if (order != 0) return desc ? -order : order;
        }
        return 0;
      }

      items = [...items]..sort(compare);
    }
    final size = perPage.clamp(1, 500);
    final total = items.length;
    final pages = total == 0 ? 0 : (total / size).ceil();
    final start = (page - 1) * size;
    final slice = start >= total
        ? <Map<String, dynamic>>[]
        : items.sublist(start, (start + size).clamp(0, total));
    return {
      'page': page,
      'perPage': size,
      'totalItems': total,
      'totalPages': pages,
      'items': [for (final r in slice) _present(auth, collection, r, expand)],
    };
  }

  Map<String, dynamic> view(
    DemoAuth? auth,
    String collection,
    String id, {
    String expand = '',
  }) {
    _requireCollection(collection);
    if (auth == null) {
      throw const DemoError(
        401,
        'The request requires valid record authorization token.',
      );
    }
    final record = byId(collection, id);
    if (record == null || !canView(auth, collection, record)) {
      throw const DemoError(404, 'The requested resource wasn\'t found.');
    }
    return _present(auth, collection, record, expand);
  }

  Map<String, dynamic> create(
    DemoAuth? auth,
    String collection,
    Map<String, dynamic> body, {
    String expand = '',
  }) {
    _requireCollection(collection);
    _requireWrite(auth, collection, 'create', null, body);
    final data = Map<String, dynamic>.from(body);
    data.remove('passwordConfirm');
    data.remove('id');
    if (collection == 'users') {
      if (!(auth?.isAdmin ?? false)) data['role'] = 'registrar';
      if ('${body['password']}' != '${body['passwordConfirm']}') {
        throw const DemoError(400, 'Failed to create record.', {
          'passwordConfirm': {
            'code': 'validation_values_mismatch',
            'message': 'Values don\'t match.',
          },
        });
      }
    }
    final record = _insert(collection, data);
    return _present(auth, collection, record, expand);
  }

  Map<String, dynamic> update(
    DemoAuth? auth,
    String collection,
    String id,
    Map<String, dynamic> body, {
    String expand = '',
  }) {
    _requireCollection(collection);
    final record = byId(collection, id);
    if (record == null) {
      throw const DemoError(404, 'The requested resource wasn\'t found.');
    }
    if (auth != null && !canView(auth, collection, record) && collection != 'users') {
      throw const DemoError(404, 'The requested resource wasn\'t found.');
    }
    _requireWrite(auth, collection, 'update', record, body);
    final original = Map<String, dynamic>.from(record);
    final candidate = Map<String, dynamic>.from(record);
    body.forEach((key, value) {
      if (key == 'id' || key == 'passwordConfirm') return;
      if (key == 'password' && (value == null || '$value'.isEmpty)) return;
      candidate[key] = value;
    });
    candidate['updated'] = _stamp(clock());
    _validate(collection, candidate, original);
    if (_referenceCollections.contains(collection) ||
        const {'patients', 'appointments'}.contains(collection)) {
      final before = stringOf(original['deletedAt']);
      final after = stringOf(candidate['deletedAt']);
      if (before.isEmpty && after.isNotEmpty) {
        _guardDelete(collection, candidate, includeDeleted: false);
      }
    }
    _beforeSave(collection, candidate, original);
    record
      ..clear()
      ..addAll(candidate);
    return _present(auth, collection, record, expand);
  }

  void delete(DemoAuth? auth, String collection, String id) {
    _requireCollection(collection);
    final record = byId(collection, id);
    if (record == null) {
      throw const DemoError(404, 'The requested resource wasn\'t found.');
    }
    _requireWrite(auth, collection, 'delete', record, const {});
    if (_dependents.containsKey(collection)) {
      _guardDelete(collection, record, includeDeleted: true);
    }
    _rows(collection).remove(record);
    if (collection == 'patients') {
      _rows('patient_cards').removeWhere((c) => c['patient'] == id);
    }
    if (collection == 'users') {
      for (final d in _rows('doctors')) {
        if (d['user'] == id) d['user'] = '';
      }
    }
  }

  void _requireCollection(String collection) {
    if (!tables.containsKey(collection)) {
      throw const DemoError(404, 'Missing collection context.');
    }
  }

  String _title(Map<String, dynamic> r) {
    for (final key in ['fullName', 'name', 'number']) {
      final v = stringOf(r[key]);
      if (v.isNotEmpty) return v;
    }
    return '${r['id']}';
  }

  void _guardDelete(
    String collection,
    Map<String, dynamic> record, {
    required bool includeDeleted,
  }) {
    var total = 0;
    final parts = <String>[];
    for (final (other, field, label) in _dependents[collection] ?? const <(String, String, String)>[]) {
      final count = _rows(other)
          .where(
            (o) =>
                _ids(o[field]).contains(record['id']) &&
                (includeDeleted || stringOf(o['deletedAt']).isEmpty),
          )
          .length;
      if (count > 0) {
        total += count;
        parts.add('$label: $count');
      }
    }
    if (total > 0) {
      throw DemoError(
        409,
        'Запись «${_title(record)}» удалить нельзя: на неё ссылаются другие записи ($total). ${parts.join(', ')}.',
        {'count': total},
      );
    }
  }

  void _beforeSave(
    String collection,
    Map<String, dynamic> record,
    Map<String, dynamic>? original,
  ) {
    if (collection == 'appointments') _prepareAppointment(record, original);
    if (collection == 'payments') _preparePayment(record);
  }

  bool _changed(
    Map<String, dynamic> record,
    Map<String, dynamic>? original,
    String field,
  ) => original == null || '${record[field]}' != '${original[field]}';

  void _prepareAppointment(
    Map<String, dynamic> record,
    Map<String, dynamic>? original,
  ) {
    final scheduleChanged = const [
      'startAt',
      'endAt',
      'doctor',
      'patient',
      'status',
      'deletedAt',
    ].any((f) => _changed(record, original, f));
    final costChanged = _changed(record, original, 'services') ||
        _changed(record, original, 'patient');
    final start = DateTime.parse('${record['startAt']}'.replaceFirst(' ', 'T'));
    final end = DateTime.parse('${record['endAt']}'.replaceFirst(' ', 'T'));
    if (!end.isAfter(start)) {
      throw const DemoError(400, 'Ошибка валидации', {
        'endAt': {
          'code': 'invalid_range',
          'message': 'Окончание приёма должно быть позже начала.',
        },
      });
    }
    if (scheduleChanged &&
        record['status'] != 'cancelled' &&
        stringOf(record['deletedAt']).isEmpty) {
      final overlap = _findOverlap(record, start, end);
      if (overlap != null) {
        throw DemoError(409, overlap.$2, {
          'kind': overlap.$1,
          'appointment': overlap.$3,
        });
      }
    }
    if (costChanged) {
      var sum = 0.0;
      for (final id in _ids(record['services'])) {
        sum += doubleOf(byId('services', id)?['price']);
      }
      final done = _rows('appointments').where(
        (a) =>
            a['patient'] == record['patient'] &&
            a['status'] == 'done' &&
            stringOf(a['deletedAt']).isEmpty &&
            a['id'] != record['id'],
      ).length;
      final discount = done >= 10 ? 15 : (done >= 5 ? 10 : 0);
      record['discountPercent'] = discount;
      record['total'] = (sum * (100 - discount) / 100).roundToDouble();
    }
  }

  (String, String, String)? _findOverlap(
    Map<String, dynamic> record,
    DateTime start,
    DateTime end,
  ) {
    final doctor = byId('doctors', '${record['doctor']}');
    final cabinet = stringOf(doctor?['cabinet']);
    String label(Map<String, dynamic> a) {
      String hm(Object? v) {
        final d = DateTime.parse('$v'.replaceFirst(' ', 'T')).add(const Duration(hours: 3));
        return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }

      return '${hm(a['startAt'])}–${hm(a['endAt'])}';
    }

    final checks = <(String, String, bool Function(Map<String, dynamic>))>[
      ('doctor', 'Врач занят в это время', (a) => a['doctor'] == record['doctor']),
      (
        'patient',
        'Пациент уже записан на это время',
        (a) => a['patient'] == record['patient'],
      ),
      if (cabinet.isNotEmpty)
        (
          'cabinet',
          'Кабинет занят в это время',
          (a) => byId('doctors', '${a['doctor']}')?['cabinet'] == cabinet,
        ),
    ];
    for (final (kind, text, match) in checks) {
      for (final a in _rows('appointments')) {
        if (a['id'] == record['id'] ||
            a['status'] == 'cancelled' ||
            stringOf(a['deletedAt']).isNotEmpty ||
            !match(a)) {
          continue;
        }
        final aStart = DateTime.parse('${a['startAt']}'.replaceFirst(' ', 'T'));
        final aEnd = DateTime.parse('${a['endAt']}'.replaceFirst(' ', 'T'));
        if (aStart.isBefore(end) && aEnd.isAfter(start)) {
          return (kind, '$text: существует приём ${label(a)}.', '${a['id']}');
        }
      }
    }
    return null;
  }

  void _preparePayment(Map<String, dynamic> record) {
    final appointment = byId('appointments', '${record['appointment']}');
    if (appointment == null) return;
    if (appointment['status'] == 'cancelled') {
      throw const DemoError(409, 'Приём отменён: оплату принять нельзя.');
    }
    var paid = 0.0;
    for (final p in _rows('payments')) {
      if (p['appointment'] == appointment['id'] &&
          p['id'] != record['id'] &&
          stringOf(p['deletedAt']).isEmpty) {
        paid += doubleOf(p['amount']);
      }
    }
    final rest = doubleOf(appointment['total']) - paid;
    if (stringOf(record['deletedAt']).isEmpty && doubleOf(record['amount']) > rest) {
      throw DemoError(
        409,
        'Сумма оплат превышает стоимость приёма. Осталось оплатить: ${rest.toStringAsFixed(rest == rest.roundToDouble() ? 0 : 2)} ₽.',
        {'rest': rest},
      );
    }
  }

  DemoAuth? authenticate(String email, String password) {
    for (final u in _rows('users')) {
      if (stringOf(u['email']).toLowerCase() == email.toLowerCase() &&
          u['password'] == password) {
        return DemoAuth('${u['id']}', '${u['role']}');
      }
    }
    return null;
  }

  Map<String, dynamic> userRecord(String id) =>
      _present(DemoAuth(id, 'admin'), 'users', byId('users', id)!, '');

  String dump() => jsonEncode(snapshot());
}
