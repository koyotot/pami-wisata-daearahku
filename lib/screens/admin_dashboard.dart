// ============================================================
// lib/screens/admin_dashboard.dart
// REDESIGN: biru terang + Plus Jakarta Sans — selaras home_screen
// - Hero gradasi + kartu statistik yang menumpuk di atasnya
// - Menu kelola wisata dalam grid kartu putih
// - Pendaftar terbaru
// - DRAWER navigasi (☰) + Kelola Admin khusus superadmin
// Package: google_fonts
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import 'session_destination.dart';
import 'tambah_wisata_screen.dart';
import 'daftar_wisata_screen.dart';
import 'daftar_pendaftar_screen.dart';
import 'kelola_admin_screen.dart';

// ── Palet & font (sama dengan home_screen.dart) ──────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const background = Color(0xFFF5F8FD);
  static const tint = Color(0xFFE6F0FC);
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);
  static const teal = Color(0xFF26A69A);
  static const purple = Color(0xFF7E57C2);
  static const amber = Color(0xFFF59E0B);
}

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

// Data satu menu (dipakai grid dan drawer)
class _MenuAdmin {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _MenuAdmin({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _memuat = false;

  bool get _isSuperAdmin => AuthSession.instance.role == 2;
  bool get _canAccess => AuthSession.instance.authenticated.value &&
      AuthSession.instance.deviceSessionReady &&
      (AuthSession.instance.role == 1 || AuthSession.instance.role == 2);
  String get _namaAdmin => currentUser?.namaLengkap ?? 'Administrator';
  final _repository = BusinessRepository();
  int? _destinationCount;
  int? _bookingCount;
  List<Booking>? _recent;
  String? _loadError;
  late final int _sessionGeneration;

  void _sessionChanged() {
    if (!mounted) return;
    if (AuthSession.instance.sessionGeneration != _sessionGeneration) {
      _recent = null;
      _destinationCount = null;
      _bookingCount = null;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _sessionGeneration = AuthSession.instance.sessionGeneration;
    AuthSession.instance.sessionChanges.addListener(_sessionChanged);
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (_canAccess) {
      _muatData();
    }
  }

  Future<void> _muatData() async {
    if (_memuat) return;
    setState(() {
      _memuat = true;
      _loadError = null;
      _recent = null;
      _destinationCount = null;
      _bookingCount = null;
    });
    try {
      final destinations = await _repository.destinations();
      final bookings = await _repository.adminBookings();
      if (!mounted ||
          _sessionGeneration != AuthSession.instance.sessionGeneration) return;
      setState(() {
        _destinationCount = destinations.meta?['total'] as int?;
        _bookingCount = bookings.meta?['total'] as int?;
        _recent = bookings.items.take(3).toList();
      });
    } catch (e) {
      if (mounted &&
          _sessionGeneration == AuthSession.instance.sessionGeneration) {
        setState(() => _loadError = e.toString());
      }
    } finally {
      if (mounted &&
          _sessionGeneration == AuthSession.instance.sessionGeneration) {
        setState(() => _memuat = false);
      }
    }
  }

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_sessionChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _bukaMenu() => _scaffoldKey.currentState?.openDrawer();

  void _buka(Widget page, {bool refresh = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (refresh && mounted) setState(() {});
    });
  }

  Future<void> _logout() async {
    try {
      await AuthSession.instance.logout();
    } catch (_) {
      // Local credentials are cleared even when the network logout fails.
    }
  }

  Future<void> _konfirmasiLogout() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Keluar dari Admin?',
            style: _font(17, FontWeight.w800, _C.navy)),
        content: Text(
          'Kamu perlu login kembali untuk mengelola konten wisata.',
          style: _font(13, FontWeight.w500, _C.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: _font(13.5, FontWeight.w600, _C.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Keluar', style: _font(13.5, FontWeight.w800, _C.danger)),
          ),
        ],
      ),
    );
    if (yakin == true && mounted) _logout();
  }

  // ── Daftar menu (dipakai grid & drawer) ────────────────────
  List<_MenuAdmin> get _menuWisata => [
        _MenuAdmin(
          icon: Icons.add_location_alt_rounded,
          label: 'Tambah Wisata',
          sub: 'Destinasi baru',
          color: _C.blue,
          onTap: () => _buka(const TambahWisataScreen(), refresh: true),
        ),
        _MenuAdmin(
          icon: Icons.format_list_bulleted_rounded,
          label: 'Tampilkan Wisata',
          sub: 'Lihat semua data',
          color: _C.teal,
          onTap: () => _buka(const DaftarWisataScreen(mode: 'view')),
        ),
        _MenuAdmin(
          icon: Icons.edit_rounded,
          label: 'Ubah Wisata',
          sub: 'Edit informasi',
          color: _C.purple,
          onTap: () =>
              _buka(const DaftarWisataScreen(mode: 'edit'), refresh: true),
        ),
        _MenuAdmin(
          icon: Icons.delete_sweep_rounded,
          label: 'Hapus Wisata',
          sub: 'Hapus permanen',
          color: _C.danger,
          onTap: () =>
              _buka(const DaftarWisataScreen(mode: 'hapus'), refresh: true),
        ),
      ];

  _MenuAdmin get _menuPendaftar => _MenuAdmin(
        icon: Icons.supervised_user_circle_rounded,
        label: 'Data Pendaftar',
        sub: 'Pantau booking kunjungan pengunjung',
        color: _C.orange,
        onTap: () => _buka(const DaftarPendaftarScreen()),
      );

  _MenuAdmin get _menuKelolaAdmin => _MenuAdmin(
        icon: Icons.manage_accounts_rounded,
        label: 'Kelola Admin',
        sub: 'Tambah & hapus akun administrator',
        color: _C.blueDeep,
        onTap: () => _buka(const KelolaAdminScreen()),
      );

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_canAccess || _sessionGeneration != AuthSession.instance.sessionGeneration) {
      return sessionDestination();
    }
    final inset = MediaQuery.of(context).padding.top;
    final heroH = inset + 236;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _C.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _C.background,
        drawer: _buildDrawer(),
        body: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: RefreshIndicator(
              onRefresh: _muatData,
              color: _C.blue,
              edgeOffset: heroH,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: heroH,
                            child: _buildHero(inset),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(20, heroH - 46, 20, 0),
                            child: _buildStats(),
                          ),
                        ],
                      ),
                    ),
                    _buildBody(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HERO
  // ══════════════════════════════════════════════════════════
  Widget _buildHero(double inset) {
    final inisial =
        _namaAdmin.trim().isEmpty ? 'A' : _namaAdmin.trim()[0].toUpperCase();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A93F0), _C.blue, _C.blueDeep],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _ScenePainter())),
          Padding(
            padding: EdgeInsets.fromLTRB(20, inset + 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bar atas: menu • judul • refresh
                Row(
                  children: [
                    _heroButton(
                      icon: Icons.menu_rounded,
                      onTap: _bukaMenu,
                    ),
                    Expanded(
                      child: Text(
                        'Dashboard Admin',
                        textAlign: TextAlign.center,
                        style: _font(16, FontWeight.w800, Colors.white,
                            letterSpacing: -0.3),
                      ),
                    ),
                    _heroButton(
                      icon: Icons.refresh_rounded,
                      loading: _memuat,
                      onTap: _muatData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sapaan
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 2),
                      ),
                      child: Text(inisial,
                          style: _font(22, FontWeight.w800, Colors.white)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang,',
                            style: _font(
                              12.5,
                              FontWeight.w500,
                              Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _namaAdmin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _font(21, FontWeight.w800, Colors.white,
                                letterSpacing: -0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chip peran
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PulseDot(color: Color(0xFFFFE9B0)),
                      const SizedBox(width: 7),
                      Icon(
                        _isSuperAdmin
                            ? Icons.verified_user_rounded
                            : Icons.shield_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isSuperAdmin ? 'Super Administrator' : 'Administrator',
                        style: _font(11.5, FontWeight.w700, Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroButton({
    required IconData icon,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  // ── Kartu statistik (menumpuk di hero) ─────────────────────
  Widget _buildStats() {
    return Row(
      children: [
        _statCard(Icons.map_rounded, _destinationCount?.toString() ?? '-',
            'Destinasi', _C.blue),
        const SizedBox(width: 10),
        _statCard(Icons.people_rounded, _bookingCount?.toString() ?? '-',
            'Pendaftar', _C.orange),
        const SizedBox(width: 10),
        _statCard(Icons.star_rounded, '-', 'Rata-rata', _C.teal),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _C.blue.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 8),
            Text(value,
                style:
                    _font(20, FontWeight.w800, _C.navy, letterSpacing: -0.5)),
            const SizedBox(height: 1),
            Text(label, style: _font(10.5, FontWeight.w600, _C.textMuted)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BODY
  // ══════════════════════════════════════════════════════════
  Widget _buildBody() {
    final menu = _menuWisata;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Kelola Wisata'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _gridCard(menu[0])),
              const SizedBox(width: 12),
              Expanded(child: _gridCard(menu[1])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _gridCard(menu[2])),
              const SizedBox(width: 12),
              Expanded(child: _gridCard(menu[3])),
            ],
          ),
          const SizedBox(height: 26),
          _sectionLabel('Lainnya'),
          const SizedBox(height: 14),
          _wideCard(_menuPendaftar),
          if (_isSuperAdmin) ...[
            const SizedBox(height: 12),
            _wideCard(_menuKelolaAdmin),
          ],
          const SizedBox(height: 26),
          _sectionLabel('Pendaftar Terbaru'),
          const SizedBox(height: 14),
          _buildPendaftarTerbaru(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _C.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: _font(15.5, FontWeight.w800, _C.navy, letterSpacing: -0.3)),
      ],
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );

  Widget _gridCard(_MenuAdmin m) {
    return Container(
      height: 142,
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: m.onTap,
          splashColor: m.color.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                top: -26,
                right: -26,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: m.color.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(m.icon, color: m.color, size: 23),
                    ),
                    const Spacer(),
                    Text(m.label,
                        style: _font(13.5, FontWeight.w800, _C.navy,
                            letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(m.sub,
                        style: _font(11, FontWeight.w500, _C.textMuted)),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Icon(Icons.arrow_outward_rounded,
                    color: m.color.withValues(alpha: 0.7), size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideCard(_MenuAdmin m) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: m.onTap,
          splashColor: m.color.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(m.icon, color: m.color, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: _font(14.5, FontWeight.w800, _C.navy,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(m.sub,
                          style: _font(11.5, FontWeight.w500, _C.textMuted)),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      color: m.color, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Pendaftar terbaru (3 terakhir) ─────────────────────────
  Widget _buildPendaftarTerbaru() {
    final terbaru = _recent ?? <Booking>[];
    if (_recent == null) {
      return Center(
          child: Text(_memuat
              ? 'Memuat data...'
              : (_loadError ?? 'Data belum tersedia.')));
    }

    if (terbaru.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: _C.tint),
              child: const Icon(Icons.inbox_rounded, color: _C.blue, size: 26),
            ),
            const SizedBox(height: 12),
            Text('Belum ada pendaftar',
                style: _font(14, FontWeight.w800, _C.navy)),
            const SizedBox(height: 3),
            Text('Pendaftaran kunjungan akan muncul di sini.',
                textAlign: TextAlign.center,
                style: _font(11.5, FontWeight.w500, _C.textMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < terbaru.length; i++) ...[
            _pendaftarTile(terbaru[i]),
            if (i != terbaru.length - 1)
              const Divider(height: 1, indent: 70, color: _C.border),
          ],
          InkWell(
            onTap: () => _buka(const DaftarPendaftarScreen()),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(22)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: const BoxDecoration(
                color: _C.tint,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lihat semua pendaftar',
                      style: _font(12.5, FontWeight.w800, _C.blueDeep)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      color: _C.blueDeep, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendaftarTile(Booking p) {
    final nama = p.visitorName.trim();
    final inisial = nama.isEmpty ? '?' : nama[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF42A5F5), _C.blue],
              ),
            ),
            child:
                Text(inisial, style: _font(16, FontWeight.w800, Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama.isEmpty ? '-' : nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(13.5, FontWeight.w800, _C.navy)),
                const SizedBox(height: 2),
                Text('${p.destinationName}  ·  ${p.json['visit_date'] ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(11.5, FontWeight.w500, _C.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _C.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${p.json['quantity'] ?? '-'} org',
                style: _font(11, FontWeight.w800, const Color(0xFFE08600))),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DRAWER
  // ══════════════════════════════════════════════════════════
  Widget _buildDrawer() {
    final wisata = _menuWisata;

    return Drawer(
      width: 308,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              children: [
                _drawerLabel('Menu'),
                _drawerItem(
                  icon: Icons.dashboard_rounded,
                  color: _C.blue,
                  label: 'Dashboard',
                  selected: true,
                  onTap: () => _scaffoldKey.currentState?.closeDrawer(),
                ),
                const SizedBox(height: 10),
                _drawerLabel('Kelola Wisata'),
                for (final m in wisata)
                  _drawerItem(
                    icon: m.icon,
                    color: m.color,
                    label: m.label,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      m.onTap();
                    },
                  ),
                const SizedBox(height: 10),
                _drawerLabel('Lainnya'),
                _drawerItem(
                  icon: _menuPendaftar.icon,
                  color: _menuPendaftar.color,
                  label: _menuPendaftar.label,
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    _menuPendaftar.onTap();
                  },
                ),
                if (_isSuperAdmin)
                  _drawerItem(
                    icon: _menuKelolaAdmin.icon,
                    color: _menuKelolaAdmin.color,
                    label: _menuKelolaAdmin.label,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _menuKelolaAdmin.onTap();
                    },
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _drawerItem(
                    icon: Icons.refresh_rounded,
                    color: _C.textMuted,
                    label: 'Muat Ulang Data',
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _muatData();
                    },
                  ),
                  _drawerItem(
                    icon: Icons.logout_rounded,
                    color: _C.danger,
                    label: 'Keluar',
                    danger: true,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _konfirmasiLogout();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final nama = _namaAdmin.trim();
    final inisial = nama.isEmpty ? 'A' : nama[0].toUpperCase();
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(22, topInset + 26, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A93F0), _C.blue, _C.blueDeep],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.only(topRight: Radius.circular(30)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE9B0), _C.orange],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC46B).withValues(alpha: 0.6),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: Text(inisial,
                    style: _font(26, FontWeight.w800, Colors.white)),
              ),
              const SizedBox(height: 14),
              Text(
                nama.isEmpty ? 'Administrator' : nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(18, FontWeight.w800, Colors.white,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSuperAdmin
                          ? Icons.verified_user_rounded
                          : Icons.shield_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSuperAdmin ? 'Super Administrator' : 'Administrator',
                      style: _font(
                        11.5,
                        FontWeight.w600,
                        Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Text(
        text.toUpperCase(),
        style: _font(
          11,
          FontWeight.w800,
          _C.textMuted.withValues(alpha: 0.85),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? _C.blue.withValues(alpha: 0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: _font(
                      14,
                      selected ? FontWeight.w800 : FontWeight.w600,
                      selected ? _C.blueDeep : (danger ? _C.danger : _C.navy),
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: _C.blue, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pulse dot animasi ──────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 1.0, end: 0.35)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: widget.color)),
      );
}

// ── Matahari & pegunungan (sama dengan home_screen) ──────────
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sun = Offset(w * 0.84, h * 0.22);
    final r = w * 0.07;
    canvas.drawCircle(
      sun,
      r * 2.8,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x80FFC46B), Color(0x00FFC46B)],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 2.8)),
    );
    canvas.drawCircle(
      sun,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE9B0), Color(0xFFFF9800)],
        ).createShader(Rect.fromCircle(center: sun, radius: r)),
    );

    final back = Path()
      ..moveTo(0, h * 0.78)
      ..lineTo(w * 0.20, h * 0.64)
      ..lineTo(w * 0.38, h * 0.74)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.80, h * 0.76)
      ..lineTo(w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0x4D1558B0));

    final front = Path()
      ..moveTo(0, h * 0.88)
      ..lineTo(w * 0.24, h * 0.76)
      ..lineTo(w * 0.48, h * 0.86)
      ..lineTo(w * 0.72, h * 0.75)
      ..lineTo(w, h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x801558B0), Color(0xB3102D59)],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
