import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth_session.dart';
import 'business_repository.dart';
import 'app_data.dart';

/// Retains an uncertain booking until the identical request is resolved.
class BookingIntent {
  static bool _busy = false;
  final BusinessRepository repository;
  final FlutterSecureStorage storage;

  BookingIntent({BusinessRepository? repository, FlutterSecureStorage? storage})
      : repository = repository ?? BusinessRepository(),
        storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, dynamic>?> pending(String userGuid) async {
    if (currentUser?.isLaravel != true || currentUser?.id != userGuid) {
      throw const ApiException('Sesi tidak valid.', 401);
    }
    final saved = await storage.read(key: 'booking_intent_$userGuid');
    if (saved == null) return null;
    final intent = jsonDecode(saved) as Map<String, dynamic>;
    return jsonDecode(intent['fields'] as String) as Map<String, dynamic>;
  }

  Future<Booking> submit(String userGuid, Map<String, dynamic> fields,
      {bool reconcile = false}) async {
    if (_busy) throw const ApiException('Pendaftaran sedang diproses.');
    _busy = true;
    final session = repository.api.session;
    final generation = session.sessionGeneration;
    final storageKey = 'booking_intent_$userGuid';
    try {
      if (currentUser?.isLaravel != true || currentUser?.id != userGuid) {
        throw const ApiException('Sesi tidak valid.', 401);
      }
      final encodedFields = jsonEncode(fields);
      var requestFields = fields;
      final saved = await storage.read(key: storageKey);
      String key;
      if (saved != null) {
        if (!reconcile) {
          throw const ApiException(
              'Pendaftaran sebelumnya belum dipastikan. Coba lagi untuk memeriksa hasilnya.');
        }
        final intent = jsonDecode(saved) as Map<String, dynamic>;
        requestFields =
            jsonDecode(intent['fields'] as String) as Map<String, dynamic>;
        key = intent['key'] as String;
      } else {
        final random = Random.secure();
        key = List.generate(32,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        await storage.write(
            key: storageKey,
            value: jsonEncode({'fields': encodedFields, 'key': key}));
      }
      if (generation != session.sessionGeneration) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      Booking created;
      try {
        created = await repository.createBooking(requestFields, key);
      } on ApiException catch (error) {
        if (saved == null &&
            (error.status == 422 || error.status == 409) &&
            generation == session.sessionGeneration) {
          await storage.delete(key: storageKey);
        }
        rethrow;
      }
      final booking = await repository.booking(created.guid);
      if (generation != session.sessionGeneration) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      final data = booking.json;
      if (data['booking_number'] is! String ||
          data['status'] is! String ||
          data['destination_guid'] is! String ||
          data['visit_date'] is! String ||
          data['visitor_name'] is! String ||
          data['visitor_email'] is! String ||
          data['visitor_phone'] is! String ||
          data['destination_name'] is! String ||
          data['quantity'] is! int ||
          (data['notes'] != null && data['notes'] is! String)) {
        throw const ApiException(
            'Hasil pendaftaran belum diketahui. Coba lagi.');
      }
      await storage.delete(key: storageKey);
      if (generation != session.sessionGeneration) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      return booking;
    } finally {
      _busy = false;
    }
  }
}
