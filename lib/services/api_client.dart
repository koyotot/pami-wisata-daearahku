import 'package:flutter/foundation.dart';
import 'auth_session.dart';

typedef Json = Map<String, dynamic>;

class ApiPage<T> {
  final List<T> items;
  final Json? meta;
  final Json? links;
  const ApiPage(this.items, this.meta, this.links);
}

class ApiClient {
  final AuthSession session;
  ApiClient([AuthSession? session]) : session = session ?? AuthSession.instance;

  Future<Json> object(String method, String path,
      {bool authenticated = false,
      Json? body,
      Map<String, String>? headers}) async {
    final envelope = await _request(method, path, authenticated, body, headers);
    final data = envelope['data'];
    if (data is! Json) throw const ApiException('Respons layanan tidak valid.');
    return data;
  }

  Future<ApiPage<T>> collection<T>(String path, T Function(Json) map,
      {bool authenticated = false}) async {
    final envelope = await _request('GET', path, authenticated, null, null);
    final data = envelope['data'];
    if (data is! List || data.any((item) => item is! Json)) {
      throw const ApiException('Respons layanan tidak valid.');
    }
    try {
      return ApiPage(data.cast<Json>().map(map).toList(),
          envelope['meta'] as Json?, envelope['links'] as Json?);
    } on TypeError {
      throw const ApiException('Respons layanan tidak valid.');
    }
  }

  Future<Json> _request(String method, String path, bool authenticated,
      Json? body, Map<String, String>? headers) async {
    final generation = session.sessionGeneration;
    final result = authenticated
        ? await session.requestEnvelope(method, path,
            body: body, headers: headers)
        : await session.publicEnvelope(method, path, body: body);
    if (authenticated && generation != session.sessionGeneration) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    return result;
  }
}

/// Ignores obsolete results after reload or dispose; requests are not aborted.
class RequestState<T> extends ChangeNotifier {
  T? data;
  Object? error;
  bool loading = false;
  int _generation = 0;
  bool _disposed = false;
  Future<void> Function()? _retry;

  Future<void> load(Future<T> Function() request) async {
    final generation = ++_generation;
    _retry = () => load(request);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await request();
      if (generation == _generation && !_disposed) data = value;
    } catch (e) {
      if (generation == _generation && !_disposed) error = e;
    } finally {
      if (generation == _generation && !_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _generation++;
    data = null;
    error = null;
    loading = false;
    _retry = null;
    notifyListeners();
  }

  Future<void> retry() async => _retry?.call();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
