import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../services/api_client.dart';
import 'admin_common.dart';
import 'operations_booking_screen.dart';
import 'operations_dashboard/operations_dashboard.dart'
    show OperationsPage, showOperationsFilters;
import '../../theme/app_colors.dart';
import '../../widgets/operations_chrome.dart';

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
  Map<String, String> _filters = {};
  String? _destinationLabel;
  bool _accessRevoked = false;
  final Map<String?, GlobalKey> _statusKeys = {};
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
    if (_role == 1) {
      final now = DateTime.now().toUtc();
      _filters = {
        'from': isoDay(DateTime(now.year, now.month)),
        'to': isoDay(DateTime(now.year, now.month + 1, 0)),
      };
    }
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

  Future<void> _filter() async {
    if (!_valid || _accessRevoked) return;
    final revision = _session.sessionChanges.value;
    var destinationLabel = _destinationLabel;
    final result = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: _filters,
        home: true,
        destinationLabel: _destinationLabel,
        onDestinationLabelSelected: (label) => destinationLabel = label);
    if (result == null ||
        !_valid ||
        _accessRevoked ||
        revision != _session.sessionChanges.value) return;
    setState(() {
      _filters = result;
      _destinationLabel =
          result['destination_guid'] == null ? null : destinationLabel;
    });
    await _load();
  }

  bool _matchesFilters(Booking booking) {
    if (_role != 1) return true;
    // shortcut: filter the loaded history (up to 10,000 rows); use server filters when the list API supports them.
    final destination = _filters['destination_guid'];
    final from = _filters['from'];
    final to = _filters['to'];
    final day = visitDay(booking.visitDate);
    return (destination == null || booking.destinationGuid == destination) &&
        (from == null || day.compareTo(from) >= 0) &&
        (to == null || day.compareTo(to) <= 0);
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
    final rows = _list.error == null
        ? _list.items.where(_matchesFilters).toList()
        : <Booking>[];
    if (_role == 1)
      return OperationsPage(
          role: _role,
          title: 'Data Pendaftar',
          subtitle: 'Riwayat booking destinasi yang ditugaskan',
          embedded: false,
          onRefresh: _load,
          children: [
            OperationsFilterBar(
                filters: _filters,
                keyPrefix: 'registrants',
                destinationLabel: _destinationLabel,
                dateTooltip: 'Tanggal kunjungan · kalender lokal destinasi',
                onDestinationPressed: _accessRevoked ? null : _filter,
                onDatePressed: _accessRevoked ? null : _filter),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final item in <(String, String?)>[
                    ('Semua', null),
                    for (final status in kBookingStatuses)
                      (bookingStatusLabel(status), status),
                  ])
                    Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Semantics(
                            selected: _status == item.$2,
                            child: TextButton(
                                key: _statusKeys.putIfAbsent(
                                    item.$2, () => GlobalKey()),
                                style: TextButton.styleFrom(
                                    foregroundColor: _status == item.$2
                                        ? AppColors.surface
                                        : AppColors.blueDeep,
                                    backgroundColor: _status == item.$2
                                        ? AppColors.blue
                                        : AppColors.surface,
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg,
                                        vertical: AppSpacing.sm),
                                    shape: StadiumBorder(
                                        side: BorderSide(
                                            color: _status == item.$2
                                                ? AppColors.blue
                                                : AppColors.border))),
                                onPressed: !_valid || _accessRevoked
                                    ? null
                                    : () {
                                        setState(() => _status = item.$2);
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          final chipContext =
                                              _statusKeys[item.$2]
                                                  ?.currentContext;
                                          if (mounted && chipContext != null)
                                            Scrollable.of(chipContext)
                                                .position
                                                .ensureVisible(
                                                    chipContext
                                                        .findRenderObject()!,
                                                    alignment: .5,
                                                    duration: MediaQuery
                                                            .disableAnimationsOf(
                                                                context)
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 200));
                                        });
                                        _load();
                                      },
                                child: Text(item.$1,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700))))),
                ])),
            const SizedBox(height: 16),
            if (_list.loading) const LinearProgressIndicator(),
            if (_accessRevoked)
              const Text(
                  'Akses destinasi berubah. Kembali ke pilihan destinasi.')
            else if (_list.error != null)
              Text(
                  '${adminErrorMessage(_list.error!)}\nTarik turun untuk menyinkronkan.')
            else if (!_list.loading && rows.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Belum ada pendaftar untuk filter ini.',
                      textAlign: TextAlign.center)),
            for (final booking in rows)
              Padding(
                  key: ValueKey(booking.guid),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Material(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border)),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          isThreeLine: true,
                          titleAlignment: ListTileTitleAlignment.center,
                          leading: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                  color: AppColors.blueTint,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(PhosphorIconsRegular.users,
                                  color: AppColors.blue, size: 20)),
                          title: Text(booking.visitorName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy)),
                          subtitle: Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                  '${booking.destinationName} · ${visitDay(booking.visitDate)}\n'
                                  '${booking.quantity} orang · ${bookingStatusLabel(booking.status)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.8,
                                      color: AppColors.textSecondary))),
                          trailing: const Icon(PhosphorIconsRegular.caretRight,
                              color: AppColors.navy, size: 20),
                          onTap: () => _open(booking)))),
          ]);
    return AdminPage(
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
            adminEmptySliver(PhosphorIconsRegular.users, 'Belum Ada Pendaftar',
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
                              trailing:
                                  const Icon(PhosphorIconsRegular.caretRight),
                              onTap: () => _open(booking)));
                    })),
        ]);
  }
}
