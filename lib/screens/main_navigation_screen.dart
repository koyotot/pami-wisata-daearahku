// ============================================================
// lib/screens/main_navigation_screen.dart
// Shell utama navigasi user setelah login.
// Navigasi antar tab (Beranda, Cari, Riwayat, Profil) lewat DRAWER.
// Drawer bisa dibuka dari tombol menu di Beranda, atau dengan
// menggeser dari tepi kiri layar di tab mana pun.
// Tema: biru terang — sama dengan home, login, dan register.
// Package: google_fonts, firebase_auth
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_fonts/google_fonts.dart';

import '../data/app_data.dart';
import 'beranda_user_screen.dart';
import 'cari_wisata_screen.dart';
import 'bukti_pendaftaran_screen.dart';
import 'profil_user_screen.dart';
import 'home_screen.dart';
import 'user_login_screen.dart';

// ── Palet & font (sama dengan home_screen.dart) ──────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const textMuted = Color(0xFF728099);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);
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

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  void _gotoTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _bukaMenu() => _scaffoldKey.currentState?.openDrawer();

  late final List<Widget> _tabs = [
    BerandaUserScreen(onBukaMenu: _bukaMenu),
    CariWisataScreen(
      embedded: true,
      onBukaMenu: _bukaMenu, // tombol ☰ membuka drawer
      onKembali: () => _gotoTab(0), // tombol kembali -> tab Beranda
    ),
    BuktiPendaftaranScreen(
      embedded: true,
      // Dari tab Riwayat yang kosong, tombol "Jelajahi Wisata"
      // mengarahkan kembali ke tab Beranda alih-alih Navigator.pop.
      onExploreWisata: () => _gotoTab(0),
      onBukaMenu: _bukaMenu, // tombol ☰ membuka drawer
      onKembali: () => _gotoTab(0), // tombol kembali -> tab Beranda
    ),
    ProfilUserScreen(
      onBukaMenu: _bukaMenu, // tombol ☰ membuka drawer
      onKembali: () => _gotoTab(0), // tombol kembali -> tab Beranda
    ),
  ];

  static const List<_MenuData> _menu = [
    _MenuData(
      icon: Icons.home_rounded,
      label: 'Beranda',
      color: _C.blue,
    ),
    _MenuData(
      icon: Icons.search_rounded,
      label: 'Cari Wisata',
      color: Color(0xFF7E57C2),
    ),
    _MenuData(
      icon: Icons.receipt_long_rounded,
      label: 'Riwayat',
      color: _C.orange,
    ),
    _MenuData(
      icon: Icons.person_rounded,
      label: 'Profil',
      color: Color(0xFF26A69A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      // Tombol kembali: dari tab lain kembali ke Beranda dulu.
      child: PopScope(
        canPop: _selectedIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _gotoTab(0);
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          drawer: _buildDrawer(),
          // IndexedStack mempertahankan state setiap tab (mis. hasil pencarian,
          // scroll position) walau pengguna berpindah-pindah tab.
          body: IndexedStack(
            index: _selectedIndex,
            children: _tabs,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  DRAWER
  // ══════════════════════════════════════════════════════════
  Widget _buildDrawer() {
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
                ...List.generate(_menu.length, (i) {
                  final m = _menu[i];
                  return _drawerItem(
                    icon: m.icon,
                    color: m.color,
                    label: m.label,
                    selected: i == _selectedIndex,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _gotoTab(i);
                    },
                  );
                }),
              ],
            ),
          ),

          // Bagian bawah
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
                    icon: Icons.info_outline_rounded,
                    color: _C.textMuted,
                    label: 'Tentang Aplikasi',
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _tampilkanTentang();
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
    final user = currentUser;
    final nama = user?.namaLengkap.trim() ?? '';
    final inisial = nama.isEmpty ? '' : nama[0].toUpperCase();
    final email = user?.email ?? '';
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
                child: inisial.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: Colors.white, size: 30)
                    : Text(
                        inisial,
                        style: _font(26, FontWeight.w800, Colors.white),
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                nama.isEmpty ? 'Pengunjung' : nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(
                  18,
                  FontWeight.w800,
                  Colors.white,
                  letterSpacing: -0.4,
                ),
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
                    Icon(Icons.email_rounded,
                        color: Colors.white.withValues(alpha: 0.9), size: 12),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        email.isEmpty ? '-' : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _font(
                          11.5,
                          FontWeight.w600,
                          Colors.white.withValues(alpha: 0.95),
                        ),
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

  // ── Dialog: tentang aplikasi ───────────────────────────────
  void _tampilkanTentang() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF42A5F5), _C.blue],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.travel_explore_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Wisata Daerahku',
                style: _font(17, FontWeight.w800, _C.navy),
              ),
            ),
          ],
        ),
        content: Text(
          'Versi 1.0.0\nJelajahi & daftarkan kunjunganmu ke destinasi '
          'wisata terbaik di daerahmu.',
          style: _font(13, FontWeight.w500, _C.textMuted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: _font(13.5, FontWeight.w800, _C.blue)),
          ),
        ],
      ),
    );
  }

  // ── Dialog: konfirmasi keluar ──────────────────────────────
  Future<void> _konfirmasiLogout() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Keluar dari Akun?',
          style: _font(17, FontWeight.w800, _C.navy),
        ),
        content: Text(
          'Kamu perlu login kembali untuk mengakses akun ini.',
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

    if (yakin != true) return;

    await fb_auth.FirebaseAuth.instance.signOut();
    currentUser = null;
    if (!mounted) return;

    _keLogin(context);
  }
}

class _MenuData {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuData({
    required this.icon,
    required this.label,
    required this.color,
  });
}
