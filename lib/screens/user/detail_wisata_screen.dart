import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:latlong2/latlong.dart';
import '../../data/admin_state.dart' show canAccessAdmin;
import '../../data/app_data.dart';
import '../../data/business_repository.dart';
import '../../data/favorite_state.dart';
import '../../services/api_client.dart';
import '../../services/auth_session.dart';
import '../../services/destination_directions.dart';
import '../../theme/app_colors.dart';
import '../../widgets/destination_hero_gallery.dart';
import '../../widgets/reviews_sheet.dart';
import '../../widgets/visit_format.dart';
import '../../widgets/destination_location_map_preview.dart';
import '../../widgets/operations_chrome.dart';
import '../../widgets/scroll_aware_status_bar.dart';
import 'daftar_kunjungan_screen.dart';
import 'destination_map_screen.dart';

export '../../services/destination_directions.dart'
    show destinationDirectionsUri;

class _C {
  static const blue = AppColors.blue;
  static const navy = AppColors.navy;
  static const bg = AppColors.bg;
  static const card = AppColors.surface;
  static const text = navy;
  static const textMuted = AppColors.textSecondary;
  static const border = AppColors.border;
}

class DetailWisataScreen extends StatefulWidget {
  final Wisata wisata;
  final BusinessRepository? repository;
  final bool adminPreview;
  final AuthSession? session;
  const DetailWisataScreen(
      {super.key,
      required this.wisata,
      this.repository,
      this.adminPreview = false,
      this.session});
  @override
  State<DetailWisataScreen> createState() => _DetailWisataScreenState();
}

class _DetailWisataScreenState extends State<DetailWisataScreen> {
  late final _repository =
      widget.repository ?? BusinessRepository(ApiClient(widget.session));
  AuthSession get _session => _repository.api.session;
  final _detail = RequestState<Destination>();
  FavoriteState get _favorites => FavoriteState.instance;
  bool get _isSaved => _favorites.isFavorite(widget.wisata.id);
  bool _loadingSave = false;
  bool _expanded = false;
  bool _openingMap = false;

  @override
  void initState() {
    super.initState();
    _detail.addListener(_detailChanged);
    if (!widget.adminPreview) _favorites.favorites.addListener(_detailChanged);
    if (widget.adminPreview) {
      _session.sessionChanges.addListener(_previewSessionChanged);
    }
    _loadDetail();
  }

  void _previewSessionChanged() {
    _detail.reset();
    _loadDetail();
  }

  void _detailChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDetail() {
    final id = widget.wisata.id;
    return _detail.load(() async {
      final revision = _session.sessionChanges.value;
      if (widget.adminPreview &&
          (!_session.authenticated.value ||
              !_session.deviceSessionReady ||
              !canAccessAdmin(_session.role))) {
        throw const ApiException(
            'Akses pratinjau berakhir. Kembali ke Kelola.', 403);
      }
      final destination = widget.adminPreview
          ? await _repository.adminDestination(id)
          : await _repository.destination(id);
      if (widget.adminPreview && revision != _session.sessionChanges.value) {
        throw const ApiException(
            'Akses diperbarui. Tarik turun untuk menyinkronkan.', 403);
      }
      if (destination.guid != id) {
        throw const ApiException('Identitas wisata tidak sesuai.');
      }
      return destination;
    });
  }

  @override
  void didUpdateWidget(covariant DetailWisataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminPreview != widget.adminPreview) {
      if (widget.adminPreview) {
        _favorites.favorites.removeListener(_detailChanged);
        _session.sessionChanges.addListener(_previewSessionChanged);
      } else {
        _session.sessionChanges.removeListener(_previewSessionChanged);
        _favorites.favorites.addListener(_detailChanged);
      }
    }
    if (oldWidget.wisata.id != widget.wisata.id ||
        oldWidget.adminPreview != widget.adminPreview) {
      _expanded = false;
      _detail.reset();
      _loadDetail();
    }
  }

  @override
  void dispose() {
    if (widget.adminPreview) {
      _session.sessionChanges.removeListener(_previewSessionChanged);
    }
    if (!widget.adminPreview) {
      _favorites.favorites.removeListener(_detailChanged);
    }
    _detail.removeListener(_detailChanged);
    _detail.dispose();
    super.dispose();
  }

  Future<void> _toggleSave() async {
    if (widget.adminPreview || _loadingSave) return;
    if (!_favorites.session.authenticated.value ||
        !_favorites.session.deviceSessionReady) {
      _showSnack('Login dulu untuk menyimpan wisata.');
      return;
    }
    final id = widget.wisata.id;
    final generation = _favorites.session.sessionGeneration;
    if (_favorites.favorites.error != null ||
        _favorites.favorites.data == null) {
      await _favorites.load();
      if (!mounted ||
          generation != _favorites.session.sessionGeneration ||
          id != widget.wisata.id ||
          !_favorites.session.deviceSessionReady) {
        return;
      }
      if (_favorites.favorites.error != null ||
          _favorites.favorites.data == null) {
        _showSnack(_favorites.favorites.error?.toString() ??
            'Gagal memuat wisata tersimpan.');
        return;
      }
    }
    final wasSaved = _isSaved;
    setState(() => _loadingSave = true);
    try {
      await _favorites.toggle(id);
      if (!mounted ||
          generation != _favorites.session.sessionGeneration ||
          id != widget.wisata.id) {
        return;
      }
      if (_favorites.favorites.error != null) {
        _showSnack(_favorites.favorites.error.toString());
      } else if (_isSaved != wasSaved) {
        _showSnack(_isSaved ? 'Wisata disimpan!' : 'Dihapus dari tersimpan');
      }
    } catch (e) {
      if (mounted && generation == _favorites.session.sessionGeneration) {
        _showSnack(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingSave = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: const TextStyle(color: _C.text, fontSize: 13)),
        backgroundColor: _C.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openReviews() {
    if (widget.adminPreview &&
        (_detail.data == null ||
            _detail.loading ||
            _detail.error != null ||
            !_session.authenticated.value ||
            !canAccessAdmin(_session.role))) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReviewsSheet(
          destinationGuid: widget.wisata.id,
          repository: _repository,
          adminPreview: widget.adminPreview),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleOne = widget.adminPreview || _repository.api.session.role == 1;
    final destination = _detail.data;
    if (_detail.loading ||
        _detail.error != null ||
        destination == null ||
        destination.guid != widget.wisata.id) {
      final error = _detail.error;
      if (roleOne)
        return OperationsTheme(
            role: _session.role == 2 ? 2 : 1,
            child: Scaffold(
                backgroundColor: _C.bg,
                body: RefreshIndicator(
                    onRefresh: _loadDetail,
                    child: ListView(
                        padding: EdgeInsets.zero,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          OperationsScenicHeader(
                              title: 'Detail Destinasi',
                              subtitle: widget.adminPreview
                                  ? 'Mode Pratinjau'
                                  : widget.wisata.nama,
                              onBack: () => Navigator.maybePop(context)),
                          Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: _detail.loading
                                  ? const LinearProgressIndicator()
                                  : Text(
                                      '${error ?? 'Destinasi belum tersedia.'}\nTarik turun untuk menyinkronkan.',
                                      textAlign: TextAlign.center)),
                        ]))));
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(title: const Text('Detail Destinasi')),
        body: _detail.loading
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                    height: MediaQuery.sizeOf(context).height * .42,
                    color: _C.border),
                const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: LinearProgressIndicator()),
                const Center(child: Text('Memuat destinasi...')),
              ])
            : Center(
                child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          error is ApiException && error.status == 404
                              ? 'Destinasi tidak ditemukan atau tidak tersedia.'
                              : '${error ?? 'Destinasi belum tersedia.'}',
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                          onPressed: _loadDetail,
                          child: const Text('Coba lagi')),
                    ]))),
      );
    }
    final heroHeight = MediaQuery.sizeOf(context).height * .48;
    final knownFavorite = !widget.adminPreview &&
        _favorites.favorites.data != null &&
        _favorites.favorites.error == null;
    final rating =
        destination.ratingCount > 0 && destination.ratingAverage != null
            ? destination.ratingAverage!.toStringAsFixed(1)
            : '-';
    // The hero photo is the last dark surface; past it the status bar sits on
    // the light page background.
    return ScrollAwareStatusBar(
      scrimColor: _C.bg,
      builder: (context, heroKey) => Scaffold(
        backgroundColor: _C.bg,
        bottomNavigationBar: _bookingBar(destination),
        body: RefreshIndicator(
          onRefresh: _loadDetail,
          child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (roleOne)
                  SliverToBoxAdapter(
                      child: OperationsScenicHeader(
                          title: 'Detail Destinasi',
                          subtitle: destination.name,
                          onBack: () => Navigator.maybePop(context),
                          actions: [
                        if (!widget.adminPreview)
                          IconButton(
                              tooltip: _isSaved
                                  ? 'Hapus dari favorit'
                                  : 'Simpan favorit',
                              onPressed:
                                  _loadingSave || _favorites.favorites.loading
                                      ? null
                                      : _toggleSave,
                              icon: Icon(_isSaved
                                  ? PhosphorIconsFill.heart
                                  : PhosphorIconsRegular.heart)),
                      ])),
                if (widget.adminPreview)
                  const SliverToBoxAdapter(
                      child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                        'Mode Pratinjau · Tidak dapat melakukan pemesanan',
                        key: ValueKey('v3-preview-mode'),
                        style: TextStyle(
                            color: _C.navy, fontWeight: FontWeight.w700)),
                  )),
                SliverToBoxAdapter(
                    child: SizedBox(
                        key: heroKey,
                        height: heroHeight,
                        child: Stack(children: [
                          Positioned.fill(
                              child: DestinationHeroGallery(
                                  key: ValueKey(
                                      '${destination.guid}-${destination.galleryVersion}'),
                                  images: destination.images,
                                  adminGuid: widget.adminPreview
                                      ? destination.guid
                                      : null,
                                  repository: _repository)),
                          const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 130,
                              child: IgnorePointer(
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                    Color(0x99000000),
                                    Colors.transparent
                                  ]))))),
                          if (!roleOne)
                            Positioned(
                                top: MediaQuery.paddingOf(context).top + 10,
                                left: 16,
                                right: 16,
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _topAction(
                                          'Kembali',
                                          PhosphorIconsRegular.arrowLeft,
                                          () => Navigator.pop(context)),
                                      _topAction(
                                          knownFavorite
                                              ? (_isSaved
                                                  ? 'Hapus dari favorit'
                                                  : 'Simpan favorit')
                                              : 'Periksa favorit',
                                          knownFavorite && _isSaved
                                              ? PhosphorIconsFill.heart
                                              : PhosphorIconsRegular.heart,
                                          _loadingSave ||
                                                  _favorites.favorites.loading
                                              ? null
                                              : _toggleSave,
                                          busy: _loadingSave ||
                                              _favorites.favorites.loading),
                                    ])),
                        ]))),
                SliverToBoxAdapter(
                    child: Transform.translate(
                        offset: const Offset(0, -8),
                        child: Container(
                          decoration: const BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28))),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(destination.name,
                                    style: GoogleFonts.plusJakartaSans(
                                        color: _C.navy,
                                        fontSize: 22,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.5)),
                                const SizedBox(height: AppSpacing.sm),
                                _location(destination.location),
                                const SizedBox(height: AppSpacing.lg),
                                Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      if (destination.category != null)
                                        _meta(PhosphorIconsRegular.squaresFour,
                                            destination.category!.name),
                                      if (destination.openingHours.isNotEmpty)
                                        _meta(PhosphorIconsRegular.clock,
                                            destination.openingHours),
                                      OutlinedButton.icon(
                                        onPressed: _openReviews,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _C.navy,
                                          backgroundColor: _C.card,
                                          minimumSize: const Size(48, 48),
                                          tapTargetSize:
                                              MaterialTapTargetSize.padded,
                                          visualDensity: VisualDensity.standard,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: AppSpacing.sm),
                                          side: const BorderSide(
                                              color: _C.border),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(PhosphorIconsFill.star,
                                            size: 16, color: _C.blue),
                                        label: Text(
                                            rating == '-'
                                                ? (destination.ratingCount == 0
                                                    ? 'Belum ada rating'
                                                    : 'Rating belum tersedia')
                                                : '$rating · ${destination.ratingCount} ulasan',
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ]),
                                if (!(destination.isActive &&
                                    destination.category?.isActive !=
                                        false)) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  const Text(
                                      'Destinasi ini sedang tidak menerima kunjungan.',
                                      style: TextStyle(color: _C.textMuted)),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                _heading('Tentang destinasi'),
                                const SizedBox(height: AppSpacing.md),
                                _contentCard(LayoutBuilder(
                                    builder: (context, constraints) {
                                  final description =
                                      destination.description.isEmpty
                                          ? 'Deskripsi belum tersedia.'
                                          : destination.description;
                                  final style = DefaultTextStyle.of(context)
                                      .style
                                      .merge(const TextStyle(
                                          color: _C.textMuted,
                                          fontSize: 12,
                                          height: 1.6))
                                      .merge(MediaQuery.boldTextOf(context)
                                          ? const TextStyle(
                                              fontWeight: FontWeight.bold)
                                          : null);
                                  final textScaler =
                                      MediaQuery.textScalerOf(context);
                                  final textDirection =
                                      Directionality.of(context);
                                  final painter = TextPainter(
                                    text: TextSpan(
                                        text: description, style: style),
                                    maxLines: 3,
                                    ellipsis: '\u2026',
                                    textScaler: textScaler,
                                    textDirection: textDirection,
                                    locale:
                                        Localizations.maybeLocaleOf(context),
                                  )..layout(maxWidth: constraints.maxWidth);
                                  final overflows = painter.didExceedMaxLines;
                                  painter.dispose();
                                  final collapsed = overflows && !_expanded;
                                  return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(description,
                                            maxLines: collapsed ? 3 : null,
                                            overflow: collapsed
                                                ? TextOverflow.ellipsis
                                                : TextOverflow.visible,
                                            textScaler: textScaler,
                                            textDirection: textDirection,
                                            style: style),
                                        if (overflows)
                                          TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor: _C.blue,
                                                minimumSize: const Size(48, 48),
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment.centerLeft,
                                                textStyle:
                                                    GoogleFonts.plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800),
                                              ),
                                              onPressed: () => setState(
                                                  () => _expanded = !_expanded),
                                              child: Text(_expanded
                                                  ? 'Ringkas ↑'
                                                  : 'Selengkapnya ↓')),
                                      ]);
                                })),
                                const SizedBox(height: AppSpacing.xl),
                                _heading('Fasilitas'),
                                const SizedBox(height: AppSpacing.md),
                                if (destination.facilities.isEmpty)
                                  _contentCard(const Text(
                                      'Informasi fasilitas belum dicantumkan oleh pengelola.',
                                      style: TextStyle(
                                          color: _C.textMuted,
                                          fontSize: 12,
                                          height: 1.6)))
                                else
                                  Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      children: destination.facilities
                                          .map((facility) => _meta(
                                              _facilityIcon(facility.iconKey),
                                              facility.name))
                                          .toList()),
                                const SizedBox(height: AppSpacing.xl),
                                _heading('Lokasi Destinasi'),
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _C.border),
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _location(destination.location),
                                          const SizedBox(height: AppSpacing.md),
                                          if (destination.hasCoordinates) ...[
                                            Material(
                                                clipBehavior: Clip.antiAlias,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: InkWell(
                                                    onTap: widget.adminPreview
                                                        ? null
                                                        : () => _viewMap(
                                                            destination),
                                                    child: Semantics(
                                                        button: !widget
                                                            .adminPreview,
                                                        label:
                                                            'Lihat peta ${destination.name}',
                                                        child: SizedBox(
                                                            height: 180,
                                                            child: Stack(
                                                                children: [
                                                                  Positioned.fill(
                                                                      child: IgnorePointer(
                                                                          child: DestinationLocationMap(
                                                                              key: ValueKey('${destination.latitude},${destination.longitude}'),
                                                                              point: LatLng(destination.latitude!, destination.longitude!)))),
                                                                  const Positioned(
                                                                    top: 12,
                                                                    right: 12,
                                                                    child: IgnorePointer(
                                                                        child: DecoratedBox(
                                                                      decoration: BoxDecoration(
                                                                          color: Colors
                                                                              .white,
                                                                          borderRadius:
                                                                              BorderRadius.all(Radius.circular(8))),
                                                                      child: Padding(
                                                                          padding: EdgeInsets.all(AppSpacing.sm),
                                                                          child: Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              Icon(PhosphorIconsRegular.arrowsOut, color: _C.blue),
                                                                              SizedBox(width: AppSpacing.xs),
                                                                              Text('Lihat peta', style: TextStyle(color: _C.navy))
                                                                            ],
                                                                          )),
                                                                    )),
                                                                  ),
                                                                ]))))),
                                            const SizedBox(
                                                height: AppSpacing.sm),
                                            OutlinedButton.icon(
                                                onPressed: widget
                                                            .adminPreview ||
                                                        _openingMap
                                                    ? null
                                                    : () =>
                                                        _openMap(destination),
                                                icon: const Icon(
                                                    PhosphorIconsRegular
                                                        .navigationArrow),
                                                label: const Text(
                                                    'Buka Google Maps')),
                                          ] else
                                            const Text(
                                                'Lokasi destinasi belum tersedia',
                                                style: TextStyle(
                                                    color: _C.textMuted,
                                                    fontSize: 12)),
                                        ])),
                                const SizedBox(height: AppSpacing.xl),
                                // Full width so the link sits at the right
                                // edge; it still wraps below at large text.
                                SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: AppSpacing.md,
                                      children: [
                                        _heading('Ulasan pengunjung'),
                                        if (destination.ratingCount > 0)
                                          TextButton(
                                              onPressed: _openReviews,
                                              child: const Text('Lihat Semua',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800)))
                                      ]),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (destination.ratingCount == 0)
                                  _contentCard(const Text(
                                      'Belum ada ulasan untuk destinasi ini.',
                                      style: TextStyle(
                                          color: _C.textMuted,
                                          fontSize: 12,
                                          height: 1.6)))
                                else
                                  Text(
                                      '$rating dari 5, ${destination.ratingCount} ulasan pengunjung',
                                      style: const TextStyle(
                                          color: _C.textMuted,
                                          fontSize: 12,
                                          height: 1.6)),
                              ]),
                        ))),
              ]),
        ),
      ),
    );
  }

  Future<void> _openMap(Destination destination) async {
    if (widget.adminPreview || !mounted || _openingMap) return;
    if (!destination.hasCoordinates) {
      _showSnack('Lokasi destinasi belum tersedia');
      return;
    }
    setState(() => _openingMap = true);
    final opened = await openDestinationDirections(destination);
    if (!mounted) return;
    setState(() => _openingMap = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Google Maps dan browser tidak dapat dibuka.'),
          action: SnackBarAction(
              label: 'Coba Lagi', onPressed: () => _openMap(destination))));
    }
  }

  void _viewMap(Destination destination) {
    if (widget.adminPreview) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DestinationMapScreen(destination: destination)));
  }

  void _book(Destination destination) {
    if (widget.adminPreview ||
        !destination.isActive ||
        destination.category?.isActive == false) {
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DaftarKunjunganScreen(
                wisata: Wisata.fromDestination(destination),
                repository: _repository)));
  }

  Widget _bookingBar(Destination destination) {
    final price = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Harga tiket / orang',
              style: TextStyle(color: _C.textMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.xs),
          Text(visitMoney(destination.ticketPrice, destination.currency),
              style: GoogleFonts.plusJakartaSans(
                  color: _C.navy, fontSize: 13, fontWeight: FontWeight.w800)),
        ]);
    final action = FilledButton(
        onPressed: !widget.adminPreview &&
                destination.isActive &&
                destination.category?.isActive != false
            ? () => _book(destination)
            : null,
        style: FilledButton.styleFrom(
            backgroundColor: _C.blue,
            minimumSize: const Size(140, 50),
            textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w800),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: Text(
            widget.adminPreview
                ? 'Daftar Kunjungan'
                : destination.isActive &&
                        destination.category?.isActive != false
                    ? 'Daftar Kunjungan'
                    : 'Tidak tersedia',
            textAlign: TextAlign.center));
    return Material(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: AppColors.dockShadow,
        surfaceTintColor: Colors.transparent,
        child: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19)
                    return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          price,
                          const SizedBox(height: AppSpacing.md),
                          action
                        ]);
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: price),
                        const SizedBox(width: AppSpacing.md),
                        ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth / 2),
                            child: action)
                      ]);
                }))));
  }

  Widget _topAction(String label, IconData icon, VoidCallback? onPressed,
          {bool busy = false}) =>
      Material(
          color: const Color(0xAA102D59),
          shape: const CircleBorder(),
          child: IconButton(
              tooltip: label,
              onPressed: onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(icon, color: Colors.white),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48)));
  Widget _contentCard(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: _C.card,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(AppSpacing.lg)),
      child: child);
  Widget _heading(String text) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          color: _C.navy, fontSize: 14, fontWeight: FontWeight.w700));
  Widget _location(String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(PhosphorIconsRegular.mapPin, color: _C.blue, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text.isEmpty ? 'Lokasi belum dicantumkan.' : text,
                style: const TextStyle(
                    color: _C.textMuted, fontSize: 12, height: 1.6)))
      ]);
  Widget _meta(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _C.blue, size: 16),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
            child: Text(text,
                style: GoogleFonts.plusJakartaSans(
                    color: _C.navy, fontSize: 11, fontWeight: FontWeight.w600)))
      ]));
  IconData _facilityIcon(String? key) => switch (key) {
        'parking' || 'local_parking' => PhosphorIconsRegular.car,
        'toilet' || 'wc' => PhosphorIconsRegular.toilet,
        'wifi' => PhosphorIconsRegular.wifiHigh,
        'restaurant' || 'food' => PhosphorIconsRegular.forkKnife,
        'prayer_room' || 'mosque' => PhosphorIconsRegular.mosque,
        'accessible' || 'wheelchair' => PhosphorIconsRegular.wheelchair,
        _ => PhosphorIconsRegular.checkCircle,
      };
}
