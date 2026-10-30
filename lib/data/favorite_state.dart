import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'business_repository.dart';

class FavoriteState {
  static final instance = FavoriteState();
  final BusinessRepository repository;
  final favorites = RequestState<List<Favorite>>();
  bool _busy = false;

  FavoriteState({BusinessRepository? repository})
      : repository = repository ?? BusinessRepository() {
    session.sessionChanges.addListener(_sessionChanged);
    session.authenticated.addListener(_sessionChanged);
    if (session.authenticated.value && session.deviceSessionReady) load();
  }

  AuthSession get session => repository.api.session;

  void _sessionChanged() {
    favorites.reset();
    _busy = false;
    if (session.authenticated.value && session.deviceSessionReady) load();
  }

  bool isFavorite(String guid) =>
      favorites.data?.any((item) => item.destination.guid == guid) ?? false;

  Future<void> load() => _load();

  Future<void> _load({bool afterMutation = false}) async {
    if (_busy && !afterMutation) return;
    if (!session.authenticated.value || !session.deviceSessionReady) return;
    final generation = session.sessionGeneration;
    await favorites.load(() async {
      final items = <Favorite>[];
      final seen = <String>{};
      var page = 1;
      while (true) {
        final result = await repository.favorites(query: {
          'per_page': '100',
          'page': '$page',
        });
        if (generation != session.sessionGeneration) {
          throw const ApiException('Sesi telah berakhir.', 401);
        }
        items.addAll(
            result.items.where((item) => seen.add(item.destination.guid)));
        final lastPage = result.meta?['last_page'];
        if (lastPage is! int || page >= lastPage) break;
        page++;
      }
      return items;
    });
  }

  Future<void> toggle(String guid) async {
    if (!session.authenticated.value || !session.deviceSessionReady) {
      throw const ApiException('Silakan masuk kembali.', 401);
    }
    if (_busy || favorites.loading || favorites.data == null) return;
    _busy = true;
    final generation = session.sessionGeneration;
    try {
      if (isFavorite(guid)) {
        await repository.removeFavorite(guid);
      } else {
        await repository.addFavorite(guid);
      }
      if (generation == session.sessionGeneration) {
        await _load(afterMutation: true);
      }
    } finally {
      if (generation == session.sessionGeneration) _busy = false;
    }
  }

  void dispose() {
    session.sessionChanges.removeListener(_sessionChanged);
    session.authenticated.removeListener(_sessionChanged);
    favorites.dispose();
  }
}
