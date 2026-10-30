import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth_session.dart';
import 'app_data.dart';
import 'booking_errors.dart';
import 'business_repository.dart';

/// Outcome of resolving a stored create attempt against the server.
sealed class IntentResolution {
  const IntentResolution();
}

/// There is no stored attempt for the account.
class IntentNone extends IntentResolution {
  const IntentNone();
}

/// The server holds a booking for the attempt; [booking] carries its CURRENT status.
/// The local intent has been deleted.
class IntentCompleted extends IntentResolution {
  final Booking booking;
  const IntentCompleted(this.booking);
}

/// The server never received (or never committed) the attempt. When [replaySafe] the same
/// key and payload may be sent again (idempotent). The local intent is kept.
class IntentNotFound extends IntentResolution {
  final bool replaySafe;
  const IntentNotFound({required this.replaySafe});
}

/// The attempt can never be sent again ([abandoned] on the server, or its key expired).
/// The local intent is kept so the user can clean it up with [BookingIntent.abandon].
class IntentUnusable extends IntentResolution {
  final bool abandoned;
  final bool keyExpired;
  const IntentUnusable({required this.abandoned, required this.keyExpired});
}

/// The attempt was abandoned on the server and the local intent has been deleted.
class IntentAbandoned extends IntentResolution {
  const IntentAbandoned();
}

/// Retains an uncertain booking until the identical request is resolved.
///
/// The intent (payload + Idempotency-Key) is written to secure storage per user GUID BEFORE
/// the POST. It is deleted only when the server outcome is known: a booking exists
/// (success / completed), the server definitively refused it, or the user abandoned it.
/// Any POST is sent at most once per call; an unknown outcome is never retried automatically.
class BookingIntent {
  static bool _busy = false;
  final BusinessRepository repository;
  final FlutterSecureStorage storage;

  BookingIntent({BusinessRepository? repository, FlutterSecureStorage? storage})
      : repository = repository ?? BusinessRepository(),
        storage = storage ?? const FlutterSecureStorage();

  String _storageKey(String userGuid) => 'booking_intent_$userGuid';

  void _requireUser(String userGuid) {
    if (currentUser?.isLaravel != true || currentUser?.id != userGuid) {
      throw const ApiException('Sesi tidak valid.', 401);
    }
  }

  Future<Map<String, dynamic>?> _read(String userGuid) async {
    final saved = await storage.read(key: _storageKey(userGuid));
    if (saved == null) return null;
    return jsonDecode(saved) as Map<String, dynamic>;
  }

  /// Payload of the unresolved attempt, or null.
  Future<Map<String, dynamic>?> pending(String userGuid) async {
    _requireUser(userGuid);
    final intent = await _read(userGuid);
    if (intent == null) return null;
    return jsonDecode(intent['fields'] as String) as Map<String, dynamic>;
  }

  /// Sends [fields] as a new attempt, or - with [reconcile] - re-sends the stored payload and
  /// key unchanged (only after the server reported the attempt as replay-safe or unknown).
  /// Without [reconcile] a stored, unresolved attempt blocks the new one.
  Future<Booking> submit(String userGuid, Map<String, dynamic> fields,
      {bool reconcile = false}) async {
    if (_busy) throw const ApiException('Pendaftaran sedang diproses.');
    _busy = true;
    final session = repository.api.session;
    final generation = session.sessionGeneration;
    final storageKey = _storageKey(userGuid);
    try {
      _requireUser(userGuid);
      final encodedFields = jsonEncode(fields);
      var requestFields = fields;
      final intent = await _read(userGuid);
      String key;
      if (intent != null) {
        if (!reconcile) {
          throw const ApiException(
              'Pendaftaran sebelumnya belum dipastikan. Periksa hasilnya terlebih dahulu.',
              null,
              'intent_unresolved');
        }
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
        // Only a definitive refusal of a freshly created attempt discards it: the server
        // provably created no booking. Unknown outcomes keep the intent for reconciliation.
        if (intent == null && _definitiveRefusal(error)) {
          await storage.delete(key: storageKey);
        }
        rethrow;
      }
      // The create response is the stored creation result; prefer it when complete and
      // otherwise read the current booking.
      var booking = created;
      if (!_validBooking(booking)) {
        booking = await repository.booking(created.guid);
      }
      if (generation != session.sessionGeneration) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      if (!_validBooking(booking)) {
        throw const ApiException(
            'Hasil pendaftaran belum diketahui. Periksa hasilnya sebelum mencoba lagi.',
            null,
            'invalid_response');
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

  /// Asks the server what happened to the stored attempt (`GET booking-intents/{key}`).
  /// Never creates anything. `completed` deletes the intent; other states keep it.
  Future<IntentResolution> reconcile(String userGuid) async {
    if (_busy) throw const ApiException('Pendaftaran sedang diproses.');
    _busy = true;
    final session = repository.api.session;
    final generation = session.sessionGeneration;
    try {
      _requireUser(userGuid);
      final intent = await _read(userGuid);
      if (intent == null) return const IntentNone();
      final state = await repository.bookingIntent(intent['key'] as String);
      if (generation != session.sessionGeneration) {
        throw const ApiException('Sesi telah berakhir.', 401);
      }
      switch (state.state) {
        case 'completed':
          final booking = state.booking;
          if (booking == null || !_validBooking(booking)) {
            throw const ApiException(
                'Hasil pendaftaran belum dapat dibaca. Coba periksa kembali.',
                null,
                'invalid_response');
          }
          await storage.delete(key: _storageKey(userGuid));
          return IntentCompleted(booking);
        case 'not_found':
          return IntentNotFound(replaySafe: state.replaySafe);
        case 'abandoned':
          return IntentUnusable(abandoned: true, keyExpired: state.keyExpired);
        default:
          throw const ApiException(
              'Status percobaan pendaftaran tidak dikenali.',
              null,
              'invalid_response');
      }
    } finally {
      _busy = false;
    }
  }

  /// Safe exit: the server refuses any later create with this key, then the local intent is
  /// deleted. If a booking already exists (`intent_already_completed`, or an expired key
  /// that points at its booking) that booking is returned instead and the intent is deleted.
  Future<IntentResolution> abandon(String userGuid) async {
    if (_busy) throw const ApiException('Pendaftaran sedang diproses.');
    _busy = true;
    final session = repository.api.session;
    final generation = session.sessionGeneration;
    try {
      _requireUser(userGuid);
      final intent = await _read(userGuid);
      if (intent == null) return const IntentNone();
      try {
        final state =
            await repository.abandonBookingIntent(intent['key'] as String);
        if (generation != session.sessionGeneration) {
          throw const ApiException('Sesi telah berakhir.', 401);
        }
        if (state.state != 'abandoned') {
          throw const ApiException(
              'Percobaan pendaftaran belum dapat dibatalkan. Coba lagi.',
              null,
              'invalid_response');
        }
        await storage.delete(key: _storageKey(userGuid));
        return const IntentAbandoned();
      } on ApiException catch (error) {
        final bookingGuid = error.context?['booking_guid'];
        if (error.code == 'intent_already_completed' && bookingGuid is String) {
          final booking = await repository.booking(bookingGuid);
          if (generation != session.sessionGeneration) {
            throw const ApiException('Sesi telah berakhir.', 401);
          }
          await storage.delete(key: _storageKey(userGuid));
          return IntentCompleted(booking);
        }
        rethrow;
      }
    } finally {
      _busy = false;
    }
  }

  /// A refusal after which the server certainly created no booking for this attempt.
  /// A 409 without a recognised code is treated like the domain conflicts it is.
  bool _definitiveRefusal(ApiException error) {
    if (error.status == 422) return true;
    if (error.status != 409) return false;
    return error.code == null || definitiveCreateRejections.contains(error.code);
  }

  bool _validBooking(Booking booking) {
    final data = booking.json;
    return data['booking_number'] is String &&
        data['status'] is String &&
        data['destination_guid'] is String &&
        data['visit_date'] is String &&
        data['visitor_name'] is String &&
        data['visitor_email'] is String &&
        data['visitor_phone'] is String &&
        data['destination_name'] is String &&
        data['quantity'] is int &&
        (data['notes'] == null || data['notes'] is String);
  }
}
