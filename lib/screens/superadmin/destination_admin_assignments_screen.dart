import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../../widgets/select_sheet.dart' show showConfirmSheet;
import '../admin/admin_common.dart';

/// Super admin: which Admin may manage (scan tickets for) which destination.
/// Two views over the same data: per Admin (editable, bottom sheet) and per
/// destination (read only, bottom sheet).
class DestinationAdminAssignmentsScreen extends StatefulWidget {
  const DestinationAdminAssignmentsScreen({super.key, this.repository});
  final BusinessRepository? repository;
  @override
  State<DestinationAdminAssignmentsScreen> createState() =>
      _DestinationAdminAssignmentsScreenState();
}

class _DestinationAdminAssignmentsScreenState
    extends State<DestinationAdminAssignmentsScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final int _generation;
  final _searchController = TextEditingController();

  List<Destination> _destinations = [];
  List<AdminAccount> _admins = [];

  /// destination guid → guids of the Admins assigned to it.
  Map<String, Set<String>> _assigned = {};
  String? _error;
  bool _loading = true;
  int _request = 0;

  bool _perAdmin = true;
  String _filter = 'all';
  String _query = '';
  String? _highlightAdmin;
  String? _highlightDestination;

  bool get _valid =>
      mounted &&
      _repository.api.session.isCurrentGeneration(_generation) &&
      _repository.api.session.role == 2;

  @override
  void initState() {
    super.initState();
    _generation = _repository.api.session.sessionGeneration;
    _repository.api.session.sessionChanges.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    ++_request;
    _searchController.dispose();
    _repository.api.session.sessionChanges.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (!_valid) {
        _admins = [];
        _destinations = [];
        _assigned = {};
      }
    });
  }

  // ── Data ─────────────────────────────────────────────────
  Future<void> _load() async {
    if (!_valid) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final destinations = <Destination>[];
      final admins = <AdminAccount>[];
      for (var page = 1;; page++) {
        final data = await _repository.adminDestinations(
            query: {'status': 'all', 'per_page': '100', 'page': '$page'});
        if (!_valid || request != _request) return;
        destinations.addAll(data.items);
        if (page >= (data.meta?['last_page'] as int? ?? 1)) break;
      }
      for (var page = 1;; page++) {
        final data = await _repository.adminAccounts(
            query: {'role': '1', 'per_page': '100', 'page': '$page'});
        if (!_valid || request != _request) return;
        admins.addAll(data.items);
        if (page >= (data.meta?['last_page'] as int? ?? 1)) break;
      }
      // The API only exposes assignments per destination.
      final assigned = <String, Set<String>>{};
      var failed = 0;
      for (var i = 0; i < destinations.length; i += 6) {
        final batch = destinations.skip(i).take(6).toList();
        final results = await Future.wait([
          for (final destination in batch)
            _repository
                .destinationAdmins(destination.guid)
                .then<List<String>?>((value) => value)
                .catchError((Object _) => null),
        ]);
        if (!_valid || request != _request) return;
        for (var j = 0; j < batch.length; j++) {
          final admins = results[j];
          if (admins == null) {
            failed++;
          } else {
            assigned[batch[j].guid] = admins.toSet();
          }
        }
      }
      if (!_valid || request != _request) return;
      setState(() {
        _destinations = destinations;
        _admins = admins;
        _assigned = assigned;
        if (failed > 0) {
          _error = '$failed destinasi gagal dimuat penugasannya. '
              'Jumlah penugasan mungkin belum lengkap.';
        }
      });
    } catch (e) {
      if (_valid && request == _request) {
        setState(() => _error = adminErrorMessage(e));
      }
    } finally {
      if (_valid && request == _request) setState(() => _loading = false);
    }
  }

  int _destinationCountOf(AdminAccount admin) =>
      _assigned.values.where((admins) => admins.contains(admin.guid)).length;

  Set<String> _destinationGuidsOf(AdminAccount admin) => {
        for (final entry in _assigned.entries)
          if (entry.value.contains(admin.guid)) entry.key
      };

  int _adminCountOf(Destination destination) =>
      (_assigned[destination.guid] ?? const <String>{})
          .where((guid) => _admins.any((a) => a.guid == guid))
          .length;

  /// Applies [target] (destination guids) to [admin]. Each destination's
  /// current set is re-read right before the PUT so another super admin's
  /// change to the same destination is not overwritten.
  Future<String?> _saveAdmin(AdminAccount admin, Set<String> target) async {
    if (!_valid) return 'Sesi telah berakhir.';
    final current = _destinationGuidsOf(admin);
    final changed =
        target.difference(current).union(current.difference(target));
    final failures = <String>[];
    for (final guid in changed) {
      try {
        final latest = (await _repository.destinationAdmins(guid)).toSet();
        if (target.contains(guid)) {
          latest.add(admin.guid);
        } else {
          latest.remove(admin.guid);
        }
        await _repository.assignDestinationAdmins(guid, latest.toList());
        if (!_valid) return 'Sesi telah berakhir.';
        _assigned[guid] = latest;
      } catch (_) {
        failures.add(_destinations
            .firstWhere((d) => d.guid == guid,
                orElse: () => Destination({'guid': guid, 'name': guid}))
            .name);
      }
    }
    if (mounted) setState(() {});
    if (failures.isEmpty) return null;
    return 'Gagal menyimpan: ${failures.join(', ')}. '
            '${failures.length < changed.length ? 'Sebagian perubahan sudah tersimpan.' : ''}'
        .trim();
  }

  // ── Sheets ───────────────────────────────────────────────
  Future<void> _openAdmin(AdminAccount admin) async {
    setState(() => _highlightAdmin = admin.guid);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AssignmentSheet(
        admin: admin,
        destinations: _destinations,
        initial: _destinationGuidsOf(admin),
        onSave: (target) => _saveAdmin(admin, target),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penugasan destinasi disimpan.')));
    }
  }

  Future<void> _openDestination(Destination destination) async {
    setState(() => _highlightDestination = destination.guid);
    final assigned = [
      for (final admin in _admins)
        if ((_assigned[destination.guid] ?? const <String>{})
            .contains(admin.guid))
          admin
    ];
    final action = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) =>
          _DestinationAccessSheet(destination: destination, admins: assigned),
    );
    if (!mounted || action == null) return;
    if (action is AdminAccount) {
      await _openAdmin(action);
    } else {
      setState(() {
        _perAdmin = true;
        _filter = 'all';
        _query = '';
        _searchController.clear();
      });
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

  Widget _tabs() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFE9EFF8),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final tab in const [
            (true, 'Kelola per Admin'),
            (false, 'Lihat per Destinasi')
          ])
            Expanded(
              child: Semantics(
                selected: _perAdmin == tab.$1,
                button: true,
                child: GestureDetector(
                  key: ValueKey(
                      'assignment-tab-${tab.$1 ? 'admin' : 'destination'}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_perAdmin == tab.$1) return;
                    setState(() {
                      _perAdmin = tab.$1;
                      _filter = 'all';
                      _query = '';
                      _searchController.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 46),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                        color: _perAdmin == tab.$1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _perAdmin == tab.$1
                            ? const [
                                BoxShadow(
                                    color: Color(0x14102D59),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ]
                            : null),
                    child: Text(tab.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _perAdmin == tab.$1
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

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          key: ValueKey('assignment-filter-$value'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _filter = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 36),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: selected ? const Color(0xFFE8F3FF) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? AdminColors.blue : AdminColors.border)),
            child: Text(label,
                style: TextStyle(
                    color: selected ? AdminColors.blue : AdminColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, {double size = 44}) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: const Color(0xFFE6F0FC),
          borderRadius: BorderRadius.circular(12)),
      child: Text(initials.isEmpty ? '?' : initials,
          style: const TextStyle(
              color: AdminColors.blue,
              fontSize: 13,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _row({
    required bool highlighted,
    required VoidCallback onTap,
    required Widget child,
    Key? key,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: highlighted ? const Color(0xFFE8F3FF) : Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: highlighted ? AdminColors.blue : Colors.transparent,
                  width: highlighted ? 1.2 : 0)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: child,
            ),
          ),
        ),
      );

  Widget _adminRow(AdminAccount admin) {
    final count = _destinationCountOf(admin);
    return _row(
      key: ValueKey('assignment-admin-${admin.guid}'),
      highlighted: _highlightAdmin == admin.guid,
      onTap: () => _openAdmin(admin),
      child: Row(children: [
        _avatar(admin.name),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(admin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AdminColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(admin.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                      color: admin.isActive
                          ? AdminColors.success
                          : AdminColors.textMuted,
                      shape: BoxShape.circle)),
              Text(admin.isActive ? 'Aktif' : 'Nonaktif',
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const Text('  ·  ',
                  style:
                      TextStyle(color: AdminColors.textMuted, fontSize: 11)),
              Text(count == 0 ? 'Belum ditugaskan' : '$count destinasi',
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        const Icon(PhosphorIconsRegular.caretRight,
            size: 16, color: AdminColors.textMuted),
      ]),
    );
  }

  Widget _destinationRow(Destination destination) {
    final count = _adminCountOf(destination);
    return _row(
      key: ValueKey('assignment-destination-${destination.guid}'),
      highlighted: _highlightDestination == destination.guid,
      onTap: () => _openDestination(destination),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(destination.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AdminColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
                destination.location.isEmpty
                    ? 'Lokasi belum dicantumkan'
                    : destination.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(count == 0 ? 'Belum ada admin' : '$count admin ditugaskan',
                style: TextStyle(
                    color:
                        count == 0 ? AdminColors.textMuted : AdminColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const Icon(PhosphorIconsRegular.caretRight,
            size: 16, color: AdminColors.textMuted),
      ]),
    );
  }

  Widget _listCard() {
    final query = _query.trim().toLowerCase();
    final admins = [
      for (final admin in _admins)
        if ((query.isEmpty ||
                admin.name.toLowerCase().contains(query) ||
                admin.email.toLowerCase().contains(query)) &&
            switch (_filter) {
              'active' => admin.isActive,
              'unassigned' => _destinationCountOf(admin) == 0,
              _ => true,
            })
          admin
    ];
    final destinations = [
      for (final destination in _destinations)
        if ((query.isEmpty ||
                destination.name.toLowerCase().contains(query) ||
                destination.location.toLowerCase().contains(query)) &&
            switch (_filter) {
              'active' => destination.isActive,
              'unassigned' => _adminCountOf(destination) == 0,
              _ => true,
            })
          destination
    ];
    final total = _perAdmin ? _admins.length : _destinations.length;
    final shown = _perAdmin ? admins.length : destinations.length;
    return Container(
      decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Expanded(
                child: Text(_perAdmin ? 'Daftar Admin' : 'Daftar Destinasi',
                    style: const TextStyle(
                        color: AdminColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F8),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_perAdmin ? '$total admin' : '$total destinasi',
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: const Color(0xFFF5F8FD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border)),
            child: TextField(
              key: const ValueKey('assignment-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 14, color: AdminColors.navy),
              decoration: InputDecoration(
                  hintText: _perAdmin
                      ? 'Cari nama atau email admin...'
                      : 'Cari nama destinasi...',
                  hintStyle: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('all', 'Semua'),
              _chip('active', 'Aktif'),
              _chip('unassigned', 'Tanpa penugasan'),
            ]),
          ),
        ),
        const Divider(height: 1, color: AdminColors.border),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: LinearProgressIndicator(color: AdminColors.blue))
        else if (shown == 0)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(
                  total == 0
                      ? (_perAdmin
                          ? 'Belum ada akun Admin.'
                          : 'Belum ada destinasi. Tambahkan destinasi terlebih dahulu.')
                      : 'Tidak ada hasil untuk pencarian atau filter ini.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AdminColors.textMuted, fontSize: 13)))
        else if (_perAdmin)
          for (final admin in admins) _adminRow(admin)
        else
          for (final destination in destinations) _destinationRow(destination),
        const SizedBox(height: 4),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) {
      return AdminPage(
          role: 2,
          title: 'Penugasan Destinasi',
          subtitle: 'Akses pemindaian tiket per destinasi',
          slivers: [
            adminEmptySliver(PhosphorIconsRegular.lockSimple,
                'Akses Superadmin diperlukan', 'Masuk sebagai Superadmin.')
          ]);
    }
    final assignedAdmins =
        _admins.where((admin) => _destinationCountOf(admin) > 0).length;
    return AdminPage(
      role: 2,
      title: 'Penugasan Destinasi',
      subtitle: 'Akses pemindaian tiket per destinasi',
      onRefresh: _load,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _statCard('${_admins.length}', 'Total admin'),
                      const SizedBox(width: 10),
                      _statCard('$assignedAdmins', 'Sudah ditugaskan'),
                      const SizedBox(width: 10),
                      _statCard('${_admins.length - assignedAdmins}',
                          'Belum ditugaskan'),
                    ]),
              ),
              const SizedBox(height: 16),
              _tabs(),
              const SizedBox(height: 16),
              if (_error != null) ...[
                AdminNotice(_error!),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: _load, child: const Text('Coba lagi')),
                ),
                const SizedBox(height: 8),
              ],
              _listCard(),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Sheet: edit one Admin's destinations ─────────────────────
class _AssignmentSheet extends StatefulWidget {
  const _AssignmentSheet({
    required this.admin,
    required this.destinations,
    required this.initial,
    required this.onSave,
  });
  final AdminAccount admin;
  final List<Destination> destinations;
  final Set<String> initial;
  final Future<String?> Function(Set<String> target) onSave;

  @override
  State<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<_AssignmentSheet> {
  late final Set<String> _selected = {...widget.initial};
  bool _saving = false;
  String? _error;

  int get _changes => _selected
      .difference(widget.initial)
      .union(widget.initial.difference(_selected))
      .length;

  Future<void> _save() async {
    if (_saving || _changes == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await widget.onSave({..._selected});
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = failure;
      });
    }
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (_changes == 0) {
      Navigator.pop(context);
      return;
    }
    final discard = await showConfirmSheet(context,
        title: 'Buang perubahan?',
        message: 'Perubahan penugasan belum disimpan.',
        confirmLabel: 'Buang',
        cancelLabel: 'Lanjut edit');
    if (discard && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.admin;
    return PopScope(
      canPop: _changes == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Penugasan Admin',
                          style: TextStyle(
                              color: AdminColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          '${admin.name} · pilih destinasi yang boleh dikelola',
                          style: const TextStyle(
                              color: AdminColors.textMuted, fontSize: 12)),
                      if (!admin.isActive) ...[
                        const SizedBox(height: 8),
                        const AdminNotice(
                            'Akun nonaktif: penugasan hanya dapat dilepas, tidak dapat ditambah.',
                            color: AdminColors.warning),
                      ],
                    ]),
              ),
              Flexible(
                child: widget.destinations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Belum ada destinasi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AdminColors.textMuted)))
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: widget.destinations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final destination = widget.destinations[index];
                          final checked = _selected.contains(destination.guid);
                          final locked =
                              _saving || (!admin.isActive && !checked);
                          return Material(
                            color: checked
                                ? const Color(0xFFE8F3FF)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: checked
                                        ? AdminColors.blue
                                        : AdminColors.border,
                                    width: checked ? 1.3 : 1)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: ValueKey('assign-${destination.guid}'),
                              onTap: locked
                                  ? null
                                  : () => setState(() {
                                        if (checked) {
                                          _selected.remove(destination.guid);
                                        } else {
                                          _selected.add(destination.guid);
                                        }
                                      }),
                              child: Opacity(
                                opacity: locked && !_saving ? .5 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    Checkbox(
                                        value: checked,
                                        activeColor: AdminColors.blue,
                                        onChanged: locked
                                            ? null
                                            : (_) => setState(() {
                                                  if (checked) {
                                                    _selected.remove(
                                                        destination.guid);
                                                  } else {
                                                    _selected
                                                        .add(destination.guid);
                                                  }
                                                })),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFE6F0FC),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: const Icon(
                                          PhosphorIconsRegular.mapPin,
                                          color: AdminColors.blue,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(destination.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: AdminColors.navy,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            const SizedBox(height: 2),
                                            Text(
                                                destination.location.isEmpty
                                                    ? 'Lokasi belum dicantumkan'
                                                    : destination.location,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color:
                                                        AdminColors.textMuted,
                                                    fontSize: 12)),
                                          ]),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }),
              ),
              const Divider(height: 1, color: AdminColors.border),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AdminNotice(_error!),
                        const SizedBox(height: 10),
                      ],
                      Text(
                          _changes == 0
                              ? '✓ Tidak ada perubahan'
                              : '$_changes perubahan belum disimpan',
                          style: TextStyle(
                              color: _changes == 0
                                  ? AdminColors.textMuted
                                  : AdminColors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            key: const ValueKey('assign-cancel'),
                            onPressed: _saving ? null : _cancel,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AdminColors.blue,
                                minimumSize: const Size.fromHeight(50),
                                side:
                                    const BorderSide(color: AdminColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800)),
                            child: const Text('Batalkan'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: FilledButton(
                            key: const ValueKey('assign-save'),
                            onPressed: _saving || _changes == 0 ? null : _save,
                            style: FilledButton.styleFrom(
                                backgroundColor: AdminColors.blue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800)),
                            child: Text(
                                _saving ? 'Menyimpan...' : 'Simpan Penugasan'),
                          ),
                        ),
                      ]),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheet: read-only view of one destination's Admins ────────
class _DestinationAccessSheet extends StatelessWidget {
  const _DestinationAccessSheet(
      {required this.destination, required this.admins});
  final Destination destination;
  final List<AdminAccount> admins;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final value = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return value.isEmpty ? '?' : value;
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Akses Destinasi',
                  style: TextStyle(
                      color: AdminColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Informasi penugasan — hanya lihat',
                  style:
                      TextStyle(color: AdminColors.textMuted, fontSize: 12)),
            ]),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE6F0FC),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(PhosphorIconsRegular.mapPin,
                        color: AdminColors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(destination.name,
                              style: const TextStyle(
                                  color: AdminColors.navy,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                              destination.location.isEmpty
                                  ? 'Lokasi belum dicantumkan'
                                  : destination.location,
                              style: const TextStyle(
                                  color: AdminColors.textMuted, fontSize: 12)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCFE2F8))),
                  child: const Text.rich(
                    TextSpan(
                        text:
                            'Daftar admin yang ditugaskan pada destinasi ini. Ubah akses dari menu ',
                        children: [
                          TextSpan(
                              text: 'Kelola per Admin',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: '.'),
                        ]),
                    style: TextStyle(
                        color: AdminColors.navy, fontSize: 12, height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(
                      child: Text('Admin yang Ditugaskan',
                          style: TextStyle(
                              color: AdminColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800))),
                  Text('${admins.length} orang',
                      style: const TextStyle(
                          color: AdminColors.textMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                if (admins.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Belum ada admin yang ditugaskan.',
                          style: TextStyle(
                              color: AdminColors.textMuted, fontSize: 13)))
                else
                  for (final admin in admins)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AdminColors.border))),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color(0xFFE6F0FC),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(_initials(admin.name),
                              style: const TextStyle(
                                  color: AdminColors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(admin.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AdminColors.navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    admin.isActive
                                        ? 'Admin aktif'
                                        : 'Admin nonaktif',
                                    style: const TextStyle(
                                        color: AdminColors.textMuted,
                                        fontSize: 12)),
                              ]),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: const Color(0xFFE8F3FF),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: ValueKey('access-manage-${admin.guid}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, admin),
                            child: Container(
                              constraints: const BoxConstraints(
                                  minHeight: 40, minWidth: 64),
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: const Text('Kelola',
                                  style: TextStyle(
                                      color: AdminColors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ]),
                    ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: OutlinedButton(
              key: const ValueKey('access-open-admin-tab'),
              onPressed: () => Navigator.pop(context, 'tab'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.navy,
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: AdminColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              child: const Text('Kelola Penugasan per Admin'),
            ),
          ),
        ],
      ),
    );
  }
}
