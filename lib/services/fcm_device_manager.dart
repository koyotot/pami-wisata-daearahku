import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import 'auth_session.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Data-only messages do not create an Android system notification.
}

class FcmDeviceManager {
  FcmDeviceManager(this.session);

  final AuthSession session;
  Future<void> _queue = Future.value();
  String? _token;
  int _tokenRevision = 0;
  String? _registeredToken;
  int? _registeredGeneration;
  int? _loggingOutGeneration;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  void attach() {
    session.deviceSessionChanged = sessionChanged;
    session.beforeDeviceLogout = _beforeLogout;
    sessionChanged();
  }

  Future<void> start(
      {required void Function(RemoteMessage) onForeground}) async {
    if (!Platform.isAndroid) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _messageSubscription = FirebaseMessaging.onMessage.listen(onForeground);
    // No notification inbox exists yet; opening a message leaves the current route intact.
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_opened);
    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(updateToken);
    final revision = _tokenRevision;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && revision == _tokenRevision) updateToken(token);
    } catch (_) {
      // FCM availability must not prevent authentication or app startup.
    }
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _opened(initial);
    } catch (_) {
      // FCM availability must not prevent authentication or app startup.
    }
  }

  void _opened(RemoteMessage message) {
    // The backend inbox has no corresponding screen in this app yet.
  }

  void updateToken(String token) {
    if (token.isEmpty) return;
    _tokenRevision++;
    _token = token;
    sessionChanged();
  }

  void sessionChanged() {
    final generation = session.sessionGeneration;
    final token = _token;
    if (!session.deviceSessionReady ||
        token == null ||
        _loggingOutGeneration == generation) {
      return;
    }
    _enqueue(() async {
      if (generation != session.sessionGeneration ||
          !session.deviceSessionReady ||
          _loggingOutGeneration == generation ||
          token != _token ||
          (_registeredGeneration == generation && _registeredToken == token)) {
        return;
      }
      if (_registeredGeneration == generation &&
          _registeredToken != null &&
          _registeredToken != token) {
        await session.unregisterDevice(_registeredToken!);
        _registeredToken = null;
        if (generation != session.sessionGeneration ||
            !session.deviceSessionReady ||
            _loggingOutGeneration == generation ||
            token != _token) {
          return;
        }
      }
      await session.registerDevice(token);
      _registeredGeneration = generation;
      _registeredToken = token;
    });
  }

  Future<void> _beforeLogout() {
    final generation = session.sessionGeneration;
    _loggingOutGeneration = generation;
    return _enqueue(() async {
      final token =
          _registeredGeneration == generation ? _registeredToken : _token;
      if (generation == session.sessionGeneration &&
          token != null &&
          session.deviceSessionReady) {
        await session.unregisterDevice(token);
      }
      if (_registeredGeneration == generation) {
        _registeredGeneration = null;
        _registeredToken = null;
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.catchError((Object _) {});
    return next.catchError((Object _) {});
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
    session.deviceSessionChanged = null;
    session.beforeDeviceLogout = null;
  }
}
