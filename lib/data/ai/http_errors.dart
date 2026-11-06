import 'package:dio/dio.dart';

import 'ai_provider.dart';

/// Turns HTTP failures into short messages a user can act on.
AiException aiHttpError(String provider, DioException e) {
  final code = e.response?.statusCode;
  final body = e.response?.data;
  String? apiMsg;
  if (body is Map) {
    final err = body['error'];
    apiMsg = err is Map ? err['message'] as String? : err?.toString();
  }
  final msg = switch (code) {
    400 => '$provider rejected the request${apiMsg != null ? ': $apiMsg' : '.'}',
    401 || 403 => '$provider API key is invalid or lacks access. Check it in Settings.',
    404 => '$provider model not found. Check the model name in Settings.',
    429 => '$provider rate limit or quota reached. Wait a minute, or check your plan.',
    final c? when c >= 500 => '$provider is having problems right now. Try again shortly.',
    _ => e.type == DioExceptionType.receiveTimeout
        ? '$provider took too long to answer. Try again.'
        : 'Could not reach $provider. Check your connection.',
  };
  return AiException(msg);
}
