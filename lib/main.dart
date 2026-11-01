import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/auth_api.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'demo/demo_interceptor.dart';
import 'state/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();

  late final AuthNotifier auth;
  final dio = buildDio(
    tokenProvider: () => auth.accessToken,
    onRefreshToken: () => auth.refreshTokens(),
  );
  if (demoMode) {
    dio.interceptors.add(await DemoInterceptor.load(prefs));
  }
  auth = AuthNotifier(prefs, AuthApi(dio));
  await auth.restore();

  runApp(
    AppProviders(
      dio: dio,
      auth: auth,
      child: ClinicApp(router: createRouter(auth: auth)),
    ),
  );
}
