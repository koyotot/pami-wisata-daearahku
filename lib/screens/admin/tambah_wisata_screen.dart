// ============================================================
// lib/screens/tambah_wisata_screen.dart
// Tema: biru terang — sama dengan home, login, dan dashboard admin
// Dependency: image_picker (tambah ke pubspec.yaml)
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/admin_state.dart';
import '../../data/facility_state.dart';
import '../../data/app_data.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../widgets/operations_chrome.dart';
import '../../widgets/scroll_aware_status_bar.dart';
import '../../theme/app_colors.dart';
import '../../data/gallery_draft.dart';
import '../../widgets/admin_destination_gallery_editor.dart';
import '../../data/favorite_state.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../widgets/destination_location_map_preview.dart';
import '../../widgets/select_sheet.dart';
import 'destination_location_picker_screen.dart';

// ── Palet (sama dengan home_screen.dart) ─────────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const surface = Colors.white;
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const tint = Color(0xFFE6F0FC);
  static const field = Color(0xFFF8FAFD);
  static const danger = Color(0xFFE5484D);

  // Alias supaya kode lama tetap jalan dengan warna baru
  static const teal = blue;
  static const tealDark = blueDeep;
  static const gold = orange;
}

class TambahWisataScreen extends StatefulWidget {
  final Wisata? wisataEdit;
  final BusinessRepository? repository;
  final AuthSession? session;
  final bool initialGallery;
  const TambahWisataScreen(
      {super.key,
      this.wisataEdit,
      this.repository,
      this.session,
      this.initialGallery = false});

  @override
  State<TambahWisataScreen> createState() => _TambahWisataScreenState();
}

class _TambahWisataScreenState extends State<TambahWisataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _galleryKey = GlobalKey();
  late TextEditingController namaCtrl, lokasiCtrl, deskCtrl, hargaCtrl;
  final _openCtrl = TextEditingController(),
      _closeCtrl = TextEditingController();
  double _rating = 0;
  int _ratingCount = 0;

  // Opening hours are stored as free text ("08.00 - 17.00"). Existing values
  // are parsed into the two pickers; an unparseable legacy value is kept
  // as-is until the admin picks new times.
  TimeOfDay? _openTime, _closeTime;
  String _rawHours = '';
  bool _hoursEdited = false;
  final List<GalleryDraftItem> _gallery = [];
  int _galleryVersion = 0;
  String? _operationKey, _operationFingerprint;
  bool _failedSave = false;
  bool _galleryLoading = false;
  bool _galleryReady = false;
  bool _picking = false;
  bool _dirty = false;
  bool _isSaving = false;
  LatLng? _locationPoint;
  bool _locationEdited = false, _hydratingLocation = false;
  Map<String, String> _locationErrors = {};

  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<Category> _categories;
  String? _categoryGuid;
  String? _savedDestinationGuid;
  late final DestinationFacilitiesState _facilities;
  late String _timezone;
  late final int _sessionGeneration;

  Future<void> _load() => _categories.load();

  Set<String>? _facilityDraft;

  /// The admin shell re-validates the session (`me()`) every time the app
  /// resumes, e.g. after the photo picker closes. That bumps `sessionChanges`,
  /// which empties the category and facility lists even though the same
  /// session is still valid, so the chosen category vanished and the select
  /// could not be opened. Same session → reload the lists and keep the draft.
  void _onSessionRevalidated() {
    if (!mounted ||
        !_session.isCurrentGeneration(_sessionGeneration) ||
        !canAccessAdmin(_session.role)) {
      return;
    }
    // Runs before the lists clear themselves, so the draft can still be read.
    _facilityDraft = _facilities.ready && _facilities.changed
        ? Set.of(_facilities.selected)
        : null;
    Future.microtask(_reloadAfterRevalidation);
  }

  Future<void> _reloadAfterRevalidation() async {
    final draft = _facilityDraft;
    _facilityDraft = null;
    if (!mounted ||
        !_session.isCurrentGeneration(_sessionGeneration) ||
        !canAccessAdmin(_session.role)) {
      return;
    }
    await Future.wait([_load(), _facilities.load(_savedDestinationGuid)]);
    if (!mounted || draft == null || !_facilities.ready) return;
    for (final facility in _facilities.items) {
      final wanted = draft.contains(facility.guid);
      if (_facilities.selected.contains(facility.guid) != wanted) {
        _facilities.toggle(facility.guid, wanted);
      }
    }
  }

  void _onCategories() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final w = widget.wisataEdit;
    namaCtrl = TextEditingController(text: w?.nama ?? '');
    lokasiCtrl = TextEditingController(text: w?.lokasi ?? '');
    if (w?.latitude != null && w?.longitude != null) {
      _locationPoint = LatLng(w!.latitude!, w.longitude!);
    }
    deskCtrl = TextEditingController(text: w?.deskripsi ?? '');
    hargaCtrl = TextEditingController(
        text:
            w == null ? '' : _RupiahInputFormatter.format('${w.ticketPrice}'));
    _rawHours = (w?.jamBuka ?? '').trim();
    final times = RegExp(r'(\d{1,2})[.:](\d{2})')
        .allMatches(_rawHours)
        .map((m) => (int.parse(m[1]!), int.parse(m[2]!)))
        .where((t) => t.$1 < 24 && t.$2 < 60)
        .map((t) => TimeOfDay(hour: t.$1, minute: t.$2))
        .toList();
    if (times.isNotEmpty) _openTime = times.first;
    if (times.length > 1) _closeTime = times[1];
    _openCtrl.text = _formatTime(_openTime);
    _closeCtrl.text = _formatTime(_closeTime);
    for (final controller in [namaCtrl, lokasiCtrl, deskCtrl, hargaCtrl]) {
      controller.addListener(() {
        if (_hydratingLocation) return;
        if (controller == lokasiCtrl) {
          _locationEdited = true;
          _locationErrors = {};
        }
        if (mounted) setState(() => _dirty = true);
      });
    }
    _ratingCount = w?.ratingCount ?? 0;
    _rating = _ratingCount > 0 ? w!.rating : 0;
    _categoryGuid =
        (w?.categoryGuid.isNotEmpty ?? false) ? w!.categoryGuid : null;
    _timezone =
        (w?.timezone.isNotEmpty ?? false) ? w!.timezone : kAdminTimezones.first;
    _sessionGeneration = _session.sessionGeneration;
    // Registered before the lists below so it runs first (see _onSessionRevalidated).
    _session.sessionChanges.addListener(_onSessionRevalidated);
    _categories = PagedListController<Category>(
      session: _session,
      keyOf: (category) => category.guid,
      fetchPage: (page, _) => _repository.categories(query: {'page': '$page'}),
    )..addListener(_onCategories);
    _facilities = DestinationFacilitiesState(_repository, session: _session)
      ..addListener(_onCategories);
    _savedDestinationGuid = w?.id;
    _galleryVersion = w?.galleryVersion ?? 0;
    _gallery.addAll((w?.images ?? [])
        .where((e) => !e.guid.startsWith('legacy-'))
        .map(GalleryDraftItem.existing));
    _galleryReady = w == null;
    if (w != null) _loadGallery();
    if (widget.initialGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final galleryContext = _galleryKey.currentContext;
        if (mounted && galleryContext != null) {
          Scrollable.ensureVisible(galleryContext);
        }
      });
    }
    if (canAccessAdmin(_session.role)) {
      _load();
      _facilities.load(w?.id);
    }
  }

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_onSessionRevalidated);
    _facilities
      ..removeListener(_onCategories)
      ..dispose();
    _categories
      ..removeListener(_onCategories)
      ..dispose();
    namaCtrl.dispose();
    lokasiCtrl.dispose();
    deskCtrl.dispose();
    hargaCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    super.dispose();
  }

  // ── Pilih gambar ──────────────────────────────────────────
  bool get _canSave =>
      !_isSaving &&
      !_picking &&
      !_galleryLoading &&
      _galleryReady &&
      _gallery.isNotEmpty &&
      _gallery.length <= 10 &&
      _categoryGuid != null &&
      (widget.wisataEdit != null || _locationPoint != null) &&
      lokasiCtrl.text.trim().length <= 255 &&
      [namaCtrl, lokasiCtrl, deskCtrl].every((c) => c.text.trim().isNotEmpty) &&
      _openingHours.isNotEmpty &&
      (_price ?? -1) >= 0;

  Future<void> _reloadGallery() async {
    if (await _confirmDiscard() && mounted) await _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() => _galleryLoading = true);
    try {
      final value = await _repository.adminDestination(_savedDestinationGuid!);
      if (!mounted || !_session.isCurrentGeneration(_sessionGeneration)) return;
      setState(() {
        if (!_galleryReady && !_locationEdited) {
          _hydratingLocation = true;
          lokasiCtrl.text = value.location;
          _locationPoint = value.hasCoordinates
              ? LatLng(value.latitude!, value.longitude!)
              : null;
          _hydratingLocation = false;
        }
        _galleryReady = true;
        _galleryVersion = value.galleryVersion;
        _gallery
          ..clear()
          ..addAll(value.images
              .where((e) => !e.guid.startsWith('legacy-'))
              .map(GalleryDraftItem.existing));
        _operationKey = null;
        _operationFingerprint = null;
      });
    } catch (e) {
      if (mounted) _snack('Galeri belum dimuat: ${adminErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  Future<void> _pickImages() async {
    if (_picking || _isSaving || _galleryLoading) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (!mounted) return;
      if (_gallery.length + picked.length > 10) {
        _snack('Maksimal 10 foto. Pilih kembali sesuai slot yang tersisa.');
        return;
      }
      final additions = <GalleryDraftItem>[];
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        final problem = validateDestinationImage(bytes);
        final extension = file.name.toLowerCase().split('.').last;
        if (problem != null ||
            !['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
          if (mounted) _snack(problem ?? 'Pilih JPEG, PNG, atau WebP.');
          return;
        }
        additions.add(GalleryDraftItem.upload(bytes, file.name));
      }
      if (!mounted) return;
      setState(() {
        _gallery.addAll(additions);
        _dirty = true;
      });
    } catch (_) {
      if (mounted) {
        _snack(
            'Foto belum dapat dibaca. Periksa izin foto lalu coba lagi. Draft tetap ada.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_isSaving) return false;
    if (!_dirty) return true;
    return showConfirmSheet(context,
        title: 'Buang perubahan?',
        message: 'Draft foto dan form belum disimpan.',
        confirmLabel: 'Buang',
        cancelLabel: 'Lanjut edit');
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
              error
                  ? PhosphorIconsFill.warningCircle
                  : PhosphorIconsFill.checkCircle,
              color: Colors.white,
              size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: error ? _C.danger : _C.tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<Destination?> _reconcileGallery() async {
    if (_savedDestinationGuid != null) {
      final remote = await _repository.adminDestination(_savedDestinationGuid!);
      return remote.json['last_gallery_operation_key'] == _operationKey
          ? remote
          : null;
    }
    var page = 1;
    while (true) {
      final result = await _repository.adminDestinations(query: {
        'search': namaCtrl.text.trim(),
        'page': '$page',
        'per_page': '100',
        'status': 'all'
      });
      for (final remote in result.items) {
        if (remote.json['last_gallery_operation_key'] == _operationKey) {
          return remote;
        }
      }
      if (result.links?['next'] == null) return null;
      page++;
    }
  }

  Future<void> _simpan() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final edit = widget.wisataEdit;
    if (edit == null && _locationPoint == null) {
      setState(() =>
          _locationErrors = {'latitude': 'Pilih titik lokasi terlebih dahulu'});
      return;
    }
    if (!_session.isCurrentGeneration(_sessionGeneration) ||
        !canAccessAdmin(_session.role)) {
      _snack('Sesi telah berakhir. Silakan masuk kembali.');
      return;
    }
    if (_categoryGuid == null) {
      _snack('Pilih kategori terlebih dahulu.');
      return;
    }
    final price = _price;
    if (price == null || price < 0) {
      _snack('Harga harus berupa bilangan bulat nonnegatif.');
      return;
    }
    if (!_galleryReady ||
        _galleryLoading ||
        _gallery.isEmpty ||
        _gallery.length > 10) {
      _snack('Galeri wajib berisi 1-10 foto dan selesai dimuat.');
      return;
    }
    final fields = <String, dynamic>{
      'destination_category_guid': _categoryGuid,
      'name': namaCtrl.text.trim(),
      'location': lokasiCtrl.text.trim(),
      if (_locationPoint != null) 'latitude': _locationPoint!.latitude,
      if (_locationPoint != null) 'longitude': _locationPoint!.longitude,
      'description': deskCtrl.text.trim(),
      'ticket_price': price,
      'opening_hours': _openingHours,
      'timezone': _timezone,
    };
    final manifest = _gallery.map((e) => e.manifest).toList();
    final fingerprint = '$fields|$manifest|$_galleryVersion';
    if (_operationFingerprint != fingerprint) {
      _operationKey = galleryUuid();
      _operationFingerprint = fingerprint;
    }
    final creating = _savedDestinationGuid == null;
    final uploads = <UploadFile>[
      for (final item in _gallery)
        if (item.bytes != null)
          UploadFile(creating ? 'images[]' : 'new_images[${item.key}]',
              item.bytes!, item.filename),
    ];
    setState(() {
      _isSaving = true;
      _failedSave = false;
    });
    try {
      Destination saved;
      try {
        saved = await _repository.saveDestinationGallery(
            guid: _savedDestinationGuid,
            fields: fields,
            galleryVersion: _galleryVersion,
            manifest: manifest,
            files: uploads,
            idempotencyKey: _operationKey!);
      } on ApiException catch (error) {
        if (!error.outcomeUnknown) rethrow;
        Destination? remote;
        try {
          remote = await _reconcileGallery();
        } catch (_) {/* Retry keeps the same operation key. */}
        if (remote == null) rethrow;
        saved = remote;
      }
      if (!mounted || !_session.isCurrentGeneration(_sessionGeneration)) return;
      _savedDestinationGuid = saved.guid;
      _galleryVersion = saved.galleryVersion;
      _gallery
        ..clear()
        ..addAll(saved.images.map(GalleryDraftItem.existing));
      _operationKey = null;
      _operationFingerprint = null;
      _dirty = false;
      FavoriteState.instance.load();
      if (_facilities.changed) {
        final failure = await _facilities.save(_savedDestinationGuid!);
        if (!mounted || !_session.isCurrentGeneration(_sessionGeneration)) {
          return;
        }
        if (failure != null) {
          _snack(
              'Destinasi sudah tersimpan. Fasilitas: $failure Tidak perlu menambah destinasi lagi.');
          return;
        }
      }
      if (!mounted || !_session.isCurrentGeneration(_sessionGeneration)) return;
      _snack(
          edit != null
              ? 'Data wisata berhasil diubah!'
              : 'Wisata baru berhasil ditambahkan!',
          error: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted || !_session.isCurrentGeneration(_sessionGeneration)) return;
      setState(() {
        _failedSave = true;
        _isSaving = false;
        if (e is ApiException && e.status == 422) {
          _locationErrors = Map.fromEntries(e.fieldErrors.entries.where(
              (entry) =>
                  ['location', 'latitude', 'longitude'].contains(entry.key)));
        }
      });
      if (e is ApiException && e.status == 409) {
        final refresh = await showDialog<bool>(
            context: context,
            builder: (context) => OperationsTheme(
                role: _session.role,
                child: AlertDialog(
                    title: const Text('Galeri telah berubah'),
                    content: const Text(
                        'Admin lain telah menyimpan perubahan. Draft lokal tetap ada. Muat ulang untuk mengganti draft foto dengan galeri terbaru, lalu susun kembali perubahan Anda.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Pertahankan draft')),
                      if (_session.role != 1)
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Muat ulang'))
                    ])));
        if (refresh == true && mounted) await _loadGallery();
      } else {
        _snack(e is ApiException && e.outcomeUnknown
            ? 'Hasil simpan belum pasti. Draft tetap ada; Coba Lagi memakai operasi yang sama. ${e.message}'
            : 'Gagal menyimpan: ${adminErrorMessage(e)}. Draft tetap ada.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      // Font Plus Jakarta Sans untuk seluruh halaman
      data: _session.role == 1
          ? AppColors.operationsTheme
          : Theme.of(context).copyWith(
              textTheme: GoogleFonts.plusJakartaSansTextTheme(
                  Theme.of(context).textTheme),
            ),
      // Both operations roles open with a scenic header that scrolls away.
      child: ScrollAwareStatusBar(
        navigationBarColor: Colors.white,
        builder: (context, headerKey) => PopScope(
            canPop: !_dirty && !_isSaving,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop && await _confirmDiscard() && mounted) {
                setState(() => _dirty = false);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: _buildScaffold(context, headerKey)),
      ),
    );
  }

  Future<void> _refreshFormData() async {
    if (_isSaving || _picking || _galleryLoading) return;
    await _load();
    if (!mounted || !_session.isCurrentGeneration(_sessionGeneration)) return;
    if (!_facilities.changed) await _facilities.load(_savedDestinationGuid);
    if (mounted && _savedDestinationGuid != null) await _reloadGallery();
  }

  Widget _buildScaffold(BuildContext context, GlobalKey headerKey) {
    final isEdit = widget.wisataEdit != null || _savedDestinationGuid != null;

    if (!canAccessAdmin(_session.role) ||
        !_session.isCurrentGeneration(_sessionGeneration)) {
      return Scaffold(
          appBar: AppBar(title: const Text('Kelola Wisata')),
          body: const Center(
              child: Text('Akses ditolak. Silakan masuk kembali.')));
    }
    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
          onRefresh: _session.role == 1 ? _refreshFormData : () async {},
          notificationPredicate: (_) => _session.role == 1,
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: _session.role == 1
                  ? const AlwaysScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              slivers: [
                // ── SliverAppBar ─────────────────────────────────
                if (_session.role == 1)
                  SliverToBoxAdapter(
                      child: KeyedSubtree(
                          key: headerKey,
                          child: OperationsScenicHeader(
                              title: isEdit
                                  ? 'Ubah Destinasi'
                                  : 'Tambah Destinasi',
                              subtitle:
                                  'Informasi, galeri, dan fasilitas destinasi',
                              onBack: () => Navigator.maybePop(context))))
                else
                  SliverToBoxAdapter(
                      child: KeyedSubtree(
                          key: headerKey,
                          child: OperationsDayHeader(
                              label: 'Wisata Daerahku · Operasional',
                              title: isEdit
                                  ? 'Ubah Destinasi'
                                  : 'Tambah Destinasi',
                              subtitle:
                                  'Informasi, galeri, dan fasilitas destinasi',
                              onBack: () => Navigator.maybePop(context)))),

                // ── Konten Form ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _infoSection(),
                        const SizedBox(height: 16),
                        _locationSection(),
                        const SizedBox(height: 16),
                        _gallerySection(),
                        const SizedBox(height: 16),
                        _detailSection(),
                        const SizedBox(height: 16),
                        _ticketSection(),
                        const SizedBox(height: 16),
                        _facilitySection(),
                        const SizedBox(height: 16),
                        _ratingSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )),
      // ── Tombol Simpan fixed di bawah ──────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: _C.surface,
          border:
              Border(top: BorderSide(color: _C.border.withValues(alpha: 0.6))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSave ? _simpan : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 54),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: _C.teal,
                  disabledBackgroundColor: _C.teal.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          ),
                          SizedBox(width: 10),
                          Flexible(
                              child: Text(
                            'Menyimpan...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          )),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEdit
                                ? PhosphorIconsRegular.floppyDisk
                                : PhosphorIconsRegular.mapPinPlus,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                              child: Text(
                            isEdit
                                ? 'Simpan Perubahan'
                                : 'Simpan Destinasi Baru',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          )),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Opening hours ─────────────────────────────────────────
  static String _formatTime(TimeOfDay? time, {String separator = ':'}) =>
      time == null
          ? ''
          : '${time.hour.toString().padLeft(2, '0')}$separator'
              '${time.minute.toString().padLeft(2, '0')}';

  /// Value sent as `opening_hours`: the two picked times, or the untouched
  /// legacy text when the admin hasn't changed the hours.
  String get _openingHours {
    if (_openTime != null && _closeTime != null) {
      return '${_formatTime(_openTime, separator: '.')} - '
          '${_formatTime(_closeTime, separator: '.')}';
    }
    return _hoursEdited ? '' : _rawHours;
  }

  bool get _legacyHoursOnly =>
      !_hoursEdited &&
      _rawHours.isNotEmpty &&
      (_openTime == null || _closeTime == null);

  /// Ticket price as an int; the field only *displays* thousands dots.
  int? get _price =>
      int.tryParse(hargaCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

  /// Parses an inline "HH:MM" entry, or null when incomplete/out of range.
  static TimeOfDay? _parseTime(String text) {
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
    if (m == null) return null;
    final hour = int.parse(m[1]!), minute = int.parse(m[2]!);
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _onTimeChanged({required bool opening}) {
    final text = (opening ? _openCtrl : _closeCtrl).text;
    setState(() {
      if (opening) {
        _openTime = _parseTime(text);
      } else {
        _closeTime = _parseTime(text);
      }
      _hoursEdited = true;
      _dirty = true;
    });
  }

  // ── Location ──────────────────────────────────────────────
  Future<void> _pickLocation() async {
    if (_isSaving ||
        !_galleryReady ||
        _galleryLoading ||
        !_session.isCurrentGeneration(_sessionGeneration) ||
        !canAccessAdmin(_session.role)) {
      return;
    }
    final result = await Navigator.push<DestinationLocationDraft>(
        context,
        MaterialPageRoute(
            builder: (_) => DestinationLocationPickerScreen(
                  initialPoint: _locationPoint,
                  initialAddress: lokasiCtrl.text,
                  repository: _repository,
                  session: _session,
                )));
    if (result == null ||
        !mounted ||
        !_session.isCurrentGeneration(_sessionGeneration)) {
      return;
    }
    setState(() {
      _locationPoint = result.point;
      lokasiCtrl.text = result.address;
      _locationEdited = true;
      _locationErrors = {};
      _dirty = true;
    });
  }

  // ── Building blocks ───────────────────────────────────────
  /// Numbered white card: "01" badge, title and subtitle, then [children].
  Widget _section({
    Key? key,
    required int number,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) =>
      Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _C.tint, borderRadius: BorderRadius.circular(10)),
                child: Text(number.toString().padLeft(2, '0'),
                    style: const TextStyle(
                        color: _C.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: _C.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: _C.textMuted, fontSize: 12)),
                    ]),
              ),
            ]),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      );

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(
          TextSpan(text: text, children: [
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: _C.danger)),
          ]),
          style: const TextStyle(
              color: _C.text, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );

  InputDecoration _decoration({
    String? hint,
    String? helper,
    String? errorText,
    Widget? prefix,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _C.textDim, fontSize: 14),
      helperText: helper,
      helperMaxLines: 2,
      helperStyle: const TextStyle(color: _C.textMuted, fontSize: 11.5),
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(color: _C.danger, fontSize: 11.5),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      filled: true,
      fillColor: _C.field,
      border: border(_C.border, 1.2),
      enabledBorder: border(_C.border, 1.2),
      disabledBorder: border(_C.border, 1.2),
      focusedBorder: border(_C.blue, 1.5),
      errorBorder: border(_C.danger, 1.2),
      focusedErrorBorder: border(_C.danger, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Widget _textField({
    Key? key,
    required TextEditingController ctrl,
    required String hint,
    String? helper,
    String? errorText,
    Widget? prefix,
    int maxLines = 1,
    int? minLines,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        key: key,
        controller: ctrl,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        enabled: !_isSaving,
        keyboardType: keyboardType ??
            (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        textCapitalization: capitalization,
        inputFormatters: formatters,
        validator: validator,
        style: const TextStyle(color: _C.text, fontSize: 14, height: 1.5),
        decoration: _decoration(
            hint: hint, helper: helper, errorText: errorText, prefix: prefix),
      );

  Widget _helperText(String text, {Color color = _C.textMuted}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11.5, height: 1.4)),
      );

  Widget _mapChip(String text) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F102D59), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _C.text, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ),
      );

  // ── 01 Informasi Utama ────────────────────────────────────
  Widget _infoSection() => _section(
        number: 1,
        title: 'Informasi Utama',
        subtitle: 'Identitas dan kategori tempat wisata',
        children: [
          _label('Nama destinasi', required: true),
          _textField(
            ctrl: namaCtrl,
            hint: 'Contoh: Pantai Parangtritis',
            capitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nama destinasi wajib diisi'
                : null,
          ),
          const SizedBox(height: 16),
          _label('Kategori wisata', required: true),
          _kategoriPicker(),
        ],
      );

  Widget _kategoriPicker() {
    final items = _categories.items;
    final known = items.any((c) => c.guid == _categoryGuid);
    // An edited destination may point at a category that's no longer active
    // (so not in the list); keep it selectable instead of silently dropping it.
    final legacyName = widget.wisataEdit?.kategori ?? '';
    final showLegacy =
        _categoryGuid != null && !known && legacyName.trim().isNotEmpty;
    final value = known || showLegacy ? _categoryGuid : null;
    final loading = _categories.loading && items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectFormField<String>(
          key: const ValueKey('category-field'),
          value: value,
          sheetTitle: 'Pilih kategori',
          sheetSubtitle: 'Kategori menentukan pengelompokan destinasi',
          hint: loading ? 'Memuat kategori...' : 'Pilih kategori',
          enabled: !_isSaving,
          options: [
            for (final category in items)
              SelectOption(category.guid, category.name),
            if (showLegacy)
              SelectOption(_categoryGuid!, '$legacyName (nonaktif)'),
          ],
          onChanged: (value) => setState(() {
            _categoryGuid = value;
            _dirty = true;
          }),
          validator: (v) => v == null ? 'Pilih kategori wisata' : null,
          decoration: _decoration(),
        ),
        if (_categories.error != null && _session.role != 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _load,
                child: const Text('Gagal memuat kategori. Coba lagi')),
          ),
      ],
    );
  }

  // ── 02 Lokasi Destinasi ───────────────────────────────────
  Widget _locationSection() {
    final point = _locationPoint;
    final address = lokasiCtrl.text.trim();
    final shortAddress = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .take(2)
        .join(', ');
    final canPick = !_isSaving && _galleryReady && !_galleryLoading;
    return _section(
      number: 2,
      title: 'Lokasi Destinasi',
      subtitle: 'Tentukan posisi yang tepat pada peta',
      children: [
        _label('Titik lokasi'),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 180,
              child: point == null
                  ? const ColoredBox(
                      color: _C.field,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(PhosphorIconsRegular.mapPinLine,
                                color: _C.blue, size: 30),
                            SizedBox(height: 8),
                            Text('Belum ada titik lokasi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _C.text,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Pilih titik pada peta untuk pratinjau',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _C.textMuted, fontSize: 12)),
                          ]),
                        ),
                      ),
                    )
                  : Stack(fit: StackFit.expand, children: [
                      IgnorePointer(
                          child: DestinationLocationMap(
                              key: ValueKey(point), point: point)),
                      Positioned(
                          top: 10,
                          right: 10,
                          child: IgnorePointer(
                              child: _mapChip('Pratinjau lokasi'))),
                      if (shortAddress.isNotEmpty)
                        Positioned(
                            left: 10,
                            bottom: 10,
                            right: 60,
                            child: Align(
                                alignment: Alignment.bottomLeft,
                                child: IgnorePointer(
                                    child: _mapChip(shortAddress)))),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: canPick ? _pickLocation : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFFF5F9FF),
            foregroundColor: _C.blue,
            side: BorderSide(color: canPick ? _C.blue : _C.border, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(PhosphorIconsRegular.mapPin, size: 18),
          label: Text(
              point == null ? 'Pilih Titik Lokasi' : 'Ubah Titik Lokasi',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 18),
        _label('Alamat lengkap', required: true),
        _textField(
            ctrl: lokasiCtrl,
            hint: 'Contoh: Yogyakarta, DIY',
            helper: 'Alamat yang akan dilihat pengunjung.',
            maxLines: 4,
            minLines: 3,
            maxLength: 255,
            errorText: _locationErrors['location'],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Alamat lengkap wajib diisi';
              }
              return value.trim().length > 255 ? 'Maksimal 255 karakter' : null;
            }),
        const SizedBox(height: 4),
        Row(children: [
          Icon(
              point == null
                  ? PhosphorIconsRegular.info
                  : PhosphorIconsRegular.crosshair,
              size: 13,
              color: _C.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                point == null
                    ? widget.wisataEdit == null
                        ? 'Pilih titik lokasi terlebih dahulu'
                        : 'Lokasi peta belum ditentukan'
                    : 'Koordinat: ${point.latitude.toStringAsFixed(7)}, ${point.longitude.toStringAsFixed(7)}',
                style: const TextStyle(color: _C.textMuted, fontSize: 11.5)),
          ),
        ]),
        for (final field in ['latitude', 'longitude'])
          if (_locationErrors[field] != null)
            _helperText(_locationErrors[field]!, color: _C.danger),
      ],
    );
  }

  // ── 03 Galeri Destinasi ───────────────────────────────────
  Widget _gallerySection() => _section(
        key: _galleryKey,
        number: 3,
        title: 'Galeri Destinasi',
        subtitle: 'Tampilkan suasana terbaik tempat wisata',
        children: [
          if (_galleryLoading)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator()),
          if (_galleryReady &&
              widget.wisataEdit?.imageUrl != null &&
              _gallery.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Foto lama belum dapat diedit di galeri. Tambahkan foto untuk menyimpan.',
                  style: TextStyle(color: _C.textMuted, fontSize: 12)),
            ),
          AdminDestinationGalleryEditor(
              items: _gallery,
              enabled: !_isSaving && !_galleryLoading && !_picking,
              destinationGuid: _savedDestinationGuid,
              repository: _repository,
              onAdd: _pickImages,
              onRemove: (index) {
                if (_gallery.length == 1) {
                  _snack('Minimal satu foto harus dipertahankan.');
                  return;
                }
                setState(() {
                  _gallery.removeAt(index);
                  _dirty = true;
                });
              },
              onReorder: (from, to) => setState(() {
                    final item = _gallery.removeAt(from);
                    _gallery.insert(to, item);
                    _dirty = true;
                  })),
          if (_failedSave || (widget.wisataEdit != null && _session.role != 1))
            Wrap(spacing: 4, children: [
              if (_failedSave)
                TextButton(
                    onPressed: _isSaving || !_galleryReady || _gallery.isEmpty
                        ? null
                        : _simpan,
                    child: const Text('Coba Lagi')),
              if (widget.wisataEdit != null && _session.role != 1)
                TextButton(
                    onPressed: _isSaving ? null : _reloadGallery,
                    child: const Text('Muat ulang galeri')),
            ]),
        ],
      );

  // ── 04 Detail & Deskripsi ─────────────────────────────────
  Widget _detailSection() => _section(
        number: 4,
        title: 'Detail & Deskripsi',
        subtitle: 'Informasi tentang pengalaman berkunjung',
        children: [
          _label('Deskripsi destinasi', required: true),
          _textField(
            ctrl: deskCtrl,
            hint: 'Ceritakan keunikan tempat wisata ini...',
            helper: 'Gunakan deskripsi yang mudah dipahami calon pengunjung.',
            minLines: 4,
            maxLines: 8,
            capitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Deskripsi wajib diisi'
                : null,
          ),
        ],
      );

  // ── 05 Tiket & Operasional ────────────────────────────────
  Widget _timeField({required bool opening}) => TextFormField(
        key: ValueKey(opening ? 'open-time-field' : 'close-time-field'),
        controller: opening ? _openCtrl : _closeCtrl,
        enabled: !_isSaving,
        keyboardType: TextInputType.number,
        inputFormatters: [_TimeInputFormatter()],
        onChanged: (_) => _onTimeChanged(opening: opening),
        style: const TextStyle(color: _C.text, fontSize: 14),
        validator: (v) {
          final text = v ?? '';
          if (text.isEmpty) return _legacyHoursOnly ? null : 'Wajib diisi';
          return _parseTime(text) == null ? 'Jam tidak valid' : null;
        },
        decoration: _decoration(
          hint: '--:--',
          suffix:
              const Icon(PhosphorIconsRegular.clock, color: _C.text, size: 18),
        ),
      );

  Widget _ticketSection() {
    final zones = <String>{...kAdminTimezones, _timezone}.toList();
    return _section(
      number: 5,
      title: 'Tiket & Operasional',
      subtitle: 'Atur harga dan waktu kunjungan',
      children: [
        _label('Harga tiket per pengunjung', required: true),
        _textField(
          ctrl: hargaCtrl,
          hint: 'Contoh: 25.000',
          helper: 'Isi 0 untuk destinasi dengan tiket gratis.',
          keyboardType: TextInputType.number,
          formatters: [_RupiahInputFormatter()],
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Rp',
                  style: TextStyle(
                      color: _C.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Container(width: 1, height: 22, color: _C.border),
            ]),
          ),
          validator: (v) {
            final text = v?.trim() ?? '';
            if (text.isEmpty) return 'Harga tiket wajib diisi';
            final price = _price;
            return price == null || price < 0 ? 'Bilangan bulat ≥ 0' : null;
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(height: 1, color: _C.border),
        ),
        const Text('JAM OPERASIONAL',
            style: TextStyle(
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_label('Jam buka'), _timeField(opening: true)]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_label('Jam tutup'), _timeField(opening: false)]),
          ),
        ]),
        if (_legacyHoursOnly)
          _helperText('Tersimpan: "$_rawHours". Pilih jam untuk menggantinya.'),
        const SizedBox(height: 16),
        _label('Zona waktu'),
        SelectFormField<String>(
          key: const ValueKey('timezone-field'),
          value: _timezone,
          sheetTitle: 'Pilih zona waktu',
          sheetSubtitle: 'Sesuaikan dengan lokasi destinasi',
          hint: 'Pilih zona waktu',
          enabled: !_isSaving,
          options: [
            for (final zone in zones) SelectOption(zone, timezoneLabel(zone)),
          ],
          onChanged: (value) => setState(() {
            _timezone = value;
            _dirty = true;
          }),
          decoration: _decoration(
              helper: 'Jam operasional mengikuti zona waktu lokasi destinasi.'),
        ),
      ],
    );
  }

  // ── 06 Fasilitas Destinasi ────────────────────────────────
  Widget _facilitySection() => _section(
        number: 6,
        title: 'Fasilitas Destinasi',
        subtitle: 'Pilih fasilitas yang tersedia untuk pengunjung',
        children: [
          if (_facilities.loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator())),
          if (_facilities.error != null) ...[
            Text(adminErrorMessage(_facilities.error!),
                style: const TextStyle(color: _C.danger, fontSize: 12.5)),
            if (_session.role != 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => _facilities.load(_savedDestinationGuid),
                    child: const Text('Muat ulang fasilitas')),
              ),
          ],
          if (_facilities.ready && _facilities.items.isEmpty)
            const Text(
                'Belum ada fasilitas aktif. Superadmin dapat menambahkannya.',
                style: TextStyle(color: _C.textMuted, fontSize: 12.5)),
          if (_facilities.ready && _facilities.items.isNotEmpty)
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _facilities.items.map((facility) {
                  final selected = _facilities.selected.contains(facility.guid);
                  return FilterChip(
                    key: ValueKey('facility-${facility.guid}'),
                    showCheckmark: false,
                    avatar: Icon(
                        selected
                            ? PhosphorIconsBold.check
                            : PhosphorIconsBold.plus,
                        size: 14,
                        color: selected ? _C.blue : _C.textMuted),
                    label: Text(facility.name),
                    labelStyle: TextStyle(
                        color: selected ? _C.blue : _C.text,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600),
                    labelPadding: const EdgeInsets.only(left: 2, right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    backgroundColor: _C.surface,
                    selectedColor: _C.tint,
                    disabledColor: _C.field,
                    side: BorderSide(
                        color: selected ? _C.blue : _C.border,
                        width: selected ? 1.3 : 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    selected: selected,
                    onSelected: _isSaving
                        ? null
                        : (selected) {
                            final error =
                                _facilities.toggle(facility.guid, selected);
                            if (error != null) _snack(error);
                          },
                  );
                }).toList()),
          _helperText(
              'Ketuk fasilitas untuk memilih atau membatalkan pilihan.'),
          if (_facilities.changed)
            _helperText('Perubahan fasilitas belum disimpan.', color: _C.blue),
          if (widget.wisataEdit != null)
            _helperText(
                'Fasilitas hanya diperbarui jika pilihan diubah. Fasilitas yang sudah dinonaktifkan dan tidak tampil di sini dapat ikut dilepas saat diperbarui.'),
        ],
      );

  // ── 07 Rating Pengunjung ──────────────────────────────────
  Widget _ratingSection() {
    final rated = _ratingCount > 0 && _rating > 0;
    return _section(
      number: 7,
      title: 'Rating Pengunjung',
      subtitle: 'Dikelola otomatis oleh sistem',
      children: [
        CustomPaint(
          painter: _DashedBorderPainter(color: _C.border, radius: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _C.field, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      rated
                          ? PhosphorIconsFill.star
                          : PhosphorIconsRegular.star,
                      color: _C.gold,
                      size: 18),
                  const SizedBox(width: 8),
                  if (rated) ...[
                    Text(_rating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: _C.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('dari $_ratingCount ulasan',
                          style: const TextStyle(
                              color: _C.textMuted, fontSize: 12.5)),
                    ),
                  ] else
                    const Flexible(
                      child: Text('Belum ada rating',
                          style: TextStyle(
                              color: _C.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
                const SizedBox(height: 12),
                ExcludeSemantics(
                  child: Row(children: [
                    for (var i = 0; i < 5; i++) ...[
                      Icon(
                        _rating >= i + 1
                            ? PhosphorIconsFill.star
                            : _rating >= i + .5
                                ? PhosphorIconsFill.starHalf
                                : PhosphorIconsRegular.star,
                        color: _C.gold,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                const Text(
                    'Rating akan muncul secara otomatis dari ulasan pengunjung. Admin tidak dapat mengubahnya secara manual.',
                    style: TextStyle(
                        color: _C.textMuted, fontSize: 12, height: 1.45)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashed rounded-rectangle outline for read-only, system-managed panels.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Digits only, displayed with thousands dots ("25000" → "25.000").
/// Purely visual: the stored value is parsed back to a plain int.
class _RupiahInputFormatter extends TextInputFormatter {
  static String format(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final out = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) out.write('.');
      out.write(trimmed[i]);
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Inline 24-hour entry: digits only, auto-inserts the colon ("0800" → "08:00").
class _TimeInputFormatter extends TextInputFormatter {
  /// Keeps only digits that stay a valid 00:00–23:59 time as typed:
  /// a leading 3–9 becomes "0d", hour ≤ 23, minute tens ≤ 5 (so ≤ 59).
  static String _sanitize(String raw) {
    final out = <int>[];
    for (final unit in raw.codeUnits) {
      final d = unit - 0x30;
      if (out.length == 4) break;
      if (out.isEmpty) {
        if (d > 2) {
          out.addAll([0, d]);
        } else {
          out.add(d);
        }
      } else if (out.length == 1) {
        if (out[0] == 2 && d > 3) continue;
        out.add(d);
      } else if (out.length == 2) {
        if (d > 5) continue;
        out.add(d);
      } else {
        out.add(d);
      }
    }
    return out.join();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final oldDigits = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Backspace on the colon removes only the separator: drop the digit
    // before it instead, otherwise the colon is re-inserted and it sticks.
    if (newValue.text.length < oldValue.text.length &&
        digits == oldDigits &&
        digits.length > 2) {
      digits = digits.substring(0, 1) + digits.substring(2);
    }
    digits = _sanitize(digits);
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
