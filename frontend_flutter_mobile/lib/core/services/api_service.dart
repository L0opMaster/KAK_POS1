import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Ported from `frontend-flutter-pos/lib/core/services/api_service.dart` —
/// COPY/ADAPT NEARLY EXACTLY. Same Dio wrapper, same auth-token interceptor,
/// same error-mapping table. Only `getBytes`/`download`/`uploadFile` were
/// dropped for Day 4 (nothing in auth needs them yet — Day 12/13's printing
/// work is what will need them, and they can be pulled back in unchanged
/// from source at that point). See DAY_04.md for the full mapping.
class ApiService {
  ApiService() : _dio = Dio(_createDioOptions()) {
    _setupInterceptors();
  }
  final Dio _dio;

  static BaseOptions _createDioOptions() => BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

  void _setupInterceptors() {
    _dio.interceptors.addAll(<Interceptor>[
      InterceptorsWrapper(
        onRequest: (
          final RequestOptions options,
          final RequestInterceptorHandler handler,
        ) async {
          final token = await _getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (
          final DioException error,
          final ErrorInterceptorHandler handler,
        ) async {
          if (error.response?.statusCode == 401) {
            await _clearAuthToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
      if (kDebugMode)
        InterceptorsWrapper(
          onRequest: (final RequestOptions options,
              final RequestInterceptorHandler handler) {
            options.extra['startTime'] = DateTime.now().millisecondsSinceEpoch;
            handler.next(options);
          },
          onResponse: (final Response<dynamic> response,
              final ResponseInterceptorHandler handler) {
            final start = response.requestOptions.extra['startTime'] as int?;
            final ms = start != null
                ? DateTime.now().millisecondsSinceEpoch - start
                : null;
            debugPrint(
                'API ${response.requestOptions.method} ${response.requestOptions.path}'
                ' -> ${response.statusCode}${ms != null ? ' (${ms}ms)' : ''}');
            handler.next(response);
          },
          onError: (final DioException error,
              final ErrorInterceptorHandler handler) {
            debugPrint(
                'API ${error.requestOptions.method} ${error.requestOptions.path}'
                ' -> ERR ${error.response?.statusCode ?? error.type}');
            handler.next(error);
          },
        ),
    ]);
  }

  /// Optional callback invoked when the backend rejects the session (401).
  static void Function()? onUnauthorized;

  Future<void> _clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.authTokenKey);
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.authTokenKey);
  }

  Future<T> get<T>(
    final String path, {
    final Map<String, dynamic>? queryParameters,
    final T Function(Object? data)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> post<T>(
    final String path, {
    final Object? data,
    final Map<String, dynamic>? queryParameters,
    final T Function(Object? data)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> put<T>(
    final String path, {
    final Object? data,
    final Map<String, dynamic>? queryParameters,
    final T Function(Object? data)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> delete<T>(
    final String path, {
    final Map<String, dynamic>? queryParameters,
    final T Function(Object? data)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(final DioException error) {
    var message = 'An error occurred';

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      final extracted = _extractMessage(data);
      switch (statusCode) {
        case 400:
          message = extracted ?? 'Bad request';
        case 401:
          message = 'Unauthorized access';
        case 403:
          message = 'Access forbidden';
        case 404:
          message = 'Resource not found';
        case 409:
          message = extracted ?? 'Conflict';
        case 422:
          message = extracted ?? 'Validation error';
        case 500:
          message = extracted ?? 'Internal server error';
        default:
          message = 'Server error: $statusCode';
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      message = 'Receive timeout';
    } else if (error.type == DioExceptionType.sendTimeout) {
      message = 'Send timeout';
    } else if (error.type == DioExceptionType.cancel) {
      message = 'Request cancelled';
    } else {
      message = error.message ?? 'Network error';
    }

    return ApiException(message, statusCode: error.response?.statusCode);
  }

  String? _extractMessage(final dynamic data) {
    try {
      if (data == null) return null;
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['message'] != null) {
          return decoded['message'].toString();
        }
        return data;
      }
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// A lightweight API error that preserves HTTP status and a friendly
/// message — identical shape to `[OLD/SOURCE]`'s `ApiException`.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

final ApiService apiService = ApiService();

final Provider<ApiService> apiServiceProvider =
    Provider<ApiService>((final Ref<ApiService> ref) => apiService);
