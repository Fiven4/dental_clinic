import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'repositories/clinic_repositories.dart';
import 'state/auth_notifier.dart';

class AppProviders extends StatelessWidget {
  final Dio dio;
  final AuthNotifier auth;
  final Widget child;

  const AppProviders({
    super.key,
    required this.dio,
    required this.auth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dio>.value(value: dio),
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),
        ChangeNotifierProvider(create: (_) => SpecializationRepository(dio)),
        ChangeNotifierProvider(create: (_) => CabinetRepository(dio)),
        ChangeNotifierProvider(create: (_) => ServiceCategoryRepository(dio)),
        ChangeNotifierProvider(create: (_) => ServiceRepository(dio)),
        ChangeNotifierProvider(create: (_) => DoctorRepository(dio)),
        ChangeNotifierProvider(create: (_) => PatientRepository(dio)),
        ChangeNotifierProvider(create: (_) => PatientCardRepository(dio)),
        ChangeNotifierProvider(create: (_) => AppointmentRepository(dio)),
        ChangeNotifierProvider(create: (_) => PaymentRepository(dio)),
        ChangeNotifierProvider(create: (_) => UserRepository(dio)),
      ],
      child: child,
    );
  }
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00796B),
    brightness: brightness,
  ),
  useMaterial3: true,
  dialogTheme: const DialogThemeData(
    constraints: BoxConstraints(maxWidth: 560),
  ),
);

class ClinicApp extends StatelessWidget {
  final GoRouter router;

  const ClinicApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Стоматологическая клиника',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
