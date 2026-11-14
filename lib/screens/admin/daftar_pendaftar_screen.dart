import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../services/api_client.dart';
import 'operations_booking_screen.dart';
import 'operations_dashboard/operations_dashboard.dart'
    show OperationsPage, OperationsSkeleton, showOperationsFilters;
import '../../theme/app_colors.dart';
import '../../widgets/operations_chrome.dart';
import '../../widgets/operations_option_sheet.dart';
import '../../widgets/operations_status.dart';

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
  String _query = '';
  String _sort = 'newest';
  final _search = TextEditingController();
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
    // Superadmin loads everything once and filters/sorts locally, so the
    // status chips can reflect what the server actually returned.
    await _list.load(
        filters: {if (_status != null && _role != 2) 'status': _status!});
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
    _search.dispose();
    _list
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  // ── Superadmin ───────────────────────────────────────────

  static const _sortLabels = {
    'newest': 'Terbaru',
    'oldest': 'Terlama',
    'name': 'Nama A–Z',
  };

  OperationsTone _tone(String status) => switch (status) {
        'pending_approval' => OperationsTone.orange,
        'confirmed' => OperationsTone.green,
        'rejected' => OperationsTone.red,
        'awaiting_payment' ||
        'payment_verification' ||
        'payment_review' =>
          OperationsTone.blue,
        _ => OperationsTone.grey,
      };

  /// Statuses that actually occur in the loaded data, in canonical order.
  List<String> _presentStatuses() {
    final present = {for (final b in _list.items) b.status};
    return [
      for (final status in kBookingStatuses)
        if (present.contains(status)) status,
      for (final status in present)
        if (!kBookingStatuses.contains(status)) status,
    ];
  }

  List<Booking> _superadminRows(String? status) {
    final query = _query.trim().toLowerCase();
    final rows = _list.items.where((b) {
      if (status != null && b.status != status) return false;
      if (query.isEmpty) return true;
      return [b.destinationName, b.visitorName, b.visitorEmail, b.bookingNumber]
          .any((text) => text.toLowerCase().contains(query));
    }).toList();
    DateTime when(Booking b) =>
        b.createdAt ??
        DateTime.tryParse(visitDay(b.visitDate)) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    rows.sort(switch (_sort) {
      'oldest' => (a, b) => when(a).compareTo(when(b)),
      'name' => (a, b) =>
          a.visitorName.toLowerCase().compareTo(b.visitorName.toLowerCase()),
      _ => (a, b) => when(b).compareTo(when(a)),
    });
    return rows;
  }

  Future<void> _pickSort() async {
    final value = await showOperationsOptionSheet(context,
        title: 'Urutkan',
        options: _sortLabels,
        selected: _sort,
        keyPrefix: 'registrants-sort');
    if (value != null && mounted) setState(() => _sort = value);
  }

  Widget _searchField() => DecoratedBox(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: TextField(
          key: const ValueKey('registrants-search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(fontSize: 13, color: AppColors.navy),
          decoration: InputDecoration(
              hintText: 'Cari pendaftar atau destinasi...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 20, color: AppColors.blue),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () => setState(() {
                            _query = '';
                            _search.clear();
                          }),
                      icon: const Icon(PhosphorIconsRegular.x, size: 18)))));

  Widget _statusChips(String? status, List<String> statuses) =>
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final item in <(String, String?)>[
              ('Semua', null),
              for (final s in statuses) (bookingStatusLabel(s), s),
            ])
              Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Semantics(
                      selected: status == item.$2,
                      child: TextButton(
                          key: ValueKey('registrants-status-${item.$2 ?? 'all'}'),
                          style: TextButton.styleFrom(
                              foregroundColor: status == item.$2
                                  ? AppColors.surface
                                  : AppColors.blueDeep,
                              backgroundColor: status == item.$2
                                  ? AppColors.blue
                                  : AppColors.surface,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.sm),
                              shape: StadiumBorder(
                                  side: BorderSide(
                                      color: status == item.$2
                                          ? AppColors.blue
                                          : AppColors.border))),
                          onPressed: () => setState(() => _status = item.$2),
                          child: Text(item.$1,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700))))),
          ]));

  Widget _registrantCard(Booking booking) {
    final who = booking.visitorName.trim().isNotEmpty
        ? booking.visitorName
        : booking.visitorEmail;
    return Container(
        key: ValueKey(booking.guid),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20)),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: () => _open(booking),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      const Text('DESTINASI WISATA',
                                          style: TextStyle(
                                              fontSize: 10,
                                              letterSpacing: .8,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      Text(booking.destinationName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              height: 1.3,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy)),
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        const Icon(PhosphorIconsRegular.user,
                                            size: 15, color: AppColors.blue),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(who,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary))),
                                      ]),
                                    ])),
                                const SizedBox(width: 8),
                                OperationsStatusBadge(
                                    bookingStatusLabel(booking.status),
                                    _tone(booking.status),
                                    small: true),
                              ]),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 14),
                          Row(children: [
                            const Icon(PhosphorIconsRegular.calendarBlank,
                                size: 15, color: AppColors.blue),
                            const SizedBox(width: 6),
                            Text(visitDayLabel(booking.visitDate),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            const Spacer(),
                            const Icon(PhosphorIconsRegular.users,
                                size: 15, color: AppColors.blue),
                            const SizedBox(width: 6),
                            Text('${booking.quantity} orang',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            const Spacer(),
                            Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: AppColors.blueTint,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(PhosphorIconsRegular.caretRight,
                                    size: 16, color: AppColors.blue)),
                          ]),
                        ])))));
  }

  Widget _messageBox(
      {required IconData icon,
      required Color color,
      required String title,
      required String body,
      String? action,
      VoidCallback? onAction}) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ]));
  }

  List<Widget> _superadminBody() {
    final loaded = _list.hasLoaded && _list.error == null;
    final statuses = _presentStatuses();
    // A chip whose status vanished from the data falls back to "Semua".
    final status = statuses.contains(_status) ? _status : null;
    final rows = loaded ? _superadminRows(status) : <Booking>[];
    final firstLoad = _list.loading && _list.items.isEmpty;
    final filtering = status != null || _query.trim().isNotEmpty;
    return [
      _searchField(),
      const SizedBox(height: 12),
      _statusChips(status, statuses),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Riwayat Booking',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text(
              loaded
                  ? '${rows.length} pendaftaran ditemukan'
                  : firstLoad
                      ? 'Memuat data…'
                      : 'Data belum tersedia',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        OutlinedButton.icon(
            key: const ValueKey('registrants-sort'),
            onPressed: loaded ? _pickSort : null,
            iconAlignment: IconAlignment.end,
            icon: const Icon(PhosphorIconsRegular.caretDown, size: 16),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                backgroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            label: Text(_sortLabels[_sort]!,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 14),
      if (firstLoad)
        const OperationsSkeleton()
      else if (_list.loading)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator()),
      if (_accessRevoked)
        _messageBox(
            icon: PhosphorIconsRegular.lock,
            color: const Color(0xFFB23B3B),
            title: 'Akses telah berubah',
            body: 'Akses destinasi berubah. Kembali dan pilih ulang destinasi.',
            action: 'Kembali',
            onAction: () => Navigator.maybePop(context))
      else if (_list.error != null && !_list.loading)
        _messageBox(
            icon: PhosphorIconsRegular.wifiSlash,
            color: const Color(0xFF98621E),
            title: 'Data belum dapat dimuat',
            body: adminErrorMessage(_list.error!),
            action: 'Coba lagi',
            onAction: _load)
      else if (loaded && rows.isEmpty)
        _messageBox(
            icon: filtering
                ? PhosphorIconsRegular.magnifyingGlassMinus
                : PhosphorIconsRegular.users,
            color: AppColors.blue,
            title: filtering ? 'Tidak ada hasil' : 'Belum ada pendaftar',
            body: filtering
                ? 'Tidak ada pendaftar yang cocok dengan pencarian atau status ini.'
                : 'Belum ada booking yang tercatat.',
            action: filtering ? 'Reset pencarian' : null,
            onAction: () => setState(() {
                  _status = null;
                  _query = '';
                  _search.clear();
                })),
      for (final booking in rows) _registrantCard(booking),
    ];
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
    return OperationsPage(
        role: _role,
        title: 'Data Pendaftar',
        subtitle: 'Riwayat booking seluruh destinasi',
        embedded: false,
        onRefresh: _load,
        children: _superadminBody());
  }
}
