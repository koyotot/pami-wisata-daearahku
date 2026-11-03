// ============================================================
// lib/screens/tambah_wisata_screen.dart
// Tema: biru terang — sama dengan home, login, dan dashboard admin
// Dependency: image_picker (tambah ke pubspec.yaml)
// ============================================================
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/admin_state.dart';
import '../data/facility_state.dart';
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import '../data/gallery_draft.dart';
import '../widgets/admin_destination_gallery_editor.dart';
import '../data/favorite_state.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/destination_location_map_preview.dart';
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
  const TambahWisataScreen(
      {super.key, this.wisataEdit, this.repository, this.session});

  @override
  State<TambahWisataScreen> createState() => _TambahWisataScreenState();
}

class _TambahWisataScreenState extends State<TambahWisataScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController namaCtrl, lokasiCtrl, deskCtrl, hargaCtrl, jamCtrl;
  double _rating = 0;
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
    hargaCtrl =
        TextEditingController(text: w == null ? '' : '${w.ticketPrice}');
    jamCtrl = TextEditingController(text: w?.jamBuka ?? '');
    for (final controller in [
      namaCtrl,
      lokasiCtrl,
      deskCtrl,
      hargaCtrl,
      jamCtrl
    ]) {
      controller.addListener(() {
        if (_hydratingLocation) return;
        if (controller == lokasiCtrl) {
          _locationEdited = true;
          _locationErrors = {};
        }
        if (mounted) setState(() => _dirty = true);
      });
    }
    _rating = (w?.ratingCount ?? 0) > 0 ? w!.rating : 0;
    _categoryGuid =
        (w?.categoryGuid.isNotEmpty ?? false) ? w!.categoryGuid : null;
    _timezone =
        (w?.timezone.isNotEmpty ?? false) ? w!.timezone : kAdminTimezones.first;
    _sessionGeneration = _session.sessionGeneration;
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
    if (canAccessAdmin(_session.role)) {
      _load();
      _facilities.load(w?.id);
    }
  }

  @override
  void dispose() {
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
    jamCtrl.dispose();
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
      [namaCtrl, lokasiCtrl, deskCtrl, jamCtrl]
          .every((c) => c.text.trim().isNotEmpty) &&
      (int.tryParse(hargaCtrl.text.trim()) ?? -1) >= 0;

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
    return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Buang perubahan?'),
                    content: const Text('Draft foto dan form belum disimpan.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Lanjut edit')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Buang'))
                    ])) ??
        false;
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white, size: 18),
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
    final price = int.tryParse(hargaCtrl.text.trim());
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
      'opening_hours': jamCtrl.text.trim(),
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
            builder: (context) => AlertDialog(
                    title: const Text('Galeri telah berubah'),
                    content: const Text(
                        'Admin lain telah menyimpan perubahan. Draft lokal tetap ada. Muat ulang untuk mengganti draft foto dengan galeri terbaru, lalu susun kembali perubahan Anda.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Pertahankan draft')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Muat ulang'))
                    ]));
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
      data: Theme.of(context).copyWith(
        textTheme:
            GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PopScope(
            canPop: !_dirty && !_isSaving,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop && await _confirmDiscard() && mounted) {
                setState(() => _dirty = false);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: _buildScaffold(context)),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── SliverAppBar ─────────────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              floating: false,
              pinned: true,
              snap: false,
              backgroundColor: const Color(0xFF1558B0),
              elevation: 0,
              leading: GestureDetector(
                onTap: () async {
                  if (await _confirmDiscard() && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A93F0),
                        Color(0xFF1976D2),
                        Color(0xFF1558B0)
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Teks header
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 46,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: _C.gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    isEdit
                                        ? 'UBAH DESTINASI'
                                        : 'DESTINASI BARU',
                                    style: const TextStyle(
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
                            Text(
                              isEdit ? 'Edit Wisata' : 'Tambah Wisata',
                              style: const TextStyle(
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
                              isEdit
                                  ? 'Perbarui informasi destinasi'
                                  : 'Tambah destinasi nusantara baru',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tepi bawah melengkung menyatu dengan form
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        child: Container(
                          height: 26,
                          decoration: const BoxDecoration(
                            color: _C.bg,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(26)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Konten Form ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Upload Foto ──────────────────────────────
                    _sectionLabel('Foto Destinasi'),
                    const SizedBox(height: 12),
                    if (_galleryLoading) const LinearProgressIndicator(),
                    if (_galleryReady &&
                        widget.wisataEdit?.imageUrl != null &&
                        _gallery.isEmpty)
                      const Text(
                          'Foto lama belum dapat diedit di galeri. Tambahkan foto untuk menyimpan.'),
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
                    if (_failedSave)
                      TextButton(
                          onPressed:
                              _isSaving || !_galleryReady || _gallery.isEmpty
                                  ? null
                                  : _simpan,
                          child: const Text('Coba Lagi')),
                    if (widget.wisataEdit != null)
                      TextButton(
                          onPressed: _isSaving ? null : _reloadGallery,
                          child: const Text('Muat ulang galeri')),
                    const SizedBox(height: 24),

                    // ── Info Dasar ───────────────────────────────
                    _sectionLabel('Informasi Dasar'),
                    const SizedBox(height: 14),
                    _field(
                      ctrl: namaCtrl,
                      label: 'Nama Wisata',
                      hint: 'Contoh: Pantai Parangtritis',
                      icon: Icons.landscape_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama wisata wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _locationSection(),
                    const SizedBox(height: 12),
                    _kategoriPicker(),
                    const SizedBox(height: 12),
                    _timezonePicker(),
                    const SizedBox(height: 24),

                    // ── Detail ───────────────────────────────────
                    _sectionLabel('Detail & Harga'),
                    const SizedBox(height: 14),
                    _field(
                      ctrl: deskCtrl,
                      label: 'Deskripsi',
                      hint: 'Ceritakan keunikan tempat wisata ini...',
                      icon: Icons.description_rounded,
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Deskripsi wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _field(
                          ctrl: hargaCtrl,
                          label: 'Harga Tiket',
                          hint: 'Rupiah, 0 = gratis',
                          icon: Icons.local_activity_rounded,
                          keyboardType: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) return 'Wajib diisi';
                            final price = int.tryParse(text);
                            return price == null || price < 0
                                ? 'Bilangan bulat ≥ 0'
                                : null;
                          },
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field(
                          ctrl: jamCtrl,
                          label: 'Jam Buka',
                          hint: '08.00 – 17.00',
                          icon: Icons.schedule_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Rating ───────────────────────────────────
                    _fasilitasPicker(),
                    const SizedBox(height: 24),
                    _sectionLabel(isEdit ? 'Rating Destinasi' : 'Rating Awal'),
                    const SizedBox(height: 14),
                    _ratingPicker(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
              height: 54,
              child: ElevatedButton(
                onPressed: _canSave ? _simpan : null,
                style: ElevatedButton.styleFrom(
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
                          Text(
                            'Menyimpan...',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEdit
                                ? Icons.save_rounded
                                : Icons.add_location_alt_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Photo Uploader ────────────────────────────────────────
  Widget _timezonePicker() {
    final zones = <String>{...kAdminTimezones, _timezone}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zona Waktu',
            style: TextStyle(
                color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          key: const ValueKey('timezone-field'),
          initialValue: _timezone,
          isExpanded: true,
          items: [
            for (final zone in zones)
              DropdownMenuItem(value: zone, child: Text(timezoneLabel(zone))),
          ],
          onChanged: _isSaving
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _timezone = value;
                      _dirty = true;
                    });
                  }
                },
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.public_rounded, color: _C.teal, size: 18),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: _C.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.teal, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Section label ─────────────────────────────────────────
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

  Widget _locationSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Lokasi Destinasi',
            style: TextStyle(
                color: _C.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Tentukan titik akurat pada peta.',
            style: TextStyle(color: _C.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
                height: 160,
                child: _locationPoint == null
                    ? const ColoredBox(
                        color: Colors.white,
                        child: Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Tentukan lokasi di peta',
                                    textAlign: TextAlign.center))))
                    : IgnorePointer(
                        child: DestinationLocationMap(
                            key: ValueKey(_locationPoint),
                            point: _locationPoint)))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: _isSaving || !_galleryReady || _galleryLoading
                ? null
                : _pickLocation,
            icon: const Icon(Icons.pin_drop_outlined, size: 20),
            label: Text(_locationPoint == null
                ? 'Pilih Titik Lokasi'
                : 'Ubah Titik Lokasi')),
        const SizedBox(height: 8),
        _field(
            ctrl: lokasiCtrl,
            label: 'Alamat Lengkap',
            hint: 'Contoh: Yogyakarta, DIY',
            icon: Icons.location_on_rounded,
            maxLines: 3,
            maxLength: 255,
            errorText: _locationErrors['location'],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Alamat lengkap wajib diisi';
              }
              return value.trim().length > 255 ? 'Maksimal 255 karakter' : null;
            }),
        const SizedBox(height: 8),
        Text(
            _locationPoint == null
                ? widget.wisataEdit == null
                    ? 'Pilih titik lokasi terlebih dahulu'
                    : 'Lokasi peta belum ditentukan'
                : 'Koordinat: ${_locationPoint!.latitude.toStringAsFixed(7)}, ${_locationPoint!.longitude.toStringAsFixed(7)}',
            style: const TextStyle(color: _C.textMuted, fontSize: 12)),
        for (final field in ['latitude', 'longitude'])
          if (_locationErrors[field] != null)
            Text(_locationErrors[field]!,
                style: const TextStyle(color: _C.danger, fontSize: 12)),
      ]);

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: _C.teal, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: _C.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
      ],
    );
  }

  // ── Form field ────────────────────────────────────────────

  // ── Rating Picker ─────────────────────────────────────────
  Widget _ratingPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rating Destinasi',
                style: TextStyle(color: _C.textMuted, fontSize: 13),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _C.gold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _rating == 0 ? '-' : _rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _C.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.45,
            child: Row(
              children: List.generate(5, (i) {
                final starVal = i + 1.0;
                final halfVal = i + 0.5;
                final star = Icon(
                  _rating >= starVal
                      ? Icons.star_rounded
                      : _rating >= halfVal
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                  color: _C.gold,
                  size: 36,
                );
                return Expanded(child: star);
              }),
            ),
          ),
          const SizedBox(height: 8),
          ...[
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: _C.textDim),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rating dikunci — dihitung otomatis dari ulasan pengunjung, bukan diatur manual oleh admin.',
                    style:
                        TextStyle(color: _C.textDim, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? errorText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: !_isSaving,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          style: const TextStyle(color: _C.text, fontSize: 14),
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, color: _C.teal, size: 18),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: _C.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.teal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.danger, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.danger, width: 1.5),
            ),
            errorStyle: const TextStyle(color: _C.danger, fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Kategori picker chip ──────────────────────────────────
  Widget _fasilitasPicker() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Pilihan Fasilitas'),
          const SizedBox(height: 10),
          if (_facilities.changed)
            const Text('Perubahan fasilitas belum disimpan.',
                style: TextStyle(color: _C.textMuted, fontSize: 12)),
          if (widget.wisataEdit != null)
            const Text(
                'Fasilitas hanya diganti bila pilihan diubah. Penggantian dapat melepas relasi fasilitas nonaktif yang tersembunyi.',
                style: TextStyle(color: _C.textMuted, fontSize: 12)),
          if (_facilities.loading)
            const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator()),
          if (_facilities.error != null) ...[
            Text(adminErrorMessage(_facilities.error!),
                style: const TextStyle(color: _C.danger)),
            TextButton(
                onPressed: _isSaving
                    ? null
                    : () => _facilities.load(_savedDestinationGuid),
                child: const Text('Muat ulang fasilitas')),
          ],
          if (_facilities.ready && _facilities.items.isEmpty)
            const Text(
                'Belum ada fasilitas aktif. Superadmin dapat menambahkannya.',
                style: TextStyle(color: _C.textMuted)),
          if (_facilities.ready)
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _facilities.items
                    .map((facility) => FilterChip(
                          key: ValueKey('facility-${facility.guid}'),
                          label: Text(facility.name),
                          selected:
                              _facilities.selected.contains(facility.guid),
                          onSelected: _isSaving
                              ? null
                              : (selected) {
                                  final error = _facilities.toggle(
                                      facility.guid, selected);
                                  if (error != null) _snack(error);
                                },
                        ))
                    .toList()),
        ],
      );

  Widget _kategoriPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kategori',
            style: TextStyle(
                color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (_categories.loading) const CircularProgressIndicator(),
        if (_categories.error != null)
          TextButton(
              onPressed: _load,
              child: const Text('Gagal memuat kategori. Coba lagi')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.items.map((category) {
            final k = {'label': category.name, 'icon': Icons.explore_rounded};
            final selected = _categoryGuid == category.guid;
            return GestureDetector(
              onTap: () => setState(() {
                _categoryGuid = category.guid;
                _dirty = true;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color:
                      selected ? _C.teal.withValues(alpha: 0.15) : _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _C.teal : _C.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(k['icon'] as IconData,
                        size: 14, color: selected ? _C.teal : _C.textMuted),
                    const SizedBox(width: 6),
                    Text(k['label'] as String,
                        style: TextStyle(
                            color: selected ? _C.teal : _C.textMuted,
                            fontSize: 12.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
