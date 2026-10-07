import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class OutgoingFile {
  OutgoingFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.token,
    this.onUnauthorized,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() token;
  final void Function()? onUnauthorized;
  final http.Client _http;

  Future<Map<String, dynamic>> getJson(String path) {
    return _send(() => http.Request('GET', _uri(path)), retry: true);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) {
    return _send(() {
      final request = http.Request('POST', _uri(path));
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
      return request;
    });
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) {
    return _send(() {
      final request = http.Request('PUT', _uri(path));
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
      return request;
    });
  }

  Future<Map<String, dynamic>> deleteJson(String path, [Map<String, dynamic>? body]) {
    return _send(() {
      final request = http.Request('DELETE', _uri(path));
      if (body != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return request;
    });
  }

  Future<Uint8List> getBytes(String path) async {
    final request = http.Request('GET', _uri(path));
    _authorize(request);
    final response = await _http.send(request).timeout(const Duration(seconds: 60));
    final bytes = await response.stream.toBytes();
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Sign in again.', status: 401, code: 'UNAUTHENTICATED');
    }
    if (response.statusCode >= 400) {
      throw _errorFromBody(response.statusCode, utf8.decode(bytes, allowMalformed: true));
    }
    return bytes;
  }

  Future<Map<String, dynamic>> sendForm(
    String path, {
    required Map<String, String> fields,
    List<OutgoingFile> files = const [],
    void Function(double progress)? onProgress,
    String method = 'POST',
  }) async {
    final multipart = http.MultipartRequest(method, _uri(path));
    _authorize(multipart);
    multipart.fields.addAll(fields);
    for (final file in files) {
      multipart.files.add(http.MultipartFile.fromBytes(
        'attachments',
        file.bytes,
        filename: file.name,
      ));
    }

    final payload = await multipart.finalize().toBytes();
    final contentType = multipart.headers['content-type'] ?? 'multipart/form-data';
    final total = payload.length;
    var sent = 0;
    const chunkSize = 64 * 1024;

    final request = http.StreamedRequest(method, _uri(path));
    _authorize(request);
    request.headers['content-type'] = contentType;
    request.contentLength = total;

    final future = _http.send(request).timeout(const Duration(minutes: 2));
    for (var offset = 0; offset < payload.length; offset += chunkSize) {
      final end = offset + chunkSize > payload.length ? payload.length : offset + chunkSize;
      request.sink.add(payload.sublist(offset, end));
      sent = end;
      onProgress?.call(total == 0 ? 1 : sent / total);
      await Future<void>.delayed(Duration.zero);
    }
    await request.sink.close();

    final response = await future;
    final raw = await response.stream.bytesToString();
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Sign in again.', status: 401, code: 'UNAUTHENTICATED');
    }
    if (response.statusCode >= 400) throw _errorFromBody(response.statusCode, raw);
    if (raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _send(http.Request Function() build, {bool retry = false}) async {
    try {
      return await _once(build());
    } on ApiException {
      rethrow;
    } catch (err) {
      if (!retry) {
        throw ApiException('The network request failed.');
      }
      try {
        return await _once(build());
      } catch (err) {
        if (err is ApiException) rethrow;
        throw ApiException('The network request failed.');
      }
    }
  }

  Future<Map<String, dynamic>> _once(http.Request request) async {
    _authorize(request);
    final response = await _http.send(request).timeout(const Duration(seconds: 30));
    final raw = await response.stream.bytesToString();
    if (response.statusCode == 401 && request.url.path != '/api/auth/login') {
      onUnauthorized?.call();
      throw ApiException('Sign in again.', status: 401, code: 'UNAUTHENTICATED');
    }
    if (response.statusCode >= 400) throw _errorFromBody(response.statusCode, raw);
    if (raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void _authorize(http.BaseRequest request) {
    final value = token();
    if (value != null && value.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $value';
    }
    request.headers['accept'] = 'application/json';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  ApiException _errorFromBody(int status, String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map && json['error'] is Map) {
        final error = json['error'] as Map;
        return ApiException(
          error['message']?.toString() ?? 'Request failed.',
          status: status,
          code: error['code']?.toString() ?? 'REQUEST_FAILED',
        );
      }
    } catch (_) {}
    return ApiException('Request failed.', status: status);
  }
}
