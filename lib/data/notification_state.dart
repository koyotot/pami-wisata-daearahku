import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';

class InboxItem {
  InboxItem(this.json);
  final Json json;
  String get guid => json['guid'] as String;
  String? get bookingGuid => json['booking_guid'] as String?;
  String get title => json['title'] as String;
  String get body => json['body'] as String;
  bool get unread => json['read_at'] == null;
  DateTime? get createdAt =>
      DateTime.tryParse(json['created_at'] as String? ?? '');
}

/// Only authenticated Laravel inbox data supplies the badge and activity list.
class NotificationState extends ChangeNotifier {
  NotificationState([ApiClient? client]) : api = client ?? ApiClient() {
    api.session.sessionChanges.addListener(_sessionChanged);
  }
  final ApiClient api;
  final inbox = RequestState<List<InboxItem>>();
  final count = RequestState<int>();
  bool _disposed = false;

  bool get _allowed =>
      api.session.deviceSessionReady &&
      api.session.authenticated.value &&
      api.session.role == 0;

  void _sessionChanged() {
    inbox.reset();
    count.reset();
    notifyListeners();
  }

  Future<void> refreshCount() async {
    if (!_allowed) return;
    await count.load(() async {
      final data = await api.object('GET', 'notifications/unread-count',
          authenticated: true);
      final value = data['unread_count'];
      if (value is! int || value < 0) {
        throw const ApiException('Jumlah notifikasi tidak valid.');
      }
      return value;
    });
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (!_allowed) return;
    await Future.wait([
      refreshCount(),
      inbox.load(() async {
        final items = <InboxItem>[];
        final seen = <String>{};
        for (var page = 1; page <= 200; page++) {
          final result = await api.collection(
              'notifications?page=$page', InboxItem.new,
              authenticated: true);
          items.addAll(result.items.where((item) => seen.add(item.guid)));
          final last = result.meta?['last_page'];
          if (last is! int || page >= last) return items;
        }
        throw const ApiException(
            'Daftar aktivitas terlalu panjang. Coba lagi nanti.');
      }),
    ]);
  }

  Future<void> markRead(InboxItem item) async {
    if (!_allowed || !item.unread) return;
    final generation = api.session.sessionGeneration;
    await api.object(
        'PATCH', 'notifications/${Uri.encodeComponent(item.guid)}/read',
        authenticated: true);
    if (_disposed || !api.session.isCurrentGeneration(generation)) return;
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    api.session.sessionChanges.removeListener(_sessionChanged);
    inbox.dispose();
    count.dispose();
    super.dispose();
  }
}
