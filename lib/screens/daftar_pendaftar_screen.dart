import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import '../services/api_client.dart';
import 'admin_common.dart';
import 'operations_booking_screen.dart';

/// Legacy history entry point; decisions always open the explicit claim flow.
class DaftarPendaftarScreen extends StatefulWidget {
  const DaftarPendaftarScreen({super.key, this.repository, this.session});
  final BusinessRepository? repository;
  final AuthSession? session;
  @override
  State<DaftarPendaftarScreen> createState() => _DaftarPendaftarScreenState();
}

class _DaftarPendaftarScreenState extends State<DaftarPendaftarScreen> {
  late final AuthSession _session =
      widget.session ?? widget.repository?.api.session ?? AuthSession.instance;
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final int _generation = _session.sessionGeneration;
  late final int? _role = _session.role;
  late final PagedListController<Booking> _list;
  String? _status;
  bool _accessRevoked = false;
  bool get _valid =>
      mounted &&
      _session.isCurrentGeneration(_generation) &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      _session.role == _role &&
      canAccessAdmin(_role);

  @override
  void initState() {
    super.initState();
    _list = PagedListController<Booking>(
        session: _session,
        keyOf: (booking) => booking.guid,
        fetchPage: (page, filters) => _repository.adminBookings(
            query: {...filters, 'page': '$page', 'per_page': '50'}))
      ..addListener(_changed);
    if (_valid) _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!_valid || _accessRevoked) return;
    await _list.load(filters: {if (_status != null) 'status': _status!});
    final error = _list.error;
    if (_valid &&
        error is ApiException &&
        (error.status == 403 || error.status == 404)) {
      setState(() => _accessRevoked = true);
      try {
        await _session.me();
      } catch (_) {/* Session resolves invalid credentials. */}
    }
  }

  Future<void> _open(Booking booking) async {
    if (!_valid) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperationsBookingScreen(
            bookingGuid: booking.guid,
            repository: _repository,
            session: _session)));
    if (_valid) await _load();
  }

  @override
  void dispose() {
    _list
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    final rows = _list.error == null ? _list.items : <Booking>[];
    return AdminPage(
        badge: 'DATA PENGUNJUNG',
        title: 'Data Pendaftar',
        subtitle: 'Riwayat booking dari Laravel',
        onRefresh: _load,
        slivers: [
          SliverToBoxAdapter(
              child: AdminFilterChips<String?>(
                  options: [
                ('Semua', null),
                for (final status in kBookingStatuses)
                  (bookingStatusLabel(status), status)
              ],
                  selected: _status,
                  onSelected: (status) {
                    setState(() => _status = status);
                    _load();
                  })),
          if (_accessRevoked)
            adminErrorSliver(
                'Akses destinasi berubah. Kembali dan pilih ulang destinasi.',
                () async {
              await Navigator.maybePop(context);
            })
          else if (_list.loading)
            adminLoadingSliver()
          else if (_list.error != null)
            adminErrorSliver(adminErrorMessage(_list.error!), _load)
          else if (rows.isEmpty)
            adminEmptySliver(Icons.people_outline, 'Belum Ada Pendaftar',
                'Tidak ada pendaftar dengan status ini.')
          else
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final booking = rows[index];
                      return Card(
                          key: ValueKey(booking.guid),
                          child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(booking.visitorName),
                              subtitle: Text(
                                  '${booking.destinationName}\n${visitDay(booking.visitDate)} ? ${booking.quantity} orang\n${bookingStatusLabel(booking.status)}'),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _open(booking)));
                    })),
        ]);
  }
}
