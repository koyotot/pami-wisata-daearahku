// ============================================================
// lib/screens/daftar_kunjungan_screen.dart
// Form pendaftaran kunjungan wisata — tema biru terang
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import '../../data/booking_errors.dart';
import '../../data/booking_intent.dart';
import '../../data/booking_state.dart';
import '../../data/business_repository.dart';
import '../../services/api_client.dart';
import '../../services/auth_session.dart';
import '../../data/app_data.dart';
import '../../widgets/api_image.dart';
import '../../widgets/availability_calendar.dart';
import '../../widgets/international_phone_field.dart';
import '../../widgets/visit_format.dart';
import 'permintaan_terkirim_screen.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

// ── Palet (sama dengan home_screen.dart) ─────────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);

  // Alias supaya kode lama tetap jalan dengan warna baru
  static const teal = blue;
  static const gold = orange;
}

class DaftarKunjunganScreen extends StatefulWidget {
  final Wisata wisata;

  /// Injected only by tests; production uses the shared API client.
  final BusinessRepository? repository;
  final BookingIntent? intent;

  /// Optional initial selection; availability is always revalidated by Laravel.
  final DateTime? initialDate;
  final int initialQuantity;
  const DaftarKunjunganScreen(
      {super.key,
      required this.wisata,
      this.repository,
      this.intent,
      this.initialDate,
      this.initialQuantity = 1});

  @override
  State<DaftarKunjunganScreen> createState() => _DaftarKunjunganScreenState();
}

class _DaftarKunjunganScreenState extends State<DaftarKunjunganScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _calendarKey = GlobalKey();
  final _guestKey = GlobalKey();
  BuildContext? _summaryContext;
  bool _reviewing = false;
  bool _pendingLoading = true;
  Map<String, String> _fieldErrors = {};

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
  final _availability = RequestState<MonthlyAvailability>();
  late DateTime _month;
  IsoCode _phoneCountry = IsoCode.ID;
  String? _phoneError;
  AuthSession get _session => _repository.api.session;

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
      duration: const Duration(milliseconds: 200),
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

    _session.sessionChanges.addListener(_sessionChanged);
    _availability.addListener(_availabilityChanged);

    // Auto-fill data dari akun yang sedang login
    if (currentUser != null) {
      _namaCtrl.text = currentUser!.namaLengkap;
      _teleponCtrl.text = currentUser!.noTelepon;
      _emailCtrl.text = currentUser!.email;
    }
    _tanggal = widget.initialDate;
    _jumlahOrang = widget.initialQuantity.clamp(1, 1000000);
    final initial =
        widget.initialDate ?? destinationCalendarNow(widget.wisata.timezone);
    _month = DateTime(initial.year, initial.month);
    _detectPhoneCountry();
    _loadAvailability();
    _loadPendingIntent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _animCtrl.value = 1;
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
    final summary = _summaryContext;
    if (summary != null &&
        summary.mounted &&
        ModalRoute.of(summary)?.isCurrent == true)
      Navigator.of(summary).pop(false);
    _summaryContext = null;
    _fieldErrors = {};
    _namaCtrl.clear();
    _teleponCtrl.clear();
    _phoneCountry = IsoCode.ID;
    _phoneError = null;
    _emailCtrl.clear();
    _catatanCtrl.clear();
    final user = _session.deviceSessionReady ? currentUser : null;
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
        _pendingFields = null;
        _resolution = null;
        _intentMessage = null;
        _intentBusy = false;
        _isLoading = false;
        _reviewing = false;
      });
    }
    _detectPhoneCountry();
    _loadAvailability();
    _loadPendingIntent();
  }

  void _detectPhoneCountry() {
    if (_teleponCtrl.text.trim().startsWith('+')) {
      final phone = parseBookingPhone(_teleponCtrl.text, _phoneCountry);
      if (phone != null) _phoneCountry = phone.isoCode;
    }
  }

  /// Reads the stored unresolved attempt of the signed-in account (secure storage only).
  Future<void> _loadPendingIntent() async {
    if (mounted) setState(() => _pendingLoading = true);
    final user = currentUser;
    if (user == null || !user.isLaravel || !widget.wisata.isLaravel) {
      if (mounted) setState(() => _pendingLoading = false);
      return;
    }
    final generation = _session.sessionGeneration;
    try {
      final pending = await _intent.pending(user.id);
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != _session.sessionGeneration) {
        return;
      }
      setState(() {
        _pendingLoading = false;
        _pendingFields = pending;
        if (pending == null) _resolution = null;
      });
    } catch (_) {
      if (_sameSession(user, generation)) {
        setState(() => _intentMessage =
            'Percobaan sebelumnya belum dapat diperiksa. Muat ulang sebelum melanjutkan.');
      }
    }
  }

  /// Reset before every load so a previous month/quantity cannot enable submit.
  void _loadAvailability() {
    _availability.reset();
    if (!widget.wisata.isLaravel) return;
    final guid = widget.wisata.id;
    final month =
        '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';
    final quantity = _jumlahOrang;
    _availability.load(() async {
      final response =
          await _repository.monthlyAvailability(guid, month, quantity);
      if (response.destinationGuid != guid ||
          response.month != month ||
          response.requestedQuantity != quantity) {
        throw const ApiException(
            'Respons ketersediaan tidak sesuai permintaan.');
      }
      return response;
    });
  }

  AvailabilityDay? get _selectedAvailability => _tanggal == null
      ? null
      : _availability.data?.onDate(formatVisitDate(_tanggal!));

  bool get _canSubmit =>
      widget.wisata.isActive &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      !_availability.loading &&
      _availability.error == null &&
      _availability.data?.requestedQuantity == _jumlahOrang &&
      _selectedAvailability?.bookable == true;

  void _changeQuantity(int quantity) {
    setState(() {
      _jumlahOrang = quantity;
      _fieldErrors.remove('quantity');
    });
    _loadAvailability();
  }

  /// Open day with enough remaining capacity, no unresolved earlier attempt, nothing in flight.
  bool get _submitEnabled =>
      _canSubmit &&
      _pendingFields == null &&
      !_pendingLoading &&
      !_reviewing &&
      !_isLoading &&
      !_intentBusy &&
      !_completed;

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_sessionChanged);
    _availability.removeListener(_availabilityChanged);
    _availability.dispose();
    _animCtrl.dispose();
    _namaCtrl.dispose();
    _teleponCtrl.dispose();
    _emailCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// All server-confirmed paths converge here; replacement removes the completed form.
  void _onBooked(Booking booking) {
    if (!mounted || _completed) return;
    setState(() {
      _completed = true;
      _pendingFields = null;
      _resolution = null;
      _intentMessage = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final session = _session;
    final generation = session.sessionGeneration;
    BookingEvents.notify();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => PermintaanTerkirimScreen(
          booking: booking, session: session, sessionGeneration: generation),
    ));
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

    if (_isLoading || _intentBusy || _completed || _pendingLoading) return;
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
    final generation = _session.sessionGeneration;
    setState(() {
      _isLoading = true;
      _phoneError = null;
      _fieldErrors = {};
    });
    final fields = <String, dynamic>{
      'destination_guid': widget.wisata.id,
      'visit_date': formatVisitDate(_tanggal!),
      'quantity': _jumlahOrang,
      'visitor_name': _namaCtrl.text.trim(),
      'visitor_email': _emailCtrl.text.trim(),
      'visitor_phone':
          parseBookingPhone(_teleponCtrl.text, _phoneCountry)!.international,
      'notes': _catatanCtrl.text.trim(),
    };
    try {
      final booking = await _intent.submit(user.id, fields);
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != _session.sessionGeneration) {
        return;
      }
      _onBooked(booking);
    } catch (error) {
      if (!mounted ||
          currentUser?.id != user.id ||
          generation != _session.sessionGeneration) {
        return;
      }
      if (error is ApiException && error.status == 422) {
        setState(() {
          _fieldErrors = error.fieldErrors;
          _phoneError = error.fieldErrors['visitor_phone'];
        });
        final target = error.fieldErrors.keys.any((key) => [
                  'visitor_name',
                  'visitor_email',
                  'visitor_phone'
                ].contains(key))
            ? _guestKey
            : _calendarKey;
        _scrollTo(target);
      }
      _showMessage(bookingErrorMessage(error, mutation: true));
      // An unknown outcome leaves the intent behind: surface it. A definitive refusal
      // removed it and the capacity shown may be outdated, so ask the server again.
      await _loadPendingIntent();
      if (!_sameSession(user, generation)) return;
      await _resolveConflict(error, user, generation);
      if (_sameSession(user, generation)) _loadAvailability();
    } finally {
      if (_sameSession(user, generation)) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveConflict(Object error, User user, int generation) async {
    if (error is! ApiException || error.status != 409) return;
    setState(() => _tanggal = null);
    if (_pendingFields == null) return;
    try {
      final result = await _intent.reconcile(user.id);
      if (!_sameSession(user, generation)) return;
      if (result is IntentCompleted) {
        _onBooked(result.booking);
      } else {
        setState(() => _resolution = result);
      }
    } catch (_) {
      // Keep the stored intent available for explicit reconciliation.
    }
  }

  bool _sameSession(User user, int generation) =>
      mounted &&
      currentUser?.id == user.id &&
      generation == _session.sessionGeneration;

  /// "Periksa hasil": asks the server what happened to the earlier attempt.
  Future<void> _checkIntent() async {
    final user = currentUser;
    if (user == null || _intentBusy || _isLoading) return;
    final generation = _session.sessionGeneration;
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
      if (_sameSession(user, generation)) setState(() => _intentBusy = false);
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
    final generation = _session.sessionGeneration;
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
      if (!_sameSession(user, generation)) return;
      await _resolveConflict(error, user, generation);
      if (_sameSession(user, generation)) _loadAvailability();
    } finally {
      if (_sameSession(user, generation)) setState(() => _intentBusy = false);
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
    final generation = _session.sessionGeneration;
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
      setState(
          () => _intentMessage = bookingErrorMessage(error, mutation: true));
    } finally {
      if (_sameSession(user, generation)) setState(() => _intentBusy = false);
    }
  }

  String get _currency => widget.wisata.hargaTiket.split(' ').first;
  String get _unitPrice => visitMoney(widget.wisata.ticketPrice, _currency);
  bool get _busy => _isLoading || _intentBusy || _completed;

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null)
      Scrollable.ensureVisible(target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          alignment: .08);
  }

  Future<void> _reviewRegistration() async {
    if (!_submitEnabled) return;
    if (!_formKey.currentState!.validate()) {
      _scrollTo(_guestKey);
      return;
    }
    final user = currentUser;
    if (user == null || !user.isLaravel) return;
    final generation = _session.sessionGeneration;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _reviewing = true);
    final phone = parseBookingPhone(_teleponCtrl.text, _phoneCountry)!;
    final date = _tanggal!;
    final quantity = _jumlahOrang;
    final name = _namaCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final notes = _catatanCtrl.text.trim();
    var answered = false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        _summaryContext = context;
        return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .88),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Ringkasan Pendaftaran',
                            style: TextStyle(
                                color: _C.navy,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text(
                            'Periksa kembali kunjungan Anda sebelum mengirim permintaan.',
                            style: TextStyle(color: _C.textMuted, height: 1.5)),
                        const SizedBox(height: 20),
                        _summaryRow('Destinasi', widget.wisata.nama),
                        _summaryRow('Tanggal kunjungan', visitDateLabel(date)),
                        _summaryRow('Jumlah pengunjung', '$quantity orang'),
                        const Divider(height: 28, color: _C.border),
                        _summaryRow('Nama lengkap', name),
                        _summaryRow('Nomor telepon', phone.international),
                        _summaryRow('Email', email),
                        if (notes.isNotEmpty) _summaryRow('Catatan', notes),
                        const Divider(height: 28, color: _C.border),
                        _summaryRow('Harga / orang', _unitPrice),
                        _summaryRow(
                            'Estimasi Total',
                            visitMoney(widget.wisata.ticketPrice * quantity,
                                _currency)),
                        const SizedBox(height: 8),
                        const Text(
                            'Harga dan ketersediaan akhir mengikuti konfirmasi layanan. Permintaan ini belum berarti persetujuan pengelola atau pembayaran berhasil.',
                            style: TextStyle(
                                color: _C.textMuted,
                                fontSize: 12,
                                height: 1.6)),
                        const SizedBox(height: 24),
                        FilledButton(
                            key: const ValueKey('confirmBookingButton'),
                            onPressed: () {
                              if (answered ||
                                  ModalRoute.of(context)?.isCurrent != true)
                                return;
                              answered = true;
                              Navigator.pop(context, true);
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: _C.blue,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            child: const Text('Kirim Permintaan Kunjungan',
                                textAlign: TextAlign.center)),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: () {
                              if (answered ||
                                  ModalRoute.of(context)?.isCurrent != true)
                                return;
                              answered = true;
                              Navigator.pop(context, false);
                            },
                            child: const Text('Ubah Data')),
                      ])),
            ));
      },
    );
    _summaryContext = null;
    if (!_sameSession(user, generation)) return;
    setState(() => _reviewing = false);
    if (confirmed == true && _submitEnabled) await _submit();
  }

  Widget _summaryRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _C.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: _C.navy, fontWeight: FontWeight.w700, height: 1.5))
      ]));

  @override
  Widget build(BuildContext context) {
    final canChooseDate = !_busy && !_reviewing && _pendingFields == null;
    final canGuide = canChooseDate &&
        !_pendingLoading &&
        widget.wisata.isActive &&
        _session.deviceSessionReady;
    final remaining = _selectedAvailability?.remaining;
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _C.navy,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark),
          leading: IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(PhosphorIconsRegular.arrowLeft)),
          title: const Text('Daftar Kunjungan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          centerTitle: true),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _C.border))),
              child: SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                runSpacing: 8,
                                spacing: 16,
                                children: [
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Estimasi Total',
                                            style: TextStyle(
                                                color: _C.textMuted,
                                                fontSize: 12)),
                                        const SizedBox(height: 3),
                                        Text(
                                            visitMoney(
                                                widget.wisata.ticketPrice *
                                                    _jumlahOrang,
                                                _currency),
                                            style: const TextStyle(
                                                color: _C.navy,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800))
                                      ]),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Tanggal kunjungan',
                                            style: TextStyle(
                                                color: _C.textMuted,
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                            _tanggal == null
                                                ? 'Belum dipilih'
                                                : visitDateLabel(_tanggal!),
                                            style: const TextStyle(
                                                color: _C.navy,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600))
                                      ]),
                                ]),
                            const SizedBox(height: 12),
                            FilledButton(
                                key: const ValueKey('submitButton'),
                                onPressed: _submitEnabled
                                    ? _reviewRegistration
                                    : canGuide && _tanggal == null
                                        ? () => _scrollTo(_calendarKey)
                                        : null,
                                style: FilledButton.styleFrom(
                                    backgroundColor: _C.blue,
                                    disabledBackgroundColor:
                                        const Color(0xFFB5C7DD),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(
                                        _pendingFields != null
                                            ? 'Selesaikan Percobaan Sebelumnya'
                                            : _tanggal == null
                                                ? 'Pilih Tanggal Kunjungan'
                                                : 'Tinjau Pendaftaran',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800))),
                          ]))),
            ),
      body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
              position: _slideAnim,
              child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _DestinasiCard(
                          wisata: widget.wisata, repository: _repository),
                      if (!widget.wisata.isActive)
                        const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                                'Destinasi ini sedang tidak menerima kunjungan.',
                                style: TextStyle(color: _C.danger))),
                      if (_pendingLoading)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _infoCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(_intentMessage ??
                                      'Memeriksa percobaan pendaftaran sebelumnya...'),
                                  if (_intentMessage != null)
                                    TextButton(
                                        onPressed: _loadPendingIntent,
                                        child: const Text('Coba lagi'))
                                ]))),
                      if (_pendingFields != null && !_completed) ...[
                        const SizedBox(height: 16),
                        _buildIntentPanel(_pendingFields!)
                      ],
                      const SizedBox(height: 28),
                      KeyedSubtree(
                          key: _guestKey,
                          child: _sectionLabel('Data Pengunjung')),
                      const SizedBox(height: 6),
                      const Text(
                          'Kontak untuk kunjungan ini. Perubahan tidak mengganti profil Anda.',
                          style: TextStyle(
                              color: _C.textMuted, fontSize: 12, height: 1.6)),
                      const SizedBox(height: 16),
                      _DarkField(
                          controller: _namaCtrl,
                          label: 'Nama Lengkap',
                          hint: 'Masukkan nama lengkap',
                          icon: PhosphorIconsRegular.userCircle,
                          enabled: !_busy,
                          error: _fieldErrors['visitor_name'],
                          onChanged: () => setState(
                              () => _fieldErrors.remove('visitor_name')),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nama wajib diisi'
                              : v.trim().length > 255
                                  ? 'Nama maksimal 255 karakter'
                                  : null),
                      const SizedBox(height: 14),
                      InternationalPhoneField(
                          controller: _teleponCtrl,
                          country: _phoneCountry,
                          enabled: !_busy,
                          error: _phoneError,
                          onCountryChanged: (country) => setState(() {
                                _phoneCountry = country;
                                _phoneError = null;
                                if (_teleponCtrl.text.trim().startsWith('+')) {
                                  final phone = parseBookingPhone(
                                      _teleponCtrl.text, country);
                                  if (phone != null)
                                    _teleponCtrl.text = phone.nsn;
                                }
                                final phone = parseBookingPhone(
                                    _teleponCtrl.text, country);
                                if (phone != null)
                                  _teleponCtrl.text = phone.formatNsn(
                                      format: NsnFormat.international);
                              }),
                          onChanged: () => setState(() {
                                _phoneError = null;
                                _detectPhoneCountry();
                              })),
                      const SizedBox(height: 14),
                      _DarkField(
                          controller: _emailCtrl,
                          label: 'Email',
                          hint: 'nama@email.com',
                          icon: PhosphorIconsRegular.envelope,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_busy,
                          error: _fieldErrors['visitor_email'],
                          onChanged: () => setState(
                              () => _fieldErrors.remove('visitor_email')),
                          validator: (v) => v == null ||
                                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(v.trim())
                              ? 'Email tidak valid'
                              : v.trim().length > 255
                                  ? 'Email maksimal 255 karakter'
                                  : null),
                      const SizedBox(height: 30),
                      KeyedSubtree(
                          key: _calendarKey,
                          child: _sectionLabel('Tanggal Kunjungan')),
                      const SizedBox(height: 6),
                      const Text(
                          'Pilih tanggal dan lihat sisa tiket yang tersedia.',
                          style: TextStyle(
                              color: _C.textMuted, fontSize: 12, height: 1.6)),
                      const SizedBox(height: 14),
                      _infoCard(
                          child: AvailabilityCalendar(
                              month: _month,
                              availability: _availability.data,
                              selectedDate: _tanggal == null
                                  ? null
                                  : formatVisitDate(_tanggal!),
                              enabled: canChooseDate &&
                                  !_availability.loading &&
                                  _availability.error == null,
                              navigationEnabled: canChooseDate,
                              earliestMonth: destinationCalendarNow(
                                  _availability.data?.timezone ??
                                      widget.wisata.timezone),
                              onMonthChanged: (month) {
                                setState(() {
                                  _month = month;
                                  _tanggal = null;
                                  _fieldErrors.remove('visit_date');
                                });
                                _loadAvailability();
                              },
                              onSelected: (day) => setState(() {
                                    _tanggal = DateTime.parse(day.date);
                                    _fieldErrors.remove('visit_date');
                                  }))),
                      const SizedBox(height: 12),
                      _buildAvailability(),
                      if (_fieldErrors['visit_date'] != null)
                        _inlineError(_fieldErrors['visit_date']!),
                      const SizedBox(height: 26),
                      _sectionLabel('Jumlah Pengunjung'),
                      const SizedBox(height: 14),
                      _infoCard(
                          child: LayoutBuilder(builder: (context, constraints) {
                        final label = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_jumlahOrang orang',
                                  style: const TextStyle(
                                      color: _C.navy,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('$_unitPrice / orang',
                                  style: const TextStyle(
                                      color: _C.textMuted, fontSize: 12))
                            ]);
                        final counter =
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          _CounterBtn(
                              icon: PhosphorIconsRegular.minus,
                              onTap: !_busy && _jumlahOrang > 1
                                  ? () => _changeQuantity(_jumlahOrang - 1)
                                  : null),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('$_jumlahOrang',
                                  style: const TextStyle(
                                      color: _C.navy,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          _CounterBtn(
                              icon: PhosphorIconsRegular.plus,
                              onTap: !_busy &&
                                      _jumlahOrang < 1000000 &&
                                      (remaining == null ||
                                          _jumlahOrang < remaining)
                                  ? () => _changeQuantity(_jumlahOrang + 1)
                                  : null),
                        ]);
                        if (constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(14) > 19)
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label,
                                const SizedBox(height: 14),
                                counter
                              ]);
                        return Row(children: [
                          Expanded(child: label),
                          const SizedBox(width: 8),
                          counter
                        ]);
                      })),
                      if (_fieldErrors['quantity'] != null)
                        _inlineError(_fieldErrors['quantity']!),
                      const SizedBox(height: 26),
                      _sectionLabel('Catatan Tambahan'),
                      const SizedBox(height: 12),
                      _DarkField(
                          controller: _catatanCtrl,
                          label: 'Catatan (opsional)',
                          hint:
                              'Kebutuhan aksesibilitas atau informasi untuk pengelola',
                          icon: PhosphorIconsRegular.note,
                          maxLines: 3,
                          enabled: !_busy,
                          error: _fieldErrors['notes'],
                          onChanged: () =>
                              setState(() => _fieldErrors.remove('notes')),
                          validator: (v) => (v?.length ?? 0) > 5000
                              ? 'Catatan maksimal 5000 karakter'
                              : null),
                      const SizedBox(height: 16),
                      const Text(
                          'Anda akan meninjau ringkasan sebelum permintaan dikirim.',
                          style: TextStyle(
                              color: _C.textMuted, fontSize: 12, height: 1.6)),
                    ],
                  )))),
    );
  }

  Widget _inlineError(String message) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message,
          style: const TextStyle(color: _C.danger, fontSize: 12)));

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
    final availability = _selectedAvailability;
    if (availability == null) {
      return _infoCard(
        child: Text(
            _tanggal == null
                ? 'Pilih tanggal untuk melihat ketersediaan tiket.'
                : 'Ketersediaan tanggal terpilih belum tersedia. Pilih tanggal lain.',
            style: const TextStyle(color: _C.textMuted, fontSize: 12.5)),
      );
    }
    final ok = availability.bookable;
    final tooMany = availability.status == 'insufficient_quantity';
    return _infoCard(
      accent: ok ? null : _C.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              ok
                  ? '${availabilityLevelLabel(availability.level)} - ${availability.remaining ?? '\u2014'} tiket tersisa'
                  : availabilityStatusLabel(availability.status),
              style: TextStyle(
                  color: ok ? _C.teal : _C.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
              'Kuota total ${availability.capacity ?? '—'} · sisa ${availability.remaining ?? '—'}',
              style: const TextStyle(color: _C.textMuted, fontSize: 12.5)),
          if (tooMany)
            Text(
                'Jumlah pengunjung melebihi sisa kuota (${availability.remaining ?? '—'}).',
                style: const TextStyle(color: _C.danger, fontSize: 12.5)),
        ],
      ),
    );
  }

  // Unresolved earlier attempt; actions always use the original stored intent.
  Widget _buildIntentPanel(Map<String, dynamic> pending) {
    final resolution = _resolution;
    final canResend = resolution is IntentNotFound && resolution.replaySafe;
    final sameDestination = pending['destination_guid'] == widget.wisata.id;
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

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          color: _C.navy, fontWeight: FontWeight.w800, fontSize: 17));
}

// ── Destinasi Info Card ────────────────────────────────────
class _DestinasiCard extends StatelessWidget {
  final Wisata wisata;
  final BusinessRepository repository;
  const _DestinasiCard({required this.wisata, required this.repository});

  Widget _buildImage() {
    // Destinasi Laravel: gambar dimuat lewat API (imagePath selalu null).
    if (wisata.isLaravel) {
      return ApiImage(
          imageUrl: wisata.images.isEmpty
              ? wisata.imageUrl
              : wisata.images.first.url('thumbnail'),
          repository: repository,
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
          child: Icon(PhosphorIconsRegular.mountains,
              color: Color(0xFF1976D2), size: 28),
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
                  wisata.lokasi,
                  style:
                      const TextStyle(color: Color(0xFF728099), fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    wisata.kategori,
                    wisata.jamBuka,
                    '${visitMoney(wisata.ticketPrice, wisata.hargaTiket.split(' ').first)} / orang'
                  ].where((value) => value.isNotEmpty).join(' - '),
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
  final String? Function(String?)? validator;
  final int maxLines;
  final String? error;
  final VoidCallback? onChanged;
  final bool enabled;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.error,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      onChanged: (_) => onChanged?.call(),
      scrollPadding: const EdgeInsets.all(24),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Color(0xFF102D59), fontSize: 14),
      decoration: InputDecoration(
        errorText: error,
        errorMaxLines: 3,
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
    return Semantics(
      button: true,
      enabled: active,
      label: icon == PhosphorIconsRegular.plus
          ? 'Tambah pengunjung'
          : 'Kurangi pengunjung',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
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
      ),
    );
  }
}
