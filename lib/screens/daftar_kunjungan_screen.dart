// ============================================================
// lib/screens/daftar_kunjungan_screen.dart
// Form pendaftaran kunjungan wisata — tema biru terang
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/booking_errors.dart';
import '../data/booking_intent.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../data/app_data.dart';
import '../widgets/api_image.dart';

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

  /// Injected only by tests; production uses the shared API client.
  final BusinessRepository? repository;
  final BookingIntent? intent;

  /// Pre-selected visit date (tests only; the user normally picks it).
  final DateTime? initialDate;
  const DaftarKunjunganScreen(
      {super.key,
      required this.wisata,
      this.repository,
      this.intent,
      this.initialDate});

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

  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final BookingIntent _intent =
      widget.intent ?? BookingIntent(repository: _repository);
  final _availability = RequestState<Availability?>();

  /// Server-confirmed booking shown after success (number and SERVER status).
  Booking? _booking;

  /// Payload of an unresolved earlier attempt, and what the server said about it.
  Map<String, dynamic>? _pendingFields;
  IntentResolution? _resolution;
  bool _intentBusy = false;
  String? _intentMessage;

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
    _availability.addListener(_availabilityChanged);

    // Auto-fill data dari akun yang sedang login
    if (currentUser != null) {
      _namaCtrl.text = currentUser!.namaLengkap;
      _teleponCtrl.text = currentUser!.noTelepon;
      _emailCtrl.text = currentUser!.email;
    }
    _tanggal = widget.initialDate;
    _loadAvailability();
    _loadPendingIntent();
  }

  @override
  void didUpdateWidget(covariant DaftarKunjunganScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wisata.id != widget.wisata.id) {
      _tanggal = null;
      _loadAvailability();
    }
  }

  void _availabilityChanged() {
    if (mounted) setState(() {});
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
    _availability.reset();
    if (mounted) {
      setState(() {
        _tanggal = null;
        _jumlahOrang = 1;
        _completed = false;
        _booking = null;
        _pendingFields = null;
        _resolution = null;
        _intentMessage = null;
        _intentBusy = false;
      });
    }
    _loadPendingIntent();
  }

  /// Reads the stored unresolved attempt of the signed-in account (secure storage only).
  Future<void> _loadPendingIntent() async {
    final user = currentUser;
    if (user == null || !user.isLaravel || !widget.wisata.isLaravel) return;
    final generation = AuthSession.instance.sessionGeneration;
    try {
      final pending = await _intent.pending(user.id);
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != AuthSession.instance.sessionGeneration) {
        return;
      }
      setState(() {
        _pendingFields = pending;
        if (pending == null) _resolution = null;
      });
    } catch (_) {
      /* Invalid session: the session listener resets this screen. */
    }
  }

  /// Asks the server for the visit date's availability; the newest request wins.
  void _loadAvailability() {
    final date = _tanggal;
    _availability.reset();
    if (date == null || !widget.wisata.isLaravel) return;
    final guid = widget.wisata.id;
    final visitDate = formatVisitDate(date);
    _availability.load(() async {
      final rows =
          await _repository.availability(guid, visitDate: visitDate);
      return availabilityFor(rows, visitDate);
    });
  }

  bool get _availabilityReady =>
      _tanggal != null &&
      !_availability.loading &&
      _availability.error == null &&
      _availability.data != null;

  bool get _canSubmit =>
      _availabilityReady &&
      canBookAvailability(_availability.data, _jumlahOrang);

  /// Open day with enough remaining capacity, no unresolved earlier attempt, nothing in flight.
  bool get _submitEnabled =>
      _canSubmit &&
      _pendingFields == null &&
      !_isLoading &&
      !_intentBusy &&
      !_completed;

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_sessionChanged);
    _availability.removeListener(_availabilityChanged);
    _availability.dispose();
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
    if (picked != null) {
      setState(() => _tanggal = picked);
      _loadAvailability();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// A booking now exists on the server: show its number and SERVER status. No QR or proof
  /// is generated locally.
  void _onBooked(Booking booking) {
    setState(() {
      _booking = booking;
      _completed = true;
      _pendingFields = null;
      _resolution = null;
      _intentMessage = null;
    });
    BookingEvents.notify();
    _showMessage(
        'Pendaftaran ${booking.bookingNumber}: ${bookingStatusLabel(booking.status)}');
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

    if (_isLoading || _intentBusy || _completed) return;
    final user = currentUser;
    if (user == null || !user.isLaravel || !widget.wisata.isLaravel) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pendaftaran memerlukan akun dan destinasi Laravel.')));
      return;
    }
    // An unresolved earlier attempt blocks a new one until it is checked or abandoned.
    if (_pendingFields != null) {
      _showMessage(
          'Selesaikan dulu pendaftaran sebelumnya: periksa hasilnya atau batalkan percobaan.');
      return;
    }
    // UI gate only; the server re-checks on POST.
    if (!_canSubmit) {
      _showMessage('Kuota untuk tanggal dan jumlah ini belum tersedia.');
      return;
    }
    final generation = AuthSession.instance.sessionGeneration;
    setState(() => _isLoading = true);
    final fields = <String, dynamic>{
      'destination_guid': widget.wisata.id,
      'visit_date': formatVisitDate(_tanggal!),
      'quantity': _jumlahOrang,
      'visitor_name': _namaCtrl.text.trim(),
      'visitor_email': _emailCtrl.text.trim(),
      'visitor_phone': _teleponCtrl.text.trim(),
      'notes': _catatanCtrl.text.trim(),
    };
    try {
      final booking = await _intent.submit(user.id, fields);
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != AuthSession.instance.sessionGeneration) {
        return;
      }
      _onBooked(booking);
    } catch (error) {
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != AuthSession.instance.sessionGeneration) {
        return;
      }
      _showMessage(bookingErrorMessage(error, mutation: true));
      // An unknown outcome leaves the intent behind: surface it. A definitive refusal
      // removed it and the capacity shown may be outdated, so ask the server again.
      await _loadPendingIntent();
      if (_pendingFields == null) _loadAvailability();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _sameSession(User user, int generation) =>
      mounted &&
      currentUser?.id == user.id &&
      generation == AuthSession.instance.sessionGeneration;

  /// "Periksa hasil": asks the server what happened to the earlier attempt.
  Future<void> _checkIntent() async {
    final user = currentUser;
    if (user == null || _intentBusy || _isLoading) return;
    final generation = AuthSession.instance.sessionGeneration;
    setState(() {
      _intentBusy = true;
      _intentMessage = null;
    });
    try {
      final result = await _intent.reconcile(user.id);
      if (!_sameSession(user, generation)) return;
      switch (result) {
        case IntentCompleted(:final booking):
          _onBooked(booking);
        case IntentNotFound(:final replaySafe):
          setState(() {
            _resolution = result;
            _intentMessage = replaySafe
                ? 'Server belum menerima pendaftaran sebelumnya. Anda dapat mengirim ulang dengan data yang sama, atau membatalkan percobaan.'
                : 'Pendaftaran sebelumnya tidak dapat dikirim ulang. Batalkan percobaan tersebut.';
          });
        case IntentUnusable():
          setState(() {
            _resolution = result;
            _intentMessage =
                'Percobaan sebelumnya sudah ditutup di server dan tidak dapat dikirim ulang. Batalkan percobaan untuk membersihkannya.';
          });
        case IntentNone() || IntentAbandoned():
          setState(() {
            _pendingFields = null;
            _resolution = null;
          });
      }
    } catch (error) {
      if (!_sameSession(user, generation)) return;
      setState(() => _intentMessage = bookingErrorMessage(error));
    } finally {
      if (mounted) setState(() => _intentBusy = false);
    }
  }

  /// "Kirim ulang": same key and payload, only after the server called it replay-safe.
  Future<void> _resendIntent() async {
    final user = currentUser;
    final stored = _pendingFields;
    final resolution = _resolution;
    if (user == null ||
        stored == null ||
        _intentBusy ||
        _isLoading ||
        resolution is! IntentNotFound ||
        !resolution.replaySafe) {
      return;
    }
    final generation = AuthSession.instance.sessionGeneration;
    setState(() {
      _intentBusy = true;
      _intentMessage = null;
    });
    try {
      final booking = await _intent.submit(user.id, stored, reconcile: true);
      if (!_sameSession(user, generation)) return;
      _onBooked(booking);
    } catch (error) {
      if (!_sameSession(user, generation)) return;
      // Whatever happened, the earlier answer is stale: check again before another resend.
      setState(() {
        _resolution = null;
        _intentMessage = bookingErrorMessage(error, mutation: true);
      });
      await _loadPendingIntent();
    } finally {
      if (mounted) setState(() => _intentBusy = false);
    }
  }

  /// "Batalkan percobaan": the server refuses the key from now on, then the intent is deleted.
  Future<void> _abandonIntent() async {
    final user = currentUser;
    if (user == null || _intentBusy || _isLoading) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Batalkan percobaan?'),
              content: const Text(
                  'Percobaan pendaftaran sebelumnya tidak akan diproses dan tidak dapat dilanjutkan. Anda dapat mendaftar kembali setelahnya.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Kembali')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Batalkan percobaan')),
              ],
            ));
    if (confirm != true || !mounted) return;
    final generation = AuthSession.instance.sessionGeneration;
    if (currentUser?.id != user.id) return;
    setState(() {
      _intentBusy = true;
      _intentMessage = null;
    });
    try {
      final result = await _intent.abandon(user.id);
      if (!_sameSession(user, generation)) return;
      if (result is IntentCompleted) {
        // The booking had in fact been created: show it instead of discarding it.
        _onBooked(result.booking);
      } else {
        setState(() {
          _pendingFields = null;
          _resolution = null;
          _intentMessage = null;
        });
        _showMessage('Percobaan dibatalkan. Anda dapat mendaftar kembali.');
        _loadAvailability();
      }
    } catch (error) {
      if (!_sameSession(user, generation)) return;
      setState(() => _intentMessage = bookingErrorMessage(error, mutation: true));
    } finally {
      if (mounted) setState(() => _intentBusy = false);
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
                  label: 'Email',
                  hint: 'nama@email.com',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  // Backend mewajibkan email yang valid (StoreBookingRequest).
                  validator: (v) =>
                      (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                          ? 'Email tidak valid'
                          : null,
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
                if (_tanggal != null) ...[
                  const SizedBox(height: 10),
                  _buildAvailability(),
                ],
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

                if (_booking != null) ...[
                  _buildSuccess(_booking!),
                  const SizedBox(height: 20),
                ],
                if (_pendingFields != null && !_completed) ...[
                  _buildIntentPanel(_pendingFields!),
                  const SizedBox(height: 20),
                ],

                // ── Tombol Daftar ───────────────────────────
                GestureDetector(
                  key: const ValueKey('submitButton'),
                  onTap: _submitEnabled ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isLoading || !_submitEnabled
                            ? [
                                _C.teal.withValues(alpha: 0.5),
                                _C.tealDark.withValues(alpha: 0.5)
                              ]
                            : [_C.teal, _C.tealDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isLoading || !_submitEnabled
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

  // ── Ketersediaan (dihitung server) ──────────────────────────
  Widget _infoCard({required Widget child, Color? accent}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent ?? _C.border),
        ),
        child: child,
      );

  Widget _buildAvailability() {
    if (_availability.loading) {
      return _infoCard(
        child: const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Memeriksa ketersediaan...',
              style: TextStyle(color: _C.textMuted, fontSize: 12.5)),
        ]),
      );
    }
    if (_availability.error != null) {
      return _infoCard(
        accent: _C.danger,
        child: Row(children: [
          Expanded(
              child: Text(
                  'Ketersediaan belum dapat diperiksa. ${bookingErrorMessage(_availability.error!)}',
                  style: const TextStyle(color: _C.danger, fontSize: 12.5))),
          TextButton(
              onPressed: _loadAvailability, child: const Text('Coba lagi')),
        ]),
      );
    }
    final availability = _availability.data;
    if (availability == null) {
      return _infoCard(
        accent: _C.danger,
        child: const Text(
            'Kuota untuk tanggal ini belum tersedia. Pilih tanggal lain.',
            style: TextStyle(color: _C.danger, fontSize: 12.5)),
      );
    }
    final ok = canBookAvailability(availability, _jumlahOrang);
    final tooMany = availability.isOpen && _jumlahOrang > availability.remaining;
    return _infoCard(
      accent: ok ? null : _C.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(availabilityStatusLabel(availability.status),
              style: TextStyle(
                  color: ok ? _C.teal : _C.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
              'Kuota total ${availability.capacity} · sisa ${availability.remaining}',
              style: const TextStyle(color: _C.textMuted, fontSize: 12.5)),
          if (tooMany)
            Text(
                'Jumlah pengunjung melebihi sisa kuota (${availability.remaining}).',
                style: const TextStyle(color: _C.danger, fontSize: 12.5)),
        ],
      ),
    );
  }

  // ── Hasil pendaftaran (status dari server) ──────────────────
  Widget _buildSuccess(Booking booking) {
    final note = bookingStatusNote(booking.status);
    return _infoCard(
      accent: _C.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pendaftaran diterima server',
              style: TextStyle(
                  color: _C.text, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Nomor: ${booking.bookingNumber}',
              key: const ValueKey('bookingNumber'),
              style: const TextStyle(color: _C.text, fontSize: 13)),
          Text('Status: ${bookingStatusLabel(booking.status)}',
              key: const ValueKey('bookingStatus'),
              style: const TextStyle(color: _C.text, fontSize: 13)),
          if (note != null)
            Text(note,
                style: const TextStyle(color: _C.textMuted, fontSize: 12.5)),
          const SizedBox(height: 4),
          const Text('Pantau status dan dokumen di menu Riwayat.',
              style: TextStyle(color: _C.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }

  // ── Percobaan sebelumnya belum dipastikan ───────────────────
  Widget _buildIntentPanel(Map<String, dynamic> pending) {
    final resolution = _resolution;
    final canResend = resolution is IntentNotFound && resolution.replaySafe;
    final sameDestination =
        pending['destination_guid'] == widget.wisata.id;
    return _infoCard(
      accent: _C.gold,
      child: Column(
        key: const ValueKey('intentPanel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pendaftaran sebelumnya belum dipastikan',
              style: TextStyle(
                  color: _C.text, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'Hasil pendaftaran untuk ${sameDestination ? widget.wisata.nama : 'destinasi lain'}, tanggal ${pending['visit_date']}, '
              '${pending['quantity']} orang atas nama ${pending['visitor_name']} belum diketahui. '
              'Periksa hasilnya sebelum mendaftar lagi.',
              style: const TextStyle(color: _C.textMuted, fontSize: 12.5)),
          if (_intentMessage != null) ...[
            const SizedBox(height: 6),
            Text(_intentMessage!,
                key: const ValueKey('intentMessage'),
                style: const TextStyle(color: _C.text, fontSize: 12.5)),
          ],
          const SizedBox(height: 8),
          if (_intentBusy)
            const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Wrap(spacing: 8, children: [
              OutlinedButton(
                  key: const ValueKey('intentCheck'),
                  onPressed: _checkIntent,
                  child: const Text('Periksa hasil')),
              if (canResend)
                OutlinedButton(
                    key: const ValueKey('intentResend'),
                    onPressed: _resendIntent,
                    child: const Text('Kirim ulang')),
              OutlinedButton(
                  key: const ValueKey('intentAbandon'),
                  onPressed: _abandonIntent,
                  child: const Text('Batalkan percobaan')),
            ]),
        ],
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
    // Destinasi Laravel: gambar dimuat lewat API (imagePath selalu null).
    if (wisata.isLaravel) {
      return ApiImage(
          imageUrl: wisata.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_) => _placeholder());
    }
    final path = wisata.imagePath;
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
