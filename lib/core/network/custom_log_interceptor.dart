import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CustomLogInterceptor extends Interceptor {
  final bool requestHeader;
  final bool requestBody;
  final bool responseBody;
  final bool error;

  CustomLogInterceptor({
    this.requestHeader = true,
    this.requestBody = true,
    this.responseBody = true,
    this.error = true,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kDebugMode) {
      return super.onRequest(options, handler);
    }

    try {
      debugPrint('╔ 🌐 HTTP REQUEST ────────────────────────────────────────');
      debugPrint('║ ➡ ${options.method} ${options.uri}');
      
      if (requestHeader && options.headers.isNotEmpty) {
        debugPrint('║ ── Headers:');
        options.headers.forEach((key, value) {
          debugPrint('║    $key: $value');
        });
      }

      if (options.queryParameters.isNotEmpty) {
        debugPrint('║ ── Query Parameters:');
        final sanitizedQuery = _sanitizeData(options.queryParameters);
        debugPrint('║    $sanitizedQuery');
      }

      if (requestBody && options.data != null) {
        debugPrint('║ ── Request Body:');
        final sanitizedData = _sanitizeBodyData(options.data);
        _printFormatted(sanitizedData);
      }
      debugPrint('╚═════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('║ [Logger Error] Failed to log request: $e');
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!kDebugMode) {
      return super.onResponse(response, handler);
    }

    try {
      debugPrint('╔ ✅ HTTP RESPONSE [${response.statusCode}] ───────────────────');
      debugPrint('║ ⬅ ${response.requestOptions.method} ${response.requestOptions.uri}');

      if (responseBody && response.data != null) {
        debugPrint('║ ── Response Body:');
        final sanitizedData = _sanitizeBodyData(response.data);
        _printFormatted(sanitizedData);
      }
      debugPrint('╚═════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('║ [Logger Error] Failed to log response: $e');
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kDebugMode) {
      return super.onError(err, handler);
    }

    try {
      debugPrint('╔ ❌ HTTP ERROR [${err.response?.statusCode}] ──────────────────');
      debugPrint('║ ✖ ${err.requestOptions.method} ${err.requestOptions.uri}');
      debugPrint('║ 💬 Message: ${err.message}');
      if (err.response?.data != null) {
        debugPrint('║ ── Error Body:');
        final sanitizedData = _sanitizeBodyData(err.response?.data);
        _printFormatted(sanitizedData);
      }
      debugPrint('╚═════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('║ [Logger Error] Failed to log error: $e');
    }

    super.onError(err, handler);
  }

  dynamic _sanitizeBodyData(dynamic data) {
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return _sanitizeData(decoded);
      } catch (_) {
        return _sanitizeData(data);
      }
    }
    return _sanitizeData(data);
  }

  dynamic _sanitizeData(dynamic data) {
    if (data is String) {
      // 1. Check data URI base64 (e.g. data:image/png;base64,...)
      if (data.startsWith('data:') && data.contains('base64,')) {
        final index = data.indexOf('base64,');
        final prefix = data.substring(0, index + 7);
        final content = data.substring(index + 7);
        if (content.length > 30) {
          return '$prefix${content.substring(0, 20)}... [truncated, len: ${data.length}]';
        }
      }
      // 2. Check long base64 strings (no spaces, matches base64 charset, length > 100)
      if (data.length > 100 && !data.contains(' ') && _isBase64(data)) {
        return '${data.substring(0, 30)}... [BASE64 len: ${data.length}]';
      }
      // 3. Very long strings without spaces (like raw base64 or large hashes/tokens)
      if (data.length > 200 && !data.contains(' ')) {
        return '${data.substring(0, 30)}... [LONG STR len: ${data.length}]';
      }
      return data;
    } else if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), _sanitizeData(value)));
    } else if (data is List) {
      return data.map((item) => _sanitizeData(item)).toList();
    } else if (data is FormData) {
      final map = <String, dynamic>{};
      for (var entry in data.fields) {
        map[entry.key] = _sanitizeData(entry.value);
      }
      for (var entry in data.files) {
        map[entry.key] = 'MultipartFile: ${entry.value.filename} (${entry.value.length} bytes)';
      }
      return map;
    }
    return data;
  }

  bool _isBase64(String str) {
    final base64Regex = RegExp(r'^[A-Za-z0-9\+/]+={0,2}$');
    return base64Regex.hasMatch(str);
  }

  void _printFormatted(dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final prettyString = encoder.convert(data);
      for (var line in prettyString.split('\n')) {
        debugPrint('║    $line');
      }
    } catch (_) {
      for (var line in data.toString().split('\n')) {
        debugPrint('║    $line');
      }
    }
  }
}
