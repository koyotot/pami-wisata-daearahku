// ============================================================
// lib/screens/kelola_fasilitas_screen.dart
// Kelola fasilitas destinasi (khusus superadmin / role 2).
// Data dari Laravel: daftar (termasuk nonaktif), tambah, ubah,
// nonaktifkan, aktifkan kembali.
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/facility_state.dart';
import '../../data/business_repository.dart';
import '../../services/api_client.dart';
import '../../services/auth_session.dart';
import '../../widgets/select_sheet.dart' show showConfirmSheet;
import '../admin/admin_common.dart';

const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

class KelolaFasilitasScreen extends StatefulWidget {
  final BusinessRepository? repository;
  final AuthSession? session;
  const KelolaFasilitasScreen({super.key, this.repository, this.session});

  @override
  State<KelolaFasilitasScreen> createState() => _KelolaFasilitasScreenState();
}

class _KelolaFasilitasScreenState extends State<KelolaFasilitasScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<Facility> _list;
  final _guard = InFlightGuard();
  final _searchController = TextEditingController();
  String _query = '';
  String _status = 'all'; // all | active | inactive (disaring di perangkat)

  @override
  void initState() {
    super.initState();
    _list = PagedListController<Facility>(
      session: _session,
      keyOf: (facility) => facility.guid,
      fetchPage: (page, _) =>
          _repository.superadminFacilities(status: 'all', page: page, perPage: 50),
    )..addListener(_changed);
    _guard.addListener(_changed);
    _session.sessionChanges.addListener(_sessionChanged);
    if (_allowed) _muat();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (_session.authenticated.value &&
        _session.deviceSessionReady &&
        canManageFacilities(_session.role)) {
      _muat();
    }
  }

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_sessionChanged);
    _searchController.dispose();
    _guard
      ..removeListener(_changed)
      ..dispose();
    _list
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  bool get _allowed =>
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      canManageFacilities(_session.role);

  bool get _filtering => _query.trim().isNotEmpty || _status != 'all';

  List<Facility> get _filtered {
    final query = _query.trim().toLowerCase();
    return [
      for (final facility in _list.items)
        if ((_status == 'all' ||
                (_status == 'active') == facility.isActive) &&
            (query.isEmpty || facility.name.toLowerCase().contains(query)))
          facility,
    ];
  }

  void _resetFilters() => setState(() {
        _query = '';
        _status = 'all';
        _searchController.clear();
      });

  Future<void> _muat() async {
    if (_allowed) await _list.load(filters: {'status': 'all'});
  }

  Future<void> _form([Facility? facility]) async {
    if (!_allowed) return;
    final generation = _session.sessionGeneration;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _FacilityFormSheet(
        facility: facility,
        session: _session,
        onSubmit: (fields) async {
          try {
            if (!_allowed || !_session.isCurrentGeneration(generation)) {
              return 'Sesi telah berakhir. Silakan masuk kembali.';
            }
            if (facility == null) {
              await _repository.createFacility(fields);
            } else {
              await _repository.updateFacility(facility.guid, fields);
            }
            return null;
          } catch (e) {
            return adminErrorMessage(e);
          }
        },
      ),
    );
    if (saved == true && mounted && _session.isCurrentGeneration(generation)) {
      showAdminSnack(context,
          facility == null ? 'Fasilitas ditambahkan' : 'Fasilitas diperbarui');
      await _muat();
    }
  }

  Future<void> _openActions(Facility facility) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _FacilityActionSheet(facility: facility),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _form(facility);
    } else if (action == 'toggle') {
      await _toggle(facility);
    }
  }

  Future<void> _toggle(Facility facility) async {
    if (!_allowed || _guard.isBusy(facility.guid)) return;
    final generation = _session.sessionGeneration;
    final deactivate = facility.isActive;
    final ok = await showConfirmSheet(
      context,
      title: deactivate ? 'Nonaktifkan Fasilitas?' : 'Aktifkan Fasilitas?',
      message: deactivate
          ? '"${facility.name}" tidak akan tampil di destinasi maupun pilihan fasilitas. Relasi historis tetap disimpan.'
          : '"${facility.name}" akan tampil kembali pada destinasi yang masih memiliki relasi historis dan pilihan fasilitas.',
      confirmLabel: deactivate ? 'Nonaktifkan' : 'Aktifkan',
      cancelLabel: 'Batal',
      icon: deactivate
          ? PhosphorIconsRegular.eyeSlash
          : PhosphorIconsRegular.arrowCounterClockwise,
      confirmColor: deactivate ? AdminColors.danger : AdminColors.blue,
      emphasizeConfirm: !deactivate,
    );
    if (!ok ||
        !mounted ||
        !_allowed ||
        !_session.isCurrentGeneration(generation)) {
      return;
    }
    await _guard.run<void>(facility.guid, () async {
      try {
        if (deactivate) {
          await _repository.deactivateFacility(facility.guid);
        } else {
          await _repository.updateFacility(
              facility.guid, {'is_active': true, 'icon_key': null});
        }
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(
            context,
            deactivate
                ? 'Fasilitas dinonaktifkan'
                : 'Fasilitas diaktifkan kembali');
      } catch (e) {
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(context, adminErrorMessage(e), error: true);
      }
      if (mounted && _session.isCurrentGeneration(generation)) await _muat();
    });
  }

  // ── Build blocks ─────────────────────────────────────────
  Widget _searchField() => DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.border)),
        child: TextField(
          key: const ValueKey('facility-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(fontSize: 14, color: AdminColors.navy),
          decoration: InputDecoration(
              hintText: 'Cari nama fasilitas...',
              hintStyle:
                  const TextStyle(color: AdminColors.textMuted, fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  color: AdminColors.blue, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () => setState(() {
                        _query = '';
                        _searchController.clear();
                      }),
                      icon: const Icon(PhosphorIconsRegular.x, size: 18))),
        ),
      );

  Widget _statusSegments() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFE9EFF8),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final option in const [
            ('all', 'Semua'),
            ('active', 'Aktif'),
            ('inactive', 'Nonaktif'),
          ])
            Expanded(
              child: Semantics(
                selected: _status == option.$1,
                button: true,
                child: GestureDetector(
                  key: ValueKey('status-filter-${option.$1}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _status = option.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 46),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                        color: _status == option.$1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _status == option.$1
                            ? const [
                                BoxShadow(
                                    color: Color(0x14102D59),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ]
                            : null),
                    child: Text(option.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _status == option.$1
                                ? AdminColors.blue
                                : AdminColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _emptyState() {
    final filtering = _filtering;
    return CustomPaint(
      painter: const AdminDashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              filtering
                  ? PhosphorIconsRegular.magnifyingGlass
                  : PhosphorIconsRegular.bellSimple,
              size: 32,
              color: AdminColors.blue.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(filtering ? 'Tidak ada fasilitas yang cocok' : 'Belum ada fasilitas',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AdminColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              filtering
                  ? 'Coba dengan kata lain atau atur kembali filter.'
                  : 'Tambahkan fasilitas pertama untuk dipilih pada destinasi.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AdminColors.textMuted, fontSize: 12, height: 1.4)),
          if (filtering) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              key: const ValueKey('reset-filter'),
              onPressed: _resetFilters,
              style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.navy,
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AdminColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              child: const Text('Reset Filter'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _infoNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AdminColors.blue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.blue.withValues(alpha: 0.18))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(PhosphorIconsRegular.info, size: 18, color: AdminColors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
                'Fasilitas aktif dapat digunakan pada data destinasi. '
                'Nonaktifkan fasilitas untuk menghentikan pemilihan baru tanpa menghapus datanya.',
                style: TextStyle(
                    color: AdminColors.textMuted, fontSize: 12, height: 1.5)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    final items = _list.items;
    final shown = _filtered;
    final active = items.where((f) => f.isActive).length;
    return AdminPage(
      title: 'Kelola Fasilitas',
      subtitle: allowed
          ? '${_list.total ?? items.length} fasilitas'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _muat : null,
      bottomBar: allowed
          ? AdminActionBar(
              note: 'Master Data\nFasilitas Wisata',
              label: 'Tambah Fasilitas',
              icon: PhosphorIconsRegular.plus,
              buttonKey: const ValueKey('add-facility'),
              onPressed: () => _form())
          : null,
      slivers: [
        if (!allowed)
          adminEmptySliver(PhosphorIconsRegular.lock, 'Akses ditolak',
              'Kelola Fasilitas hanya untuk Super Administrator.')
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: AdminStatCard(
                                '${items.length}', 'Total fasilitas')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: AdminStatCard('$active', 'Aktif',
                                dotColor: AdminColors.success)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: AdminStatCard(
                                '${items.length - active}', 'Nonaktif',
                                dotColor: AdminColors.textDim)),
                      ]),
                ),
                const SizedBox(height: 20),
                const Text('Daftar Fasilitas',
                    style: TextStyle(
                        color: AdminColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text(
                    'Cari dan atur fasilitas yang dapat digunakan destinasi.',
                    style: TextStyle(
                        color: AdminColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                _searchField(),
                const SizedBox(height: 16),
                _statusSegments(),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(
                      child: Text('Fasilitas Terdaftar',
                          style: TextStyle(
                              color: AdminColors.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800))),
                  Text('${shown.length} ditemukan',
                      style: const TextStyle(
                          color: AdminColors.textMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 12),
                if (_list.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminNotice(items.isEmpty
                              ? adminErrorMessage(_list.error!)
                              : 'Gagal memuat ulang: ${adminErrorMessage(_list.error!)}'),
                          TextButton(
                              onPressed: _muat, child: const Text('Coba lagi')),
                        ]),
                  ),
                if (!_list.hasLoaded && _list.error == null)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AdminColors.blue)))
                else if (shown.isEmpty && _list.error == null)
                  _emptyState()
                else
                  for (final facility in shown)
                    _FacilityCard(
                      key: ValueKey(facility.guid),
                      facility: facility,
                      busy: _guard.isBusy(facility.guid),
                      onManage: () => _openActions(facility),
                    ),
                const SizedBox(height: 8),
                _infoNote(),
              ]),
            ),
          ),
      ],
    );
  }
}

class _FacilityIcon extends StatelessWidget {
  const _FacilityIcon({this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AdminColors.blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(PhosphorIconsRegular.bellSimple,
            color: AdminColors.blue, size: size * 0.45),
      );
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  final bool busy;
  final VoidCallback onManage;
  const _FacilityCard({
    super.key,
    required this.facility,
    required this.busy,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final active = facility.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: adminCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facility.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                AdminBadge(
                  active ? 'Aktif' : 'Nonaktif',
                  active ? AdminColors.success : AdminColors.textMuted,
                  icon: PhosphorIconsFill.circle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            Material(
              color: const Color(0xFFF0F3F8),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: ValueKey('actions-${facility.guid}'),
                borderRadius: BorderRadius.circular(12),
                onTap: onManage,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(PhosphorIconsBold.dotsThreeVertical,
                      color: AdminColors.textMuted, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the actions for one facility. Pops 'edit' or 'toggle'.
class _FacilityActionSheet extends StatelessWidget {
  const _FacilityActionSheet({required this.facility});
  final Facility facility;

  Widget _action(Key key, IconData icon, String label, Color color,
          String result, BuildContext context,
          {bool last = false}) =>
      InkWell(
        key: key,
        onTap: () => Navigator.pop(context, result),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AdminColors.border))),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),
            const Icon(PhosphorIconsRegular.caretRight,
                size: 14, color: AdminColors.textMuted),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final active = facility.isActive;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Kelola Fasilitas',
                      style: TextStyle(
                          color: AdminColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F3F8),
                    foregroundColor: AdminColors.textMuted),
                icon: const Icon(PhosphorIconsRegular.x, size: 16),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const _FacilityIcon(size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(facility.name,
                          style: const TextStyle(
                              color: AdminColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            _action(
                ValueKey('edit-${facility.guid}'),
                PhosphorIconsRegular.pencilSimple,
                'Edit Fasilitas',
                AdminColors.navy,
                'edit',
                context),
            _action(
                ValueKey('toggle-${facility.guid}'),
                active
                    ? PhosphorIconsRegular.eyeSlash
                    : PhosphorIconsRegular.arrowCounterClockwise,
                active ? 'Nonaktifkan Fasilitas' : 'Aktifkan Fasilitas',
                active ? AdminColors.danger : AdminColors.success,
                'toggle',
                context,
                last: true),
          ],
        ),
      ),
    );
  }
}

/// Create / edit bottom sheet. [onSubmit] returns an error message, or null on
/// success. The slug is derived by the server and never entered by the user.
class _FacilityFormSheet extends StatefulWidget {
  final Facility? facility;
  final Future<String?> Function(Json fields) onSubmit;
  final AuthSession session;
  const _FacilityFormSheet(
      {this.facility, required this.onSubmit, required this.session});

  @override
  State<_FacilityFormSheet> createState() => _FacilityFormSheetState();
}

class _FacilityFormSheetState extends State<_FacilityFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.facility?.name ?? '');
  late final int _generation = widget.session.sessionGeneration;
  late bool _active = widget.facility?.isActive ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    widget.session.sessionChanges.removeListener(_sessionChanged);
    _name.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.session.sessionChanges.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted && !widget.session.isCurrentGeneration(_generation)) {
      Navigator.pop(context, false);
    }
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit({
      'name': _name.text.trim(),
      'icon_key': null,
      'is_active': _active,
    });
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AdminColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.facility != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(editing ? 'Ubah Fasilitas' : 'Tambah Fasilitas',
                      style: const TextStyle(
                          color: AdminColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('facility-close'),
                  tooltip: 'Tutup',
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F3F8),
                      foregroundColor: AdminColors.textMuted),
                  icon: const Icon(PhosphorIconsRegular.x, size: 16),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                  editing
                      ? 'Perbarui informasi fasilitas wisata.'
                      : 'Lengkapi informasi fasilitas baru yang akan tersedia di data master wisata.',
                  style: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 13, height: 1.4)),
              const SizedBox(height: 20),
              _label('Nama fasilitas *'),
              TextFormField(
                key: const ValueKey('facility-name'),
                controller: _name,
                enabled: !_saving,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: adminInputDecoration(null, hint: 'Contoh: Area Parkir')
                    .copyWith(
                        hintStyle: const TextStyle(
                            color: AdminColors.textDim, fontSize: 14),
                        errorMaxLines: 2),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                    color: AdminColors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AdminColors.blue.withValues(alpha: 0.15))),
                child: Row(children: [
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status fasilitas',
                              style: TextStyle(
                                  color: AdminColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('Fasilitas dapat dipilih oleh admin destinasi.',
                              style: TextStyle(
                                  color: AdminColors.textMuted,
                                  fontSize: 12,
                                  height: 1.4)),
                        ]),
                  ),
                  Switch(
                    key: const ValueKey('facility-active'),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminNotice(_error!),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('facility-cancel'),
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.textMuted,
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AdminColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('facility-save'),
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: AdminColors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(editing ? 'Simpan Perubahan' : 'Tambah Fasilitas'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
