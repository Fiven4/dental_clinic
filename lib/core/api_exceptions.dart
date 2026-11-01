import 'package:dio/dio.dart';

class RepositoryException implements Exception {
  final String message;
  const RepositoryException(this.message);

  @override
  String toString() => message;
}

sealed class ApiException extends RepositoryException {
  const ApiException(super.message);
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Сервер недоступен. Проверьте соединение и повторите попытку.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  final String? kind;

  const ConflictException([super.message = 'Операция невозможна.', this.kind]);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;

  const ValidationException([
    super.message = 'Ошибка валидации',
    this.errors = const {},
  ]);
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

const _codeMessages = {
  'validation_required': 'Поле обязательно для заполнения',
  'validation_not_unique': 'Такое значение уже используется',
  'validation_is_email': 'Некорректный адрес почты',
  'validation_invalid_email': 'Некорректный адрес почты',
  'validation_invalid_value': 'Недопустимое значение',
  'validation_length_too_short': 'Значение слишком короткое',
  'validation_length_too_long': 'Значение слишком длинное',
  'validation_min_text_constraint': 'Значение слишком короткое',
  'validation_max_text_constraint': 'Значение слишком длинное',
  'validation_min_number_constraint': 'Число меньше допустимого',
  'validation_max_number_constraint': 'Число больше допустимого',
  'validation_invalid_format': 'Неверный формат значения',
  'validation_values_mismatch': 'Значения не совпадают',
  'validation_pattern_mismatch': 'Неверный формат значения',
  'invalid_range': 'Недопустимый диапазон',
};

Map<String, String> _fieldErrors(dynamic data) {
  if (data is! Map) return const {};
  final result = <String, String>{};
  data.forEach((key, value) {
    if (value is Map) {
      final code = '${value['code'] ?? ''}';
      final message = '${value['message'] ?? ''}';
      result['$key'] =
          _codeMessages[code] ?? (message.isEmpty ? code : message);
    }
  });
  return result;
}

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;
  final data = body is Map ? body['data'] : null;

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException('Недостаточно прав для этого действия.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(
      message ?? 'Операция невозможна.',
      data is Map ? data['kind'] as String? : null,
    ),
    400 => _badRequest(message, data),
    422 => _badRequest(message, data),
    _ => ServerException(message ?? 'Ошибка сервера (код $status).'),
  };
}

ApiException _badRequest(String? message, dynamic data) {
  final errors = _fieldErrors(data);
  if (errors.isNotEmpty) {
    return ValidationException('Ошибка валидации', errors);
  }
  if (message != null && message.contains('required relation reference')) {
    return const ConflictException(
      'Запись удалить нельзя: на неё ссылаются другие записи.',
    );
  }
  return ValidationException(message ?? 'Некорректный запрос');
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя. Повторите попытку.',
    ),
    DioExceptionType.connectionError => const NetworkException(),
    DioExceptionType.cancel => const NetworkException('Запрос отменён.'),
    _ => const ServerException(),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
