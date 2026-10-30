// ============================================================
// lib/screens/daftar_kunjungan_screen.dart
// Form pendaftaran kunjungan wisata — tema biru terang
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/booking_intent.dart';
import '../services/auth_session.dart';
import '../data/app_data.dart';

// ── Palet (sama dengan home_screen.dart) ─────────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const surface = Colors.white;
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);

  // Alias supaya kode lama tetap jalan dengan warna baru
  static const teal = blue;
  static const tealDark = blueDeep;
  static const gold = orange;
}

class DaftarKunjunganScreen extends StatefulWidget {
  final Wisata wisata;
  const DaftarKunjunganScreen({super.key, required this.wisata});

  @override
  State<DaftarKunjunganScreen> createState() => _DaftarKunjunganScreenState();
}

class _DaftarKunjunganScreenState extends State<DaftarKunjunganScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _namaCtrl = TextEditingController();
  final _teleponCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  DateTime? _tanggal;
  int _jumlahOrang = 1;
  bool _isLoading = false;
  bool _completed = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    AuthSession.instance.sessionChanges.addListener(_sessionChanged);

    // Auto-fill data dari akun yang sedang login
    if (currentUser != null) {
      _namaCtrl.text = currentUser!.namaLengkap;
      _teleponCtrl.text = currentUser!.noTelepon;
      _emailCtrl.text = currentUser!.email;
    }
  }

  void _sessionChanged() {
    _namaCtrl.clear();
    _teleponCtrl.clear();
    _emailCtrl.clear();
    _catatanCtrl.clear();
    final user = AuthSession.instance.deviceSessionReady ? currentUser : null;
    if (user != null && user.isLaravel) {
      _namaCtrl.text = user.namaLengkap;
      _teleponCtrl.text = user.noTelepon;
      _emailCtrl.text = user.email;
    }
    if (mounted) {
      setState(() {
        _tanggal = null;
        _jumlahOrang = 1;
        _completed = false;
      });
    }
  }

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_sessionChanged);
    _animCtrl.dispose();
    _namaCtrl.dispose();
    _teleponCtrl.dispose();
    _emailCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1976D2),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF102D59),
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan pilih tanggal kunjungan'),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (_isLoading || _completed) return;
    final user = currentUser;
    if (user == null || !user.isLaravel || !widget.wisata.isLaravel) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pendaftaran memerlukan akun dan destinasi Laravel.')));
      return;
    }
    final generation = AuthSession.instance.sessionGeneration;
    setState(() => _isLoading = true);
    final date = _tanggal!;
    final fields = <String, dynamic>{
      'destination_guid': widget.wisata.id,
      'visit_date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'quantity': _jumlahOrang,
      'visitor_name': _namaCtrl.text.trim(),
      'visitor_email': _emailCtrl.text.trim(),
      'visitor_phone': _teleponCtrl.text.trim(),
      'notes': _catatanCtrl.text.trim(),
    };
    try {
      final intent = BookingIntent();
      final pending = await intent.pending(user.id);
      if (!mounted || generation != AuthSession.instance.sessionGeneration) {
        return;
      }
      if (pending != null) {
        final reconcile = await showDialog<bool>(
            context: context,
            builder: (context) => ValueListenableBuilder<int>(
                valueListenable: AuthSession.instance.sessionChanges,
                builder: (context, _, __) => generation !=
                        AuthSession.instance.sessionGeneration
                    ? const AlertDialog(content: Text('Sesi telah berakhir.'))
                    : AlertDialog(
                        title: const Text('Periksa pendaftaran sebelumnya'),
                        content: Text(
                            'Hasil pendaftaran sebelumnya belum diketahui. Periksa ulang untuk destinasi ${pending['destination_guid']}, tanggal ${pending['visit_date']}, atas nama ${pending['visitor_name']}. Permintaan lama dapat membuat booking jika sebelumnya belum diterima. Data formulir saat ini belum dikirim.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Periksa kembali'))
                        ],
                      )));
        if (reconcile != true ||
            !mounted ||
            generation != AuthSession.instance.sessionGeneration) {
          return;
        }
      }
      final booking =
          await intent.submit(user.id, fields, reconcile: pending != null);
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != AuthSession.instance.sessionGeneration) {
        return;
      }
      setState(() => _completed = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Pendaftaran ${booking.json['booking_number']}: ${booking.status}')));
    } catch (error) {
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != AuthSession.instance.sessionGeneration) {
        return;
      }
      final message = error is ApiException &&
              error.status != null &&
              error.status! < 500
          ? error.message
          : 'Hasil pendaftaran belum diketahui. Periksa kembali pendaftaran sebelumnya.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF102D59), size: 18),
          ),
        ),
        title: const Text(
          'Daftar Kunjungan',
          style: TextStyle(
            color: Color(0xFF102D59),
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.teal.withValues(alpha: 0.12)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [
                // ── Destinasi Info Card ─────────────────────
                _DestinasiCard(wisata: widget.wisata),
                const SizedBox(height: 28),

                // ── Section: Data Pengunjung ────────────────
                _sectionLabel('Data Pengunjung'),
                const SizedBox(height: 14),

                _DarkField(
                  controller: _namaCtrl,
                  label: 'Nama Lengkap',
                  hint: 'Masukkan nama lengkap',
                  icon: Icons.person_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),

                _DarkField(
                  controller: _teleponCtrl,
                  label: 'Nomor Telepon',
                  hint: 'Contoh: 08123456789',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'Nomor telepon tidak valid'
                      : null,
                ),
                const SizedBox(height: 14),

                _DarkField(
                  controller: _emailCtrl,
                  label: 'Email (opsional)',
                  hint: 'nama@email.com',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 28),

                // ── Section: Detail Kunjungan ───────────────
                _sectionLabel('Detail Kunjungan'),
                const SizedBox(height: 14),

                // Tanggal Kunjungan
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _C.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.calendar_today_rounded,
                              color: _C.teal, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tanggal Kunjungan',
                                  style: TextStyle(
                                      color: _C.textDim,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                _tanggal == null
                                    ? 'Pilih tanggal'
                                    : '${_tanggal!.day.toString().padLeft(2, '0')}/${_tanggal!.month.toString().padLeft(2, '0')}/${_tanggal!.year}',
                                style: TextStyle(
                                  color:
                                      _tanggal == null ? _C.textDim : _C.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: _C.textDim, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Jumlah Orang
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _C.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(Icons.group_rounded, color: _C.gold, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jumlah Pengunjung',
                                style: TextStyle(
                                    color: _C.textDim,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                            Text(
                              '$_jumlahOrang orang',
                              style: TextStyle(
                                color: _C.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _CounterBtn(
                            icon: Icons.remove_rounded,
                            onTap: _jumlahOrang > 1
                                ? () => setState(() => _jumlahOrang--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '$_jumlahOrang',
                              style: TextStyle(
                                color: _C.teal,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _CounterBtn(
                            icon: Icons.add_rounded,
                            onTap: _jumlahOrang < 50
                                ? () => setState(() => _jumlahOrang++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Catatan
                _DarkField(
                  controller: _catatanCtrl,
                  label: 'Catatan (opsional)',
                  hint: 'Kebutuhan khusus, aksesibilitas, dll.',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 36),

                // ── Tombol Daftar ───────────────────────────
                GestureDetector(
                  onTap: _isLoading || _completed ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isLoading
                            ? [
                                _C.teal.withValues(alpha: 0.5),
                                _C.tealDark.withValues(alpha: 0.5)
                              ]
                            : [_C.teal, _C.tealDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: _C.teal.withValues(alpha: 0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.how_to_reg_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Konfirmasi Pendaftaran',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.teal, _C.gold],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _C.text,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
}

// ── Destinasi Info Card ────────────────────────────────────
class _DestinasiCard extends StatelessWidget {
  final Wisata wisata;
  const _DestinasiCard({required this.wisata});

  Widget _buildImage() {
    final path = wisata.imagePath;
    debugPrint('🖼️ [DestinasiCard] imagePath = $path');
    if (path == null || path.isEmpty) return _placeholder();

    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp/1.0)',
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child; // sudah selesai load
          return Container(
            color: const Color(0xFFE6F0FC),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF1976D2),
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFE6F0FC),
        child: const Center(
          child:
              Icon(Icons.landscape_rounded, color: Color(0xFF1976D2), size: 28),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Thumbnail gambar wisata
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: _buildImage(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wisata.nama,
                  style: const TextStyle(
                    color: Color(0xFF102D59),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '📍 ${wisata.lokasi}',
                  style:
                      const TextStyle(color: Color(0xFF728099), fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  '🎫 ${wisata.hargaTiket}  ·  🕐 ${wisata.jamBuka}',
                  style:
                      const TextStyle(color: Color(0xFF728099), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dark-themed text field ─────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Color(0xFF102D59), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF728099), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF9AA7BC), fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: const Color(0xFF1976D2), size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE4F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFE5484D), fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Counter Button ─────────────────────────────────────────
class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1976D2).withValues(alpha: 0.15)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF1976D2).withValues(alpha: 0.4)
                : const Color(0xFFDCE4F0),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? const Color(0xFF1976D2) : const Color(0xFF9AA7BC),
        ),
      ),
    );
  }
}
