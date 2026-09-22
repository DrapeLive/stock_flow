import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../utils/perf.dart';

/// Thrown for non-2xx responses; [message] is derived from the backend error
/// payload so screens can surface it directly.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetwork = false, this.data});
  final String message;
  final int? statusCode;
  final bool isNetwork;

  /// Raw decoded response body, when available. Screens use this to read
  /// structured error payloads (e.g. `out_of_stock_items`).
  final dynamic data;

  @override
  String toString() => message;
}

/// Thin Dio wrapper mirroring `frontend/lib/api/axios.ts`.
///
/// - base URL from [AppConfig.baseUrl]
/// - Bearer token injected from [setToken]
/// - 401 responses routed through [onUnauthorized] (logout)
class ApiClient {
  ApiClient._();

  static String? _token;
  static void Function()? onUnauthorized;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      headers: const {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );

  static void init() {
    dio.interceptors.clear();
    if (Perf.enabled) {
      dio.interceptors.add(_PerfInterceptor());
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  static void setToken(String? token) => _token = token;

  static void _perfBytes(RequestOptions o, int? status, dynamic data, {DioException? error}) {
    final start = o.extra[kPerfStartKey];
    final ms =
        start is DateTime ? DateTime.now().difference(start).inMilliseconds : -1;
    int? bytes;
    if (data is String) {
      bytes = utf8.encode(data).length;
    } else if (data is Map || data is List) {
      try {
        bytes = utf8.encode(jsonEncode(data)).length;
      } catch (_) {}
    }
    debugPrint('[perf] NET ${o.method} ${o.path} -> ${status ?? 'ERR'}'
        '${bytes != null ? ' $bytes' : ''}B ${ms}ms${error != null ? ' ${error.type}' : ''}');
  }

  @visibleForTesting
  static const String kPerfStartKey = 'perf_start';

  /// Converts a DioError into an [ApiException] with a human-readable message.
  static ApiException mapError(Object? error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final networkTypes = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.unknown,
      };
      if (error.response == null && networkTypes.contains(error.type)) {
        return ApiException(
          'Network error. Check your connection and try again.',
          isNetwork: true,
        );
      }
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = _extractMessage(data, error.response?.statusCode);
        return ApiException(msg,
            statusCode: error.response?.statusCode, data: data);
      }
      if (data != null) {
        return ApiException(
          _extractMessage(const {}, error.response?.statusCode),
          statusCode: error.response?.statusCode,
          data: data,
        );
      }
      return ApiException(
        'Something went wrong (${error.response?.statusCode ?? 'unknown'}).',
        statusCode: error.response?.statusCode,
      );
    }
    return ApiException('Something went wrong. Please try again.');
  }

  static String _extractMessage(Map<String, dynamic> data, int? statusCode) {
    final keys = ['error_message', 'message', 'detail', 'error'];
    for (final key in keys) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }
    // Field-level validation errors: pick the first one.
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is List && v.isNotEmpty) {
        return '${entry.key}: ${v.first}';
      }
      if (v is String && entry.key == 'pin') return 'Incorrect PIN';
    }
    if (statusCode == 400) return 'Please check the form and try again.';
    if (statusCode == 403) return 'You do not have permission to do that.';
    if (statusCode == 404) return 'Not found.';
    return 'Something went wrong. Please try again.';
  }
}

/// Request logger — installed when [Perf.enabled] (debug, or release built
/// with `--dart-define=PERF_LOG=true`).
class _PerfInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[ApiClient.kPerfStartKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    ApiClient._perfBytes(response.requestOptions, response.statusCode, response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ApiClient._perfBytes(err.requestOptions, err.response?.statusCode,
        err.response?.data,
        error: err);
    handler.next(err);
  }
}
