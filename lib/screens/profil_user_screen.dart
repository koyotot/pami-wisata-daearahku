import '../services/auth_session.dart';
// ============================================================
// lib/screens/profil_user_screen.dart
// Tab "Profil" — bagian dari navigasi drawer (MainNavigationScreen)
// Tema: biru terang — sama dengan home, login, beranda, dan drawer.
// Header punya tombol KEMBALI (ke Beranda) dan tombol MENU (☰)
// yang membuka drawer.
// Package: google_fonts, firebase_auth, cloud_firestore
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
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
  static const success = Color(0xFF2E9E6B);
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

  const ProfilUserScreen({super.key, this.onBukaMenu, this.onKembali});

  @override
  State<ProfilUserScreen> createState() => _ProfilUserScreenState();
}

class _ProfilUserScreenState extends State<ProfilUserScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _loadingJumlah = true;
  int _jumlahPendaftaran = 0;
  int _jumlahUlasan = 0;
  int _jumlahDikunjungi = 0;

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
    _loadJumlahPendaftaran();
  }

  // Ambil jumlah pendaftaran milik user yang sedang login langsung dari
  // Firestore (sumber kebenaran yang sama dipakai BuktiPendaftaranScreen),
  // bukan dari `daftarPendaftar` yang cuma list sementara di RAM dan akan
  // kosong lagi setiap kali app dibuka ulang.
  Future<void> _loadJumlahPendaftaran() async {
    final uid = currentUser?.isLaravel == true ? '' : (currentUser?.id ?? '');
    if (uid.isEmpty) {
      setState(() => _loadingJumlah = false);
      return;
    }
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('pendaftar')
            .where('userId', isEqualTo: uid)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('ulasan')
            .where('userId', isEqualTo: uid)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('kunjungan')
            .where('userId', isEqualTo: uid)
            .count()
            .get(),
      ]);

      if (!mounted) return;
      setState(() {
        _jumlahPendaftaran = results[0].count ?? 0;
        _jumlahUlasan = results[1].count ?? 0;
        _jumlahDikunjungi = results[2].count ?? 0;
        _loadingJumlah = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingJumlah = false);
    }
  }

  @override
  void dispose() {
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

    try {
      await AuthSession.instance.logout();
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Sesi lokal dihapus. Pencabutan sesi server belum dapat dikonfirmasi.')));
    }
    await fb_auth.FirebaseAuth.instance.signOut();
    currentUser = null;
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
          final uid = currentUser?.id ?? '';
          if (uid.isEmpty) return;
          if (currentUser?.isLaravel == true) {
            await AuthSession.instance.updateProfile(nama, telepon);
          } else {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .update({'namaLengkap': nama, 'noTelepon': telepon});
          }
          currentUser?.namaLengkap = nama;
          currentUser?.noTelepon = telepon;
          if (!mounted) return;
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
      builder: (_) => _RiwayatUlasanSheet(
          userId:
              currentUser?.isLaravel == true ? '' : (currentUser?.id ?? '')),
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
      builder: (_) => _SemuaWisataTersimpanSheet(
          userId:
              currentUser?.isLaravel == true ? '' : (currentUser?.id ?? '')),
    );
  }

  void _bukaGantiPassword(BuildContext context) {
    if (currentUser?.isLaravel == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fitur ini belum tersedia untuk akun API.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _GantiPasswordSheet(),
    );
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
                      value: _loadingJumlah ? '–' : '$_jumlahPendaftaran',
                      label: 'Pendaftaran',
                      iconColor: _C.orange,
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      icon: Icons.location_on_rounded,
                      value: _loadingJumlah ? '–' : '$_jumlahDikunjungi',
                      label: 'Dikunjungi',
                      iconColor: _C.blue,
                    ),
                    const SizedBox(width: 8),
                    _statCard(
                      icon: Icons.star_rounded,
                      value: _loadingJumlah ? '–' : '$_jumlahUlasan',
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
    final uid = currentUser?.isLaravel == true ? '' : (currentUser?.id ?? '');
    if (uid.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.teal.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text('Login untuk melihat wisata tersimpan',
              style: TextStyle(color: _C.textMuted, fontSize: 13)),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wisataTersimpan')
          .where('userId', isEqualTo: uid)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final at = (a.data() as Map)['savedAt'];
            final bt = (b.data() as Map)['savedAt'];
            if (at == null || bt == null) return 0;
            return (bt as Timestamp).compareTo(at as Timestamp);
          });
        final isLoading =
            snap.connectionState == ConnectionState.waiting && docs.isEmpty;

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
              : docs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Belum ada wisata tersimpan',
                            style:
                                TextStyle(color: _C.textMuted, fontSize: 13)),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nama =
                              data['namaWisata'] as String? ?? 'Wisata';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _C.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _C.teal.withValues(alpha: 0.25)),
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
                          onTap: () => _bukaSemuaWisataTersimpan(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _C.gold.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _C.gold.withValues(alpha: 0.30)),
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
    if (currentUser?.isLaravel == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fitur ini belum tersedia untuk akun API.')));
      return;
    }
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _C.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Hapus Akun?',
              style: TextStyle(color: _C.danger, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semua data akun kamu akan dihapus secara permanen dan tidak bisa dikembalikan.',
                style: TextStyle(color: _C.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text('Konfirmasi dengan password kamu:',
                  style: TextStyle(
                      color: _C.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                style: TextStyle(color: _C.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Masukkan password',
                  hintStyle: TextStyle(color: _C.textDim, fontSize: 13),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _C.textDim,
                        size: 18),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  filled: true,
                  fillColor: _C.bg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _C.border, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _C.danger, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: _C.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                final pw = passwordCtrl.text.trim();
                if (pw.isEmpty) return;
                Navigator.pop(ctx);

                try {
                  final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
                  if (fbUser == null || fbUser.email == null) return;

                  // Re-autentikasi wajib sebelum hapus akun
                  final cred = fb_auth.EmailAuthProvider.credential(
                    email: fbUser.email!,
                    password: pw,
                  );
                  await fbUser.reauthenticateWithCredential(cred);

                  final uid = fbUser.uid;

                  // Hapus data Firestore milik user
                  final batch = FirebaseFirestore.instance.batch();
                  final colRefs = ['users', 'pendaftar', 'ulasan', 'kunjungan'];
                  for (final col in colRefs) {
                    if (col == 'users') {
                      batch.delete(FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid));
                    } else {
                      final snap = await FirebaseFirestore.instance
                          .collection(col)
                          .where('userId', isEqualTo: uid)
                          .get();
                      for (final doc in snap.docs) {
                        batch.delete(doc.reference);
                      }
                    }
                  }
                  await batch.commit();

                  // Hapus akun Firebase Auth
                  await fbUser.delete();

                  currentUser = null;
                  if (!context.mounted) return;
                  _keLogin(context);
                } on fb_auth.FirebaseAuthException catch (e) {
                  if (!context.mounted) return;
                  final pesan = e.code == 'wrong-password' ||
                          e.code == 'invalid-credential'
                      ? 'Password salah. Akun tidak dihapus.'
                      : 'Gagal: ${e.message}';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(pesan),
                    backgroundColor: _C.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              child: Text('Hapus',
                  style:
                      TextStyle(color: _C.danger, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  LOGOUT BUTTON
  // ══════════════════════════════════════════════════════════
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
class _GantiPasswordSheet extends StatefulWidget {
  const _GantiPasswordSheet();

  @override
  State<_GantiPasswordSheet> createState() => _GantiPasswordSheetState();
}

class _GantiPasswordSheetState extends State<_GantiPasswordSheet> {
  final _lamaCtrl = TextEditingController();
  final _baruCtrl = TextEditingController();
  final _konfirmasiCtrl = TextEditingController();

  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _obscureKonfirmasi = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Supaya strength meter & indikator kecocokan ikut update live
    // setiap kali pengguna mengetik, dan error lama otomatis hilang.
    _lamaCtrl.addListener(_onFieldChanged);
    _baruCtrl.addListener(_onFieldChanged);
    _konfirmasiCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_errorMsg != null) {
      setState(() => _errorMsg = null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _lamaCtrl.dispose();
    _baruCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  // 0–5: panjang, panjang ekstra, huruf besar, angka, simbol.
  int _calcStrength(String pw) {
    if (pw.isEmpty) return 0;
    int score = 0;
    if (pw.length >= 6) score++;
    if (pw.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
    return score;
  }

  Future<void> _submit() async {
    final lama = _lamaCtrl.text;
    final baru = _baruCtrl.text;
    final konfirmasi = _konfirmasiCtrl.text;

    if (lama.isEmpty || baru.isEmpty || konfirmasi.isEmpty) {
      setState(() => _errorMsg = 'Semua kolom wajib diisi.');
      return;
    }
    if (baru.length < 6) {
      setState(() => _errorMsg = 'Password baru minimal 6 karakter.');
      return;
    }
    if (baru != konfirmasi) {
      setState(() => _errorMsg = 'Konfirmasi password baru tidak cocok.');
      return;
    }
    if (baru == lama) {
      setState(
          () => _errorMsg = 'Password baru tidak boleh sama dengan yang lama.');
      return;
    }

    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw fb_auth.FirebaseAuthException(
          code: 'no-user',
          message: 'Sesi berakhir, silakan login kembali.',
        );
      }

      // 1. Re-autentikasi dengan password lama (wajib oleh Firebase
      //    sebelum mengubah credential sensitif seperti password).
      final cred = fb_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: lama,
      );
      await user.reauthenticateWithCredential(cred);

      // 2. Update password baru ke Firebase Auth.
      await user.updatePassword(baru);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Password berhasil diperbarui!'),
        backgroundColor: _C.tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    } on fb_auth.FirebaseAuthException catch (e) {
      String pesan;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          pesan = 'Password lama yang kamu masukkan salah.';
          break;
        case 'weak-password':
          pesan = 'Password baru terlalu lemah, gunakan kombinasi lebih kuat.';
          break;
        case 'requires-recent-login':
          pesan =
              'Sesi login sudah lama. Silakan keluar dan masuk kembali sebelum mengubah password.';
          break;
        case 'too-many-requests':
          pesan = 'Terlalu banyak percobaan. Coba lagi nanti.';
          break;
        case 'no-user':
          pesan = e.message ?? 'Sesi berakhir, silakan login kembali.';
          break;
        default:
          pesan = 'Terjadi kesalahan. Silakan coba lagi.';
      }
      setState(() {
        _errorMsg = pesan;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMsg = 'Terjadi kesalahan tidak terduga.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Naik mengikuti keyboard supaya field terakhir tidak tertutup.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.card, const Color(0xFFE6F0FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _C.teal.withValues(alpha: 0.14), width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // ── Header ikon glow di tengah ──────────────────
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.teal.withValues(alpha: 0.08),
                      ),
                    ),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_C.teal, _C.tealDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.teal.withValues(alpha: 0.45),
                            blurRadius: 22,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text('Ubah Password',
                    style: TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Perbarui kata sandi akun kamu',
                    style: TextStyle(color: _C.textMuted, fontSize: 12.5)),
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _C.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.teal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: _C.teal, size: 13),
                      const SizedBox(width: 6),
                      Text('Minimal 6 karakter, makin unik makin aman',
                          style:
                              TextStyle(color: _C.textMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMsg != null) ...[
                _ErrorBanner(message: _errorMsg!),
                const SizedBox(height: 16),
              ],

              _fieldLabel('Password Lama'),
              const SizedBox(height: 8),
              _SheetPasswordField(
                controller: _lamaCtrl,
                obscure: _obscureLama,
                onToggle: () => setState(() => _obscureLama = !_obscureLama),
              ),
              const SizedBox(height: 16),

              _fieldLabel('Password Baru'),
              const SizedBox(height: 8),
              _SheetPasswordField(
                controller: _baruCtrl,
                obscure: _obscureBaru,
                onToggle: () => setState(() => _obscureBaru = !_obscureBaru),
              ),
              _buildStrengthMeter(_baruCtrl.text),
              const SizedBox(height: 16),

              _fieldLabel('Konfirmasi Password Baru'),
              const SizedBox(height: 8),
              _SheetPasswordField(
                controller: _konfirmasiCtrl,
                obscure: _obscureKonfirmasi,
                onToggle: () =>
                    setState(() => _obscureKonfirmasi = !_obscureKonfirmasi),
                onSubmit: (_) => _submit(),
              ),
              _buildMatchIndicator(),
              const SizedBox(height: 24),

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
                    boxShadow: _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: _C.teal.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
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
                            children: const [
                              Text(
                                'Simpan Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
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

  // ── Indikator kekuatan password baru ────────────────────────
  Widget _buildStrengthMeter(String pw) {
    if (pw.isEmpty) return const SizedBox(height: 0);

    final score = _calcStrength(pw);
    late String label;
    late Color color;
    late double fraction;
    if (score <= 2) {
      label = 'Lemah';
      color = _C.danger;
      fraction = 0.33;
    } else if (score == 3) {
      label = 'Sedang';
      color = _C.warning;
      fraction = 0.66;
    } else {
      label = 'Kuat';
      color = _C.success;
      fraction = 1.0;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Indikator kecocokan konfirmasi password ─────────────────
  Widget _buildMatchIndicator() {
    final konfirmasi = _konfirmasiCtrl.text;
    if (konfirmasi.isEmpty) return const SizedBox(height: 0);

    final cocok = konfirmasi == _baruCtrl.text;
    final color = cocok ? _C.success : _C.danger;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(cocok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color, size: 14),
          const SizedBox(width: 6),
          Text(cocok ? 'Password cocok' : 'Belum cocok dengan password baru',
              style: TextStyle(color: color, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: TextStyle(
          color: _C.text,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      );
}

class _SheetPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onSubmit;

  const _SheetPasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscure,
        onSubmitted: onSubmit,
        textInputAction: TextInputAction.next,
        style: TextStyle(color: _C.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Masukkan password',
          hintStyle: TextStyle(color: _C.textDim, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.lock_rounded, color: _C.teal, size: 18),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _C.textDim,
              size: 18,
            ),
            onPressed: onToggle,
          ),
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
      );
}

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — Edit Profil
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
class _RiwayatUlasanSheet extends StatelessWidget {
  final String userId;
  const _RiwayatUlasanSheet({required this.userId});

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
          Text('Riwayat Ulasan',
              style: TextStyle(
                  color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Expanded(
            child: userId.isEmpty
                ? Center(
                    child: Text('Belum ada ulasan.',
                        style: TextStyle(color: _C.textMuted)))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('ulasan')
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = (snap.data?.docs ?? [])
                        ..sort((a, b) {
                          final at = (a.data() as Map)['createdAt'];
                          final bt = (b.data() as Map)['createdAt'];
                          if (at == null || bt == null) return 0;
                          return (bt as Timestamp).compareTo(at as Timestamp);
                        });
                      if (docs.isEmpty) {
                        return Center(
                          child: Text('Belum ada ulasan.',
                              style: TextStyle(color: _C.textMuted)),
                        );
                      }
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: _C.border.withValues(alpha: 0.5)),
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final nama =
                              data['namaWisata'] as String? ?? 'Wisata';
                          final isi = data['isi'] as String? ?? '';
                          final rating = (data['rating'] as num?)?.toInt() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.place_rounded,
                                        color: _C.teal, size: 14),
                                    const SizedBox(width: 4),
                                    Text(nama,
                                        style: TextStyle(
                                            color: _C.text,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    const Spacer(),
                                    Row(
                                      children: List.generate(
                                          5,
                                          (s) => Icon(Icons.star_rounded,
                                              size: 13,
                                              color: s < rating
                                                  ? _C.gold
                                                  : _C.border)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(isi,
                                    style: TextStyle(
                                        color: _C.textMuted,
                                        fontSize: 12.5,
                                        height: 1.4)),
                              ],
                            ),
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

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — Notifikasi
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
  final String userId;
  const _SemuaWisataTersimpanSheet({required this.userId});

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
            child: userId.isEmpty
                ? Center(
                    child: Text('Belum ada wisata tersimpan.',
                        style: TextStyle(color: _C.textMuted)))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('wisataTersimpan')
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
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
                          final data = docs[i].data() as Map<String, dynamic>;
                          final nama =
                              data['namaWisata'] as String? ?? 'Wisata';
                          final lokasi = data['lokasi'] as String? ?? '';
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
                                    style: TextStyle(
                                        color: _C.textMuted, fontSize: 12))
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
