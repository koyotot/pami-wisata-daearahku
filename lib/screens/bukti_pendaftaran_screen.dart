// ============================================================
// lib/screens/bukti_pendaftaran_screen.dart
// REDESIGN: biru terang + Plus Jakarta Sans — selaras home_screen
// - Header: tombol kembali (kiri) + tombol drawer (kanan)
// - Kartu statistik (Menunggu / Disetujui / Ditolak) = filter
// - Kartu tiket modern dengan strip status berwarna
// Butuh package: google_fonts, cloud_firestore, firebase_auth, qr_flutter
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/app_data.dart';
import '../data/booking_errors.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';

// ── Palet (sama dengan home_screen) ──────────────────────────
const _blue = Color(0xFF1976D2);
const _blueDeep = Color(0xFF1558B0);
const _navy = Color(0xFF102D59);
const _orange = Color(0xFFFF9800);
const _background = Color(0xFFF5F8FD);
const _textMuted = Color(0xFF728099);
const _border = Color(0xFFDCE4F0);
const _green = Color(0xFF10B981);
const _greenDeep = Color(0xFF059669);
const _red = Color(0xFFE5484D);
const _amber = Color(0xFFF59E0B);
const _sheetBg = Color(0xFFEAF2FC);

TextStyle _font(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

// ── Gaya per status ───────────────────────────────────────────
class _StatusStyle {
  final Color color;
  final Color deep;
  final String label;
  final IconData icon;
  const _StatusStyle(this.color, this.deep, this.label, this.icon);
}

_StatusStyle _styleFor(String status) {
  switch (status) {
    case 'confirmed':
    case 'disetujui':
      return const _StatusStyle(
          _green, _greenDeep, 'Disetujui', Icons.check_circle_rounded);
    case 'rejected':
    case 'ditolak':
      return const _StatusStyle(
          _red, Color(0xFFC53030), 'Ditolak', Icons.cancel_rounded);
    case 'pending_approval':
    case 'menunggu':
      return const _StatusStyle(
          _amber, Color(0xFFD97706), 'Menunggu', Icons.hourglass_top_rounded);
    case 'cancelled':
      return const _StatusStyle(_textMuted, Color(0xFF5B6B85),
          'Dibatalkan', Icons.block_rounded);
    case 'expired':
      return const _StatusStyle(_textMuted, Color(0xFF5B6B85),
          'Kedaluwarsa', Icons.timer_off_rounded);
    default:
      // awaiting_payment / payment_* dan status lain: label Indonesia dari server.
      return _StatusStyle(_amber, const Color(0xFFD97706),
          bookingStatusLabel(status), Icons.hourglass_top_rounded);
  }
}

Pendaftar _fromBooking(Booking booking) {
  final json = booking.json;
  return Pendaftar(
    id: booking.guid,
    userId: '',
    namaPengunjung: booking.visitorName,
    noTelepon: booking.visitorPhone,
    email: booking.visitorEmail,
    wisata: booking.destinationName,
    tanggal: booking.visitDate,
    jumlahOrang: booking.quantity,
    nomorBukti: booking.bookingNumber,
    catatan: json['notes'] as String? ?? '',
    status: booking.status,
  );
}

// ── Cari data wisata (untuk foto) berdasarkan nama ────────────
Wisata? _cariWisata(String nama) {
  final n = nama.trim().toLowerCase();
  for (final w in daftarWisata) {
    if (w.nama.trim().toLowerCase() == n) return w;
  }
  return null;
}

// ── Foto destinasi (http / asset / file / placeholder) ────────
class _FotoWisata extends StatelessWidget {
  final Wisata? wisata;
  final _StatusStyle style;
  const _FotoWisata({required this.wisata, required this.style});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.color, style.deep],
            ),
          ),
          child: Center(
            child: Icon(Icons.landscape_rounded,
                color: Colors.white.withValues(alpha: 0.35), size: 64),
          ),
        );

    final path = wisata?.imagePath;
    if (path == null || path.isEmpty) return placeholder();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder(),
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder());
    }
    return Image.file(File(path),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder());
  }
}

// ══════════════════════════════════════════════════════════
//  LAYAR UTAMA
// ══════════════════════════════════════════════════════════
class BuktiPendaftaranScreen extends StatefulWidget {
  // Saat true, layar ini ditampilkan sebagai salah satu tab di
  // MainNavigationScreen.
  final bool embedded;
  final bool active;

  // Dipanggil saat tombol "Jelajahi Wisata" pada empty state ditekan
  // ketika layar ini embedded. Jika null, dipakai Navigator.pop.
  final VoidCallback? onExploreWisata;

  // Dipanggil saat tombol menu (☰) ditekan — membuka drawer
  // yang ada di MainNavigationScreen.
  final VoidCallback? onBukaMenu;

  // Dipanggil saat tombol kembali ditekan. Saat embedded, isi dengan
  // perpindahan ke tab Beranda. Jika null dan tidak embedded,
  // dipakai Navigator.pop.
  final VoidCallback? onKembali;

  const BuktiPendaftaranScreen({
    super.key,
    this.embedded = false,
    this.active = true,
    this.onExploreWisata,
    this.onBukaMenu,
    this.onKembali,
  });

  @override
  State<BuktiPendaftaranScreen> createState() => _BuktiPendaftaranScreenState();
}

class _BuktiPendaftaranScreenState extends State<BuktiPendaftaranScreen> {
  String? _filter; // null = semua, atau 'menunggu' / 'disetujui' / 'ditolak'

  /// Riwayat dari Laravel (semua halaman, tanpa duplikat). Respons lama atau dari sesi
  /// sebelumnya tidak pernah menimpa data yang lebih baru.
  final _bookings = UserBookingsState();

  @override
  void initState() {
    super.initState();
    AuthSession.instance.sessionChanges.addListener(_refresh);
    BookingEvents.changed.addListener(_loadBookings);
    _bookings.addListener(_changed);
    _loadBookings();
  }

  @override
  void didUpdateWidget(BuktiPendaftaranScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _loadBookings() {
    final session = AuthSession.instance;
    if (!session.authenticated.value || !session.deviceSessionReady) {
      _bookings.reset();
      return;
    }
    _bookings.load();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _filter = null);
    _loadBookings();
  }

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_refresh);
    BookingEvents.changed.removeListener(_loadBookings);
    _bookings.removeListener(_changed);
    _bookings.dispose();
    super.dispose();
  }

  bool _matches(String actual, String filter) => switch (filter) {
        'menunggu' => actual == 'pending_approval',
        'disetujui' => actual == 'confirmed',
        'ditolak' => actual == 'rejected',
        _ => false,
      };

  void _jelajahi() {
    if (widget.onExploreWisata != null) {
      widget.onExploreWisata!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Builder(
          builder: (context) {
            final isLoading = _bookings.loading && _bookings.items.isEmpty;
            final hasError = _bookings.error != null && _bookings.items.isEmpty;
            final byGuid = {for (final b in _bookings.items) b.guid: b};
            final semua = _bookings.items.map(_fromBooking).toList();
            final tampil = _filter == null
                ? semua
                : semua.where((p) => _matches(p.status, _filter!)).toList();

            int hitung(String s) =>
                semua.where((p) => _matches(p.status, s)).length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(
                  total: semua.length,
                  menunggu: hitung('menunggu'),
                  disetujui: hitung('disetujui'),
                  ditolak: hitung('ditolak'),
                ),
                if (isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: _blue),
                    ),
                  )
                else if (hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(bookingErrorMessage(_bookings.error!)),
                      TextButton(
                          onPressed: _refresh, child: const Text('Coba lagi')),
                    ])),
                  )
                else if (semua.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false, child: _buildEmpty())
                else ...[
                  SliverToBoxAdapter(child: _buildSectionTitle(tampil.length)),
                  if (tampil.isEmpty)
                    SliverFillRemaining(
                        hasScrollBody: false, child: _buildFilterKosong())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final p = tampil[i];
                            return _FadeSlide(
                              // key menjaga state kartu (expand/ulasan)
                              // saat filter berganti.
                              key: ValueKey(p.id ?? p.nomorBukti),
                              index: i,
                              child: _TicketCard(
                                  pendaftar: p,
                                  booking: byGuid[p.id],
                                  isLaravel: true,
                                  onChanged: _bookings.replace),
                            );
                          },
                          childCount: tampil.length,
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header gradien: back, drawer, judul, kartu statistik ───
  Widget _buildHeader({
    required int total,
    required int menunggu,
    required int disetujui,
    required int ditolak,
  }) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _blue,
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      centerTitle: true,
      // Pill jumlah pendaftaran, di antara tombol kembali & menu
      title: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              '$total pendaftaran',
              style: _font(11.5, FontWeight.w700, Colors.white),
            ),
          ],
        ),
      ),
      // Tombol kembali
      leading: (widget.embedded && widget.onKembali == null)
          ? null
          : _headerButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 17,
              margin: const EdgeInsets.fromLTRB(20, 8, 0, 8),
              onTap: () {
                if (widget.onKembali != null) {
                  widget.onKembali!();
                } else {
                  Navigator.maybePop(context);
                }
              },
            ),
      // Tombol pembuka drawer
      actions: [
        if (widget.onBukaMenu != null)
          _headerButton(
            icon: Icons.menu_rounded,
            iconSize: 22,
            margin: const EdgeInsets.fromLTRB(0, 8, 20, 8),
            onTap: widget.onBukaMenu!,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A93F0), _blue, _blueDeep],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 22,
                right: 22,
                bottom: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Riwayat Pendaftaran',
                      style: _font(
                        26,
                        FontWeight.w800,
                        Colors.white,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pantau status & tiket kunjunganmu',
                      style: _font(
                        13,
                        FontWeight.w500,
                        Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Kartu statistik = filter
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(78),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Menunggu',
                  count: menunggu,
                  accent: const Color(0xFFD97706),
                  selected: _filter == 'menunggu',
                  onTap: () => _setFilter('menunggu'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Disetujui',
                  count: disetujui,
                  accent: _greenDeep,
                  selected: _filter == 'disetujui',
                  onTap: () => _setFilter('disetujui'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Ditolak',
                  count: ditolak,
                  accent: const Color(0xFFC53030),
                  selected: _filter == 'ditolak',
                  onTap: () => _setFilter('ditolak'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setFilter(String status) =>
      setState(() => _filter = _filter == status ? null : status);

  // ── Tombol bulat di header (kembali / menu) ────────────────
  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
    required EdgeInsets margin,
    double iconSize = 20,
  }) {
    return Padding(
      padding: margin,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.white.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.transparent,
            child: Center(
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  // ── Judul bagian ───────────────────────────────────────────
  Widget _buildSectionTitle(int jumlah) {
    final aktif = _filter != null;
    final label = aktif ? _styleFor(_filter!).label : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            aktif ? '$jumlah tiket · $label' : 'Tiket Kunjunganmu',
            style: _font(15, FontWeight.w800, _navy, letterSpacing: -0.2),
          ),
        ),
        if (aktif)
          GestureDetector(
            onTap: () => setState(() => _filter = null),
            child: Text('Reset', style: _font(12.5, FontWeight.w700, _blue)),
          ),
      ]),
    );
  }

  // ── Empty state (belum ada riwayat sama sekali) ────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _blue.withValues(alpha: 0.16),
                  _blue.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: const Icon(Icons.confirmation_number_rounded,
                size: 48, color: _blue),
          ),
          const SizedBox(height: 22),
          Text('Belum ada riwayat pendaftaran',
              style: _font(17, FontWeight.w800, _navy, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(
            'Daftarkan kunjungan wisata terlebih dahulu,\ntiketmu akan muncul di sini.',
            textAlign: TextAlign.center,
            style: _font(13, FontWeight.w500, _textMuted, height: 1.6),
          ),
          const SizedBox(height: 26),
          GestureDetector(
            onTap: _jelajahi,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2386E8), _blueDeep]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Jelajahi Wisata',
                      style: _font(14, FontWeight.w700, Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter aktif tapi tidak ada hasil ──────────────────────
  Widget _buildFilterKosong() {
    final label = _styleFor(_filter ?? '').label.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _border, width: 1.4),
            ),
            child: const Icon(Icons.inbox_rounded, size: 42, color: _textMuted),
          ),
          const SizedBox(height: 20),
          Text('Tidak ada tiket $label',
              style: _font(17, FontWeight.w800, _navy, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text('Coba lihat status yang lain',
              style: _font(13, FontWeight.w500, _textMuted)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => setState(() => _filter = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2386E8), _blueDeep]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Tampilkan semua',
                  style: _font(13, FontWeight.w700, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kartu statistik di header ─────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.count,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 62,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: _font(
                  20, FontWeight.w800, selected ? accent : Colors.white,
                  height: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: _font(
                11,
                FontWeight.w700,
                selected ? _textMuted : Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animasi masuk (fade + geser, berurutan) ───────────────────
class _FadeSlide extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeSlide({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 6)) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TICKET CARD
// ══════════════════════════════════════════════════════════
class _TicketCard extends StatefulWidget {
  final Pendaftar pendaftar;

  /// Booking Laravel asal [pendaftar]; null untuk data historis.
  final Booking? booking;
  final bool isLaravel;

  /// Dipanggil dengan salinan booking terbaru dari server (detail / hasil pembatalan).
  final ValueChanged<Booking>? onChanged;

  const _TicketCard(
      {required this.pendaftar,
      this.booking,
      this.isLaravel = false,
      this.onChanged});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _expanded = false;
  bool _sudahUlasan = false;
  String? _statusSebelumnya;
  BookingDetailController? _controller;

  @override
  void initState() {
    super.initState();
    _statusSebelumnya = widget.pendaftar.status;
    final booking = widget.booking;
    if (widget.isLaravel && booking != null) {
      _controller = BookingDetailController(BusinessRepository(), booking)
        ..addListener(_controllerChanged);
      _emitted = booking;
    }
    if (!widget.isLaravel && widget.pendaftar.status == 'disetujui') {
      _cekSudahUlasan();
    }
  }

  Booking? _emitted;

  void _controllerChanged() {
    if (!mounted) return;
    setState(() {});
    final booking = _controller?.booking;
    if (booking != null && !identical(booking, _emitted)) {
      _emitted = booking;
      widget.onChanged?.call(booking);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_controllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fresh = widget.booking;
    if (fresh != null && _controller != null) _controller!.adopt(fresh);
    final statusBaru = widget.pendaftar.status;
    if (_statusSebelumnya != null &&
        _statusSebelumnya != statusBaru &&
        mounted) {
      _statusSebelumnya = statusBaru;
      if (statusBaru == 'disetujui') {
        _cekSudahUlasan();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: _green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pendaftaran ${widget.pendaftar.wisata} disetujui!',
                style: _font(13, FontWeight.w600, Colors.white),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ));
      } else if (statusBaru == 'ditolak') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pendaftaran ${widget.pendaftar.wisata} ditolak.',
                style: _font(13, FontWeight.w600, Colors.white),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFF7F1D1D),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _cekSudahUlasan() async {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || widget.pendaftar.id == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('ulasan')
        .where('userId', isEqualTo: uid)
        .where('pendaftaranId', isEqualTo: widget.pendaftar.id)
        .limit(1)
        .get();
    if (!mounted) return;
    setState(() => _sudahUlasan = snap.docs.isNotEmpty);
  }

  void _bukaFormUlasan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FormUlasanSheet(
        pendaftar: widget.pendaftar,
        onSelesai: () {
          if (mounted) setState(() => _sudahUlasan = true);
        },
      ),
    );
  }

  void _copyNomor() {
    Clipboard.setData(ClipboardData(text: widget.pendaftar.nomorBukti));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _green, size: 18),
            const SizedBox(width: 8),
            Text('Nomor bukti disalin!',
                style: _font(13, FontWeight.w600, Colors.white)),
          ],
        ),
        backgroundColor: _navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTiketSheet(Pendaftar p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TiketBottomSheet(pendaftar: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final p = controller != null
        ? _fromBooking(controller.booking)
        : widget.pendaftar;
    // Hanya data historis (Firestore) yang memiliki QR/ulasan lokal; booking Laravel tidak.
    final isApproved = !widget.isLaravel && p.status == 'disetujui';
    final st = _styleFor(p.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isApproved ? _green.withValues(alpha: 0.45) : _border,
          width: isApproved ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isApproved ? _green : _blue).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTicketHeader(p, st),
          _buildDashedDivider(),
          _buildTicketBody(p),
          if (widget.isLaravel ||
              p.catatan.isNotEmpty ||
              p.email.isNotEmpty)
            _buildExpandBtn(p),
          if (isApproved) _buildUlasanButton(),
        ],
      ),
    );
  }

  Widget _buildTicketHeader(Pendaftar p, _StatusStyle st) {
    final isApproved = !widget.isLaravel && p.status == 'disetujui';
    final wisata = widget.isLaravel ? null : _cariWisata(p.wisata);

    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 156,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FotoWisata(wisata: wisata, style: st),
            // gradasi gelap agar teks terbaca
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33102D59), Color(0xE6102D59)],
                  stops: [0.25, 1.0],
                ),
              ),
            ),
            // area tap (buka tiket QR bila disetujui)
            Positioned.fill(
              child: InkWell(
                onTap: isApproved ? () => _showTiketSheet(p) : null,
                splashColor: Colors.white.withValues(alpha: 0.12),
                highlightColor: Colors.transparent,
              ),
            ),
            // status (kiri atas)
            Positioned(
              top: 12,
              left: 12,
              child: _StatusBadge(status: p.status, onPhoto: true),
            ),
            // petunjuk QR (kanan atas)
            if (isApproved)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          color: _blue, size: 14),
                      const SizedBox(width: 4),
                      Text('Lihat tiket QR',
                          style: _font(10.5, FontWeight.w800, _blue)),
                    ],
                  ),
                ),
              ),
            // nama wisata + nomor bukti (kiri bawah)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.wisata,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _font(20, FontWeight.w800, Colors.white,
                        height: 1.15, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: _copyNomor,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              p.nomorBukti,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _font(11.5, FontWeight.w800, Colors.white,
                                  letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.copy_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // strip warna status di tepi bawah foto
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 4,
              child: ColoredBox(color: st.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedDivider() {
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 18,
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(9)),
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(color: _border),
            ),
          ),
          Container(
            width: 14,
            height: 18,
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketBody(Pendaftar p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _InfoItem(
                      icon: Icons.person_rounded,
                      label: 'Nama',
                      value: p.namaPengunjung)),
              Expanded(
                  child: _InfoItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Tanggal',
                      value: p.tanggal)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _InfoItem(
                      icon: Icons.group_rounded,
                      label: 'Jumlah',
                      value: '${p.jumlahOrang} orang')),
              Expanded(
                  child: _InfoItem(
                      icon: Icons.phone_rounded,
                      label: 'Telepon',
                      value: p.noTelepon)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleExpand() async {
    final controller = _controller;
    if (controller == null || _expanded) {
      setState(() => _expanded = !_expanded);
      return;
    }
    setState(() => _expanded = true);
    // Saat dibuka: ambil detail terkini dan dokumen dari server (tanpa menunggu).
    controller.refresh();
    controller.loadDocuments();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCancel(BookingDetailController c) async {
    if (c.cancelling) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pendaftaran?'),
        content: Text(
            'Pendaftaran ${c.booking.bookingNumber} untuk ${c.booking.destinationName} akan dibatalkan dan kuota dilepas. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kembali')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Batalkan pendaftaran')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await c.cancel();
    if (!mounted) return;
    _snack(ok
        ? 'Pendaftaran dibatalkan. Status dari server: ${bookingStatusLabel(c.booking.status)}.'
        : (c.message ?? 'Pendaftaran belum dapat dibatalkan.'));
  }

  Future<void> _download(BookingDetailController c, String type) async {
    final saved = await c.download(type);
    if (!mounted) return;
    _snack(saved != null
        ? 'Dokumen berhasil diambil dan disimpan sementara di ${saved.path}. '
            'Aplikasi ini belum memiliki pembaca PDF; buka file tersebut dengan aplikasi lain.'
        : (c.message ?? 'Dokumen belum dapat diunduh.'));
  }

  Widget _buildExpandBtn(Pendaftar p) {
    final c = _controller;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (c?.refreshing ?? false)
                        ? 'Memuat...'
                        : (_expanded ? 'Sembunyikan detail' : 'Lihat detail'),
                    style: _font(12, FontWeight.w700, _blue),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _blue, size: 18),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.email.isNotEmpty) ...[
                          _InfoItem(
                            icon: Icons.email_rounded,
                            label: 'Email',
                            value: p.email,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (p.catatan.isNotEmpty)
                          _InfoItem(
                            icon: Icons.notes_rounded,
                            label: 'Catatan',
                            value: p.catatan,
                          ),
                        if (c != null) ..._buildServerDetail(c),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Status server, pembatalan dan dokumen untuk booking Laravel.
  List<Widget> _buildServerDetail(BookingDetailController c) {
    final b = c.booking;
    final note = bookingStatusNote(b.status);
    final docs = c.documents;
    return [
      const SizedBox(height: 10),
      _InfoItem(
        icon: Icons.payments_rounded,
        label: 'Total',
        value: '${b.currency} ${b.totalAmount}',
      ),
      const SizedBox(height: 10),
      Text('Status: ${bookingStatusLabel(b.status)}',
          key: const ValueKey('detailStatus'),
          style: _font(13, FontWeight.w700, _navy)),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(note, style: _font(12, FontWeight.w500, _textMuted)),
        ),
      if (c.message != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(c.message!,
              key: const ValueKey('detailMessage'),
              style: _font(12, FontWeight.w600, _red)),
        ),
      if (b.cancellable) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const ValueKey('cancelBooking'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _red, side: const BorderSide(color: _red)),
            onPressed: c.cancelling ? null : () => _confirmCancel(c),
            child: c.cancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Batalkan Pendaftaran'),
          ),
        ),
      ],
      const SizedBox(height: 14),
      Text('Dokumen', style: _font(13, FontWeight.w800, _navy)),
      const SizedBox(height: 6),
      if (c.loadingDocuments)
        const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
      else if (c.documentsError != null)
        Row(children: [
          Expanded(
              child: Text(c.documentsError!,
                  style: _font(12, FontWeight.w500, _red))),
          TextButton(
              onPressed: c.loadDocuments, child: const Text('Coba lagi')),
        ])
      else if (docs != null) ...[
        if (docs.invoice == null && docs.ticket == null)
          Text('Dokumen belum diterbitkan.',
              style: _font(12, FontWeight.w500, _textMuted)),
        if (docs.invoice != null)
          _documentRow(c, 'invoice', 'Konfirmasi pendaftaran (invoice)'),
        if (docs.ticket != null) _documentRow(c, 'ticket', 'Tiket'),
        if (docs.invoice != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'Invoice adalah konfirmasi pendaftaran, bukan bukti pembayaran.',
                style: _font(11.5, FontWeight.w500, _textMuted)),
          ),
      ],
    ];
  }

  Widget _documentRow(BookingDetailController c, String type, String label) {
    final busy = c.downloading == type;
    return Row(children: [
      Expanded(child: Text(label, style: _font(12.5, FontWeight.w600, _navy))),
      TextButton(
        key: ValueKey('download_$type'),
        onPressed: c.downloading != null ? null : () => _download(c, type),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Unduh'),
      ),
    ]);
  }

  Widget _buildUlasanButton() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Material(
        color: _sudahUlasan ? _background : _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _sudahUlasan ? null : _bukaFormUlasan,
          splashColor: _orange.withValues(alpha: 0.15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _sudahUlasan ? _border : _orange.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _sudahUlasan
                      ? Icons.check_circle_rounded
                      : Icons.rate_review_rounded,
                  color: _sudahUlasan ? _greenDeep : const Color(0xFFE08600),
                  size: 17,
                ),
                const SizedBox(width: 8),
                Text(
                  _sudahUlasan ? 'Ulasan Sudah Ditulis' : 'Tulis Ulasan',
                  style: _font(
                    13,
                    FontWeight.w800,
                    _sudahUlasan ? _greenDeep : const Color(0xFFE08600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FORM ULASAN BOTTOM SHEET
// ══════════════════════════════════════════════════════════
class _FormUlasanSheet extends StatefulWidget {
  final Pendaftar pendaftar;
  final VoidCallback onSelesai;

  const _FormUlasanSheet({
    required this.pendaftar,
    required this.onSelesai,
  });

  @override
  State<_FormUlasanSheet> createState() => _FormUlasanSheetState();
}

class _FormUlasanSheetState extends State<_FormUlasanSheet> {
  int _rating = 0;
  final _isiCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  static const _labelRating = [
    '',
    'Kurang bagus',
    'Lumayan',
    'Bagus',
    'Sangat bagus',
    'Luar biasa!',
  ];

  @override
  void dispose() {
    _isiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Pilih rating bintang terlebih dahulu.');
      return;
    }
    if (_isiCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Tulis ulasanmu terlebih dahulu.');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('ulasan').add({
        'userId': uid,
        'pendaftaranId': widget.pendaftar.id,
        'namaWisata': widget.pendaftar.wisata,
        'rating': _rating,
        'isi': _isiCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onSelesai();
      messenger.showSnackBar(SnackBar(
        content: Text('Ulasan berhasil dikirim! Terima kasih 🌟',
            style: _font(13, FontWeight.w600, Colors.white)),
        backgroundColor: _blueDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      setState(() {
        _error = 'Gagal mengirim ulasan, coba lagi.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.rate_review_rounded,
                        color: Color(0xFFE08600), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tulis Ulasan',
                            style: _font(18, FontWeight.w800, _navy,
                                letterSpacing: -0.4)),
                        Text(widget.pendaftar.wisata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _font(12.5, FontWeight.w500, _textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Rating', style: _font(13, FontWeight.w700, _navy)),
              const SizedBox(height: 10),
              Row(
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            key: ValueKey(filled),
                            color: filled ? _orange : _border,
                            size: 38,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _labelRating[_rating],
                      style: _font(12.5, FontWeight.w700, _orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Ulasanmu', style: _font(13, FontWeight.w700, _navy)),
              const SizedBox(height: 8),
              TextField(
                controller: _isiCtrl,
                maxLines: 4,
                style: _font(14, FontWeight.w500, _navy),
                cursorColor: _blue,
                decoration: InputDecoration(
                  hintText:
                      'Bagaimana pengalamanmu di ${widget.pendaftar.wisata}?',
                  hintStyle: _font(13, FontWeight.w500, _textMuted),
                  filled: true,
                  fillColor: _background,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _border, width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _blue, width: 1.6),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: _font(12.5, FontWeight.w600, _red)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _isLoading ? null : _submit,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isLoading
                          ? [_blueDeep, _blueDeep]
                          : [const Color(0xFF2386E8), _blueDeep],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: _blue.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 17),
                              const SizedBox(width: 8),
                              Text('Kirim Ulasan',
                                  style:
                                      _font(15, FontWeight.w800, Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  INFO ITEM
// ══════════════════════════════════════════════════════════
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: _blue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _font(10.5, FontWeight.w600, _textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _font(13, FontWeight.w700, _navy),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DASHED LINE PAINTER
// ══════════════════════════════════════════════════════════
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double x = 0;
    const dashW = 6.0;
    const gapW = 4.0;
    final y = size.height / 2;

    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════
//  STATUS BADGE — dinamis
// ══════════════════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final String status;
  final bool onPhoto; // true bila ditaruh di atas foto
  const _StatusBadge({required this.status, this.onPhoto = false});

  @override
  Widget build(BuildContext context) {
    final st = _styleFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: onPhoto
            ? Colors.white.withValues(alpha: 0.95)
            : st.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: onPhoto
            ? null
            : Border.all(color: st.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: 12, color: st.deep),
          const SizedBox(width: 5),
          Text(st.label, style: _font(10.5, FontWeight.w800, st.deep)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TIKET BOTTOM SHEET — muncul saat kartu disetujui diklik
// ══════════════════════════════════════════════════════════
class _TiketBottomSheet extends StatelessWidget {
  final Pendaftar pendaftar;
  const _TiketBottomSheet({required this.pendaftar});

  @override
  Widget build(BuildContext context) {
    final p = pendaftar;
    // Data yang diencode ke QR
    final qrData =
        'WISATA_DAERAHKU|${p.nomorBukti}|${p.wisata}|${p.namaPengunjung}|${p.tanggal}|${p.jumlahOrang}';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded,
                          color: _greenDeep, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tiket Resmi',
                              style: _font(17, FontWeight.w800, _navy,
                                  letterSpacing: -0.4)),
                          Text('Tunjukkan ke petugas loket',
                              style: _font(12, FontWeight.w500, _textMuted)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: _textMuted, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Kartu Tiket ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: _green.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── Stripe header ────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2386E8), _blueDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(26)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.wisata,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _font(17, FontWeight.w800, Colors.white,
                                    letterSpacing: -0.3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('✓ VALID',
                                  style: _font(10, FontWeight.w800, _greenDeep,
                                      letterSpacing: 0.8)),
                            ),
                          ],
                        ),
                      ),

                      // ── QR Code ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _border, width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: _blue.withValues(alpha: 0.12),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: _navy,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: _navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Kode booking
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: p.nomorBukti));
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text('Kode disalin!',
                                      style: _font(
                                          13, FontWeight.w600, Colors.white)),
                                  backgroundColor: _greenDeep,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  duration: const Duration(seconds: 2),
                                ));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 11),
                                decoration: BoxDecoration(
                                  color: _orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _orange.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons.confirmation_number_rounded,
                                        color: Color(0xFFE08600),
                                        size: 17),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        p.nomorBukti,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _font(15, FontWeight.w800,
                                            const Color(0xFFE08600),
                                            letterSpacing: 0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.copy_rounded,
                                        color: _textMuted, size: 14),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Tap kode untuk menyalin',
                                style: _font(11, FontWeight.w500, _textMuted)),
                          ],
                        ),
                      ),

                      // ── Notch divider ─────────────────────────
                      _notchDivider(),

                      // ── Info rows ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        child: Column(
                          children: [
                            _tiketRow(
                                Icons.person_rounded, 'Nama', p.namaPengunjung),
                            _tiketRow(Icons.calendar_today_rounded, 'Tanggal',
                                p.tanggal),
                            _tiketRow(Icons.group_rounded, 'Jumlah',
                                '${p.jumlahOrang} orang'),
                            _tiketRow(
                                Icons.phone_rounded, 'Telepon', p.noTelepon),
                          ],
                        ),
                      ),

                      // ── Footer ───────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(26)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: _greenDeep, size: 19),
                            const SizedBox(height: 4),
                            Text(
                              'Wisata Daerahku  ·  Tiket Resmi Terverifikasi',
                              textAlign: TextAlign.center,
                              style: _font(11, FontWeight.w600, _greenDeep,
                                  letterSpacing: 0.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notchDivider() {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 22,
            decoration: const BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(11)),
            ),
          ),
          const Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(color: _border),
            ),
          ),
          Container(
            width: 16,
            height: 22,
            decoration: const BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiketRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: _blue),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(label, style: _font(12, FontWeight.w500, _textMuted)),
          ),
          Expanded(
            child: Text(value, style: _font(13, FontWeight.w700, _navy)),
          ),
        ],
      ),
    );
  }
}
