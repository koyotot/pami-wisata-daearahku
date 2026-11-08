import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../data/app_data.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import '../data/favorite_state.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/api_image.dart';
import 'auth_presentation.dart';
import 'bukti_pendaftaran_screen.dart';
import 'detail_wisata_screen.dart';
import 'profil_user_screen.dart';

/// Attention first, then the nearest confirmed visit; terminal bookings stay in history.
Booking? selectHomeBooking(List<Booking> bookings, DateTime now) {
  final today = formatVisitDate(now);
  int priority(Booking b) => switch (b.status) {
        'awaiting_payment' => 0,
        'pending_approval' || 'payment_verification' || 'payment_review' => 1,
        'confirmed' => 2,
        _ => 3,
      };
  final relevant = bookings
      .where((b) =>
          priority(b) < 3 &&
          (b.status != 'confirmed' ||
              (b.checkedInAt == null &&
                  DateTime.tryParse(b.visitDate) != null &&
                  b.visitDate.compareTo(today) >= 0)))
      .toList()
    ..sort((a, b) {
      final order = priority(a).compareTo(priority(b));
      return order != 0 ? order : a.visitDate.compareTo(b.visitDate);
    });
  return relevant.isEmpty ? null : relevant.first;
}

class BerandaUserScreen extends StatefulWidget {
  const BerandaUserScreen(
      {super.key,
      this.onBukaMenu,
      this.active = true,
      this.onExplore,
      this.onHistory,
      this.repository,
      this.favorites});
  final VoidCallback? onBukaMenu;
  final bool active;
  final VoidCallback? onExplore;
  final VoidCallback? onHistory;
  final BusinessRepository? repository;
  final FavoriteState? favorites;

  @override
  State<BerandaUserScreen> createState() => _BerandaUserScreenState();
}

class _BerandaUserScreenState extends State<BerandaUserScreen>
    with WidgetsBindingObserver {
  late final BusinessRepository _repository;
  late final UserBookingsState _bookings;
  late final FavoriteState _favorites;
  final _inspiration = RequestState<List<Destination>>();
  Future<Destination>? _journeyDestination;
  String? _journeyDestinationGuid;
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BusinessRepository();
    _bookings = UserBookingsState(_repository)..addListener(_changed);
    _favorites = widget.favorites ?? FavoriteState.instance;
    _favorites.favorites.addListener(_changed);
    _inspiration.addListener(_changed);
    _repository.api.session.sessionChanges.addListener(_sessionChanged);
    BookingEvents.changed.addListener(_bookingChanged);
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && widget.active) setState(() => _now = DateTime.now());
    });
    if (widget.active) _refresh(initial: true);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    _journeyDestination = null;
    _journeyDestinationGuid = null;
    if (widget.active) _refresh();
  }

  void _bookingChanged() {
    if (widget.active) _loadBookings();
  }

  Future<void> _loadBookings() async {
    final session = _repository.api.session;
    if (!_bookings.loading &&
        session.authenticated.value &&
        session.deviceSessionReady) {
      final generation = session.sessionGeneration;
      await _bookings.load();
      if (!mounted || generation != session.sessionGeneration) return;
      final booking = selectHomeBooking(_bookings.items, _now);
      final guid = booking?.destinationGuid;
      if (guid != _journeyDestinationGuid) {
        setState(() {
          _journeyDestinationGuid = guid;
          _journeyDestination = guid == null || guid.isEmpty
              ? null
              : _repository.destination(guid).catchError((Object error) {
                  if (mounted &&
                      generation == session.sessionGeneration &&
                      _journeyDestinationGuid == guid) {
                    _journeyDestinationGuid = null;
                  }
                  throw error;
                });
        });
      }
    }
  }

  Future<void> _loadInspiration() async {
    if (_inspiration.loading) return;
    await _inspiration.load(() async => (await _repository.destinations(query: {
          'per_page': '4',
          'sort': '-created_at',
        }))
            .items
            .where((d) => d.isActive)
            .take(4)
            .toList());
  }

  Future<void> _refresh({bool initial = false}) async {
    _now = DateTime.now();
    await Future.wait([
      _loadBookings(),
      _loadInspiration(),
      if (!_favorites.favorites.loading &&
          (!initial || _favorites.favorites.data == null))
        _favorites.load()
    ]);
  }

  @override
  void didUpdateWidget(BerandaUserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _refresh();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _refresh();
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    BookingEvents.changed.removeListener(_bookingChanged);
    _repository.api.session.sessionChanges.removeListener(_sessionChanged);
    _favorites.favorites.removeListener(_changed);
    _bookings.dispose();
    _inspiration.dispose();
    super.dispose();
  }

  Future<void> _openDestination(Destination destination) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            DetailWisataScreen(wisata: Wisata.fromDestination(destination))));
    if (mounted && widget.active) await _refresh();
  }

  Future<void> _openBooking(Booking booking) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BookingTicketScreen(
            bookingGuid: booking.guid, repository: _repository)));
    if (mounted && widget.active) await _refresh();
  }

  TextStyle _text(double size,
          {FontWeight weight = FontWeight.w500,
          Color color = AppColors.navy}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.35);

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites.favorites;
    final saved = favorites.data ?? [];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _hero(),
            Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, 16 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Perjalanan Kamu', 'Riwayat', widget.onHistory),
                      const SizedBox(height: 12),
                      _journey(),
                      if (favorites.loading && saved.isEmpty) ...[
                        const SizedBox(height: 24),
                        _heading('Favorit Kamu'),
                        const SizedBox(height: 12),
                        _loading('Memuat favorit…'),
                      ] else if (favorites.error != null) ...[
                        const SizedBox(height: 24),
                        _heading('Favorit Kamu'),
                        _error(
                            'Favorit belum dapat diperbarui.', _favorites.load),
                      ] else if (saved.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _heading(
                            'Favorit Kamu',
                            'Lihat Semua',
                            () => showModalBottomSheet<void>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) =>
                                    const SavedDestinationsSheet())),
                        const SizedBox(height: 12),
                        _favoritesRow(saved.map((f) => f.destination).toList()),
                      ],
                      const SizedBox(height: 24),
                      _heading(
                          'Inspirasi Wisata', 'Lihat Semua', widget.onExplore),
                      const SizedBox(height: 6),
                      Text('Sedikit inspirasi untuk perjalanan berikutnya.',
                          style: _text(13, color: AppColors.textMuted)),
                      const SizedBox(height: 14),
                      if (_inspiration.error != null)
                        _error('Inspirasi belum dapat diperbarui.',
                            _loadInspiration)
                      else if (_inspiration.loading &&
                          _inspiration.data == null)
                        _loading('Memuat inspirasi…', minHeight: 210)
                      else if ((_inspiration.data ?? []).isEmpty)
                        Text('Destinasi baru akan hadir di sini.',
                            style: _text(14, color: AppColors.textMuted))
                      else
                        _editorial(_inspiration.data!),
                      const SizedBox(height: 24),
                      _exploreBanner(),
                    ]),
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _hero() {
    final name =
        currentUser?.namaLengkap.trim().split(' ').first ?? 'Pengunjung';
    final greeting = _now.hour < 5 || _now.hour >= 19
        ? 'Selamat malam'
        : _now.hour < 11
            ? 'Selamat pagi'
            : _now.hour < 15
                ? 'Selamat siang'
                : 'Selamat sore';
    return TimeBasedScenicBackground(
      active: widget.active,
      topInset: MediaQuery.paddingOf(context).top,
      child: Stack(children: [
        SafeArea(
            bottom: false,
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 48),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('Wisata Daerahku',
                                style: _text(15,
                                    weight: FontWeight.w700,
                                    color: Colors.white))),
                        if (widget.onBukaMenu != null)
                          IconButton(
                              onPressed: widget.onBukaMenu,
                              tooltip: 'Buka menu',
                              icon: const Icon(PhosphorIconsRegular.list,
                                  color: Colors.white)),
                      ]),
                      const SizedBox(height: 30),
                      Text('$greeting, ${name.isEmpty ? 'Pengunjung' : name}',
                          style: _text(14, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text('Siap untuk\npetualangan baru?',
                          style: _text(30,
                              weight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 12),
                      Text(
                          'Rencana perjalanan dan tempat favoritmu, dalam satu tempat.',
                          style: _text(14, color: Colors.white)),
                    ]),
              ),
            ))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _heading(String title, [String? action, VoidCallback? onTap]) =>
      Row(children: [
        Expanded(child: Text(title, style: _text(20, weight: FontWeight.w800))),
        if (action != null && onTap != null)
          TextButton(onPressed: onTap, child: Text(action)),
      ]);
  Widget _panel(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x09102D59), blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: child);
  Widget _loading(String label, {double minHeight = 114}) =>
      _panel(ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight - 32),
          child: Row(children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: _text(14))),
          ])));
  Widget _error(String message, VoidCallback retry) =>
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: _text(14, color: AppColors.textMuted)),
        TextButton(onPressed: retry, child: const Text('Coba lagi')),
      ]));

  Widget _journey() {
    if (_bookings.error != null) {
      return _error('Perjalanan belum dapat diperbarui.', _loadBookings);
    }
    if (_bookings.loading && _bookings.items.isEmpty) {
      return _loading('Memuat perjalanan…', minHeight: 190);
    }
    final booking = selectHomeBooking(_bookings.items, _now);
    if (booking == null) {
      return _journeyPanel(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(PhosphorIconsRegular.compass,
                color: AppColors.orange, size: 32),
            const SizedBox(height: 12),
            Text('Petualangan pertamamu menanti',
                textAlign: TextAlign.center,
                style: _text(16, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Belum ada perjalanan aktif. Mulai dari destinasi pilihanmu.',
                textAlign: TextAlign.center,
                style: _text(12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            _journeyAction('Mulai Jelajah', widget.onExplore),
          ]),
          empty: true);
    }
    final note = switch (booking.status) {
      'pending_approval' => 'Pendaftaranmu sedang ditinjau pengelola.',
      'awaiting_payment' => 'Selesaikan pembayaran sesuai tenggat dari sistem.',
      'confirmed' => 'Tiketmu sudah terkonfirmasi. Siap berkunjung!',
      _ => bookingStatusNote(booking.status),
    };
    final action = switch (booking.status) {
      'awaiting_payment' => 'Lihat Detail Pembayaran',
      'confirmed' => 'Lihat Detail Tiket',
      _ => 'Lihat Status Pendaftaran',
    };
    final visitDate = DateTime.tryParse(booking.visitDate);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final dateLabel = visitDate == null
        ? booking.visitDate
        : '${visitDate.day} ${months[visitDate.month - 1]} ${visitDate.year}';
    final statusColor = booking.status == 'confirmed'
        ? const Color(0xFF247B50)
        : booking.status == 'awaiting_payment'
            ? const Color(0xFF92400E)
            : AppColors.blueDeep;
    return _journeyPanel(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
                width: 80,
                height: 100,
                child: FutureBuilder<Destination>(
                    future: _journeyDestination,
                    builder: (_, snapshot) {
                      Destination? destination =
                          snapshot.data?.guid == booking.destinationGuid
                              ? snapshot.data
                              : null;
                      for (final item in [
                        ...?_inspiration.data,
                        ...?_favorites.favorites.data
                            ?.map((f) => f.destination),
                      ]) {
                        if (item.guid == booking.destinationGuid) {
                          destination ??= item;
                          break;
                        }
                      }
                      if (destination == null &&
                          snapshot.connectionState != ConnectionState.done &&
                          _journeyDestination != null) {
                        return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      return _cover(destination);
                    }))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  booking.status == 'confirmed'
                      ? 'Tiket dikonfirmasi'
                      : bookingStatusLabel(booking.status),
                  style:
                      _text(12, weight: FontWeight.w700, color: statusColor))),
          const SizedBox(height: 8),
          Text(booking.destinationName,
              style: _text(18, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          _meta(PhosphorIconsRegular.calendarBlank, dateLabel),
          const SizedBox(height: 6),
          _meta(PhosphorIconsRegular.ticket, '${booking.quantity} tiket'),
        ])),
      ]),
      const SizedBox(height: 16),
      const SizedBox(
          height: 1, child: CustomPaint(painter: _BoardingPassRule())),
      if (note != null) ...[
        const SizedBox(height: 12),
        Text(note, style: _text(12, color: AppColors.textMuted)),
      ],
      const SizedBox(height: 12),
      _journeyAction(action, () => _openBooking(booking),
          icon: PhosphorIconsRegular.ticket),
    ]));
  }

  Widget _journeyPanel(Widget child, {bool empty = false}) => CustomPaint(
      foregroundPainter: empty ? const _JourneyEmptyBorder() : null,
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: empty ? null : Border.all(color: AppColors.border)),
          child: child));

  Widget _journeyAction(String label, VoidCallback? onPressed,
          {IconData? icon}) =>
      ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 6),
            ],
            Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: _text(12,
                        weight: FontWeight.w800, color: Colors.white))),
            const SizedBox(width: 8),
            const Icon(PhosphorIconsRegular.arrowRight, size: 16),
          ]));

  Widget _meta(IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
            child: Text(label, style: _text(12, color: AppColors.textMuted))),
      ]);

  Widget _cover(Destination? destination, {bool featured = false}) {
    final images = destination?.images ?? [];
    return ApiImage(
        repository: _repository,
        imageUrl: images.isNotEmpty
            ? images.first.url(featured ? 'display' : 'thumbnail')
            : destination?.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_) => const ColoredBox(
            color: AppColors.border,
            child: Center(
                child: Icon(PhosphorIconsRegular.mountains,
                    color: AppColors.textMuted, size: 30))));
  }

  Widget _favoritesRow(List<Destination> items) {
    if (items.length == 1) return _favoriteCard(items.first);
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return SizedBox(
          height: 126 + 90 * (scale - 1).clamp(0, 3),
          child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                  width: constraints.maxWidth * .9,
                  child: _favoriteCard(items[i]))));
    });
  }

  Widget _favoriteCard(Destination d) => Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => _openDestination(d),
          child: Padding(
              padding: const EdgeInsets.all(10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 84, height: 72, child: _cover(d))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(d.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _text(14, weight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(PhosphorIconsRegular.mapPin,
                            size: 12, color: Color(0xFFF45B83)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(d.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _text(11, color: AppColors.textMuted))),
                      ]),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('Lihat Destinasi \u2192',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(11,
                                  weight: FontWeight.w700,
                                  color: AppColors.blue))),
                    ])),
                const SizedBox(width: 6),
                Semantics(
                    label: 'Destinasi favorit',
                    child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFFFF0F4),
                        child: Icon(PhosphorIconsFill.heart,
                            size: 14, color: Color(0xFFF45B83)))),
              ]))));

  Widget _editorial(List<Destination> destinations) {
    final seen = <String>{};
    final items = destinations.where((d) => seen.add(d.guid)).take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _featuredCard(items.first),
      if (items.length > 1) ...[
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 1; i < items.length; i++) ...[
            if (i > 1) const SizedBox(width: 8),
            Expanded(child: _miniCard(items[i])),
          ],
        ]),
      ],
    ]);
  }

  Widget _featuredCard(Destination d) => Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => _openDestination(d),
          child: LayoutBuilder(
              builder: (context, constraints) => Stack(children: [
                    Positioned.fill(child: _cover(d, featured: true)),
                    Positioned.fill(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .75)
                        ])))),
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: constraints.maxWidth * .54),
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: .22),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: .3)),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                PhosphorIconsRegular.sparkle,
                                                size: 12,
                                                color: Colors.white),
                                            const SizedBox(width: 4),
                                            Flexible(
                                                child: Text('Destinasi pilihan',
                                                    style: _text(11,
                                                        weight: FontWeight.w700,
                                                        color: Colors.white))),
                                          ])),
                                  const SizedBox(height: 6),
                                  Text(d.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _text(22,
                                          weight: FontWeight.w800,
                                          color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(PhosphorIconsRegular.mapPin,
                                        color: Color(0xFFF45B83), size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: Text(
                                            [d.location, d.category?.name]
                                                .whereType<String>()
                                                .where(
                                                    (value) => value.isNotEmpty)
                                                .join(' \u00b7 '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: _text(11,
                                                color: Colors.white))),
                                    const SizedBox(width: 8),
                                    const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                            PhosphorIconsRegular.arrowUpRight,
                                            size: 16,
                                            color: AppColors.blue)),
                                  ]),
                                ]))),
                  ]))));

  Widget _miniCard(Destination d) => Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => _openDestination(d),
          child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 40, height: 40, child: _cover(d))),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(d.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _text(11, weight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                          [d.category?.name, d.location]
                              .whereType<String>()
                              .where((value) => value.isNotEmpty)
                              .join(' \u00b7 '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _text(11, color: AppColors.textMuted)),
                    ])),
              ]))));

  Widget _exploreBanner() => Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: widget.onExplore,
          child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.blue, AppColors.blueDeep])),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Masih ingin eksplorasi?',
                          style: _text(16,
                              weight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 5),
                      Text('Temukan tujuan perjalanan berikutnya.',
                          style: _text(13, color: Colors.white)),
                    ])),
                const SizedBox(width: 12),
                const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(PhosphorIconsRegular.arrowRight,
                        color: AppColors.blue)),
              ]))));
}

class _BoardingPassRule extends CustomPainter {
  const _BoardingPassRule();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + 5).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_BoardingPassRule oldDelegate) => false;
}

class _JourneyEmptyBorder extends CustomPainter {
  const _JourneyEmptyBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blue.withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5), const Radius.circular(20)));
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 8) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_JourneyEmptyBorder oldDelegate) => false;
}
