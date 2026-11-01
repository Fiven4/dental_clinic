import 'package:dio/dio.dart';

import '../models/app_user.dart';
import '../models/json_utils.dart';
import 'api_exceptions.dart';

class AuthSession {
  final String token;
  final AppUser user;

  const AuthSession(this.token, this.user);
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login(String email, String password) async {
    try {
      final response = await guard(
        () => _dio.post<dynamic>(
          '/api/collections/users/auth-with-password',
          data: {'identity': email, 'password': password},
        ),
      );
      return _session(response.data);
    } on ValidationException {
      throw const UnauthorizedException('Неверная почта или пароль.');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await guard(
      () => _dio.post<dynamic>(
        '/api/collections/users/records',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'emailVisibility': true,
        },
      ),
    );
  }

  Future<AuthSession> refresh() async {
    final response = await guard(
      () => _dio.post<dynamic>('/api/collections/users/auth-refresh'),
    );
    return _session(response.data);
  }

  AuthSession _session(Object? data) {
    final map = mapOf(data);
    return AuthSession(
      stringOf(map['token']),
      AppUser.fromJson(mapOf(map['record'])),
    );
  }
}
