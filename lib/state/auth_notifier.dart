import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/auth_api.dart';
import '../models/app_user.dart';
import '../models/role.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this._prefs,
    this._api, {
    DateTime Function()? clock,
    this.autoRefresh = true,
  }) : _clock = clock ?? DateTime.now;

  final bool autoRefresh;

  static const _storageKey = 'clinic.session';
  static const _refreshMargin = Duration(minutes: 2);

  final SharedPreferences _prefs;
  final AuthApi _api;
  final DateTime Function() _clock;

  String? _token;
  AppUser? _user;
  Timer? _timer;
  String? _notice;
  Future<bool>? _refreshing;

  String? get accessToken => _token;
  AppUser? get user => _user;
  Role? get role => _user?.role;
  bool get isAuthenticated => _token != null && _user != null;
  String? get notice => _notice;

  bool has(Role role) => _user?.role == role;

  void clearNotice() => _notice = null;

  Future<void> restore() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final token = map['token'] as String;
      if (_expiry(token).isBefore(_clock())) {
        await _forget();
        return;
      }
      _token = token;
      _user = AppUser.fromJson(Map<String, dynamic>.from(map['user'] as Map));
    } catch (_) {
      await _forget();
      return;
    }
    try {
      await _renew();
    } on UnauthorizedException {
      await _end('Сессия недействительна. Войдите заново.');
      return;
    } on ApiException {
      _schedule();
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final session = await _api.login(email.trim(), password);
    await _accept(session);
    _notice = null;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _api.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
    );
    await login(email, password);
  }

  Future<bool> refreshTokens() {
    return _refreshing ??= _renew()
        .then((_) => true)
        .catchError((Object _) => false)
        .whenComplete(() => _refreshing = null);
  }

  Future<void> logout({String? notice}) async {
    await _end(notice);
  }

  Future<void> _renew() async {
    final session = await _api.refresh();
    await _accept(session);
    notifyListeners();
  }

  Future<void> _accept(AuthSession session) async {
    _token = session.token;
    _user = session.user;
    await _prefs.setString(
      _storageKey,
      jsonEncode({'token': session.token, 'user': session.user.toJson()}),
    );
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!autoRefresh) return;
    final token = _token;
    if (token == null) return;
    var wait = _expiry(token).difference(_clock()) - _refreshMargin;
    if (wait < const Duration(seconds: 5)) wait = const Duration(seconds: 5);
    _timer = Timer(wait, () async {
      if (!await refreshTokens()) {
        await _end('Сессия истекла. Войдите заново.');
      }
    });
  }

  Future<void> _end(String? notice) async {
    _timer?.cancel();
    _token = null;
    _user = null;
    _notice = notice;
    await _forget();
    notifyListeners();
  }

  Future<void> _forget() => _prefs.remove(_storageKey);

  DateTime _expiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    final exp = payload['exp'];
    return DateTime.fromMillisecondsSinceEpoch(
      (exp is num ? exp.toInt() : 0) * 1000,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
