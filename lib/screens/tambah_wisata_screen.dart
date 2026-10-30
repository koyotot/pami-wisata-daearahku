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
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
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
  double _rating = 4.5;
  Uint8List? _imageBytes; // Gambar baru yang dipilih (belum diunggah)
  String _imageName = 'destination.jpg';
  bool _isSaving = false;

  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<Category> _categories;
  String? _categoryGuid;
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
    deskCtrl = TextEditingController(text: w?.deskripsi ?? '');
    hargaCtrl = TextEditingController(text: w == null ? '' : '${w.ticketPrice}');
    jamCtrl = TextEditingController(text: w?.jamBuka ?? '');
    _rating = w?.rating ?? 4.5;
    _categoryGuid =
        (w?.categoryGuid.isNotEmpty ?? false) ? w!.categoryGuid : null;
    _timezone = (w?.timezone.isNotEmpty ?? false) ? w!.timezone : kAdminTimezones.first;
    _sessionGeneration = _session.sessionGeneration;
    _categories = PagedListController<Category>(
      session: _session,
      keyOf: (category) => category.guid,
      fetchPage: (page, _) => _repository.categories(query: {'page': '$page'}),
    )..addListener(_onCategories);
    _load();
  }

  @override
  void dispose() {
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
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // tutup bottom sheet
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final problem = validateDestinationImage(bytes);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(problem),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name.isEmpty ? 'destination.jpg' : picked.name;
    });
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _C.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text('Pilih Sumber Foto',
                  style: TextStyle(
                      color: _C.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _sheetBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: _C.teal,
                    onTap: () => _pickImage(ImageSource.camera),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _sheetBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: _C.gold,
                    onTap: () => _pickImage(ImageSource.gallery),
                  )),
                ],
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                _sheetBtn(
                  icon: Icons.undo_rounded,
                  label: 'Batalkan Foto Baru',
                  color: _C.danger,
                  onTap: () {
                    setState(() => _imageBytes = null);
                    Navigator.pop(context);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── Simpan ke Laravel (multipart bila ada foto baru) ────────
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

  Future<void> _simpan() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final edit = widget.wisataEdit;
    if (!_session.isCurrentGeneration(_sessionGeneration)) {
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
    final bytes = _imageBytes;
    if (bytes != null) {
      final problem = validateDestinationImage(bytes);
      if (problem != null) {
        _snack(problem);
        return;
      }
    }
    final fields = <String, dynamic>{
      'destination_category_guid': _categoryGuid,
      'name': namaCtrl.text.trim(),
      'location': lokasiCtrl.text.trim(),
      'description': deskCtrl.text.trim(),
      'ticket_price': price,
      'opening_hours': jamCtrl.text.trim(),
      'timezone': _timezone,
    };
    final upload = bytes == null ? null : UploadFile('image', bytes, _imageName);
    setState(() => _isSaving = true);
    try {
      if (edit == null) {
        await _repository.createDestination(fields, image: upload);
      } else {
        await _repository.updateDestination(edit.id, fields, image: upload);
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
      if (e is ApiException && e.outcomeUnknown) {
        // Tidak diulang otomatis: simpan tidak idempoten.
        _snack(edit == null
            ? 'Hasil penyimpanan belum pasti (${e.message}). Periksa Daftar '
                'Wisata sebelum menyimpan ulang agar tidak terjadi duplikat.'
            : 'Hasil penyimpanan belum pasti (${e.message}). Periksa data '
                'wisata sebelum menyimpan ulang.');
      } else {
        _snack('Gagal menyimpan: ${adminErrorMessage(e)}');
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
        child: _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isEdit = widget.wisataEdit != null;

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
                onTap: () => Navigator.pop(context),
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
                    _photoUploader(),
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
                    _field(
                      ctrl: lokasiCtrl,
                      label: 'Lokasi',
                      hint: 'Contoh: Yogyakarta, DIY',
                      icon: Icons.location_on_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Lokasi wajib diisi'
                          : null,
                    ),
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
                    _sectionLabel(isEdit ? 'Rating Destinasi' : 'Rating Awal'),
                    const SizedBox(height: 14),
                    _ratingPicker(locked: true),
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
                onPressed: _isSaving ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.teal,
                  disabledBackgroundColor: _C.teal.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _imageBytes != null
                                ? 'Mengupload foto...'
                                : 'Menyimpan...',
                            style: const TextStyle(
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
                          Text(
                            isEdit ? 'Simpan Perubahan' : 'Tambahkan Wisata',
                            style: const TextStyle(
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
  Widget _photoUploader() {
    // Punya gambar jika: foto baru dipilih ATAU destinasi sudah punya gambar di server
    final hasImage = _imageBytes != null ||
        (widget.wisataEdit?.imageUrl?.isNotEmpty ?? false);

    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        width: double.infinity,
        height: 190,
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasImage ? _C.teal.withValues(alpha: 0.4) : _C.border,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPreviewImage(),
                    // overlay gelap
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // badge edit
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _C.teal,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text('Ganti Foto',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    // badge kiri: berhasil
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _C.teal.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Foto dipilih',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _C.teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _C.teal.withValues(alpha: 0.25), width: 1.5),
                      ),
                      child: Icon(Icons.add_photo_alternate_rounded,
                          color: _C.teal, size: 30),
                    ),
                    const SizedBox(height: 14),
                    Text('Tap untuk upload foto',
                        style: TextStyle(
                            color: _C.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Kamera atau galeri · JPEG, PNG, WebP · maks 5 MB',
                        style: TextStyle(color: _C.textMuted, fontSize: 11.5)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPreviewImage() {
    // Prioritas 1: foto baru yang baru dipilih (belum diunggah)
    final bytes = _imageBytes;
    if (bytes != null) {
      return Image.memory(bytes,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    }
    // Prioritas 2: gambar yang tersimpan di Laravel (endpoint admin)
    final edit = widget.wisataEdit;
    if (edit != null && (edit.imageUrl?.isNotEmpty ?? false)) {
      return ApiImage(
        imageUrl: edit.imageUrl,
        adminGuid: edit.id,
        fit: BoxFit.cover,
        repository: widget.repository,
        placeholder: (_) => _placeholder(),
      );
    }
    return _placeholder();
  }

  // ── Zona waktu destinasi (IANA) ───────────────────────────
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
                  if (value != null) setState(() => _timezone = value);
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

  Widget _placeholder() => Container(
      color: _C.card,
      child: Center(
          child:
              Icon(Icons.broken_image_rounded, color: _C.textMuted, size: 32)));

  // ── Section label ─────────────────────────────────────────
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
            style: TextStyle(
                color: _C.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
      ],
    );
  }

  // ── Form field ────────────────────────────────────────────

  // ── Rating Picker ─────────────────────────────────────────
  // locked = true  → mode Edit: rating tidak boleh diubah manual oleh admin,
  //                   karena ke depannya nilai ini akan dihitung otomatis
  //                   dari ulasan pengunjung asli.
  // locked = false → mode Tambah Baru: admin boleh isi rating awal sebagai
  //                   estimasi sementara sebelum ada ulasan sama sekali.
  Widget _ratingPicker({required bool locked}) {
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
              Text(
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
                    Icon(Icons.star_rounded, color: _C.gold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _rating.toStringAsFixed(1),
                      style: TextStyle(
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
            opacity: locked ? 0.45 : 1,
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
                if (locked) {
                  // Tidak ada GestureDetector — bintang sekadar tampilan.
                  return Expanded(child: star);
                }
                return Expanded(
                  child: GestureDetector(
                    onTapDown: (d) {
                      // Tap kiri bintang = 0.5, kanan = 1.0
                      setState(() => _rating =
                          (d.localPosition.dx < 20) ? halfVal : starVal);
                    },
                    child: star,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          if (locked) ...[
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: _C.textDim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rating dikunci — akan dihitung otomatis dari ulasan pengunjung, bukan diatur manual oleh admin.',
                    style:
                        TextStyle(color: _C.textDim, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1.0', style: TextStyle(color: _C.textDim, fontSize: 11)),
                Text('5.0', style: TextStyle(color: _C.textDim, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: _C.textDim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Estimasi awal sebelum ada ulasan pengunjung. Setelah destinasi punya ulasan asli, rating akan terkunci dan dihitung otomatis.',
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          style: TextStyle(color: _C.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _C.textDim, fontSize: 13),
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
              borderSide: BorderSide(color: _C.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _C.teal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _C.danger, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _C.danger, width: 1.5),
            ),
            errorStyle: TextStyle(color: _C.danger, fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Kategori picker chip ──────────────────────────────────
  Widget _kategoriPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kategori',
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
