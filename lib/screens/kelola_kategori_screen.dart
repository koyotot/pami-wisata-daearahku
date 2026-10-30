// ============================================================
// lib/screens/kelola_kategori_screen.dart
// Kelola kategori destinasi (khusus superadmin / role 2).
// Data dari Laravel: daftar (termasuk nonaktif), tambah, ubah,
// nonaktifkan, aktifkan kembali.
// ============================================================
import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/business_repository.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'admin_common.dart';

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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(
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
      badge: 'KATEGORI DESTINASI',
      title: 'Kelola Kategori',
      subtitle: allowed
          ? '${_list.total ?? items.length} kategori'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _muat : null,
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              key: const ValueKey('add-category'),
              backgroundColor: AdminColors.blue,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Tambah Kategori',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => _form(),
            )
          : null,
      slivers: [
        if (!allowed)
          adminEmptySliver(Icons.lock_outline_rounded, 'Akses ditolak',
              'Kelola Kategori hanya untuk Super Administrator.')
        else if (!_list.hasLoaded && _list.error == null)
          adminLoadingSliver()
        else if (_list.error != null && items.isEmpty)
          adminErrorSliver(adminErrorMessage(_list.error!), _muat)
        else if (items.isEmpty)
          adminEmptySliver(Icons.category_outlined, 'Belum ada kategori',
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
            child: const Icon(Icons.category_rounded,
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
          else ...[
            IconButton(
              key: ValueKey('edit-${category.guid}'),
              tooltip: 'Ubah',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded,
                  color: Color(0xFFA78BFA), size: 20),
            ),
            IconButton(
              key: ValueKey('toggle-${category.guid}'),
              tooltip: active ? 'Nonaktifkan' : 'Aktifkan kembali',
              onPressed: onToggle,
              icon: Icon(
                  active ? Icons.visibility_off_rounded : Icons.restore_rounded,
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
class _CategoryFormDialog extends StatefulWidget {
  final Category? category;
  final Future<String?> Function(Json fields) onSubmit;
  const _CategoryFormDialog({this.category, required this.onSubmit});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _slug = TextEditingController(text: widget.category?.slug ?? '');
  late bool _slugEdited = widget.category != null;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  void _nameChanged(String value) {
    // Suggest a slug from the name until the admin edits the slug by hand.
    if (!_slugEdited) _slug.text = slugify(value);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit({
      'name': _name.text.trim(),
      'slug': _slug.text.trim(),
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
    return AlertDialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(editing ? 'Ubah Kategori' : 'Tambah Kategori',
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
                key: const ValueKey('category-name'),
                controller: _name,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: adminInputDecoration('Nama', hint: 'Contoh: Pantai'),
                onChanged: _nameChanged,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('category-slug'),
                controller: _slug,
                enabled: !_saving,
                decoration: adminInputDecoration('Slug', hint: 'contoh: pantai'),
                onChanged: (_) => _slugEdited = true,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Slug wajib diisi'
                    : null,
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
          key: const ValueKey('category-save'),
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
