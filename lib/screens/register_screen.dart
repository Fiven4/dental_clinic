import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/access.dart';
import '../core/api_exceptions.dart';
import '../core/validators.dart';
import '../state/auth_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _server(String key) => _fieldErrors[key];

  Future<void> _submit() async {
    setState(() => _fieldErrors = const {});
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthNotifier>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) context.go(homeFor(auth.role));
    } on ValidationException catch (e) {
      setState(() {
        _fieldErrors = e.errors;
        _error = e.errors.isEmpty ? e.message : null;
      });
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Регистрация',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Новая учётная запись получает роль «Регистратор». Другие роли назначает администратор.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Container(
                          key: const ValueKey('register-error'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const ValueKey('register-name'),
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Имя и фамилия',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            V.combine([
                              V.required('Укажите имя'),
                              V.length(min: 2, max: 100),
                            ])(v) ??
                            _server('name'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('register-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Электронная почта',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            V.combine([V.required('Укажите почту'), V.email()])(
                              v,
                            ) ??
                            _server('email'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('register-password'),
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          helperText: 'Не короче 8 символов',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final text = v ?? '';
                          if (text.isEmpty) return 'Укажите пароль';
                          if (text.length < 8) return 'Не короче 8 символов';
                          return _server('password');
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('register-confirm'),
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Повторите пароль',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == _password.text ? null : 'Пароли не совпадают',
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const ValueKey('register-submit'),
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Зарегистрироваться'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('register-to-login'),
                        onPressed: () => context.go('/login'),
                        child: const Text('Уже есть учётная запись? Войти'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
