import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/access.dart';
import '../state/auth_notifier.dart';

class NotFoundScreen extends StatelessWidget {
  final String location;

  const NotFoundScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('404', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text('Адрес $location не существует', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('not-found-home'),
                onPressed: () => context.go(homeFor(auth.role)),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
