import '../services/api_client.dart';

/// Resource data retains Laravel GUIDs and fields without inventing legacy IDs.
class Category {
  final Json json;
  Category(this.json) {
    guid;
    name;
  }
  String get guid => json['guid'] as String;
  String get name => json['name'] as String;
}

class Destination {
  final Json json;
  Destination(this.json) {
    guid;
    name;
  }
  String get guid => json['guid'] as String;
  String get name => json['name'] as String;
  Category? get category =>
      json['category'] is Json ? Category(json['category'] as Json) : null;
}

class Favorite {
  final Json json;
  Favorite(this.json) {
    guid;
    destination;
  }
  String get guid => json['guid'] as String;
  Destination get destination => Destination(json['destination'] as Json);
}

/// Booking is also the API representation of a legacy Pendaftar.
class Booking {
  final Json json;
  Booking(this.json) {
    guid;
  }
  String get guid => json['guid'] as String;
  String get visitorName => json['visitor_name'] as String;
  String get destinationName => json['destination_name'] as String;
  String get status => json['status'] as String;
}

class BusinessRepository {
  final ApiClient api;
  BusinessRepository([ApiClient? api]) : api = api ?? ApiClient();
  String _path(String path, Map<String, String>? query) => Uri(
          path: path,
          queryParameters: query == null || query.isEmpty ? null : query)
      .toString();
  String _id(String guid) => Uri.encodeComponent(guid);

  Future<ApiPage<Category>> categories({Map<String, String>? query}) =>
      api.collection(_path('categories', query), Category.new);
  Future<ApiPage<Destination>> destinations({Map<String, String>? query}) =>
      api.collection(_path('destinations', query), Destination.new);
  Future<Destination> destination(String guid) async =>
      Destination(await api.object('GET', 'destinations/${_id(guid)}'));
  Future<ApiPage<Favorite>> favorites({Map<String, String>? query}) => api
      .collection(_path('favorites', query), Favorite.new, authenticated: true);
  Future<Favorite> addFavorite(String guid) async => Favorite(
      await api.object('PUT', 'favorites/${_id(guid)}', authenticated: true));
  Future<void> removeFavorite(String guid) async {
    await api.object('DELETE', 'favorites/${_id(guid)}', authenticated: true);
  }

  Future<ApiPage<Booking>> bookings({Map<String, String>? query}) => api
      .collection(_path('bookings', query), Booking.new, authenticated: true);
  Future<Booking> booking(String guid) async => Booking(
      await api.object('GET', 'bookings/${_id(guid)}', authenticated: true));
  Future<Booking> createBooking(Json fields, String idempotencyKey) async =>
      Booking(await api.object('POST', 'bookings',
          authenticated: true,
          body: fields,
          headers: {'Idempotency-Key': idempotencyKey}));
}
