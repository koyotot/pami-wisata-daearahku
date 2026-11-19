// ============================================================
// lib/screens/bukti_pendaftaran_screen.dart
// REDESIGN: biru terang + Plus Jakarta Sans — selaras home_screen
// - Header: tombol kembali (kiri) + tombol drawer (kanan)
// - Kartu statistik (Menunggu / Disetujui / Ditolak) = filter
// - Kartu ringkasan dengan tautan ke halaman detail pendaftaran
// Butuh package: google_fonts
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/admin_state.dart' show formatInstantInZone, visitDayLabel;
import '../../data/app_data.dart';
import '../../data/booking_errors.dart';
import '../../data/booking_state.dart';
import '../../data/business_repository.dart';
import '../../data/payment_models.dart';
import '../../services/auth_session.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_presentation.dart';
import '../../widgets/booking_ticket_qr_section.dart';
import '../../widgets/booking_payment_section.dart';
import '../../widgets/booking_refund_section.dart';
import '../../widgets/payment_deadline.dart';
import '../../widgets/operations_status.dart';
import '../../widgets/visit_format.dart' show visitMonths;

// ── Palet (sama dengan home_screen) ──────────────────────────
const _blue = AppColors.blue;
const _blueDeep = AppColors.blueDeep;
const _navy = AppColors.navy;
const _orange = AppColors.orange;
const _background = AppColors.bg;
const _textMuted = AppColors.textSecondary;
const _border = AppColors.border;
const _green = AppColors.success;
const _greenDeep = AppColors.success;
const _red = AppColors.danger;
const _amber = AppColors.warningText;

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
          _green, _greenDeep, 'Disetujui', PhosphorIconsFill.checkCircle);
    case 'rejected':
    case 'ditolak':
      return const _StatusStyle(
          _red, AppColors.danger, 'Ditolak', PhosphorIconsFill.xCircle);
    case 'pending_approval':
      return _StatusStyle(_blue, _blueDeep, bookingStatusLabel(status),
          PhosphorIconsRegular.hourglassHigh);
    case 'menunggu':
      return const _StatusStyle(
          _blue, _blueDeep, 'Menunggu', PhosphorIconsRegular.hourglassHigh);
    case 'awaiting_payment':
      return const _StatusStyle(_blue, _blueDeep, 'Menunggu pembayaran',
          PhosphorIconsRegular.hourglassHigh);
    case 'payment_verification':
    case 'payment_review':
      return _StatusStyle(_amber, AppColors.warningText,
          bookingStatusLabel(status), PhosphorIconsRegular.hourglassHigh);
    case 'cancelled':
      return const _StatusStyle(_textMuted, AppColors.textSecondary,
          'Dibatalkan', PhosphorIconsRegular.prohibit);
    case 'expired':
      return const _StatusStyle(_textMuted, AppColors.textSecondary,
          'Kedaluwarsa', PhosphorIconsRegular.timer);
    default:
      return _StatusStyle(_textMuted, AppColors.textSecondary,
          bookingStatusLabel(status), PhosphorIconsRegular.info);
  }
}

String _formatBookingDate(String value, {bool shortMonth = false}) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final month = visitMonths[date.month - 1];
  return '${date.day} ${shortMonth ? month.substring(0, 3) : month} ${date.year}';
}

String _formatBookingTotal(Booking booking) {
  final amount = booking.totalAmount
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return booking.currency == 'IDR'
      ? 'Rp$amount'
      : '${booking.currency} $amount';
}

String _nextStepFor(Booking booking,
        {required bool? ticketIssued, EntryTicketsInfo? entry}) =>
    switch (booking.status) {
      'pending_approval' => 'Pendaftaran menunggu persetujuan pengelola.',
      'awaiting_payment' =>
        'Selesaikan pembayaran hanya melalui instruksi resmi yang tersedia. Pembayaran belum dikonfirmasi.',
      'payment_verification' ||
      'payment_review' =>
        'Pembayaran sedang diverifikasi dan belum dipastikan diterima.',
      'confirmed' when entry != null => _entryNextStep(entry),
      'confirmed' => switch (ticketIssued) {
          true => 'Tiket telah diterbitkan dan tersedia pada bagian Dokumen.',
          false =>
            'Pendaftaran telah dikonfirmasi. Dokumen tiket belum tersedia.',
          null =>
            'Pendaftaran telah dikonfirmasi. Ketersediaan dokumen tiket belum dapat diperiksa.',
        },
      'rejected' => 'Pendaftaran tidak disetujui.',
      'expired' => 'Pendaftaran telah kedaluwarsa.',
      'cancelled' => 'Pendaftaran telah dibatalkan.',
      _ => 'Informasi lanjutan belum tersedia untuk status ini.',
    };

/// Next-step copy for a confirmed booking, from `entry_tickets.state` only.
String _entryNextStep(EntryTicketsInfo entry) => switch (entry.state) {
      'available' ||
      'partially_checked_in' =>
        'Tiket masuk (QR) tersedia pada bagian Tiket masuk. Tunjukkan QR kepada petugas pada hari kunjungan.',
      'scheduled' => entry.qrAvailableFrom == null
          ? 'QR tiket masuk akan tersedia menjelang hari kunjungan.'
          : 'QR tiket masuk akan tersedia pada ${_formatBookingDate(entry.qrAvailableFrom!)}.',
      'fully_checked_in' => 'Seluruh tiket masuk sudah check-in.',
      'revoked' => 'Tiket masuk tidak dapat digunakan.',
      'expired' => 'Masa kunjungan telah berakhir.',
      'awaiting_payment' =>
        'Tiket masuk tersedia setelah pembayaran terverifikasi.',
      'awaiting_approval' =>
        'Tiket masuk tersedia setelah pendaftaran disetujui.',
      _ => 'Status tiket masuk sedang diperiksa.',
    };

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
  String? _filter;
  final _search = TextEditingController();
  String _query = '';

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
    setState(() {
      _filter = null;
      _query = '';
      _search.clear();
    });
    _loadBookings();
  }

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_refresh);
    BookingEvents.changed.removeListener(_loadBookings);
    _bookings.removeListener(_changed);
    _bookings.dispose();
    _search.dispose();
    super.dispose();
  }

  bool _matches(String actual, String filter) => switch (filter) {
        'menunggu' => actual == 'pending_approval',
        'disetujui' => actual == 'confirmed',
        'ditolak' => actual == 'rejected',
        'pembayaran' => const {
            'awaiting_payment',
            'payment_verification',
            'payment_review'
          }.contains(actual),
        'expired' => actual == 'expired',
        'cancelled' => actual == 'cancelled',
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
            final tampil = semua
                .where((p) =>
                    (_filter == null || _matches(p.status, _filter!)) &&
                    (_query.isEmpty ||
                        p.wisata.toLowerCase().contains(_query) ||
                        p.nomorBukti.toLowerCase().contains(_query)))
                .toList();

            int hitung(String s) =>
                semua.where((p) => _matches(p.status, s)).length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverSafeArea(
                  top: false,
                  left: false,
                  right: false,
                  sliver: SliverMainAxisGroup(slivers: [
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
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Text(bookingErrorMessage(_bookings.error!)),
                              TextButton(
                                  onPressed: _refresh,
                                  child: const Text('Coba lagi')),
                            ])),
                      )
                    else if (semua.isEmpty)
                      SliverFillRemaining(
                          hasScrollBody: false, child: _buildEmpty())
                    else ...[
                      SliverToBoxAdapter(
                          child: _buildSectionTitle(tampil.length)),
                      if (tampil.isEmpty)
                        SliverFillRemaining(
                            hasScrollBody: false, child: _buildFilterKosong())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                              AppSpacing.lg, AppSpacing.xl + AppSpacing.sm),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final p = tampil[i];
                                return _FadeSlide(
                                  // State kartu mengikuti booking saat filter berganti.
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
                  ]),
                ),
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
    // Larger text wraps the title and subtitle; give them room so they stay
    // below the toolbar pill instead of running into it.
    final textGrowth =
        (MediaQuery.textScalerOf(context).scale(13) / 13 - 1).clamp(0.0, 2.0);
    return SliverAppBar(
      expandedHeight: 252 + textGrowth * 150,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _blue,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.bookmark,
                size: 14, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$total pendaftaran',
              style: _font(11, FontWeight.w700, Colors.white),
            ),
          ],
        ),
      ),
      // Tombol pembuka drawer
      actions: [
        if (widget.onBukaMenu != null)
          _headerButton(
            icon: PhosphorIconsRegular.list,
            iconSize: 22,
            margin: const EdgeInsets.fromLTRB(
                0, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            onTap: widget.onBukaMenu!,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: TimeBasedScenicBackground(
          active: widget.active,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 32,
                  decoration: const BoxDecoration(
                    color: _background,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Riwayat Pendaftaran',
                      style: _font(
                        22,
                        FontWeight.w800,
                        Colors.white,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
        preferredSize: const Size.fromHeight(110),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl * 2),
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
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatTile(
                  label: 'Disetujui',
                  count: disetujui,
                  accent: _greenDeep,
                  selected: _filter == 'disetujui',
                  onTap: () => _setFilter('disetujui'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text('Daftar kunjungan',
                  style: _font(16, FontWeight.w800, _navy))),
          const SizedBox(width: AppSpacing.sm),
          Text('$jumlah pendaftaran',
              style: _font(12, FontWeight.w500, _textMuted)),
        ]),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (value, label) in const <(String?, String)>[
              (null, 'Semua'),
              ('menunggu', 'Persetujuan'),
              ('disetujui', 'Disetujui'),
              ('pembayaran', 'Pembayaran'),
              ('expired', 'Kedaluwarsa'),
              ('cancelled', 'Dibatalkan'),
              ('ditolak', 'Ditolak'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Semantics(
                  selected: _filter == value,
                  child: OutlinedButton(
                    key: ValueKey('history-filter-${value ?? 'all'}'),
                    onPressed: () => setState(() => _filter = value),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      foregroundColor:
                          _filter == value ? _blueDeep : _textMuted,
                      backgroundColor: _filter == value
                          ? AppColors.blueTint
                          : AppColors.surface,
                      side: BorderSide(
                          color: _filter == value
                              ? _blue.withValues(alpha: .3)
                              : _border),
                      textStyle: _font(13, FontWeight.w800, _navy),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.md)),
                    ),
                    child: Text(label),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          key: const ValueKey('history-search'),
          controller: _search,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          style: _font(13, FontWeight.w500, _navy),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari destinasi atau nomor booking',
            hintStyle: _font(12, FontWeight.w500, _textMuted),
            constraints:
                const BoxConstraints(minHeight: kMinInteractiveDimension),
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                size: 20, color: _textMuted),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                    icon: const Icon(PhosphorIconsRegular.x, size: 20)),
          ),
        ),
      ]),
    );
  }

  // ── Empty state (belum ada riwayat sama sekali) ────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl + AppSpacing.sm, horizontal: AppSpacing.lg),
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
            child:
                const Icon(PhosphorIconsRegular.ticket, size: 48, color: _blue),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Belum ada riwayat pendaftaran',
              style: _font(17, FontWeight.w800, _navy, letterSpacing: -0.3)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Daftarkan kunjungan wisata terlebih dahulu,\ntiketmu akan muncul di sini.',
            textAlign: TextAlign.center,
            style: _font(13, FontWeight.w500, _textMuted, height: 1.6),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: _jelajahi,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                elevation: 0,
                textStyle: _font(13, FontWeight.w800, AppColors.surface),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            icon: const Icon(PhosphorIconsRegular.compass, size: 20),
            label: const Text('Jelajahi Wisata'),
          ),
        ],
      ),
    );
  }

  // ── Filter aktif tapi tidak ada hasil ──────────────────────
  Widget _buildFilterKosong() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl + AppSpacing.sm, horizontal: AppSpacing.lg),
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
            child: const Icon(PhosphorIconsRegular.tray,
                size: 42, color: _textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Pendaftaran tidak ditemukan',
              style: _font(17, FontWeight.w800, _navy, letterSpacing: -0.3)),
          const SizedBox(height: AppSpacing.sm),
          Text('Coba kata kunci atau status yang lain.',
              style: _font(13, FontWeight.w500, _textMuted)),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => setState(() {
              _filter = null;
              _search.clear();
              _query = '';
            }),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                elevation: 0,
                textStyle: _font(13, FontWeight.w800, AppColors.surface),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Tampilkan semua'),
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
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        // The tile height is fixed by the header; at large text scales the
        // label stays on one line and the content shrinks only as far as needed.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: _font(
                    26, FontWeight.w800, selected ? accent : Colors.white,
                    height: 1.1),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: _font(
                  11,
                  FontWeight.w700,
                  selected ? _textMuted : Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
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
    if (MediaQuery.disableAnimationsOf(context)) return child;
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
  final bool initiallyExpanded;
  final bool detailPage;
  final BusinessRepository? repository;

  /// Dipanggil dengan salinan booking terbaru dari server (detail / hasil pembatalan).
  final ValueChanged<Booking>? onChanged;
  final ValueChanged<bool>? onTicketIssued;

  const _TicketCard(
      {required this.pendaftar,
      this.booking,
      this.isLaravel = false,
      this.initiallyExpanded = false,
      this.detailPage = false,
      this.repository,
      this.onChanged,
      this.onTicketIssued});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _contactExpanded = false;
  bool get _sudahUlasan => _controller?.booking.review != null;
  String? _statusSebelumnya;
  BookingDetailController? _controller;
  PaymentSnapshot? _paymentSnapshot;

  @override
  void initState() {
    super.initState();
    _statusSebelumnya = widget.pendaftar.status;
    final booking = widget.booking;
    if (widget.isLaravel && booking != null) {
      _controller = BookingDetailController(
          widget.repository ?? BusinessRepository(), booking)
        ..addListener(_controllerChanged);
      _emitted = booking;
      if (widget.initiallyExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadDetail();
        });
      }
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
    final documents = _controller?.documents;
    if (documents != null) {
      widget.onTicketIssued?.call(documents.entryTicketsIssued);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(PhosphorIconsFill.checkCircle, color: _green, size: 18),
            const SizedBox(width: AppSpacing.sm),
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
            const Icon(PhosphorIconsFill.xCircle,
                color: Colors.white, size: 18),
            const SizedBox(width: AppSpacing.sm),
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

  void _bukaFormUlasan() {
    final controller = _controller;
    if (controller == null || !controller.booking.canReview) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpacing.xl))),
      builder: (_) => SafeArea(
          top: false,
          child: _FormUlasanSheet(
            pendaftar: widget.pendaftar,
            controller: controller,
            onSelesai: () {
              if (mounted) setState(() {});
            },
          )),
    );
  }

  void _copyNomor() {
    Clipboard.setData(ClipboardData(text: widget.pendaftar.nomorBukti));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(PhosphorIconsFill.checkCircle, color: _green, size: 18),
            const SizedBox(width: AppSpacing.sm),
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final p = controller != null
        ? _fromBooking(controller.booking)
        : widget.pendaftar;
    final st = _styleFor(p.status);

    if (widget.detailPage && controller != null) {
      return _buildDetailPage(controller);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTicketHeader(p, st),
          _buildDashedDivider(),
          _buildTicketBody(p),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _detailPair(
              Text(_historySummary(controller?.booking),
                  style: _font(12, FontWeight.w500, _textMuted, height: 1.5)),
              TextButton(
                key: const ValueKey('history-booking-detail'),
                onPressed: controller == null
                    ? null
                    : () => _openBookingDetail(controller),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  foregroundColor: _blueDeep,
                  textStyle: _font(13, FontWeight.w800, _blueDeep),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Lihat detail'),
                  SizedBox(width: AppSpacing.sm),
                  Icon(PhosphorIconsRegular.arrowRight, size: 18),
                ]),
              ),
              intrinsicSecond: true,
            ),
          ),
        ],
      ),
    );
  }

  String _historySummary(Booking? booking) {
    if (booking == null) return 'Total belum tersedia';
    if (booking.status == 'confirmed') {
      if (booking.json['quantity'] is! num ||
          (booking.json['checked_in_count'] is! num &&
              booking.checkedInAt == null)) {
        return 'Check-in belum tersedia';
      }
      return '${booking.checkedInCount} dari ${booking.quantity} check-in';
    }
    return '${_detailTotal(booking)} · Total booking';
  }

  Future<void> _openBookingDetail(BookingDetailController controller) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BookingTicketScreen(
            bookingGuid: controller.booking.guid,
            repository: controller.repository)));
    if (mounted) await controller.refresh();
  }

  Widget _buildDetailPage(BookingDetailController c) {
    final b = c.booking;
    Widget page({Widget? paymentContent, Widget? checkout}) => Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(title: const Text('Detail Pendaftaran')),
          bottomNavigationBar: checkout == null
              ? null
              : Material(
                  color: AppColors.surface,
                  elevation: 8,
                  shadowColor: AppColors.dockShadow,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.all(AppSpacing.lg),
                    child: _detailPair(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total pembayaran',
                              style: _font(12, FontWeight.w500,
                                  AppColors.textSecondary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(_detailTotal(b),
                              style: _font(
                                  13, FontWeight.w800, AppColors.blueDeep)),
                        ],
                      ),
                      checkout,
                      intrinsicSecond: true,
                    ),
                  ),
                ),
          body: SafeArea(
            top: false,
            bottom: checkout == null,
            child: RefreshIndicator(
              onRefresh: () async {
                await c.refresh();
                await c.loadDocuments();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.refreshing) const LinearProgressIndicator(),
                    _detailSummary(b),
                    _detailProgress(c),
                    if (b.status == 'awaiting_payment') ...[
                      const SizedBox(height: AppSpacing.md),
                      if (b.paymentExpiresAt != null)
                        PaymentDeadline(
                          expiresAt: b.paymentExpiresAt,
                          serverTime: _paymentSnapshot?.serverTime,
                          banner: true,
                          caption: 'Status akhir diverifikasi oleh sistem.',
                          onElapsed: () {
                            c.refresh();
                            BookingEvents.notify();
                          },
                        )
                      else if (b.paymentSelectionExpiresAt != null)
                        _detailSelectionDeadline(b),
                    ],
                    if (b.status == 'confirmed' &&
                        (b.paymentStatus == 'paid' ||
                            b.paymentTestOnly ||
                            b.isFree ||
                            c.documents?.entryTickets?.isFree == true))
                      BookingTicketQrSection(
                          repository: c.repository,
                          bookingGuid: b.guid,
                          booking: b,
                          onRefreshed: c.refresh),
                    _detailHeading('Informasi Kunjungan'),
                    _detailVisit(b, c.documents?.entryTickets),
                    _detailHeading('Data Pendaftar'),
                    _detailContact(b),
                    const SizedBox(height: AppSpacing.md),
                    _detailPanel(
                      _detailNotice(
                        PhosphorIconsRegular.info,
                        'Apa langkah selanjutnya?',
                        b.status == 'awaiting_payment' &&
                                _paymentSnapshot?.canCreate == true &&
                                _paymentSnapshot?.attemptStatus == null
                            ? 'Pendaftaran sudah disetujui, tetapi pembayaran belum dikonfirmasi. Pilih metode pembayaran untuk melanjutkan. Nomor VA atau QRIS ditampilkan setelah diterbitkan provider.'
                            : _nextStepFor(b,
                                ticketIssued: c.documents?.entryTicketsIssued,
                                entry: c.documents?.entryTickets),
                      ),
                      color: AppColors.blueTint,
                    ),
                    if (b.paymentTestOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          '${b.paymentLabel ?? 'DEMO'} / TEST_ONLY · tanpa uang nyata',
                          style: _font(12, FontWeight.w700, AppColors.blueDeep),
                        ),
                      ),
                    if (paymentContent != null) paymentContent,
                    if (c.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(c.message!,
                            key: const ValueKey('detailMessage'),
                            style: _font(12, FontWeight.w600, _red)),
                      ),
                    _detailHeading('Dokumen Pendaftaran'),
                    _detailPanel(
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _documentWidgets(c)),
                        padding: AppSpacing.lg),
                    if (b.status == 'confirmed' && b.paymentStatus == 'paid')
                      BookingRefundSection(
                          repository: c.repository,
                          bookingGuid: b.guid,
                          onChanged: c.refresh),
                    if (b.cancellable) ...[
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        key: const ValueKey('cancelBooking'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _red,
                          backgroundColor: AppColors.surface,
                          textStyle: _font(13, FontWeight.w800, _red),
                          minimumSize: const Size(48, 48),
                          side: BorderSide(color: _red.withValues(alpha: .4)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.md)),
                        ),
                        onPressed:
                            c.cancelling ? null : () => _confirmCancel(c),
                        icon:
                            const Icon(PhosphorIconsRegular.xCircle, size: 20),
                        label: Text(c.cancelling
                            ? 'Membatalkan…'
                            : 'Batalkan Pendaftaran'),
                      ),
                    ],
                    if (b.canReview || _sudahUlasan) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildUlasanButton(),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        );

    if (!b.isFree &&
        (const ['awaiting_payment', 'payment_verification', 'payment_review']
                .contains(b.status) ||
            (b.paymentTestOnly && b.paymentStatus != 'paid'))) {
      return BookingPaymentSection(
        booking: b,
        repository: c.repository,
        onSnapshot: (snapshot) {
          if (mounted) setState(() => _paymentSnapshot = snapshot);
        },
        onReturned: () async {
          await c.refresh();
          await c.loadDocuments();
        },
        layoutBuilder: (context, content, checkout) => page(
            paymentContent: checkout == null ? content : null,
            checkout: checkout),
      );
    }
    return page();
  }

  String _detailTotal(Booking b) =>
      b.json['total_amount'] is num ? _formatBookingTotal(b) : 'Belum tersedia';

  Widget _detailPanel(Widget child,
          {Color color = AppColors.surface,
          Color border = AppColors.border,
          double padding = AppSpacing.lg}) =>
      Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
        child: child,
      );

  Widget _detailHeading(String title) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
        child: Text(title, style: _font(16, FontWeight.w800, AppColors.navy)),
      );

  Widget _detailPair(Widget first, Widget second,
          {bool intrinsicSecond = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: AppSpacing.md), second],
            );
          }
          return Row(children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.md),
            if (intrinsicSecond) second else Expanded(child: second),
          ]);
        },
      );

  Widget _detailSummary(Booking b) => _detailPanel(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('PENDAFTARAN WISATA',
                    style: _font(11, FontWeight.w700, AppColors.textSecondary,
                        letterSpacing: .8)),
                _StatusBadge(status: b.status, compact: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(b.destinationName,
              style: _font(16, FontWeight.w800, AppColors.navy)),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Kunjungan wisata · ${b.visitDate.isEmpty ? 'Tanggal belum tersedia' : _formatBookingDate(b.visitDate)}',
              style: _font(12, FontWeight.w500, AppColors.textSecondary)),
          const Divider(height: AppSpacing.xl, color: AppColors.border),
          _detailPair(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total tagihan',
                  style: _font(12, FontWeight.w500, AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(_detailTotal(b),
                  style: _font(26, FontWeight.w800, AppColors.blueDeep)),
            ]),
            OutlinedButton.icon(
              key: const ValueKey('booking-code'),
              onPressed:
                  b.bookingNumber.isEmpty ? null : () => _showBookingCode(b),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                backgroundColor: AppColors.blueTint,
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                side: BorderSide(color: AppColors.blue.withValues(alpha: .2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.md)),
              ),
              icon: const Icon(PhosphorIconsRegular.copy, size: 18),
              label: Text('Kode Booking',
                  style: _font(13, FontWeight.w800, AppColors.blue)),
            ),
            intrinsicSecond: true,
          ),
        ],
      ));

  Widget _detailProgress(BookingDetailController c) {
    final b = c.booking;
    final approved = const {
      'awaiting_payment',
      'payment_verification',
      'payment_review',
      'confirmed'
    }.contains(b.status);
    final confirmed = b.status == 'confirmed';
    final issued = confirmed && c.documents?.entryTicketsIssued == true;
    final stopped =
        const {'rejected', 'cancelled', 'expired'}.contains(b.status);
    final current = confirmed ? 3 : (approved ? 2 : 1);
    final steps = [
      (
        'Disetujui',
        approved ? 'Berhasil' : bookingStatusLabel(b.status),
        approved
      ),
      (
        'Pembayaran',
        confirmed
            ? (b.isFree ? 'Gratis' : 'Terkonfirmasi')
            : (approved && !stopped
                ? (b.status == 'awaiting_payment'
                    ? 'Menunggu'
                    : bookingStatusLabel(b.status))
                : 'Belum tersedia'),
        confirmed
      ),
      (
        'Tiket Masuk',
        issued
            ? 'Diterbitkan'
            : (c.loadingDocuments
                ? 'Memeriksa…'
                : (c.documents == null ? 'Belum diketahui' : 'Belum tersedia')),
        issued
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text('Progres Pendaftaran',
                style: _font(16, FontWeight.w800, AppColors.navy)),
            Text(
                stopped
                    ? bookingStatusLabel(b.status)
                    : 'Langkah $current dari 3',
                style: _font(12, FontWeight.w500, AppColors.textSecondary)),
          ],
        ),
      ),
      _detailPanel(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: SizedBox(
                  width: AppSpacing.xl,
                  child: Divider(
                      height: 1,
                      color: steps[i - 1].$3
                          ? AppColors.success.withValues(alpha: .4)
                          : AppColors.border)),
            ),
          Expanded(
              child: Column(children: [
            Container(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: steps[i].$3
                        ? AppColors.success.withValues(alpha: .2)
                        : (!stopped && current == i + 1
                            ? AppColors.blue.withValues(alpha: .25)
                            : AppColors.border)),
                color: steps[i].$3
                    ? AppColors.successTint
                    : (!stopped && current == i + 1
                        ? AppColors.blueTint
                        : AppColors.bg),
              ),
              child: steps[i].$3
                  ? const Icon(PhosphorIconsRegular.check,
                      size: 14, color: AppColors.success)
                  : Text('${i + 1}',
                      style: _font(
                          11,
                          FontWeight.w800,
                          !stopped && current == i + 1
                              ? AppColors.blue
                              : AppColors.textSecondary)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(steps[i].$1,
                textAlign: TextAlign.center,
                style: _font(12, FontWeight.w700, AppColors.navy)),
            const SizedBox(height: AppSpacing.xs),
            Text(steps[i].$2,
                textAlign: TextAlign.center,
                style: _font(12, FontWeight.w500, AppColors.textSecondary)),
          ])),
        ],
      ])),
    ]);
  }

  Widget _detailSelectionDeadline(Booking b) => _detailPanel(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warningBorder.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: const Icon(PhosphorIconsRegular.clock,
                size: 16, color: AppColors.warningText),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batas memilih pembayaran',
                    style: _font(14, FontWeight.w700, AppColors.warningText)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    formatInstantInZone(
                            b.paymentSelectionExpiresAt!, b.destinationTimezone)
                        .replaceFirst(', ', ' · '),
                    style: _font(12, FontWeight.w800, AppColors.warningText)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Pilih metode pembayaran sebelum batas waktu yang ditentukan.\nStatus akhir tetap diverifikasi oleh sistem.',
                    style: _font(12, FontWeight.w500, AppColors.warningText,
                        height: 1.5)),
              ],
            ),
          ),
        ]),
        color: AppColors.warningTint,
        border: AppColors.warningBorder,
      );

  Widget _detailVisit(Booking b, EntryTicketsInfo? entry) {
    final checked = (b.json['checked_in_count'] as num?)?.toInt() ??
        (b.checkedInAt == null ? null : b.quantity);
    final quantity = (b.json['quantity'] as num?)?.toInt();
    return _detailPanel(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _detailPair(
          _detailPanel(
              _InfoItem(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: 'Tanggal kunjungan',
                  maxLines: null,
                  compact: true,
                  value: b.visitDate.isEmpty
                      ? 'Belum tersedia'
                      : visitDayLabel(b.visitDate)),
              color: AppColors.bg,
              padding: AppSpacing.md),
          _detailPanel(
              _InfoItem(
                  icon: PhosphorIconsRegular.users,
                  label: 'Jumlah pengunjung',
                  maxLines: null,
                  compact: true,
                  value:
                      quantity == null ? 'Belum tersedia' : '$quantity orang'),
              color: AppColors.bg,
              padding: AppSpacing.md),
        ),
        const Divider(height: AppSpacing.xl, color: AppColors.border),
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text('Progres check-in',
                  style: _font(12, FontWeight.w500, AppColors.textSecondary)),
              Text(
                  checked == null || quantity == null
                      ? 'Belum tersedia'
                      : '$checked / $quantity pengunjung',
                  style: _font(12, FontWeight.w700, AppColors.blueDeep)),
            ]),
        const SizedBox(height: AppSpacing.sm),
        if (checked != null && quantity != null && quantity > 0)
          LinearProgressIndicator(
            value: (checked / quantity).clamp(0.0, 1.0),
            minHeight: AppSpacing.sm,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            backgroundColor: AppColors.bg,
            color: AppColors.blue,
            semanticsLabel: 'Progres check-in',
            semanticsValue: '$checked dari $quantity pengunjung',
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
            checked == 0 && b.status == 'awaiting_payment'
                ? 'Check-in belum dilakukan. Tiket masuk belum tersedia selama pembayaran belum terkonfirmasi.'
                : entry != null
                    ? _entryNextStep(entry)
                    : (b.status != 'confirmed'
                        ? 'Tiket masuk belum tersedia. ${bookingStatusNote(b.status) ?? bookingStatusLabel(b.status)}'
                        : 'Ketersediaan tiket masuk dapat diperiksa pada bagian Tiket masuk.'),
            style: _font(12, FontWeight.w500, AppColors.textSecondary,
                height: 1.5)),
      ],
    ));
  }

  Widget _detailContact(Booking b) => _detailPanel(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailPair(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nama pendaftar',
                  style: _font(12, FontWeight.w500, AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(b.visitorName,
                  style: _font(13, FontWeight.w700, AppColors.navy)),
            ]),
            TextButton(
              key: const ValueKey('toggle-booking-contact'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                backgroundColor: AppColors.blueTint,
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.md)),
              ),
              onPressed: () =>
                  setState(() => _contactExpanded = !_contactExpanded),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_contactExpanded ? 'Tutup Kontak' : 'Lihat Kontak',
                    style: _font(13, FontWeight.w800, AppColors.blue)),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                    _contactExpanded
                        ? PhosphorIconsRegular.caretUp
                        : PhosphorIconsRegular.caretDown,
                    size: 16),
              ]),
            ),
            intrinsicSecond: true,
          ),
          if (_contactExpanded) ...[
            const Divider(height: AppSpacing.xl, color: AppColors.border),
            Text('Email',
                style: _font(11, FontWeight.w500, AppColors.textSecondary)),
            SelectableText(
                b.visitorEmail.isEmpty ? 'Belum tersedia' : b.visitorEmail,
                style: _font(13, FontWeight.w600, AppColors.navy)),
            const SizedBox(height: AppSpacing.md),
            Text('Nomor telepon',
                style: _font(11, FontWeight.w500, AppColors.textSecondary)),
            SelectableText(
                b.visitorPhone.isEmpty ? 'Belum tersedia' : b.visitorPhone,
                style: _font(13, FontWeight.w600, AppColors.navy)),
          ],
          if (b.notes?.isNotEmpty == true) ...[
            const Divider(height: AppSpacing.xl, color: AppColors.border),
            Text('Catatan',
                style: _font(11, FontWeight.w500, AppColors.textSecondary)),
            Text(b.notes!, style: _font(12, FontWeight.w500, AppColors.navy)),
          ],
        ],
      ));

  Widget _detailNotice(IconData icon, String title, String text,
          {Color color = AppColors.blueDeep}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: _font(14, FontWeight.w700, color)),
                const SizedBox(height: AppSpacing.sm),
                Text(text,
                    style: _font(12, FontWeight.w500, AppColors.textSecondary,
                        height: 1.6)),
              ])),
        ],
      );

  Future<T?> _detailSheet<T>(Widget Function(BuildContext) content,
          {double padding = AppSpacing.sheetPadding}) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSpacing.xl))),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: content(sheetContext),
            ),
          ),
        ),
      );

  void _showBookingCode(Booking b) {
    _detailSheet<void>((sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kode Booking',
                style: _font(20, FontWeight.w800, AppColors.navy)),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(b.bookingNumber,
                style: _font(16, FontWeight.w700, AppColors.blueDeep)),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              key: const ValueKey('copy-booking-code'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  elevation: 0,
                  textStyle: _font(13, FontWeight.w800, AppColors.surface),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                Navigator.pop(sheetContext);
                _copyNomor();
              },
              icon: const Icon(PhosphorIconsRegular.copy, size: 16),
              label: const Text('Salin'),
            ),
          ],
        ));
  }

  Widget _buildTicketHeader(Pendaftar p, _StatusStyle st) {
    final tone = switch (p.status) {
      'pending_approval' ||
      'awaiting_payment' ||
      'payment_verification' ||
      'payment_review' =>
        OperationsTone.orange,
      'confirmed' => OperationsTone.green,
      'rejected' => OperationsTone.red,
      _ => OperationsTone.grey,
    };
    final colors = operationsToneColors(tone);
    final icon = switch (p.status) {
      'confirmed' => PhosphorIconsRegular.checkCircle,
      'rejected' => PhosphorIconsRegular.xCircle,
      'awaiting_payment' || 'expired' => PhosphorIconsRegular.clock,
      _ => st.icon,
    };
    return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.bg,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: colors.fg),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                  child: Text(st.label,
                      style: _font(11, FontWeight.w700, colors.fg))),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(p.wisata,
              style: _font(16, FontWeight.w800, _navy, height: 1.25)),
          const SizedBox(height: AppSpacing.sm),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(PhosphorIconsRegular.ticket, size: 16, color: _blue),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: SelectableText(
                    p.nomorBukti.isEmpty
                        ? 'Kode booking belum tersedia'
                        : p.nomorBukti,
                    style: _font(11, FontWeight.w700, _blue, height: 1.5))),
          ]),
        ]));
  }

  Widget _buildDashedDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
          height: 1,
          width: double.infinity,
          child: CustomPaint(painter: _DashedLinePainter(color: _border))),
    );
  }

  Widget _buildTicketBody(Pendaftar p) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _detailPair(
        _InfoItem(
            icon: PhosphorIconsRegular.calendarBlank,
            label: 'Tanggal kunjungan',
            compact: true,
            maxLines: null,
            value: p.tanggal.isEmpty
                ? 'Belum tersedia'
                : _formatBookingDate(p.tanggal, shortMonth: true)),
        _InfoItem(
            icon: PhosphorIconsRegular.users,
            label: 'Jumlah pengunjung',
            compact: true,
            maxLines: null,
            value: _controller?.booking.json['quantity'] is num
                ? '${p.jumlahOrang} orang'
                : 'Belum tersedia'),
      ),
    );
  }

  void _loadDetail() {
    final controller = _controller;
    if (controller == null) return;
    controller.refresh();
    controller.loadDocuments();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCancel(BookingDetailController c) async {
    if (c.cancelling) return;
    final yes = await _detailSheet<bool>(
        (sheetContext) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('Batalkan Pendaftaran',
                          style: _font(20, FontWeight.w800, AppColors.navy))),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(sheetContext, false),
                    icon: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.sheetCloseBackground,
                          borderRadius: BorderRadius.circular(AppSpacing.md)),
                      child: const Icon(PhosphorIconsRegular.x,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ]),
                const Divider(height: AppSpacing.xl, color: AppColors.border),
                Text(
                  'Yakin ingin mengajukan pembatalan pendaftaran ${c.booking.destinationName}${c.booking.visitDate.isEmpty ? '' : ' untuk ${_formatBookingDate(c.booking.visitDate)}'}?',
                  style: _font(12, FontWeight.w500, AppColors.textSecondary,
                      height: 1.6),
                ),
                const SizedBox(height: AppSpacing.xl),
                _detailPair(
                  Text('Jumlah pengunjung',
                      style:
                          _font(12, FontWeight.w500, AppColors.textSecondary)),
                  Text(
                      c.booking.json['quantity'] is num
                          ? '${c.booking.quantity} orang'
                          : 'Belum tersedia',
                      style: _font(13, FontWeight.w700, AppColors.navy)),
                  intrinsicSecond: true,
                ),
                const Divider(height: AppSpacing.xl, color: AppColors.border),
                _detailPair(
                  Text('Total tagihan',
                      style:
                          _font(12, FontWeight.w500, AppColors.textSecondary)),
                  Text(_detailTotal(c.booking),
                      style: _font(13, FontWeight.w700, AppColors.navy)),
                  intrinsicSecond: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                _detailPair(
                  OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.blueDeep,
                          side: const BorderSide(color: AppColors.border),
                          textStyle:
                              _font(13, FontWeight.w800, AppColors.blueDeep),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(kMinInteractiveDimension,
                              kMinInteractiveDimension + AppSpacing.xs)),
                      child: const Text('Kembali')),
                  ElevatedButton(
                      key: const ValueKey('confirm-cancel-booking'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: AppColors.surface,
                          elevation: 0,
                          textStyle:
                              _font(13, FontWeight.w800, AppColors.surface),
                          minimumSize: const Size(kMinInteractiveDimension,
                              kMinInteractiveDimension + AppSpacing.xs),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Batalkan')),
                ),
              ],
            ),
        padding: AppSpacing.sheetPadding);
    if (yes != true || !mounted) return;
    final ok = await c.cancel();
    if (widget.detailPage && ok && mounted) {
      await c.refresh();
      await c.loadDocuments();
    }
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

  List<Widget> _documentWidgets(BookingDetailController c) {
    final docs = c.documents;
    return [
      if (c.loadingDocuments)
        Row(children: [
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Text('Memeriksa dokumen...',
              style: _font(12, FontWeight.w500, _textMuted)),
        ])
      else if (c.documentsError != null)
        Row(children: [
          Expanded(
              child: Text(c.documentsError!,
                  style: _font(12, FontWeight.w500, _red))),
          TextButton(
              onPressed: c.loadDocuments, child: const Text('Coba lagi')),
        ])
      else if (docs != null) ...[
        if (docs.invoice == null &&
            !docs.ticketDownloadAvailable &&
            !docs.receiptAvailable)
          Text('Dokumen belum diterbitkan.',
              style: _font(12, FontWeight.w500, _textMuted)),
        if (docs.invoice != null)
          _documentRow(c, 'invoice', 'Konfirmasi pendaftaran (invoice)'),
        if (docs.receiptAvailable)
          _documentRow(c, 'receipt', 'Bukti pembayaran'),
        if (docs.ticketDownloadAvailable) ...[
          _documentRow(c, 'ticket', 'Dokumen tiket grup (PDF)'),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
                'Dokumen ini hanya konfirmasi pendaftaran, bukan tiket masuk. QR tiket masuk ada pada bagian Tiket masuk.',
                key: const ValueKey('ticketDocumentNote'),
                style: _font(11, FontWeight.w500, _textMuted)),
          ),
        ],
        if (docs.invoice != null && !widget.detailPage)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
                'Invoice adalah konfirmasi pendaftaran, bukan bukti pembayaran.',
                style: _font(11, FontWeight.w500, _textMuted)),
          ),
      ],
    ];
  }

  Widget _documentRow(BookingDetailController c, String type, String label) {
    final busy = c.downloading == type;
    if (widget.detailPage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.blueTint,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: const Icon(PhosphorIconsRegular.fileText,
                size: 20, color: AppColors.blue),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48)),
              onPressed:
                  c.downloading != null ? null : () => _download(c, type),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type == 'invoice' ? 'Konfirmasi Pendaftaran' : label,
                      style: _font(13, FontWeight.w700, AppColors.navy)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                      switch (type) {
                        'invoice' => 'Invoice · Bukan bukti pembayaran',
                        'receipt' => 'Bukti pembayaran dari sistem',
                        _ => 'PDF grup · Bukan tiket masuk QR',
                      },
                      style:
                          _font(12, FontWeight.w500, AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            key: ValueKey('download_$type'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              backgroundColor: AppColors.blueTint,
              textStyle: _font(13, FontWeight.w800, AppColors.blue),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              side: BorderSide(color: AppColors.blue.withValues(alpha: .2)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.md)),
            ),
            onPressed: c.downloading != null ? null : () => _download(c, type),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Unduh'),
          ),
        ]),
      );
    }
    return Row(children: [
      Expanded(child: Text(label, style: _font(12, FontWeight.w600, _navy))),
      TextButton(
        key: ValueKey('download_$type'),
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: _font(13, FontWeight.w800, _blue)),
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Material(
        color: _sudahUlasan ? _background : _orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _sudahUlasan ? null : _bukaFormUlasan,
          splashColor: _orange.withValues(alpha: 0.15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _sudahUlasan ? _border : _orange.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _sudahUlasan
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsRegular.chatText,
                  color: _sudahUlasan ? _greenDeep : const Color(0xFFE08600),
                  size: 17,
                ),
                const SizedBox(width: AppSpacing.sm),
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
  final BookingDetailController controller;

  const _FormUlasanSheet({
    required this.pendaftar,
    required this.onSelesai,
    required this.controller,
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
    if (_isLoading) return;
    if (_rating == 0) {
      setState(() => _error = 'Pilih rating bintang terlebih dahulu.');
      return;
    }
    if (_isiCtrl.text.trim().length > 2000) {
      setState(() => _error = 'Ulasan maksimal 2000 karakter.');
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
      final success =
          await widget.controller.submitReview(_rating, _isiCtrl.text.trim());
      if (!mounted) return;
      if (!success) {
        setState(() {
          _error = widget.controller.message ??
              'Ulasan belum dapat dikirim. Muat ulang status pendaftaran.';
          _isLoading = false;
        });
        return;
      }
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
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mengirim ulasan, coba lagi.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sheetPadding),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
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
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(PhosphorIconsRegular.chatText,
                        color: Color(0xFFE08600), size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tulis Ulasan',
                            style: _font(20, FontWeight.w800, _navy,
                                letterSpacing: -0.4)),
                        Text(widget.pendaftar.wisata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _font(12, FontWeight.w500, _textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Rating', style: _font(13, FontWeight.w700, _navy)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.sm,
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < _rating;
                    return IconButton(
                      tooltip: '${i + 1} bintang',
                      onPressed: () => setState(() => _rating = i + 1),
                      style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.all(AppSpacing.xs)),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          filled
                              ? PhosphorIconsFill.star
                              : PhosphorIconsRegular.star,
                          key: ValueKey(filled),
                          color: filled ? _orange : _border,
                          size: 38,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(_labelRating[_rating],
                  style: _font(12, FontWeight.w700, _orange)),
              const SizedBox(height: AppSpacing.lg),
              Text('Ulasanmu', style: _font(13, FontWeight.w700, _navy)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _isiCtrl,
                maxLines: 4,
                style: _font(13, FontWeight.w500, _navy),
                cursorColor: _blue,
                decoration: InputDecoration(
                  hintText:
                      'Bagaimana pengalamanmu di ${widget.pendaftar.wisata}?',
                  hintStyle: _font(13, FontWeight.w500, _textMuted),
                  filled: true,
                  fillColor: _background,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _blue, width: 1.6),
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.warningCircle,
                        color: _red, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(_error!,
                          style: _font(12, FontWeight.w600, _red)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('submit-booking-review'),
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(48, 52),
                      elevation: 0,
                      textStyle: _font(13, FontWeight.w800, AppColors.surface),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(PhosphorIconsRegular.paperPlaneTilt,
                          size: 20),
                  label: const Text('Kirim Ulasan'),
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
  final int? maxLines;
  final bool compact;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 2,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? AppSpacing.xl + AppSpacing.xs : 32,
          height: compact ? AppSpacing.xl + AppSpacing.xs : 32,
          decoration: BoxDecoration(
            color: AppColors.blueTint,
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          child: Icon(icon, size: 15, color: _blue),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _font(compact ? 11 : 12, FontWeight.w500, _textMuted,
                    height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                maxLines: maxLines,
                overflow: maxLines == null
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: _font(13, FontWeight.w700, _navy, height: 1.5),
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
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double x = 0;
    const dashW = AppSpacing.xs;
    const gapW = AppSpacing.xs;
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
  final bool compact;
  const _StatusBadge(
      {required this.status, this.onPhoto = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final st = _styleFor(status);
    final awaitingPayment = compact && status == 'awaiting_payment';
    final foreground = awaitingPayment ? AppColors.warningText : st.deep;

    return Container(
      padding: compact
          ? const EdgeInsets.all(AppSpacing.sm)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: onPhoto
            ? Colors.white.withValues(alpha: 0.95)
            : awaitingPayment
                ? AppColors.warningTint
                : st.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: onPhoto
            ? null
            : Border.all(
                color: awaitingPayment
                    ? AppColors.warningBorder
                    : st.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            ExcludeSemantics(
                child:
                    Icon(PhosphorIconsFill.circle, size: 6, color: foreground))
          else
            Icon(st.icon, size: 12, color: st.deep),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(st.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _font(11, FontWeight.w700, foreground)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DETAIL PENDAFTARAN — halaman penuh dari riwayat dan notifikasi
// ══════════════════════════════════════════════════════════

class BookingTicketScreen extends StatefulWidget {
  const BookingTicketScreen({
    super.key,
    required this.bookingGuid,
    this.repository,
    this.preloaded,
  });
  final String bookingGuid;
  final BusinessRepository? repository;

  /// A booking the caller already read from the server (the App Link screen), so it is not read twice.
  final Booking? preloaded;
  @override
  State<BookingTicketScreen> createState() => _BookingTicketScreenState();
}

class _BookingTicketScreenState extends State<BookingTicketScreen> {
  late final BusinessRepository _repository;
  late final int _generation;
  Future<Booking>? _booking;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BusinessRepository();
    final session = _repository.api.session;
    _generation = session.sessionGeneration;
    if (session.authenticated.value &&
        session.deviceSessionReady &&
        session.role == 0) {
      final preloaded = widget.preloaded;
      _booking = preloaded != null && preloaded.guid == widget.bookingGuid
          ? Future.value(preloaded)
          : _repository.booking(widget.bookingGuid);
    }
    session.sessionChanges.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository.api.session.sessionChanges.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _repository.api.session;
    final valid = session.isCurrentGeneration(_generation) &&
        session.authenticated.value &&
        session.deviceSessionReady &&
        session.role == 0;
    Widget shell(Widget body) => Scaffold(
        backgroundColor: _background,
        appBar: AppBar(title: const Text('Detail Pendaftaran')),
        body: body);
    return !valid
        ? shell(const Center(
            child: Text('Sesi berubah. Silakan buka kembali tiket.')))
        : FutureBuilder<Booking>(
            future: _booking,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return shell(const Center(child: CircularProgressIndicator()));
              }
              final booking = snapshot.data;
              if (snapshot.hasError ||
                  booking == null ||
                  booking.guid != widget.bookingGuid) {
                return shell(Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Pendaftaran belum dapat dimuat.'),
                  TextButton(
                      onPressed: () => setState(() {
                            _booking = _repository.booking(widget.bookingGuid);
                          }),
                      child: const Text('Coba lagi')),
                ])));
              }
              return _TicketCard(
                  pendaftar: _fromBooking(booking),
                  booking: booking,
                  isLaravel: true,
                  initiallyExpanded: true,
                  detailPage: true,
                  repository: _repository);
            });
  }
}
