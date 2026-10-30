import '../services/api_client.dart';
import 'business_repository.dart';

/// Independent state for each catalog screen. Reloads ignore older responses.
class CatalogState {
  final BusinessRepository repository;
  final categories = RequestState<List<Category>>();
  final destinations = RequestState<List<Destination>>();

  CatalogState([BusinessRepository? repository])
      : repository = repository ?? BusinessRepository();

  Future<List<T>> _allPages<T>(
      Future<ApiPage<T>> Function(Map<String, String>) fetch,
      String Function(T) guid,
      Map<String, String> query) async {
    final items = <T>[];
    final seen = <String>{};
    var page = 1;
    while (true) {
      final result =
          await fetch({...query, 'per_page': '100', 'page': '$page'});
      items.addAll(result.items.where((item) => seen.add(guid(item))));
      final lastPage = result.meta?['last_page'];
      if (lastPage is! int || page >= lastPage) break;
      page++;
    }
    return items;
  }

  Future<void> loadCategories() => categories.load(() => _allPages(
      (query) => repository.categories(query: query),
      (category) => category.guid, {}));

  Future<void> loadDestinations({String? category, String? search}) =>
      destinations.load(() => _allPages(
            (query) => repository.destinations(query: query),
            (destination) => destination.guid,
            {
              if (category != null && category.isNotEmpty) 'category': category,
              if (search != null && search.trim().isNotEmpty)
                'search': search.trim(),
            },
          ));

  void dispose() {
    categories.dispose();
    destinations.dispose();
  }
}
