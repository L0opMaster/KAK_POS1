// Short-term: silence some non-critical analyzer rules in this core service
// to keep onboarding focused. Remove or tighten these ignores later.
// ignore_for_file: public_member_api_docs, unnecessary_final, always_specify_types,
//   avoid_annotating_with_dynamic, avoid_print, type_annotate_public_apis,
//   omit_local_variable_types, always_put_control_body_on_new_line,
//   avoid_catches_without_on_clauses

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// ONLINE: thin wrapper around Dio that every Api***Service in the app calls
/// to talk to the backend over HTTP (get/post/put/patch/delete/download/
/// upload). Used by: core/services/auth_service.dart, and every
/// Api***Service under features/pos/services/ (cart, table, held ticket,
/// settings, ...) when its SWITCH POINT flag in AppConfig selects the
/// network-backed implementation.
///
/// It also contains a small OFFLINE piece: the auth token is cached in
/// SharedPreferences (see `_getAuthToken`/`_clearAuthToken` below) so it
/// survives app restarts and doesn't need to be re-sent on every call.
class ApiService {
  /// Download bytes from an endpoint (e.g., for PDF or image files)
  Future<Uint8List> getBytes(
    final String path, {
    final Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data as Uint8List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<T> patch<T>(
    final String path, {
    final Object? data,
    final Map<String, dynamic>? queryParameters,
    final T Function(Object? data)? fromJson,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return fromJson != null ? fromJson(response.data) : response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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
      // Auth interceptor
      InterceptorsWrapper(
        onRequest: (
          final RequestOptions options,
          final RequestInterceptorHandler handler,
        ) async {
          // Add auth token if available
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
            // Session is no longer valid: clear the stored token and notify
            // the app so it can route back to login. Without this the app
            // keeps a dead token and every request fails silently.
            await _clearAuthToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
      // Lightweight logging interceptor. Only logs method, path, status and
      // duration in debug builds. It never logs request/response bodies or
      // headers, which previously leaked the login password and bearer token
      // into device logs.
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

  /// Optional callback invoked when the backend rejects the session (HTTP 401).
  /// Set this from app startup (e.g. to trigger logout / navigate to login).
  static void Function()? onUnauthorized;

  Future<void> _clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.authTokenKey);
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.authTokenKey);
  }

  // Generic HTTP methods
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

  // File download
  Future<Response> download(final String url, final String savePath) async {
    try {
      return await _dio.download(url, savePath);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload a file via multipart/form-data.
  /// Returns the response body as a Map (expected: {url, path}).
  Future<Map<String, dynamic>> uploadFile(
    final String path, {
    required final String filePath,
    final String fieldName = 'file',
  }) async {
    try {
      final formData = FormData.fromMap(<String, dynamic>{
        fieldName: await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(path, data: formData);
      return response.data as Map<String, dynamic>;
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

  String? _extractMessage(final data) {
    try {
      if (data == null) return null;
      if (data is String) {
        // Try decode JSON string
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

/// A lightweight API error that preserves HTTP status and a friendly message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

// Singleton instance
final ApiService apiService = ApiService();

// Provider
final Provider<ApiService> apiServiceProvider =
    Provider<ApiService>((final Ref<ApiService> ref) => apiService);
