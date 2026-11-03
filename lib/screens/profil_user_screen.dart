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
import 'auth_presentation.dart';
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
  final VoidCallback? onNotifications;

  /// True saat tab ini tampil; jumlah pendaftaran dimuat ulang ketika tab dibuka kembali.
  final bool active;

  const ProfilUserScreen(
      {super.key,
      this.onBukaMenu,
      this.onKembali,
      this.onNotifications,
      this.active = true});

  @override
  State<ProfilUserScreen> createState() => _ProfilUserScreenState();
}

class _ProfilUserScreenState extends State<ProfilUserScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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

  int _jumlahRequest = 0;

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _jumlahError = null;
      _jumlahPendaftaran = null;
      _jumlahUlasan = null;
      _jumlahDikunjungi = null;
    });
    _loadJumlahPendaftaran();
  }

  Future<void> _loadJumlahPendaftaran() async {
    final session = AuthSession.instance;
    final generation = session.sessionGeneration;
    final request = ++_jumlahRequest;
    if (!session.authenticated.value || !session.deviceSessionReady) {
      return;
    }
    setState(() {
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
      });
    } catch (_) {
      if (!mounted ||
          !session.isCurrentGeneration(generation) ||
          request != _jumlahRequest) return;
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final tahunBergabung = user?.emailVerifiedAt?.year.toString() ?? '\u2014';

    return Theme(
      // Font Plus Jakarta Sans untuk seluruh halaman, dialog & bottom sheet
      data: Theme.of(context).copyWith(
        textTheme:
            GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: _C.bg,
          body: FadeTransition(
            opacity: MediaQuery.disableAnimationsOf(context)
                ? const AlwaysStoppedAnimation(1)
                : _fadeAnim,
            child: SlideTransition(
              position: MediaQuery.disableAnimationsOf(context)
                  ? const AlwaysStoppedAnimation(Offset.zero)
                  : _slideAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          height: 270,
                          width: double.infinity,
                          child: TimeBasedScenicBackground(
                            active: widget.active,
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                              top: MediaQuery.paddingOf(context).top + 8),
                          child: _buildTopBar(scenic: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 215, 20, 0),
                          child: _buildHeaderCard(user, tahunBergabung),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              subtitle: widget.onNotifications != null
                                  ? 'Lihat aktivitas pendaftaran'
                                  : 'Preferensi belum tersedia',
                              onTap: widget.onNotifications ??
                                  () => _bukaNotifikasi(context),
                            ),
                            _MenuItemData(
                              icon: Icons.language_rounded,
                              iconColor: const Color(0xFF7E57C2),
                              title: 'Bahasa',
                              subtitle:
                                  'Indonesia ? bahasa lain belum tersedia',
                              onTap: () => _bukaPilihBahasa(context),
                            ),
                            _MenuItemData(
                              icon: Icons.lock_reset_rounded,
                              iconColor: const Color(0xFF26A69A),
                              title: 'Ubah Password',
                              subtitle: 'Belum tersedia untuk akun API',
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
                              subtitle: 'Belum tersedia untuk akun API',
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
  //  TOP BAR — tombol kembali, judul, tombol menu (drawer)
  // ══════════════════════════════════════════════════════════
  Widget _buildTopBar({bool scenic = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Text(
              'Profil Saya',
              textAlign: TextAlign.center,
              style: _font(18, FontWeight.w800, scenic ? Colors.white : _C.navy,
                  letterSpacing: -0.4),
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
    final initials = nama
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final stats = [
      (
        'Pendaftaran',
        _jumlahPendaftaran == null ? '\u2014' : '$_jumlahPendaftaran'
      ),
      (
        'Dikunjungi',
        _jumlahDikunjungi == null ? '\u2014' : '$_jumlahDikunjungi'
      ),
      ('Ulasan', _jumlahUlasan == null ? '\u2014' : '$_jumlahUlasan'),
    ];
    return Container(
      key: const ValueKey('profileIdentityCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x140F2D59), blurRadius: 16, offset: Offset(0, 6))
          ]),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
              radius: 24,
              backgroundColor: _C.blue,
              child: initials.isEmpty
                  ? const Icon(Icons.person_outline, color: Colors.white)
                  : Text(initials,
                      style: _font(16, FontWeight.w800, Colors.white))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(nama.isEmpty ? 'Pengunjung' : nama,
                    style: _font(14, FontWeight.w800, _C.navy)),
                const SizedBox(height: 4),
                Text(user?.email ?? '\u2014',
                    style: _font(11, FontWeight.w500, _C.textMuted)),
                if (user?.noTelepon.isNotEmpty ?? false)
                  Text(user!.noTelepon,
                      style: _font(11, FontWeight.w500, _C.textMuted)),
              ])),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Edit Profil',
            onPressed: () => _bukaEditProfil(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECF4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_outlined, size: 16, color: _C.blue),
            ),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: _C.border),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final stat in stats)
            Expanded(
              child: Column(children: [
                Text(stat.$2, style: _font(16, FontWeight.w800, _C.navy)),
                const SizedBox(height: 4),
                Text(stat.$1,
                    textAlign: TextAlign.center,
                    style: _font(10, FontWeight.w500, _C.textMuted)),
              ]),
            ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1, color: _C.border),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.calendar_month_outlined,
              size: 13, color: _C.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text('Bergabung sejak $tahunBergabung',
                style: _font(10, FontWeight.w500, _C.textMuted)),
          ),
        ]),
      ]),
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
        Expanded(
            child: Text(
          text,
          style: _font(15.5, FontWeight.w800, _C.navy, letterSpacing: -0.3),
        )),
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
  final VoidCallback onTap;
  final bool isDanger;

  const _MenuItemData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
class _NotifikasiSheet extends StatelessWidget {
  const _NotifikasiSheet();
  @override
  Widget build(BuildContext context) => const _UnavailableSettingSheet(
        title: 'Preferensi Notifikasi',
        message:
            'Pengaturan jenis notifikasi belum tersedia. Notifikasi perangkat tetap mengikuti izin sistem perangkat.',
      );
}

class _PilihBahasaSheet extends StatelessWidget {
  const _PilihBahasaSheet();
  @override
  Widget build(BuildContext context) => const _UnavailableSettingSheet(
        title: 'Bahasa',
        message:
            'Aplikasi menggunakan Bahasa Indonesia. Pilihan bahasa lain belum tersedia.',
      );
}

class _UnavailableSettingSheet extends StatelessWidget {
  const _UnavailableSettingSheet({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _font(20, FontWeight.w800, _C.navy)),
                  const SizedBox(height: 12),
                  Text(message,
                      style: _font(14, FontWeight.w500, _C.textMuted,
                          height: 1.5)),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup')),
                ])),
      );
}

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
