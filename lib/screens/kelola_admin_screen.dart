// ============================================================
// lib/screens/kelola_admin_screen.dart
// Kelola akun admin dari Laravel (khusus superadmin / role 2).
// Sumber akun adalah database Laravel, bukan Firebase.
// ============================================================
import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'admin_common.dart';

class KelolaAdminScreen extends StatefulWidget {
  final BusinessRepository? repository;
  final AuthSession? session;

  /// GUID akun yang sedang masuk; default dari sesi saat ini.
  final String? ownGuid;
  const KelolaAdminScreen(
      {super.key, this.repository, this.session, this.ownGuid});

  @override
  State<KelolaAdminScreen> createState() => _KelolaAdminScreenState();
}

class _KelolaAdminScreenState extends State<KelolaAdminScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<AdminAccount> _list;
  final _guard = InFlightGuard();
  int? _role; // null = semua
  String? _status; // null = semua

  String? get _ownGuid => widget.ownGuid ?? currentUser?.id;

  @override
  void initState() {
    super.initState();
    _list = PagedListController<AdminAccount>(
      session: _session,
      keyOf: (account) => account.guid,
      fetchPage: (page, filters) => _repository.adminAccounts(
          query: {...filters, 'page': '$page', 'per_page': '50'}),
    )..addListener(_changed);
    _guard.addListener(_changed);
    _session.sessionChanges.addListener(_sessionChanged);
    if (canManageAdmins(_session.role)) _muat();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (_session.authenticated.value &&
        _session.deviceSessionReady &&
        canManageAdmins(_session.role)) {
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

  Future<void> _muat() => _list.load(filters: {
        if (_role != null) 'role': '$_role',
        if (_status != null) 'status': _status!,
      });

  Future<void> _tambah() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateAdminDialog(
        onSubmit: (fields) async {
          try {
            await _repository.createAdminAccount(fields);
            return null;
          } catch (e) {
            return adminErrorMessage(e);
          }
        },
      ),
    );
    if (saved == true && mounted) {
      showAdminSnack(context, 'Akun admin dibuat');
      await _muat();
    }
  }

  /// One PATCH per account at a time; the list is re-read from the server after.
  Future<void> _update(AdminAccount account, Json fields, String done) async {
    final generation = _session.sessionGeneration;
    await _guard.run<void>(account.guid, () async {
      try {
        await _repository.updateAdminAccount(account.guid, fields);
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(context, done);
      } catch (e) {
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(context, adminErrorMessage(e), error: true);
      }
      if (mounted && _session.isCurrentGeneration(generation)) await _muat();
    });
  }

  Future<void> _toggleStatus(AdminAccount account) async {
    if (_guard.isBusy(account.guid) ||
        !canModifyAccount(account, _ownGuid)) {
      return;
    }
    final suspend = account.isActive;
    final ok = await adminConfirm(
      context,
      title: suspend ? 'Tangguhkan Akun?' : 'Aktifkan Akun?',
      message: suspend
          ? '${account.name} tidak akan dapat masuk dan sesinya dicabut.'
          : '${account.name} dapat masuk kembali.',
      confirmLabel: suspend ? 'Tangguhkan' : 'Aktifkan',
      danger: suspend,
    );
    if (!ok || !mounted) return;
    await _update(
        account,
        {'status': suspend ? 'suspended' : 'active'},
        suspend ? 'Akun ditangguhkan' : 'Akun diaktifkan');
  }

  Future<void> _changeRole(AdminAccount account) async {
    if (_guard.isBusy(account.guid) ||
        !canModifyAccount(account, _ownGuid)) {
      return;
    }
    final role = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AdminColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Peran ${account.name}',
            style: const TextStyle(
                color: AdminColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        children: [
          for (final value in [2, 1, 0])
            SimpleDialogOption(
              key: ValueKey('role-$value'),
              onPressed: () => Navigator.pop(ctx, value),
              child: Row(children: [
                Icon(
                    value == account.role
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: AdminColors.blue,
                    size: 20),
                const SizedBox(width: 10),
                Text(adminRoleLabel(value)),
              ]),
            ),
        ],
      ),
    );
    if (role == null || role == account.role || !mounted) return;
    final ok = await adminConfirm(
      context,
      title: 'Ubah Peran?',
      message:
          'Peran ${account.name} akan diubah menjadi ${adminRoleLabel(role)}. '
          'Sesi akun tersebut akan dicabut.',
      confirmLabel: 'Ubah',
    );
    if (!ok || !mounted) return;
    await _update(account, {'role': role}, 'Peran diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    final items = _list.items;
    final allowed = canManageAdmins(_session.role);
    return AdminPage(
      badge: 'AKUN ADMINISTRATOR',
      title: 'Kelola Admin',
      subtitle: allowed
          ? '${_list.total ?? items.length} akun'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _muat : null,
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              key: const ValueKey('add-admin'),
              backgroundColor: AdminColors.blue,
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  color: Colors.white),
              label: const Text('Tambah Admin',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: _tambah,
            )
          : null,
      slivers: [
        if (allowed) ...[
          SliverToBoxAdapter(
            child: AdminFilterChips<int?>(
              options: const [
                ('Semua peran', null),
                ('Superadmin', 2),
                ('Admin', 1),
                ('Pengguna', 0),
              ],
              selected: _role,
              onSelected: (value) {
                if (value == _role) return;
                setState(() => _role = value);
                _muat();
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AdminFilterChips<String?>(
              options: const [
                ('Semua status', null),
                ('Aktif', 'active'),
                ('Ditangguhkan', 'suspended'),
              ],
              selected: _status,
              onSelected: (value) {
                if (value == _status) return;
                setState(() => _status = value);
                _muat();
              },
            ),
          ),
        ],
        if (!allowed)
          adminEmptySliver(Icons.lock_outline_rounded, 'Akses ditolak',
              'Kelola Admin hanya untuk Super Administrator.')
        else if (!_list.hasLoaded && _list.error == null)
          adminLoadingSliver()
        else if (_list.error != null && items.isEmpty)
          adminErrorSliver(adminErrorMessage(_list.error!), _muat)
        else if (items.isEmpty)
          adminEmptySliver(Icons.group_off_rounded, 'Tidak ada akun',
              'Tidak ada akun yang cocok dengan filter ini.')
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
                (_, i) => _AccountCard(
                  key: ValueKey(items[i].guid),
                  account: items[i],
                  own: !canModifyAccount(items[i], _ownGuid) &&
                      items[i].guid == _ownGuid,
                  modifiable: canModifyAccount(items[i], _ownGuid),
                  busy: _guard.isBusy(items[i].guid),
                  onRole: () => _changeRole(items[i]),
                  onStatus: () => _toggleStatus(items[i]),
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

class _AccountCard extends StatelessWidget {
  final AdminAccount account;
  final bool own;
  final bool modifiable;
  final bool busy;
  final VoidCallback onRole;
  final VoidCallback onStatus;
  const _AccountCard({
    super.key,
    required this.account,
    required this.own,
    required this.modifiable,
    required this.busy,
    required this.onRole,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final a = account;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: adminCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A93F0), Color(0xFF1558B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AdminColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(a.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AdminColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            AdminBadge(adminRoleLabel(a.role), AdminColors.blue,
                icon: Icons.shield_rounded),
            AdminBadge(
              a.isActive ? 'Aktif' : 'Ditangguhkan',
              a.isActive ? AdminColors.success : AdminColors.danger,
            ),
            if (own) const AdminBadge('Akun Anda', AdminColors.orange),
          ]),
          if (modifiable) ...[
            const SizedBox(height: 10),
            if (busy)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('role-${a.guid}'),
                    onPressed: onRole,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Ubah Peran'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('status-${a.guid}'),
                    onPressed: onStatus,
                    icon: Icon(
                        a.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16),
                    label: Text(a.isActive ? 'Tangguhkan' : 'Aktifkan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          a.isActive ? AdminColors.danger : AdminColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
          ],
        ],
      ),
    );
  }
}

/// New admin (role 1). [onSubmit] returns an error message, null on success.
class _CreateAdminDialog extends StatefulWidget {
  final Future<String?> Function(Json fields) onSubmit;
  const _CreateAdminDialog({required this.onSubmit});

  @override
  State<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<_CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit({
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'password_confirmation': _confirmation.text,
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
    return AlertDialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Tambah Admin',
          style: TextStyle(
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
                key: const ValueKey('admin-name'),
                controller: _name,
                enabled: !_saving,
                decoration: adminInputDecoration('Nama'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('admin-email'),
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: adminInputDecoration('Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Email tidak valid'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('admin-password'),
                controller: _password,
                enabled: !_saving,
                obscureText: true,
                decoration: adminInputDecoration('Password'),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Minimal 8 karakter'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('admin-confirmation'),
                controller: _confirmation,
                enabled: !_saving,
                obscureText: true,
                decoration: adminInputDecoration('Konfirmasi password'),
                validator: (v) =>
                    v != _password.text ? 'Konfirmasi tidak cocok' : null,
              ),
              const SizedBox(height: 10),
              const Text('Akun baru dibuat dengan peran Admin.',
                  style:
                      TextStyle(color: AdminColors.textMuted, fontSize: 11.5)),
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
          key: const ValueKey('admin-save'),
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
              : const Text('Buat',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}
