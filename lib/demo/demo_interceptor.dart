import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json_utils.dart';
import 'demo_db.dart';

const _storageKey = 'clinic.demo.db.v1';
const _tokenLifetime = Duration(minutes: 15);
const _maxAge = Duration(days: 6);

class DemoInterceptor extends Interceptor {
  DemoInterceptor(
    this._db,
    this._prefs, {
    this.latency = const Duration(milliseconds: 120),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DemoDb _db;
  final SharedPreferences? _prefs;
  final Duration latency;
  final DateTime Function() _clock;

  DemoDb get db => _db;

  static Future<DemoInterceptor> load(SharedPreferences prefs) async {
    final schema =
        jsonDecode(await rootBundle.loadString('assets/demo_schema.json'))
            as Map<String, dynamic>;
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final state = jsonDecode(stored) as Map<String, dynamic>;
        final seededOn = DateTime.tryParse('${state['seededOn']}');
        if (seededOn != null && DateTime.now().difference(seededOn) < _maxAge) {
          return DemoInterceptor(DemoDb.restore(schema, state), prefs);
        }
      } catch (_) {}
    }
    final seed =
        jsonDecode(await rootBundle.loadString('assets/seed.json'))
            as Map<String, dynamic>;
    final db = DemoDb.seed(schema, seed, DateTime.now());
    final interceptor = DemoInterceptor(db, prefs);
    interceptor._save();
    return interceptor;
  }

  void _save() {
    try {
      _prefs?.setString(_storageKey, _db.dump());
    } catch (_) {}
  }

  String _token(String userId) {
    String part(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final exp = _clock().add(_tokenLifetime).millisecondsSinceEpoch ~/ 1000;
    return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${part({'id': userId, 'collectionName': 'users', 'exp': exp})}.demo';
  }

  DemoAuth? _auth(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || header.isEmpty) return null;
    final parts = header.split('.');
    if (parts.length != 3) return null;
    try {
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = intOf(payload['exp']);
      if (exp * 1000 < _clock().millisecondsSinceEpoch) return null;
      final user = _db.byId('users', '${payload['id']}');
      if (user == null) return null;
      return DemoAuth('${user['id']}', '${user['role']}');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    try {
      final data = _route(options);
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: options.method.toUpperCase() == 'DELETE' ? 204 : 200,
          data: data,
        ),
        true,
      );
    } on DemoError catch (e) {
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: e.status,
          data: e.toJson(),
        ),
        true,
      );
    }
  }

  Object? _route(RequestOptions options) {
    final path = options.path.replaceFirst(RegExp(r'^https?://[^/]+'), '');
    final method = options.method.toUpperCase();
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 4 ||
        segments[0] != 'api' ||
        segments[1] != 'collections') {
      throw const DemoError(404, 'The requested resource wasn\'t found.');
    }
    final collection = segments[2];
    final action = segments[3];
    final query = options.queryParameters;
    final body = mapOf(options.data);
    final auth = _auth(options);

    if (collection == 'users' &&
        action == 'auth-with-password' &&
        method == 'POST') {
      final user = _db.authenticate(
        stringOf(body['identity']),
        stringOf(body['password']),
      );
      if (user == null) {
        throw const DemoError(400, 'Failed to authenticate.');
      }
      return {'token': _token(user.id), 'record': _db.userRecord(user.id)};
    }
    if (collection == 'users' && action == 'auth-refresh' && method == 'POST') {
      if (auth == null) {
        throw const DemoError(
          401,
          'The request requires valid record authorization token.',
        );
      }
      return {'token': _token(auth.id), 'record': _db.userRecord(auth.id)};
    }
    if (action != 'records') {
      throw const DemoError(404, 'The requested resource wasn\'t found.');
    }

    final expand = stringOf(query['expand']);
    if (segments.length == 4) {
      switch (method) {
        case 'GET':
          return _db.list(
            auth,
            collection,
            page: intOf(query['page'], 1),
            perPage: intOf(query['perPage'], 30),
            sort: stringOf(query['sort']),
            filter: stringOf(query['filter']),
            expand: expand,
          );
        case 'POST':
          final created = _db.create(auth, collection, body, expand: expand);
          _save();
          return created;
      }
    } else if (segments.length == 5) {
      final id = segments[4];
      switch (method) {
        case 'GET':
          return _db.view(auth, collection, id, expand: expand);
        case 'PATCH':
          final updated = _db.update(
            auth,
            collection,
            id,
            body,
            expand: expand,
          );
          _save();
          return updated;
        case 'DELETE':
          _db.delete(auth, collection, id);
          _save();
          return null;
      }
    }
    throw const DemoError(405, 'Method not allowed.');
  }
}
