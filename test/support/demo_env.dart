import 'dart:convert';
import 'dart:io';

import 'package:dental_clinic/core/api_client.dart';
import 'package:dental_clinic/core/auth_api.dart';
import 'package:dental_clinic/demo/demo_db.dart';
import 'package:dental_clinic/demo/demo_interceptor.dart';
import 'package:dental_clinic/state/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

DemoDb buildDemoDb({DateTime? today}) => DemoDb.seed(
  _json('assets/demo_schema.json'),
  _json('assets/seed.json'),
  today ?? DateTime(2026, 11, 2),
);

class DemoEnv {
  final DemoDb db;
  final Dio dio;
  final AuthNotifier auth;

  DemoEnv(this.db, this.dio, this.auth);

  static Future<DemoEnv> create({DemoDb? db}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = db ?? buildDemoDb();
    late final AuthNotifier auth;
    final dio = buildDio(
      baseUrl: 'http://demo.local',
      tokenProvider: () => auth.accessToken,
      onRefreshToken: () => auth.refreshTokens(),
    );
    dio.interceptors.add(
      DemoInterceptor(database, null, latency: Duration.zero),
    );
    auth = AuthNotifier(prefs, AuthApi(dio), autoRefresh: false);
    return DemoEnv(database, dio, auth);
  }

  Future<void> loginAs(String email, String password) =>
      auth.login(email, password);
}
