// ============================================================
// lib/screens/kelola_fasilitas_screen.dart
// Kelola fasilitas destinasi (khusus superadmin / role 2).
// Data dari Laravel: daftar (termasuk nonaktif), tambah, ubah,
// nonaktifkan, aktifkan kembali.
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../data/admin_state.dart';
import '../data/facility_state.dart';
import '../data/business_repository.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'admin_common.dart';

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
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _list = PagedListController<Facility>(
      session: _session,
      keyOf: (facility) => facility.guid,
      fetchPage: (page, filters) => _repository.superadminFacilities(
          status: filters['status'] ?? 'all', page: page, perPage: 50),
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

  Future<void> _muat() async {
    if (_allowed) await _list.load(filters: {'status': _status});
  }

  Future<void> _form([Facility? facility]) async {
    if (!_allowed) return;
    final generation = _session.sessionGeneration;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FacilityFormDialog(
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

  Future<void> _toggle(Facility facility) async {
    if (!_allowed || _guard.isBusy(facility.guid)) return;
    final generation = _session.sessionGeneration;
    final deactivate = facility.isActive;
    final ok = await adminConfirm(
      context,
      title: deactivate ? 'Nonaktifkan Fasilitas?' : 'Aktifkan Fasilitas?',
      message: deactivate
          ? '"${facility.name}" tidak akan tampil di destinasi maupun pilihan fasilitas. Relasi historis tetap disimpan.'
          : '"${facility.name}" akan tampil kembali pada destinasi yang masih memiliki relasi historis dan pilihan fasilitas.',
      confirmLabel: deactivate ? 'Nonaktifkan' : 'Aktifkan',
      danger: deactivate,
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

  @override
  Widget build(BuildContext context) {
    final items = _list.items;
    final allowed = _allowed;
    return AdminPage(
      badge: 'FASILITAS DESTINASI',
      title: 'Kelola Fasilitas',
      subtitle: allowed
          ? '${_list.total ?? items.length} fasilitas'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _muat : null,
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              key: const ValueKey('add-facility'),
              backgroundColor: AdminColors.blue,
              icon: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
              label: const Text('Tambah Fasilitas',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => _form(),
            )
          : null,
      slivers: [
        if (allowed)
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 8, children: [
              for (final status in {
                'all': 'Semua',
                'active': 'Aktif',
                'inactive': 'Nonaktif'
              }.entries)
                ChoiceChip(
                    label: Text(status.value),
                    selected: _status == status.key,
                    onSelected: (_) {
                      setState(() => _status = status.key);
                      _muat();
                    }),
            ]),
          )),
        if (!allowed)
          adminEmptySliver(PhosphorIconsRegular.lock, 'Akses ditolak',
              'Kelola Fasilitas hanya untuk Super Administrator.')
        else if (!_list.hasLoaded && _list.error == null)
          adminLoadingSliver()
        else if (_list.error != null && items.isEmpty)
          adminErrorSliver(adminErrorMessage(_list.error!), _muat)
        else if (items.isEmpty)
          adminEmptySliver(
              PhosphorIconsRegular.bellSimple,
              'Belum ada fasilitas',
              'Tambahkan fasilitas pertama untuk dipilih pada destinasi.')
        else ...[
          if (_list.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: AdminNotice(
                    'Gagal memuat ulang: ${adminErrorMessage(_list.error!)}'),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FacilityCard(
                  key: ValueKey(items[i].guid),
                  facility: items[i],
                  busy: _guard.isBusy(items[i].guid),
                  onEdit: () => _form(items[i]),
                  onToggle: () => _toggle(items[i]),
                ),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  const _FacilityCard({
    super.key,
    required this.facility,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final active = facility.isActive;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: adminCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AdminColors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(PhosphorIconsRegular.bellSimple,
                color: AdminColors.blue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facility.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(facility.slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AdminColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                AdminBadge(
                  active ? 'Aktif' : 'Nonaktif',
                  active ? AdminColors.success : AdminColors.textMuted,
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else ...[
            IconButton(
              key: ValueKey('edit-${facility.guid}'),
              tooltip: 'Ubah',
              onPressed: onEdit,
              icon: const Icon(PhosphorIconsRegular.pencilSimple,
                  color: Color(0xFFA78BFA), size: 20),
            ),
            IconButton(
              key: ValueKey('toggle-${facility.guid}'),
              tooltip: active ? 'Nonaktifkan' : 'Aktifkan kembali',
              onPressed: onToggle,
              icon: Icon(
                  active
                      ? PhosphorIconsRegular.eyeSlash
                      : PhosphorIconsRegular.arrowCounterClockwise,
                  color: active ? AdminColors.danger : AdminColors.success,
                  size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

/// Create / edit form. [onSubmit] returns an error message, or null on success.
class _FacilityFormDialog extends StatefulWidget {
  final Facility? facility;
  final Future<String?> Function(Json fields) onSubmit;
  final AuthSession session;
  const _FacilityFormDialog(
      {this.facility, required this.onSubmit, required this.session});

  @override
  State<_FacilityFormDialog> createState() => _FacilityFormDialogState();
}

class _FacilityFormDialogState extends State<_FacilityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.facility?.name ?? '');
  late final _slug = TextEditingController(text: widget.facility?.slug ?? '');
  late final int _generation = widget.session.sessionGeneration;
  late bool _active = widget.facility?.isActive ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    widget.session.sessionChanges.removeListener(_sessionChanged);
    _name.dispose();
    _slug.dispose();
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
      if (widget.facility == null && _slug.text.trim().isNotEmpty)
        'slug': _slug.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.facility != null;
    return AlertDialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(editing ? 'Ubah Fasilitas' : 'Tambah Fasilitas',
          style: const TextStyle(
              color: AdminColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('facility-name'),
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration:
                    adminInputDecoration('Nama', hint: 'Contoh: Parkir'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('facility-slug'),
                controller: _slug,
                enabled: !_saving && !editing,
                decoration: adminInputDecoration(
                    editing ? 'Slug (tetap)' : 'Slug (opsional)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: _active,
                onChanged:
                    _saving ? null : (value) => setState(() => _active = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminNotice(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13)),
        ),
        ElevatedButton(
          key: const ValueKey('facility-save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Simpan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}
