import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/catalog_state.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'api_foundation_test.dart' show Store;

http.Response page(List<Map<String, String>> items, int current, int last) =>
    http.Response(
        jsonEncode({
          'data': items,
          'meta': {'current_page': current, 'last_page': last},
          'links': {}
        }),
        200);

CatalogState catalog(http.Client client) =>
    CatalogState(BusinessRepository(ApiClient(AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: Store(),
        client: client))));

void main() {
  test('loads all pages, forwards filter and removes duplicate GUIDs',
      () async {
    final requests = <Uri>[];
    final state = catalog(MockClient((request) async {
      requests.add(request.url);
      final pageNumber = int.parse(request.url.queryParameters['page']!);
      return page(
          pageNumber == 1
              ? [
                  {'guid': 'a', 'name': 'A'}
                ]
              : [
                  {'guid': 'a', 'name': 'A'},
                  {'guid': 'b', 'name': 'B'}
                ],
          pageNumber,
          2);
    }));
    await state.loadDestinations(category: 'category-guid', search: ' beach ');
    expect(state.destinations.data!.map((d) => d.guid), ['a', 'b']);
    expect(requests.map((r) => r.queryParameters['page']), ['1', '2']);
    for (final request in requests) {
      expect(request.queryParameters['category'], 'category-guid');
      expect(request.queryParameters['search'], 'beach');
    }
    state.dispose();
  });

  test('new filter wins when older request finishes late', () async {
    final old = Completer<http.Response>();
    final state = catalog(MockClient((request) {
      if (request.url.queryParameters['category'] == 'old') return old.future;
      return Future.value(page([
        {'guid': 'new', 'name': 'New'}
      ], 1, 1));
    }));
    final first = state.loadDestinations(category: 'old');
    await state.loadDestinations(category: 'new');
    old.complete(page([
      {'guid': 'old', 'name': 'Old'}
    ], 1, 1));
    await first;
    expect(state.destinations.data!.single.guid, 'new');
    state.dispose();
  });

  test('category error is visible and retry fetches again', () async {
    var calls = 0;
    final state = catalog(MockClient((_) async => ++calls == 1
        ? http.Response('{"message":"unavailable"}', 500)
        : page([
            {'guid': 'cat', 'name': 'Category'}
          ], 1, 1)));
    await state.loadCategories();
    expect(state.categories.error, isA<ApiException>());
    expect(state.categories.data, isNull);
    await state.categories.retry();
    expect(state.categories.error, isNull);
    expect(state.categories.data!.single.guid, 'cat');
    state.dispose();
  });
}
