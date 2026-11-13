// ============================================================
// lib/screens/kelola_kategori_screen.dart
// Kelola kategori destinasi (khusus superadmin / role 2).
// Data dari Laravel: daftar (termasuk nonaktif), tambah, ubah,
// nonaktifkan, aktifkan kembali.
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../../services/api_client.dart';
import '../../services/auth_session.dart';
import '../admin/admin_common.dart';

class KelolaKategoriScreen extends StatefulWidget {
  final BusinessRepository? repository;
  final AuthSession? session;
  const KelolaKategoriScreen({super.key, this.repository, this.session});

  @override
  State<KelolaKategoriScreen> createState() => _KelolaKategoriScreenState();
}

class _KelolaKategoriScreenState extends State<KelolaKategoriScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<Category> _list;
  final _guard = InFlightGuard();

  @override
  void initState() {
    super.initState();
    _list = PagedListController<Category>(
      session: _session,
      keyOf: (category) => category.guid,
      fetchPage: (page, _) => _repository.adminCategories(
          query: {'status': 'all', 'page': '$page', 'per_page': '50'}),
    )..addListener(_changed);
    _guard.addListener(_changed);
    _session.sessionChanges.addListener(_sessionChanged);
    if (canManageCategories(_session.role)) _muat();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (_session.authenticated.value &&
        _session.deviceSessionReady &&
        canManageCategories(_session.role)) {
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

  Future<void> _muat() => _list.load();

  Future<void> _form([Category? category]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AdminColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CategoryFormSheet(
        category: category,
        onSubmit: (fields) async {
          try {
            if (category == null) {
              await _repository.createCategory(fields);
            } else {
              await _repository.updateCategory(category.guid, fields);
            }
            return null;
          } catch (e) {
            return adminErrorMessage(e);
          }
        },
      ),
    );
    if (saved == true && mounted) {
      showAdminSnack(context,
          category == null ? 'Kategori ditambahkan' : 'Kategori diperbarui');
      await _muat();
    }
  }

  Future<void> _toggle(Category category) async {
    if (_guard.isBusy(category.guid)) return;
    final deactivate = category.isActive;
    final ok = await adminConfirm(
      context,
      title: deactivate ? 'Nonaktifkan Kategori?' : 'Aktifkan Kategori?',
      message: deactivate
          ? '"${category.name}" tidak akan tampil lagi sebagai pilihan kategori.'
          : '"${category.name}" akan tampil kembali sebagai pilihan kategori.',
      confirmLabel: deactivate ? 'Nonaktifkan' : 'Aktifkan',
      danger: deactivate,
    );
    if (!ok || !mounted) return;
    final generation = _session.sessionGeneration;
    await _guard.run<void>(category.guid, () async {
      try {
        if (deactivate) {
          await _repository.deactivateCategory(category.guid);
        } else {
          await _repository.reactivateCategory(category.guid);
        }
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(
            context,
            deactivate
                ? 'Kategori dinonaktifkan'
                : 'Kategori diaktifkan kembali');
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
    final allowed = canManageCategories(_session.role);
    return AdminPage(
      title: 'Kelola Kategori',
      subtitle: allowed
          ? '${_list.total ?? items.length} kategori'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _muat : null,
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              key: const ValueKey('add-category'),
              backgroundColor: AdminColors.blue,
              icon: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
              label: const Text('Tambah Kategori',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => _form(),
            )
          : null,
      slivers: [
        if (!allowed)
          adminEmptySliver(PhosphorIconsRegular.lock, 'Akses ditolak',
              'Kelola Kategori hanya untuk Super Administrator.')
        else if (!_list.hasLoaded && _list.error == null)
          adminLoadingSliver()
        else if (_list.error != null && items.isEmpty)
          adminErrorSliver(adminErrorMessage(_list.error!), _muat)
        else if (items.isEmpty)
          adminEmptySliver(
              PhosphorIconsRegular.squaresFour,
              'Belum ada kategori',
              'Tambahkan kategori untuk mengelompokkan destinasi.')
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
                (_, i) => _CategoryCard(
                  key: ValueKey(items[i].guid),
                  category: items[i],
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

class _CategoryCard extends StatelessWidget {
  final Category category;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  const _CategoryCard({
    super.key,
    required this.category,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final active = category.isActive;
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
            child: const Icon(PhosphorIconsRegular.squaresFour,
                color: AdminColors.blue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(category.slug,
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
          else
            AdminRowMenu(
              id: category.guid,
              active: active,
              onEdit: onEdit,
              onToggle: onToggle,
            ),
        ],
      ),
    );
  }
}

/// Create / edit bottom sheet. [onSubmit] returns an error message, or null
/// on success. The slug isn't editable: new categories get one derived from
/// the name, edits keep the existing slug.
class _CategoryFormSheet extends StatefulWidget {
  final Category? category;
  final Future<String?> Function(Json fields) onSubmit;
  const _CategoryFormSheet({this.category, required this.onSubmit});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _name.text.trim();
    final error = await widget.onSubmit({
      'name': name,
      'slug': widget.category?.slug ?? slugify(name),
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
    final editing = widget.category != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(editing ? 'Ubah Kategori' : 'Tambah Kategori',
                      style: const TextStyle(
                          color: AdminColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('category-close'),
                  tooltip: 'Tutup',
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                  style: IconButton.styleFrom(
                      backgroundColor: AdminColors.bg,
                      foregroundColor: AdminColors.textMuted),
                  icon: const Icon(PhosphorIconsRegular.x, size: 16),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                  editing
                      ? 'Perbarui nama kategori destinasi.'
                      : 'Kategori dipakai untuk mengelompokkan destinasi.',
                  style: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              // Label above the field, helper text below it.
              const Text('Nama Kategori',
                  style: TextStyle(
                      color: AdminColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('category-name'),
                controller: _name,
                enabled: !_saving,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration:
                    adminInputDecoration(null, hint: 'Contoh: Wisata Pantai')
                        .copyWith(
                  helperText: 'Nama yang tampil sebagai pilihan kategori.',
                  helperMaxLines: 2,
                  helperStyle: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 12),
                  errorMaxLines: 2,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminNotice(_error!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('category-save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
