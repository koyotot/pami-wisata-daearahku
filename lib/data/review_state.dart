import '../services/auth_session.dart';
import 'business_repository.dart';

Future<List<Review>> loadAllReviews(BusinessRepository repository,
    {String? destinationGuid}) async {
  final session = repository.api.session;
  final generation = session.sessionGeneration;
  final items = <Review>[];
  final seen = <String>{};
  var page = 1;
  while (true) {
    final query = {'page': '$page', 'per_page': '50'};
    final result = destinationGuid == null
        ? await repository.reviews(query: query)
        : await repository.destinationReviews(destinationGuid, query: query);
    if (destinationGuid == null && !session.isCurrentGeneration(generation)) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    for (final item in result.items) {
      if (seen.add(item.guid)) items.add(item);
    }
    final lastPage = result.meta?['last_page'];
    if (lastPage is! int || page >= lastPage) break;
    page++;
  }
  return items;
}
