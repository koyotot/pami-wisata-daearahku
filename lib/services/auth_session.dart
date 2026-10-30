import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../data/app_data.dart';

class ApiException implements Exception {
  final String message;
  final int? status;

  /// Stable machine-readable Laravel `code` (e.g. `insufficient_capacity`), or a local
  /// transport code: `timeout`, `network`, `invalid_response`.
  final String? code;

  /// Optional Laravel `context` object that accompanies a structured conflict.
  final Map<String, dynamic>? context;
  const ApiException(this.message, [this.status, this.code, this.context]);

  /// True when the request may have reached the server and its effect is unknown, so a
  /// mutation must be reconciled rather than treated as failed or blindly repeated.
  bool get outcomeUnknown =>
      code == 'timeout' ||
      code == 'network' ||
      code == 'invalid_response' ||
      (status != null && status! >= 500);

  @override
  String toString() => message;
}

/// A file part for [AuthSession.requestMultipart]; bytes are kept so a retried request
/// after token refresh can rebuild the multipart body.
class UploadFile {
  final String field;
  final List<int> bytes;
  final String filename;
  const UploadFile(this.field, this.bytes, this.filename);
}

class BinaryResponse {
  final Uint8List bytes;
  final String contentType;
  const BinaryResponse(this.bytes, this.contentType);
}

abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage;
  const SecureSessionStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read() => storage.read(key: 'laravel_session');
  @override
  Future<void> write(String value) =>
      storage.write(key: 'laravel_session', value: value);
  @override
  Future<void> clear() => storage.delete(key: 'laravel_session');
}

class AuthSession {
  static final instance = AuthSession();
  final http.Client client;
  final SessionStore store;
  final String baseUrl;
  final ValueNotifier<bool> authenticated = ValueNotifier(false);
  final ValueNotifier<int> sessionChanges = ValueNotifier(0);
  Map<String, dynamic>? _tokens;
  Future<void>? _refreshing;
  int? _refreshGeneration;
  int _generation = 0;
  int? _logoutGeneration;
  int get sessionGeneration => _generation;
  bool isCurrentGeneration(int generation) =>
      generation == _generation && _logoutGeneration != generation;
  int? role;
  String? status;
  bool authenticating = false;
  bool deviceSessionReady = false;
  void Function()? deviceSessionChanged;
  Future<void> Function()? beforeDeviceLogout;
  Future<void> _storageQueue = Future.value();
  Future<void> _persist(Future<void> Function() action) {
    final next = _storageQueue.then((_) => action());
    _storageQueue = next.catchError((Object _) {});
    return next;
  }

  AuthSession(
      {http.Client? client,
      SessionStore? store,
      this.baseUrl = const String.fromEnvironment('API_BASE_URL')})
      : client = client ?? http.Client(),
        store = store ?? const SecureSessionStore();

  Uri _uri(String path) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme) ||
        (!kDebugMode && base.scheme != 'https')) {
      throw const ApiException(
          'Konfigurasi API_BASE_URL belum valid. Gunakan HTTPS untuk rilis.');
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path');
  }

  Map<String, String> _headers(
      {String? token, bool json = true, Map<String, String>? extra}) {
    final base = Uri.parse(baseUrl);
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',

      // Khusus Android Emulator + Laragon development
      if (kDebugMode && base.host == '127.0.0.1' && base.port == 8080)
        'Host': 'pami-wisata-daerahku-api.test',

      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  /// Sends [request] and maps transport failures; non-2xx handling stays with callers.
  Future<http.Response> _transport(http.BaseRequest request) async {
    try {
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
          'Koneksi habis waktu. Silakan coba lagi.', null, 'timeout');
    } catch (_) {
      throw const ApiException(
          'Tidak dapat terhubung ke layanan. Periksa koneksi Anda.',
          null,
          'network');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      /* Non-JSON error pages are never shown to users. */
      return {};
    }
  }

  ApiException _failure(http.Response response, Map<String, dynamic> decoded) {
    final errors = decoded['errors'];
    final validation = errors is Map
        ? errors.values
            .whereType<List>()
            .expand((v) => v)
            .whereType<String>()
            .join('\n')
        : '';
    final code = decoded['code'] is String ? decoded['code'] as String : null;
    final context = decoded['context'] is Map<String, dynamic>
        ? decoded['context'] as Map<String, dynamic>
        : null;
    return ApiException(
        response.statusCode == 422 && validation.isNotEmpty
            ? validation
            : switch (response.statusCode) {
                401 =>
                  'Sesi atau kredensial tidak valid. Silakan masuk kembali.',
                403 => 'Akses tidak diizinkan.',
                404 => 'Wisata atau data tidak ditemukan.',
                409 => decoded['message'] is String
                    ? decoded['message'] as String
                    : 'Terjadi konflik. Silakan coba lagi.',
                429 => 'Terlalu banyak percobaan. Coba lagi nanti.',
                _ => 'Layanan sedang bermasalah. Silakan coba lagi.',
              },
        response.statusCode,
        code,
        context);
  }

  Map<String, dynamic> _envelope(http.Response response) {
    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response, decoded);
    }
    if (!decoded.containsKey('data')) {
      throw ApiException('Respons layanan tidak valid.', response.statusCode,
          'invalid_response');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _sendEnvelope(String method, String path,
      {Map<String, dynamic>? body,
      String? token,
      Map<String, String>? headers}) async {
    final request = http.Request(method, _uri(path));
    request.headers.addAll(_headers(token: token, extra: headers));
    if (body != null) request.body = jsonEncode(body);
    return _envelope(await _transport(request));
  }

  Future<Map<String, dynamic>> _sendMultipart(String method, String path,
      {required Map<String, String> fields,
      required List<UploadFile> files,
      String? token}) async {
    final request = http.MultipartRequest(method, _uri(path));
    request.headers.addAll(_headers(token: token, json: false));
    request.fields.addAll(fields);
    for (final file in files) {
      // Laravel validates the real file content, not the client-declared type.
      request.files.add(http.MultipartFile.fromBytes(file.field, file.bytes,
          filename: file.filename));
    }
    return _envelope(await _transport(request));
  }

  Future<BinaryResponse> _sendBinary(String path, {String? token}) async {
    final request = http.Request('GET', _uri(path));
    request.headers.addAll(_headers(token: token, json: false));
    final response = await _transport(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response, _decode(response));
    }
    return BinaryResponse(response.bodyBytes,
        response.headers['content-type'] ?? 'application/octet-stream');
  }

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body, String? token}) async {
    final data =
        (await _sendEnvelope(method, path, body: body, token: token))['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Respons layanan tidak valid.');
    }
    return data;
  }

  Future<Map<String, dynamic>> publicEnvelope(String method, String path,
          {Map<String, dynamic>? body}) =>
      _sendEnvelope(method, path, body: body);

  void _user(Map<String, dynamic> data) {
    final nextRole = data['role'];
    if (data['guid'] is! String ||
        (data['guid'] as String).isEmpty ||
        data['name'] is! String ||
        data['email'] is! String ||
        nextRole is! int ||
        ![0, 1, 2].contains(nextRole) ||
        data['status'] != 'active') {
      throw const ApiException(
          'Akun tidak aktif atau respons identitas tidak valid.', 403);
    }
    role = nextRole;
    status = 'active';
    currentUser = User(
        id: data['guid'] as String,
        namaLengkap: data['name'] as String,
        email: data['email'] as String,
        noTelepon: data['phone'] as String? ?? '',
        password: '',
        createdAt: DateTime.now(),
        isLaravel: true);
  }

  Future<void> _save(Map<String, dynamic> data, int generation) async {
    if (generation != _generation) return;
    if (data['access_token'] is! String ||
        data['refresh_token'] is! String ||
        data['user'] is! Map<String, dynamic>) {
      throw const ApiException('Respons sesi tidak valid.');
    }
    // Both rotated tokens are persisted together in one secure-storage value.
    await _persist(() async {
      if (generation == _generation) await store.write(jsonEncode(data));
    });
    if (generation != _generation) return;
    _tokens = data;
  }

  Future<void> login(String email, String password) =>
      _authenticate('auth/login', {'email': email, 'password': password});
  Future<void> register(
          String name, String email, String password, String confirmation) =>
      _authenticate('auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': confirmation
      });

  /// Google Login hanya untuk role 0; sesi role lain ditolak dan dibersihkan.
  Future<void> google(String idToken) =>
      _authenticate('auth/google', {'id_token': idToken},
          allowedRoles: const {0});
  Future<void> _authenticate(String path, Map<String, dynamic> body,
      {Set<int>? allowedRoles}) async {
    var generation = ++_generation;
    _logoutGeneration = null;
    authenticating = true;
    role = null;
    status = null;
    currentUser = null;
    authenticated.value = false;
    sessionChanges.value++;
    try {
      if (_tokens != null && deviceSessionReady) {
        try {
          await beforeDeviceLogout?.call();
        } catch (_) {}
      }
      if (generation != _generation || _logoutGeneration == generation) {
        throw const ApiException('Permintaan masuk sudah dibatalkan.');
      }
      generation = ++_generation;
      _tokens = null;
      deviceSessionReady = false;
      sessionChanges.value++;
      deviceSessionChanged?.call();
      await _persist(() async {
        if (generation == _generation) await store.clear();
      });
      if (generation != _generation) {
        throw const ApiException('Permintaan masuk sudah dibatalkan.');
      }
      final data = await _send('POST', path, body: body);
      await _save(data, generation);
      if (generation != _generation) {
        throw const ApiException('Permintaan masuk sudah dibatalkan.');
      }
      await me(allowedRoles: allowedRoles);
      if (generation == _generation) authenticating = false;
    } catch (_) {
      if (generation == _generation && _logoutGeneration != generation) {
        authenticating = false;
        await clear();
      }
      rethrow;
    }
  }

  Future<void> restore() async {
    final generation = _generation;
    try {
      final raw = await store.read();
      if (raw == null || generation != _generation) return;
      _tokens = jsonDecode(raw) as Map<String, dynamic>;
      await me();
    } catch (_) {
      if (generation == _generation) await clear();
    }
  }

  Future<void> refresh() {
    if (_refreshing != null && _refreshGeneration == _generation) {
      return _refreshing!;
    }
    final generation = _generation;
    _refreshGeneration = generation;
    final pending = _refresh();
    _refreshing = pending;
    return pending.whenComplete(() {
      if (identical(_refreshing, pending)) {
        _refreshing = null;
        _refreshGeneration = null;
      }
    });
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final token = _tokens?['refresh_token'];
    if (token is! String) {
      await clear();
      throw const ApiException('Silakan masuk kembali.', 401);
    }
    try {
      final data =
          await _send('POST', 'auth/refresh', body: {'refresh_token': token});
      await _save(data, generation);
    } catch (_) {
      if (generation == _generation) await clear();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final data = (await requestEnvelope(method, path, body: body))['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Respons layanan tidak valid.');
    }
    return data;
  }

  Future<Map<String, dynamic>> requestEnvelope(String method, String path,
          {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _authorized((token) => _sendEnvelope(method, path,
          body: body, token: token, headers: headers));

  /// Authenticated multipart request (e.g. image upload). Use POST with a `_method`
  /// field to spoof PATCH, because PHP does not parse multipart bodies for PATCH.
  Future<Map<String, dynamic>> requestMultipart(String method, String path,
          {Map<String, String> fields = const {},
          List<UploadFile> files = const []}) =>
      _authorized((token) => _sendMultipart(method, path,
          fields: fields, files: files, token: token));

  /// Authenticated binary download (documents, protected images).
  Future<BinaryResponse> requestBytes(String path) =>
      _authorized((token) => _sendBinary(path, token: token));

  /// Unauthenticated binary download (public catalog images).
  Future<BinaryResponse> publicBytes(String path) => _sendBinary(path);

  /// Runs [send] with the current access token, refreshing once on 401 and
  /// discarding any result that belongs to an older session generation.
  Future<T> _authorized<T>(Future<T> Function(String token) send) async {
    final generation = _generation;
    final token = _tokens?['access_token'] as String?;
    if (token == null) throw const ApiException('Silakan masuk kembali.', 401);
    T result;
    try {
      result = await send(token);
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
      if (generation != _generation) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      if (token == _tokens?['access_token']) await refresh();
      if (generation != _generation || _tokens == null) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      try {
        result = await send(_tokens!['access_token'] as String);
      } on ApiException catch (retry) {
        if (retry.status == 401 && generation == _generation) await clear();
        rethrow;
      }
    }
    if (generation != _generation) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    return result;
  }

  Future<void> me({Set<int>? allowedRoles}) async {
    final generation = _generation;
    final data = await request('GET', 'auth/me');
    if (generation != _generation || _logoutGeneration == generation) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    final issuedToken = _tokens?['access_token'] as String?;
    try {
      _user(data);
      if (allowedRoles != null && !allowedRoles.contains(role)) {
        throw const ApiException(
            'Masuk dengan Google hanya untuk pengguna. '
            'Admin wajib masuk dengan email dan password.',
            403);
      }
    } catch (e) {
      if (generation == _generation) {
        await clear();
        // Best-effort: cabut token Laravel yang sempat diterbitkan.
        if (e is ApiException && allowedRoles != null && issuedToken != null) {
          try {
            await _sendEnvelope('POST', 'auth/logout', token: issuedToken);
          } catch (_) {}
        }
      }
      rethrow;
    }
    deviceSessionReady = true;
    authenticated.value = true;
    sessionChanges.value++;
    deviceSessionChanged?.call();
  }

  Future<void> updateProfile(String name, String phone) async {
    final generation = _generation;
    final data =
        await request('PATCH', 'profile', body: {'name': name, 'phone': phone});
    if (!isCurrentGeneration(generation)) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    _user(data);
  }

// =====================================================
// FIREBASE CLOUD MESSAGING — DEVICE REGISTRATION
// =====================================================

  /// Mendaftarkan FCM token ke sesi Laravel yang aktif.
  Future<void> registerDevice(String fcmToken) async {
    if (fcmToken.isEmpty) return;

    final data = await request(
      'PUT',
      'devices',
      body: {
        'token': fcmToken,
        'platform': 'android',
      },
    );

    if (data['registered'] != true) {
      throw const ApiException('Registrasi perangkat gagal.');
    }
  }

  /// Menghapus FCM token dari registrasi perangkat Laravel.
  Future<void> unregisterDevice(String fcmToken) async {
    if (fcmToken.isEmpty) return;

    final data = await request(
      'DELETE',
      'devices',
      body: {
        'token': fcmToken,
      },
    );

    if (data['registered'] != false) {
      throw const ApiException('Gagal menghapus registrasi perangkat.');
    }
  }

// =====================================================
// AUTHENTICATION — LOGOUT
// =====================================================

  Future<void> logout() async {
    final generation = _generation;
    _logoutGeneration = generation;
    authenticating = false;
    role = null;
    status = null;
    currentUser = null;
    authenticated.value = false;
    sessionChanges.value++;
    try {
      try {
        await beforeDeviceLogout?.call();
      } catch (_) {}
      if (_refreshing != null && _refreshGeneration == generation) {
        await _refreshing;
      }
      if (generation == _generation && _tokens != null) {
        await request('POST', 'auth/logout');
      }
    } finally {
      if (generation == _generation) await clear();
    }
  }

  Future<void> clear() async {
    _generation++;
    _logoutGeneration = null;
    authenticating = false;
    _tokens = null;
    role = null;
    status = null;
    deviceSessionReady = false;
    currentUser = null;
    authenticated.value = false;
    sessionChanges.value++;
    deviceSessionChanged?.call();
    await _persist(() => store.clear());
  }
}
