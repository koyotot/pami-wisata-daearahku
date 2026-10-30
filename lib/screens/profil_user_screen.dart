import '../services/auth_session.dart';
// ============================================================
// lib/screens/profil_user_screen.dart
// Tab "Profil" — bagian dari navigasi drawer (MainNavigationScreen)
// Tema: biru terang — sama dengan home, login, beranda, dan drawer.
// Header punya tombol KEMBALI (ke Beranda) dan tombol MENU (☰)
// yang membuka drawer.
// Package: google_fonts, firebase_auth
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import '../data/favorite_state.dart';
import '../widgets/reviews_sheet.dart';
import 'home_screen.dart';
import 'user_login_screen.dart';

// ── Palet & font (sama dengan home_screen.dart) ──────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFE08600);

  // Alias agar kode sheet/dialog lama tetap jalan dengan warna baru
  static const teal = blue;
  static const tealDark = blueDeep;
  static const gold = orange;
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

// Setelah logout / hapus akun: reset stack menjadi [Home, Login] supaya
// tombol kembali dari Login selalu menuju Home (bukan layar hitam).
void _keLogin(BuildContext context) {
  final nav = Navigator.of(context);
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );
  nav.push(MaterialPageRoute(builder: (_) => const UserLoginScreen()));
}

class ProfilUserScreen extends StatefulWidget {
  /// Dipanggil saat tombol menu (☰) ditekan — membuka drawer.
  final VoidCallback? onBukaMenu;

  /// Dipanggil saat tombol kembali ditekan. Di dalam MainNavigationScreen
  /// diisi perpindahan ke tab Beranda. Jika null, memakai Navigator.maybePop.
  final VoidCallback? onKembali;

  /// True saat tab ini tampil; jumlah pendaftaran dimuat ulang ketika tab dibuka kembali.
  final bool active;

  const ProfilUserScreen(
      {super.key, this.onBukaMenu, this.onKembali, this.active = true});

  @override
  State<ProfilUserScreen> createState() => _ProfilUserScreenState();
}

class _ProfilUserScreenState extends State<ProfilUserScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _loadingJumlah = true;
  int? _jumlahPendaftaran;
  int? _jumlahUlasan;
  int? _jumlahDikunjungi;
  String? _jumlahError;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    AuthSession.instance.sessionChanges.addListener(_sessionChanged);
    BookingEvents.changed.addListener(_loadJumlahPendaftaran);
    _loadJumlahPendaftaran();
  }

  @override
  void didUpdateWidget(ProfilUserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _loadJumlahPendaftaran();
  }

  int _jumlahRequest = 0;

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _jumlahError = null;
      _jumlahPendaftaran = null;
      _jumlahUlasan = null;
      _jumlahDikunjungi = null;
      _loadingJumlah = true;
    });
    _loadJumlahPendaftaran();
  }

  Future<void> _loadJumlahPendaftaran() async {
    final session = AuthSession.instance;
    final generation = session.sessionGeneration;
    final request = ++_jumlahRequest;
    if (!session.authenticated.value || !session.deviceSessionReady) {
      if (mounted) setState(() => _loadingJumlah = false);
      return;
    }
    setState(() {
      _loadingJumlah = true;
      _jumlahError = null;
    });
    try {
      final counts = await BusinessRepository().profileStatistics();
      if (!mounted ||
          !session.isCurrentGeneration(generation) ||
          request != _jumlahRequest) return;
      setState(() {
        _jumlahPendaftaran = counts.bookings;
        _jumlahUlasan = counts.reviews;
        _jumlahDikunjungi = counts.visits;
        _loadingJumlah = false;
      });
    } catch (_) {
      if (!mounted ||
          !session.isCurrentGeneration(generation) ||
          request != _jumlahRequest) return;
      setState(() {
        _loadingJumlah = false;
        _jumlahError = 'Statistik profil belum dapat dimuat.';
      });
    }
  }

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_sessionChanged);
    BookingEvents.changed.removeListener(_loadJumlahPendaftaran);
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _konfirmasiLogout(BuildContext context) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar dari Akun?',
          style: TextStyle(color: _C.text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Kamu perlu login kembali untuk mengakses akun ini.',
          style: TextStyle(color: _C.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: _C.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Keluar',
                style:
                    TextStyle(color: _C.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    final generation = AuthSession.instance.sessionGeneration;
    try {
      await AuthSession.instance.logout();
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Sesi lokal dihapus. Pencabutan sesi server belum dapat dikonfirmasi.')));
    }
    if (AuthSession.instance.sessionGeneration != generation + 1 ||
        AuthSession.instance.authenticated.value) return;
    await fb_auth.FirebaseAuth.instance.signOut();
    if (AuthSession.instance.sessionGeneration != generation + 1) return;
    if (!context.mounted) return;
    _keLogin(context);
  }

  void _bukaEditProfil(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditProfilSheet(
        namaAwal: currentUser?.namaLengkap ?? '',
        teleponAwal: currentUser?.noTelepon ?? '',
        onSimpan: (nama, telepon) async {
          final session = AuthSession.instance;
          final generation = session.sessionGeneration;
          await session.updateProfile(nama, telepon);
          if (!mounted || !session.isCurrentGeneration(generation)) return;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Profil berhasil diperbarui!'),
            backgroundColor: _C.tealDark,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ));
        },
      ),
    );
  }

  void _bukaRiwayatUlasan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ReviewsSheet(),
    );
  }

  void _bukaNotifikasi(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _NotifikasiSheet(),
    );
  }

  void _bukaPilihBahasa(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PilihBahasaSheet(),
    );
  }

  void _bukaSemuaWisataTersimpan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SemuaWisataTersimpanSheet(),
    );
  }

  void _bukaGantiPassword(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fitur ini belum tersedia untuk akun API.')));
  }

  void _kembali() {
    if (widget.onKembali != null) {
      widget.onKembali!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final tahunBergabung = user != null ? user.createdAt.year.toString() : '-';

    return Theme(
      // Font Plus Jakarta Sans untuk seluruh halaman, dialog & bottom sheet
      data: Theme.of(context).copyWith(
        textTheme:
            GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: _C.bg,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDCEBFF), _C.bg, Colors.white],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderCard(user, tahunBergabung),
                              if (_jumlahError != null)
                                TextButton.icon(
                                  onPressed: _loadJumlahPendaftaran,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text('$_jumlahError Coba lagi'),
                                ),
                              const SizedBox(height: 26),

                              // Wisata Tersimpan
                              _sectionLabel('Wisata Tersimpan'),
                              const SizedBox(height: 12),
                              _buildWisataTersimpan(),
                              const SizedBox(height: 26),

                              // Akun section
                              _sectionLabel('Akun'),
                              const SizedBox(height: 12),
                              _buildMenuGroup([
                                _MenuItemData(
                                  icon: Icons.rate_review_rounded,
                                  iconColor: const Color(0xFF1E88E5),
                                  title: 'Riwayat Ulasan',
                                  subtitle: 'Ulasan yang pernah kamu tulis',
                                  onTap: () => _bukaRiwayatUlasan(context),
                                ),
                                _MenuItemData(
                                  icon: Icons.notifications_rounded,
                                  iconColor: const Color(0xFFFF8C42),
                                  title: 'Notifikasi',
                                  subtitle: 'Atur preferensi notifikasi',
                                  badge: 'Baru',
                                  onTap: () => _bukaNotifikasi(context),
                                ),
                                _MenuItemData(
                                  icon: Icons.language_rounded,
                                  iconColor: const Color(0xFF7E57C2),
                                  title: 'Bahasa',
                                  subtitle: 'Indonesia',
                                  onTap: () => _bukaPilihBahasa(context),
                                ),
                                _MenuItemData(
                                  icon: Icons.lock_reset_rounded,
                                  iconColor: const Color(0xFF26A69A),
                                  title: 'Ubah Password',
                                  subtitle: 'Perbarui kata sandi akun kamu',
                                  onTap: () => _bukaGantiPassword(context),
                                ),
                                _MenuItemData(
                                  icon: Icons.info_outline_rounded,
                                  iconColor: _C.blue,
                                  title: 'Tentang Aplikasi',
                                  subtitle: 'Wisata Daerahku · versi 1.0.0',
                                  onTap: () => _tampilkanTentang(context),
                                ),
                                _MenuItemData(
                                  icon: Icons.delete_outline_rounded,
                                  iconColor: _C.danger,
                                  title: 'Hapus Akun',
                                  subtitle: 'Hapus akun secara permanen',
                                  onTap: () => _konfirmasiHapusAkun(context),
                                  isDanger: true,
                                ),
                              ]),
                              const SizedBox(height: 24),
                              _buildLogoutButton(context),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TOP BAR — tombol kembali, judul, tombol menu (drawer)
  // ══════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          _topButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconSize: 18,
            tooltip: 'Kembali',
            onTap: _kembali,
          ),
          Expanded(
            child: Text(
              'Profil Saya',
              textAlign: TextAlign.center,
              style: _font(18, FontWeight.w800, _C.navy, letterSpacing: -0.4),
            ),
          ),
          // Tombol pembuka drawer (spacer kosong bila tidak ada callback
          // supaya judul tetap berada di tengah)
          if (widget.onBukaMenu != null)
            _topButton(
              icon: Icons.menu_rounded,
              iconSize: 22,
              tooltip: 'Menu',
              onTap: widget.onBukaMenu!,
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _topButton({
    required IconData icon,
    required double iconSize,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: Icon(icon, color: _C.navy, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEADER — Avatar, nama, email, statistik
  // ══════════════════════════════════════════════════════════
  Widget _buildHeaderCard(User? user, String tahunBergabung) {
    final nama = user?.namaLengkap.trim() ?? '';
    final inisial = nama.isEmpty ? '' : nama[0].toUpperCase();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A93F0), _C.blue, _C.blueDeep],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lingkaran dekoratif
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          // Matahari kecil
          Positioned(
            top: 20,
            right: 22,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
            child: Column(
              children: [
                // Avatar (inisial nama)
                Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                  ),
                  child: inisial.isEmpty
                      ? const Icon(Icons.person_rounded,
                          color: Colors.white, size: 44)
                      : Text(
                          inisial,
                          style: _font(38, FontWeight.w800, Colors.white),
                        ),
                ),

                const SizedBox(height: 16),

                // Nama
                Text(
                  nama.isEmpty ? 'Pengunjung' : nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _font(
                    22,
                    FontWeight.w800,
                    Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                // Email chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_rounded,
                          color: Colors.white.withValues(alpha: 0.9), size: 13),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          (user?.email ?? '').isEmpty ? '-' : user!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _font(
                            12,
                            FontWeight.w600,
                            Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (user != null && user.noTelepon.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_rounded,
                          color: Colors.white.withValues(alpha: 0.8), size: 12),
                      const SizedBox(width: 5),
                      Text(
                        user.noTelepon,
                        style: _font(
                          12,
                          FontWeight.w500,
                          Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Tombol Edit Profil
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _bukaEditProfil(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded,
                              color: _C.blue, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Edit Profil',
                            style: _font(12.5, FontWeight.w800, _C.blueDeep),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 4 kartu statistik
                Row(
                  children: [
                    _statCard(
                      icon: Icons.receipt_long_rounded,
                      value: _loadingJumlah || _jumlahPendaftaran == null
                          ? '–'
                          : '$_jumlahPendaftaran',
                      label: 'Pendaftaran',
                      iconColor: _C.orange,
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      icon: Icons.location_on_rounded,
                      value: _loadingJumlah || _jumlahDikunjungi == null
                          ? '–'
                          : '$_jumlahDikunjungi',
                      label: 'Dikunjungi',
                      iconColor: _C.blue,
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      icon: Icons.star_rounded,
                      value: _loadingJumlah || _jumlahUlasan == null
                          ? '–'
                          : '$_jumlahUlasan',
                      label: 'Ulasan',
                      iconColor: const Color(0xFF26A69A),
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      icon: Icons.calendar_today_rounded,
                      value: tahunBergabung,
                      label: 'Bergabung',
                      iconColor: const Color(0xFFFF8C42),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: _font(15.5, FontWeight.w800, _C.navy, letterSpacing: -0.4),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: _font(9.5, FontWeight.w600, _C.textMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SECTION LABEL
  // ══════════════════════════════════════════════════════════
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
        Text(
          text,
          style: _font(15.5, FontWeight.w800, _C.navy, letterSpacing: -0.3),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  WISATA TERSIMPAN
  // ══════════════════════════════════════════════════════════
  Widget _buildWisataTersimpan() {
    final state = FavoriteState.instance;
    return AnimatedBuilder(
      animation: state.favorites,
      builder: (context, _) {
        final docs = state.favorites.data ?? [];
        final isLoading = state.favorites.loading;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.teal.withValues(alpha: 0.12)),
          ),
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              : state.favorites.error != null
                  ? TextButton(
                      onPressed: state.load,
                      child: Text(state.favorites.error.toString()))
                  : !state.session.authenticated.value
                      ? Center(
                          child: Text('Login untuk melihat wisata tersimpan',
                              style:
                                  TextStyle(color: _C.textMuted, fontSize: 13)))
                      : docs.isEmpty
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text('Belum ada wisata tersimpan',
                                    style: TextStyle(
                                        color: _C.textMuted, fontSize: 13)),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...docs.take(5).map((doc) {
                                  final nama = doc.destination.name;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _C.teal.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              _C.teal.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _C.teal,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(nama,
                                            style: TextStyle(
                                                color: _C.teal,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  );
                                }),
                                // Lihat semua chip
                                GestureDetector(
                                  onTap: () =>
                                      _bukaSemuaWisataTersimpan(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _C.gold.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              _C.gold.withValues(alpha: 0.30)),
                                    ),
                                    child: Text('+ Lihat semua',
                                        style: TextStyle(
                                            color: _C.warning,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  GROUPED MENU CARD
  // ══════════════════════════════════════════════════════════
  Widget _buildMenuGroup(List<_MenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.teal.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: item.isDanger
                                ? _C.danger.withValues(alpha: 0.12)
                                : item.iconColor.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child:
                              Icon(item.icon, color: item.iconColor, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: item.isDanger ? _C.danger : _C.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                    color: _C.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        if (item.badge != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _C.gold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: _C.textDim, size: 13),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 52,
                  color: _C.border,
                ),
            ],
          );
        }),
      ),
    );
  }

  void _konfirmasiHapusAkun(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fitur ini belum tersedia untuk akun API.')));
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _konfirmasiLogout(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _C.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: _C.danger, size: 18),
              const SizedBox(width: 8),
              Text(
                'Keluar',
                style: TextStyle(
                  color: _C.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _tampilkanTentang(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.travel_explore_rounded, color: _C.teal),
            const SizedBox(width: 10),
            Text('Wisata Daerahku',
                style: TextStyle(color: _C.text, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Versi 1.0.0\nJelajahi & daftarkan kunjunganmu ke destinasi wisata terbaik di daerahmu.',
          style: TextStyle(color: _C.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: _C.teal)),
          ),
        ],
      ),
    );
  }
}

// ── Data class untuk menu item ───────────────────────────────
class _MenuItemData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final bool isDanger;

  const _MenuItemData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.isDanger = false,
  });
}

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — Ubah Password (Firebase Auth)
// ════════════════════════════════════════════════════════════
class _EditProfilSheet extends StatefulWidget {
  final String namaAwal;
  final String teleponAwal;
  final Future<void> Function(String nama, String telepon) onSimpan;

  const _EditProfilSheet({
    required this.namaAwal,
    required this.teleponAwal,
    required this.onSimpan,
  });

  @override
  State<_EditProfilSheet> createState() => _EditProfilSheetState();
}

class _EditProfilSheetState extends State<_EditProfilSheet> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _teleponCtrl;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.namaAwal);
    _teleponCtrl = TextEditingController(text: widget.teleponAwal);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _teleponCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama tidak boleh kosong.');
      return;
    }
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await widget.onSimpan(nama, _teleponCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Gagal menyimpan: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit Profil',
              style: TextStyle(
                  color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Text('Nama Lengkap',
              style: TextStyle(
                  color: _C.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _namaCtrl,
            style: TextStyle(color: _C.text),
            decoration: InputDecoration(
              hintText: 'Nama kamu',
              hintStyle: TextStyle(color: _C.textDim),
              filled: true,
              fillColor: _C.bg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.border, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.teal, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Text('No. Telepon',
              style: TextStyle(
                  color: _C.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _teleponCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: _C.text),
            decoration: InputDecoration(
              hintText: '+62...',
              hintStyle: TextStyle(color: _C.textDim),
              filled: true,
              fillColor: _C.bg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.border, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.teal, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isLoading ? null : _submit,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [_C.tealDark, _C.tealDark]
                      : [_C.teal, _C.tealDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Simpan Perubahan',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — Riwayat Ulasan
// ════════════════════════════════════════════════════════════
class _NotifikasiSheet extends StatefulWidget {
  const _NotifikasiSheet();

  @override
  State<_NotifikasiSheet> createState() => _NotifikasiSheetState();
}

class _NotifikasiSheetState extends State<_NotifikasiSheet> {
  bool _infoWisata = true;
  bool _promoEvent = true;
  bool _statusPendaftaran = true;
  bool _pengumumanApp = false;

  Widget _switchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: _C.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _C.teal,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Notifikasi',
              style: TextStyle(
                  color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Atur notifikasi yang ingin kamu terima',
              style: TextStyle(color: _C.textMuted, fontSize: 12.5)),
          const SizedBox(height: 16),
          _switchTile('Info Wisata Baru', 'Pemberitahuan destinasi terbaru',
              _infoWisata, (v) => setState(() => _infoWisata = v)),
          Divider(color: _C.border.withValues(alpha: 0.4)),
          _switchTile('Promo & Event', 'Diskon dan acara spesial', _promoEvent,
              (v) => setState(() => _promoEvent = v)),
          Divider(color: _C.border.withValues(alpha: 0.4)),
          _switchTile(
              'Status Pendaftaran',
              'Update status kunjunganmu',
              _statusPendaftaran,
              (v) => setState(() => _statusPendaftaran = v)),
          Divider(color: _C.border.withValues(alpha: 0.4)),
          _switchTile('Pengumuman Aplikasi', 'Update dan info versi baru',
              _pengumumanApp, (v) => setState(() => _pengumumanApp = v)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_C.teal, _C.tealDark]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Simpan Preferensi',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — Pilih Bahasa
// ════════════════════════════════════════════════════════════
class _PilihBahasaSheet extends StatefulWidget {
  const _PilihBahasaSheet();

  @override
  State<_PilihBahasaSheet> createState() => _PilihBahasaSheetState();
}

class _PilihBahasaSheetState extends State<_PilihBahasaSheet> {
  String _selected = 'Indonesia';

  final _bahasa = [
    ('Indonesia', '🇮🇩'),
    ('English', '🇬🇧'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Pilih Bahasa',
              style: TextStyle(
                  color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ..._bahasa.map((b) {
            final isSelected = _selected == b.$1;
            return GestureDetector(
              onTap: () => setState(() => _selected = b.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? _C.teal.withValues(alpha: 0.12) : _C.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isSelected ? _C.teal.withValues(alpha: 0.5) : _C.border,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(b.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(b.$1,
                          style: TextStyle(
                              color: _C.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: _C.teal, size: 18),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_C.teal, _C.tealDark]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Terapkan',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — Semua Wisata Tersimpan
// ════════════════════════════════════════════════════════════
class _SemuaWisataTersimpanSheet extends StatelessWidget {
  const _SemuaWisataTersimpanSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Wisata Tersimpan',
              style: TextStyle(
                  color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: FavoriteState.instance.favorites,
              builder: (context, _) {
                final state = FavoriteState.instance;
                if (state.favorites.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.favorites.error != null) {
                  return TextButton(
                      onPressed: state.load,
                      child: Text(state.favorites.error.toString()));
                }
                final docs = state.favorites.data ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text('Belum ada wisata tersimpan.',
                        style: TextStyle(color: _C.textMuted)),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: _C.border.withValues(alpha: 0.4)),
                  itemBuilder: (context, i) {
                    final destination = docs[i].destination;
                    final nama = destination.name;
                    final lokasi =
                        destination.json['location'] as String? ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _C.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.bookmark_rounded,
                            color: _C.teal, size: 18),
                      ),
                      title: Text(nama,
                          style: TextStyle(
                              color: _C.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5)),
                      subtitle: lokasi.isNotEmpty
                          ? Text(lokasi,
                              style:
                                  TextStyle(color: _C.textMuted, fontSize: 12))
                          : null,
                      trailing: Icon(Icons.arrow_forward_ios_rounded,
                          color: _C.textDim, size: 13),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.danger.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _C.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: _C.danger, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
