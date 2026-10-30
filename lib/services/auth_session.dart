import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../data/app_data.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
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

  Future<Map<String, dynamic>> _sendEnvelope(String method, String path,
      {Map<String, dynamic>? body,
      String? token,
      Map<String, String>? headers}) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme) ||
        (!kDebugMode && base.scheme != 'https')) {
      throw const ApiException(
          'Konfigurasi API_BASE_URL belum valid. Gunakan HTTPS untuk rilis.');
    }
    try {
      final request = http.Request(method,
          Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',

        // Khusus Android Emulator + Laragon development
        if (kDebugMode && base.host == '127.0.0.1' && base.port == 8080)
          'Host': 'pami-wisata-daerahku-api.test',

        if (token != null) 'Authorization': 'Bearer $token',
        ...?headers,
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> decoded = {};
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {/* Non-JSON error pages are never shown to users. */}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errors = decoded['errors'];
        final validation = errors is Map
            ? errors.values
                .whereType<List>()
                .expand((v) => v)
                .whereType<String>()
                .join('\n')
            : '';
        throw ApiException(
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
            response.statusCode);
      }
      if (!decoded.containsKey('data')) {
        throw const ApiException('Respons layanan tidak valid.');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Koneksi habis waktu. Silakan coba lagi.');
    } catch (_) {
      throw const ApiException(
          'Tidak dapat terhubung ke layanan. Periksa koneksi Anda.');
    }
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
  Future<void> google(String idToken) =>
      _authenticate('auth/google', {'id_token': idToken});
  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
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
      await me();
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
      {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final generation = _generation;
    final token = _tokens?['access_token'] as String?;
    if (token == null) throw const ApiException('Silakan masuk kembali.', 401);
    Future<Map<String, dynamic>> send(String accessToken) =>
        _sendEnvelope(method, path,
            body: body, token: accessToken, headers: headers);
    Map<String, dynamic> result;
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

  Future<void> me() async {
    final generation = _generation;
    final data = await request('GET', 'auth/me');
    if (generation != _generation || _logoutGeneration == generation) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    try {
      _user(data);
    } catch (_) {
      if (generation == _generation) await clear();
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
    if (generation == _generation) _user(data);
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
