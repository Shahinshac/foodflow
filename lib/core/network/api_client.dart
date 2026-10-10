import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Authentication Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString(AppConstants.authTokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // Fail gracefully if SharedPreferences is temporarily inaccessible
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // If 401 Unauthorized, safely clear stale credentials to prevent loop
          if (e.response?.statusCode == 401) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(AppConstants.authTokenKey);
            } catch (_) {}
          }
          return handler.next(e);
        },
      ),
    );

    // 2. Safe Transient Retry Interceptor (idempotent GET/HEAD/OPTIONS only)
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) async {
          final requestOptions = e.requestOptions;
          final method = requestOptions.method.toUpperCase();
          final isIdempotent = method == 'GET' || method == 'HEAD' || method == 'OPTIONS';

          final isTransient = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError;

          final retryCount = (requestOptions.extra['retry_count'] as int?) ?? 0;
          const maxRetries = 2;

          if (isIdempotent && isTransient && retryCount < maxRetries) {
            requestOptions.extra['retry_count'] = retryCount + 1;
            final backoffDelay = Duration(milliseconds: 1000 * (retryCount + 1));
            await Future.delayed(backoffDelay);

            try {
              final response = await dio.fetch(requestOptions);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            } catch (err) {
              return handler.next(
                DioException(
                  requestOptions: requestOptions,
                  error: err,
                  type: DioExceptionType.unknown,
                ),
              );
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  /// Parses any exception into a clean, human-readable message for UI presentation.
  /// Never exposes raw stack dumps, SQL statements, or sensitive tokens.
  static String formatError(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timed out. Please check your internet connection and try again.';
        case DioExceptionType.connectionError:
          return 'Unable to reach the server. Please verify your internet connection.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;

          if (data is Map && data.containsKey('detail')) {
            final detail = data['detail'];
            if (detail is String && detail.isNotEmpty) {
              return detail;
            } else if (detail is List && detail.isNotEmpty) {
              final first = detail.first;
              if (first is Map && first.containsKey('msg')) {
                return first['msg'].toString();
              }
            }
          }

          if (statusCode == 401) {
            return 'Your session has expired. Please sign in again.';
          } else if (statusCode == 403) {
            return 'Access denied. You do not have permission for this action.';
          } else if (statusCode == 404) {
            return 'The requested resource was not found.';
          } else if (statusCode == 409) {
            return 'Conflict with existing data. Please refresh and try again.';
          } else if (statusCode == 422) {
            return 'Validation error. Please check your input.';
          } else if (statusCode != null && statusCode >= 500) {
            return 'Server is temporarily unavailable. Please try again in a few moments.';
          }
          return 'Server returned an error ($statusCode). Please try again.';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        default:
          return 'Network request failed. Please check your connection and try again.';
      }
    }

    final errStr = error.toString().replaceAll('Exception: ', '').trim();
    if (errStr.isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }
    return errStr;
  }
}
