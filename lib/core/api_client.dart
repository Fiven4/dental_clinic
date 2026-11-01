import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';

Dio buildDio({
  String? baseUrl,
  String? Function()? tokenProvider,
  Future<bool> Function()? onRefreshToken,
  Duration connectTimeout = const Duration(seconds: 8),
  Duration receiveTimeout = const Duration(seconds: 15),
  int maxRetries = 2,
  Duration retryDelay = const Duration(milliseconds: 400),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? pocketBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final options = error.requestOptions;

        final isAuthCall = options.path.contains('/auth-');
        if (status == 401 &&
            !isAuthCall &&
            options.extra['refreshed'] != true &&
            onRefreshToken != null) {
          try {
            if (await onRefreshToken()) {
              options.extra['refreshed'] = true;
              final token = tokenProvider?.call();
              if (token != null) options.headers['Authorization'] = token;
              final response = await dio.fetch(options);
              return handler.resolve(response);
            }
          } on DioException catch (e) {
            return handler.next(e);
          } catch (_) {}
        }

        final isGet = options.method.toUpperCase() == 'GET';
        final isNetworkError =
            error.type != DioExceptionType.badResponse &&
            error.type != DioExceptionType.cancel;
        final retry = (options.extra['retry'] as int?) ?? 0;
        if (isGet && isNetworkError && retry < maxRetries) {
          options.extra['retry'] = retry + 1;
          if (kDebugMode) {
            debugPrint('[API] повтор ${retry + 1}/$maxRetries ${options.uri}');
          }
          await Future<void>.delayed(retryDelay * (1 << retry));
          try {
            return handler.resolve(await dio.fetch(options));
          } on DioException catch (e) {
            return handler.next(e);
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}
