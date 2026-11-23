import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AnimeFriendsApi {
  AnimeFriendsApi({
    http.Client? client,
    FlutterSecureStorage? storage,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  String _baseUrl = '';
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isConfigured => _baseUrl.isNotEmpty;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> restoreSession() async {
    _baseUrl = (await _storage.read(key: 'api_base_url') ?? '').trim();
    _token = await _storage.read(key: 'auth_token');
  }

  Future<void> configure(String value) async {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        parsed.scheme != 'https' ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const ApiException(
        'Enter a public HTTPS backend URL without credentials or query parameters.',
      );
    }
    final nextBaseUrl = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (_baseUrl.isNotEmpty && _baseUrl != nextBaseUrl) {
      await clearSession();
    }
    _baseUrl = nextBaseUrl;
    await _storage.write(key: 'api_base_url', value: _baseUrl);
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearSession() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    return _request('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    return _request('POST', path, body: body);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? body}) async {
    return _request('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _request('DELETE', path);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (!isConfigured) {
      throw const ApiException('Backend URL is not configured yet.');
    }

    final base = Uri.parse(_baseUrl);
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: query,
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (isAuthenticated) 'Authorization': 'Bearer $_token',
    };

    try {
      late http.Response response;
      final encodedBody = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw const ApiException('Unsupported API method.');
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The backend returned an invalid response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          decoded['message']?.toString() ?? 'Request failed.',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The backend returned invalid JSON.');
    } on http.ClientException {
      throw const ApiException('Could not connect to the backend.');
    } catch (error) {
      if (error.toString().contains('TimeoutException')) {
        throw const ApiException('The backend took too long to respond.');
      }
      rethrow;
    }
  }

  void dispose() => _client.close();
}
