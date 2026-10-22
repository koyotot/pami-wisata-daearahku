// ============================================================
// lib/screens/kelola_admin_screen.dart
// Hanya bisa diakses oleh superadmin
// ============================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_login.dart'; // untuk model AdminUser

class KelolaAdminScreen extends StatefulWidget {
  const KelolaAdminScreen({super.key});

  @override
  State<KelolaAdminScreen> createState() => _KelolaAdminScreenState();
}

class _KelolaAdminScreenState extends State<KelolaAdminScreen> {
  // ── Warna ──────────────────────────────────────────────────
  static const _bg = Color(0xFFF5F8FD);
  static const _surface = Colors.white;
  static const _teal = Color(0xFF1976D2); // biru utama
  static const _tealDark = Color(0xFF1558B0);
  static const _gold = Color(0xFFFF9800);
  static const _goldText = Color(0xFF9A5B00);
  static const _text = Color(0xFF102D59);
  static const _muted = Color(0xFF728099);
  static const _dim = Color(0xFF9AA7BC);
  static const _red = Color(0xFFE5484D);
  static const _border = Color(0xFFDCE4F0);

  bool _showForm = false;
  bool _isSaving = false;

  final _usernameCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _namaCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Tambah admin baru ke Firestore ────────────────────────
  Future<void> _tambahAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Cek apakah username sudah ada
      final cek = await FirebaseFirestore.instance
          .collection('admins')
          .where('username', isEqualTo: _usernameCtrl.text.trim())
          .limit(1)
          .get();

      if (cek.docs.isNotEmpty) {
        _showSnack('Username sudah digunakan, pilih username lain.',
            isError: true);
        setState(() => _isSaving = false);
        return;
      }

      await FirebaseFirestore.instance.collection('admins').add({
        'username': _usernameCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'namaLengkap': _namaCtrl.text.trim(),
        'isSuperAdmin': false,
        'createdAt': Timestamp.now(),
      });

      _usernameCtrl.clear();
      _namaCtrl.clear();
      _passwordCtrl.clear();
      setState(() {
        _showForm = false;
        _isSaving = false;
      });
      _showSnack('Admin berhasil ditambahkan.');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Gagal menyimpan: $e', isError: true);
    }
  }

  // ── Hapus admin (tidak bisa hapus superadmin) ─────────────
  Future<void> _hapusAdmin(AdminUser admin) async {
    if (admin.isSuperAdmin) {
      _showSnack('Superadmin tidak dapat dihapus.', isError: true);
      return;
    }

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Admin',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
        content: Text(
          'Hapus admin "${admin.namaLengkap}" (@${admin.username})?\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(color: _muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus',
                style: TextStyle(color: _red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(admin.id)
          .delete();
      _showSnack('Admin "${admin.namaLengkap}" telah dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _red : _tealDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Header
          _header(),

          // Banner superadmin info
          _infoBanner(),

          // Form tambah admin
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showForm ? _formTambah() : const SizedBox.shrink(),
          ),

          // Daftar admin dari Firestore (realtime)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('admins')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: _teal, strokeWidth: 2));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _emptyState();
                }

                final admins = snap.data!.docs
                    .map((d) => AdminUser.fromMap(
                        d.data() as Map<String, dynamic>, d.id))
                    .toList();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: admins.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _adminCard(admins[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A93F0), Color(0xFF1976D2), Color(0xFF1558B0)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showForm = !_showForm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showForm
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5)),
                      boxShadow: _showForm
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Text(
                      _showForm ? 'Tutup' : 'Tambah',
                      style: TextStyle(
                        color: _showForm ? Colors.white : _tealDark,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'AKSES SUPERADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kelola Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tambah dan atur akun admin aplikasi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // Tepi bawah melengkung menyatu dengan konten
          Container(
            height: 26,
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner info ───────────────────────────────────────────
  Widget _infoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _gold, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Hanya superadmin yang dapat menambah dan menghapus admin. '
              'Admin biasa tidak dapat diubah menjadi superadmin.',
              style: TextStyle(color: _goldText, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form tambah admin ─────────────────────────────────────
  Widget _formTambah() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tambah Admin Baru',
                style: TextStyle(
                    color: _text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _buildField(
              controller: _namaCtrl,
              hint: 'Nama lengkap admin',
              icon: Icons.badge_outlined,
              label: 'Nama Lengkap',
              validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _usernameCtrl,
              hint: 'Username untuk login',
              icon: Icons.person_outline_rounded,
              label: 'Username',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (v.contains(' '))
                  return 'Username tidak boleh mengandung spasi';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _passwordCtrl,
              hint: 'Minimal 6 karakter',
              icon: Icons.lock_outline_rounded,
              label: 'Password',
              isPassword: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (v.length < 6) return 'Minimal 6 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _tambahAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Simpan Admin',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String label,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _text, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscure,
          validator: validator,
          style: const TextStyle(color: _text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _dim, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, color: _teal, size: 17),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _dim,
                      size: 17,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            filled: true,
            fillColor: _bg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _teal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red, width: 1.5),
            ),
            errorStyle: const TextStyle(color: _red, fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Card tiap admin ───────────────────────────────────────
  Widget _adminCard(AdminUser admin) {
    final isMe = admin.id == currentAdmin?.id;
    final badgeColor = admin.isSuperAdmin ? _goldText : _teal;
    final badgeLabel = admin.isSuperAdmin ? 'Superadmin' : 'Admin';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMe ? _teal.withValues(alpha: 0.45) : _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: admin.isSuperAdmin
                      ? [const Color(0xFFFFB74D), const Color(0xFFF57C00)]
                      : [const Color(0xFF2A93F0), _tealDark]),
              shape: BoxShape.circle,
            ),
            child: Icon(
              admin.isSuperAdmin
                  ? Icons.verified_user_rounded
                  : Icons.person_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(admin.namaLengkap,
                          style: const TextStyle(
                              color: _text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Anda',
                            style: TextStyle(
                                color: _teal,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('@${admin.username}',
                    style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(badgeLabel,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          // Tombol hapus (tidak untuk superadmin & diri sendiri)
          if (!admin.isSuperAdmin && !isMe)
            GestureDetector(
              onTap: () => _hapusAdmin(admin),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _red.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _red, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_off_rounded,
              size: 52, color: _muted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Belum ada admin',
              style: TextStyle(color: _muted, fontSize: 14)),
        ],
      ),
    );
  }
}
