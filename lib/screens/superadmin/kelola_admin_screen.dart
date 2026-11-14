// ============================================================
// lib/screens/kelola_admin_screen.dart
// Kelola akun admin dari Laravel (khusus superadmin / role 2).
// Sumber akun adalah database Laravel, bukan Firebase.
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/app_data.dart';
import '../../data/business_repository.dart';
import '../../services/api_client.dart';
import '../../services/auth_session.dart';
import '../../widgets/select_sheet.dart';
import '../admin/admin_common.dart';

const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

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
  final _searchController = TextEditingController();
  String _query = '';
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
    _searchController.dispose();
    _guard
      ..removeListener(_changed)
      ..dispose();
    _list
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  /// All accounts are loaded once; search, role and status filter locally so
  /// the stat cards always describe the whole directory.
  Future<void> _muat() => _list.load(filters: const {});

  List<AdminAccount> get _filtered {
    final query = _query.trim().toLowerCase();
    return [
      for (final account in _list.items)
        if ((_role == null || account.role == _role) &&
            (_status == null || account.status == _status) &&
            (query.isEmpty ||
                account.name.toLowerCase().contains(query) ||
                account.email.toLowerCase().contains(query)))
          account
    ];
  }

  void _resetFilters() => setState(() {
        _query = '';
        _role = null;
        _status = null;
        _searchController.clear();
      });

  Future<void> _tambah() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _CreateAdminSheet(
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
    if (_guard.isBusy(account.guid) || !canModifyAccount(account, _ownGuid)) {
      return;
    }
    final suspend = account.isActive;
    final ok = await showConfirmSheet(context,
        title: suspend ? 'Tangguhkan Akun?' : 'Aktifkan Akun?',
        message: suspend
            ? '${account.name} tidak akan dapat masuk dan sesinya dicabut.'
            : '${account.name} dapat masuk kembali.',
        icon: suspend
            ? PhosphorIconsRegular.prohibit
            : PhosphorIconsRegular.checkCircle,
        confirmLabel: suspend ? 'Tangguhkan' : 'Aktifkan',
        cancelLabel: 'Batal',
        confirmColor: suspend ? AdminColors.danger : AdminColors.blue,
        emphasizeConfirm: true);
    if (!ok || !mounted) return;
    await _update(account, {'status': suspend ? 'suspended' : 'active'},
        suspend ? 'Akun ditangguhkan' : 'Akun diaktifkan');
  }

  Future<void> _changeRole(AdminAccount account) async {
    if (_guard.isBusy(account.guid) || !canModifyAccount(account, _ownGuid)) {
      return;
    }
    final role = await showSelectSheet<int>(context,
        title: 'Peran ${account.name}',
        subtitle: 'Pilih peran baru untuk akun ini',
        selected: account.role,
        options: [
          for (final value in [2, 1, 0])
            SelectOption(value, adminRoleLabel(value),
                description: switch (value) {
                  2 => 'Akses global ke seluruh destinasi',
                  1 => 'Hanya destinasi yang ditugaskan',
                  _ => 'Pengunjung biasa',
                }),
        ]);
    if (role == null || role == account.role || !mounted) return;
    final ok = await showConfirmSheet(context,
        title: 'Ubah Peran?',
        message:
            'Peran ${account.name} akan diubah menjadi ${adminRoleLabel(role)}. '
            'Sesi akun tersebut akan dicabut.',
        icon: PhosphorIconsRegular.arrowsLeftRight,
        confirmLabel: 'Ubah',
        cancelLabel: 'Batal',
        confirmColor: AdminColors.blue,
        emphasizeConfirm: true);
    if (!ok || !mounted) return;
    await _update(account, {'role': role}, 'Peran diperbarui');
  }

  Future<void> _openDetail(AdminAccount account) async {
    final own = !canModifyAccount(account, _ownGuid);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _AccountDetailSheet(account: account, own: own),
    );
    if (!mounted) return;
    if (action == 'role') {
      await _changeRole(account);
    } else if (action == 'status') {
      await _toggleStatus(account);
    }
  }

  // ── Build blocks ─────────────────────────────────────────
  Widget _statCard(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
          decoration: BoxDecoration(
              color: AdminColors.card,
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    color: AdminColors.navy,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
      );

  Widget _roleChip(int? value, String label) {
    final selected = _role == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          key: ValueKey('role-filter-${value ?? 'all'}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _role = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
                color: selected ? AdminColors.blue : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: selected ? AdminColors.blue : AdminColors.border)),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : AdminColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _statusSegments() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFE9EFF8),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final option in const [
            (null, 'Semua'),
            ('active', 'Aktif'),
            ('suspended', 'Ditangguhkan'),
          ])
            Expanded(
              child: Semantics(
                selected: _status == option.$1,
                button: true,
                child: GestureDetector(
                  key: ValueKey('status-filter-${option.$1 ?? 'all'}'),
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
                                ? AdminColors.navy
                                : AdminColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _emptyState() => CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Akun tidak ditemukan',
                style: TextStyle(
                    color: AdminColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Coba kata kunci atau filter lain.',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 12)),
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
              child: const Text('Reset filter'),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final allowed = canManageAdmins(_session.role);
    final items = _list.items;
    final shown = _filtered;
    final managers = items.where((a) => a.role >= 1).length;
    final active = items.where((a) => a.isActive).length;
    return AdminPage(
      title: 'Kelola Admin',
      subtitle: allowed
          ? '${_list.total ?? items.length} akun'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _muat : null,
      bottomBar: allowed
          ? AdminActionBar(
              note: 'Khusus akses\nSuperadmin',
              label: 'Tambah Admin',
              icon: PhosphorIconsRegular.userPlus,
              buttonKey: const ValueKey('add-admin'),
              onPressed: _tambah)
          : null,
      slivers: [
        if (!allowed)
          adminEmptySliver(PhosphorIconsRegular.lock, 'Akses ditolak',
              'Kelola Admin hanya untuk Super Administrator.')
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _statCard('${items.length}', 'Total akun'),
                        const SizedBox(width: 10),
                        _statCard('$managers', 'Pengelola'),
                        const SizedBox(width: 10),
                        _statCard('$active', 'Akun aktif'),
                      ]),
                ),
                const SizedBox(height: 20),
                const Text('Direktori Akun',
                    style: TextStyle(
                        color: AdminColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('Cari dan kelola akses pengguna terdaftar.',
                    style: TextStyle(
                        color: AdminColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminColors.border)),
                  child: TextField(
                    key: const ValueKey('account-search'),
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    style:
                        const TextStyle(fontSize: 14, color: AdminColors.navy),
                    decoration: InputDecoration(
                        hintText: 'Cari nama atau email...',
                        hintStyle: const TextStyle(
                            color: AdminColors.textMuted, fontSize: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        prefixIcon: const Icon(
                            PhosphorIconsRegular.magnifyingGlass,
                            color: AdminColors.blue,
                            size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                onPressed: () => setState(() {
                                      _query = '';
                                      _searchController.clear();
                                    }),
                                icon: const Icon(PhosphorIconsRegular.x,
                                    size: 18))),
                  ),
                ),
                const SizedBox(height: 20),
                _label('PERAN AKUN'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _roleChip(null, 'Semua peran'),
                    _roleChip(2, 'Superadmin'),
                    _roleChip(1, 'Admin'),
                    _roleChip(0, 'Pengguna'),
                  ]),
                ),
                const SizedBox(height: 20),
                _label('STATUS AKUN'),
                _statusSegments(),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(
                      child: Text('Daftar Akun',
                          style: TextStyle(
                              color: AdminColors.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800))),
                  Text('${shown.length} akun ditemukan',
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
                  for (final account in shown)
                    _AccountCard(
                      key: ValueKey(account.guid),
                      account: account,
                      own: !canModifyAccount(account, _ownGuid) &&
                          account.guid == _ownGuid,
                      busy: _guard.isBusy(account.guid),
                      onManage: () => _openDetail(account),
                    ),
              ]),
            ),
          ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final value = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return value.isEmpty ? '?' : value;
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {this.size = 48});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A93F0), Color(0xFF1558B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(_initials(name),
            style: TextStyle(
                color: Colors.white,
                fontSize: size * .36,
                fontWeight: FontWeight.w800)),
      );
}

List<Widget> _badges(AdminAccount a, {bool own = false}) => [
      AdminBadge(adminRoleLabel(a.role), AdminColors.blue),
      AdminBadge(
        a.isActive ? 'Aktif' : 'Ditangguhkan',
        a.isActive ? AdminColors.success : AdminColors.danger,
      ),
      if (own) const AdminBadge('Akun Anda', AdminColors.orange),
    ];

class _AccountCard extends StatelessWidget {
  final AdminAccount account;
  final bool own;
  final bool busy;
  final VoidCallback onManage;
  const _AccountCard({
    super.key,
    required this.account,
    required this.own,
    required this.busy,
    required this.onManage,
  });

  String get _note => own
      ? 'Akun terlindungi'
      : switch (account.role) {
          2 => 'Akun superadmin',
          1 => 'Akun pengelola',
          _ => 'Akun pengguna',
        };

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
          Row(children: [
            _Avatar(a.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Long names and similar emails must stay distinguishable,
                  // so the name gets two lines and the email wraps in full.
                  Text(a.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AdminColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(a.email,
                      style: const TextStyle(
                          color: AdminColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: _badges(a, own: own)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminColors.border),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text(_note,
                    style: const TextStyle(
                        color: AdminColors.textMuted, fontSize: 12))),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
            else
              Material(
                color: const Color(0xFFE8F3FF),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey('manage-${a.guid}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: onManage,
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: 44, minWidth: 64),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('Kelola Akun →',
                        style: TextStyle(
                            color: AdminColors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC3D0E3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Sheet: detail + actions for one account ──────────────────
class _AccountDetailSheet extends StatelessWidget {
  const _AccountDetailSheet({required this.account, required this.own});
  final AdminAccount account;
  final bool own;

  Widget _row(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AdminColors.border))),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 13))),
          Text(value,
              style: const TextStyle(
                  color: AdminColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final a = account;
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
                  child: Text('Detail Akun',
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
              _Avatar(a.name, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(
                              color: AdminColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(a.email,
                          style: const TextStyle(
                              color: AdminColors.textMuted, fontSize: 12)),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: _badges(a)),
            const SizedBox(height: 8),
            _row('Peran akun', adminRoleLabel(a.role)),
            _row('Status akses', a.isActive ? 'Aktif' : 'Ditangguhkan'),
            _row(
                'Lingkup akses',
                switch (a.role) {
                  2 => 'Global',
                  1 => 'Destinasi ditugaskan',
                  _ => 'Pengunjung',
                }),
            if (own) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF7EA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0AD))),
                child: const Text(
                    'Akun superadmin yang sedang digunakan dilindungi.',
                    style: TextStyle(
                        color: Color(0xFF98621E), fontSize: 12, height: 1.4)),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('role-${a.guid}'),
                  onPressed: own ? null : () => Navigator.pop(context, 'role'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.blue,
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: AdminColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  child: const Text('Ubah Peran'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('status-${a.guid}'),
                  onPressed:
                      own ? null : () => Navigator.pop(context, 'status'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          a.isActive ? AdminColors.danger : AdminColors.blue,
                      backgroundColor: own
                          ? null
                          : (a.isActive
                              ? const Color(0xFFFFF0F0)
                              : const Color(0xFFE8F3FF)),
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(
                          color: a.isActive
                              ? AdminColors.danger.withValues(alpha: .35)
                              : AdminColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  child: Text(a.isActive ? 'Tangguhkan' : 'Aktifkan'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Sheet: new admin (role 1) ────────────────────────────────
/// [onSubmit] returns an error message, null on success.
class _CreateAdminSheet extends StatefulWidget {
  final Future<String?> Function(Json fields) onSubmit;
  const _CreateAdminSheet({required this.onSubmit});

  @override
  State<_CreateAdminSheet> createState() => _CreateAdminSheetState();
}

class _CreateAdminSheetState extends State<_CreateAdminSheet> {
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

  InputDecoration _decoration(String hint) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.border));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AdminColors.textDim, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AdminColors.blue, width: 1.5)),
      errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AdminColors.danger)),
      focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AdminColors.danger, width: 1.5)),
    );
  }

  Widget _field(String label, Widget field) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label,
                style: const TextStyle(
                    color: AdminColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800))),
        field,
        const SizedBox(height: 16),
      ]);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .92),
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
                    const Expanded(
                        child: Text('Tambah Admin',
                            style: TextStyle(
                                color: AdminColors.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800))),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF0F3F8),
                          foregroundColor: AdminColors.textMuted),
                      icon: const Icon(PhosphorIconsRegular.x, size: 16),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _field(
                      'Nama lengkap',
                      TextFormField(
                        key: const ValueKey('admin-name'),
                        controller: _name,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(
                            color: AdminColors.navy, fontSize: 14),
                        decoration: _decoration('Nama admin'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      )),
                  _field(
                      'Email',
                      TextFormField(
                        key: const ValueKey('admin-email'),
                        controller: _email,
                        enabled: !_saving,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                            color: AdminColors.navy, fontSize: 14),
                        decoration: _decoration('admin@contoh.com'),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Email tidak valid'
                            : null,
                      )),
                  _field(
                      'Password',
                      TextFormField(
                        key: const ValueKey('admin-password'),
                        controller: _password,
                        enabled: !_saving,
                        obscureText: true,
                        style: const TextStyle(
                            color: AdminColors.navy, fontSize: 14),
                        decoration: _decoration('Minimal 8 karakter'),
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Minimal 8 karakter'
                            : null,
                      )),
                  _field(
                      'Konfirmasi password',
                      TextFormField(
                        key: const ValueKey('admin-confirmation'),
                        controller: _confirmation,
                        enabled: !_saving,
                        obscureText: true,
                        style: const TextStyle(
                            color: AdminColors.navy, fontSize: 14),
                        decoration: _decoration('Ulangi password'),
                        validator: (v) => v != _password.text
                            ? 'Konfirmasi tidak cocok'
                            : null,
                      )),
                  _field(
                      'Peran',
                      InputDecorator(
                        decoration: _decoration('').copyWith(
                            enabled: false,
                            suffixIcon: const Icon(
                                PhosphorIconsRegular.caretDown,
                                color: AdminColors.textMuted,
                                size: 18)),
                        child: const Text('Admin',
                            style: TextStyle(
                                color: AdminColors.navy, fontSize: 14)),
                      )),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCFE2F8))),
                    child: const Text(
                        'Admin hanya dapat mengakses destinasi yang ditugaskan kepadanya.',
                        style: TextStyle(
                            color: AdminColors.navy,
                            fontSize: 12,
                            height: 1.45)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AdminNotice(_error!),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AdminColors.blue,
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: AdminColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                        child: const Text('Batalkan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('admin-save'),
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
                            : const Text('Tambah Akun'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
