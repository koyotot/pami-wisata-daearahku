import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../admin/admin_common.dart';

class DestinationAdminAssignmentsScreen extends StatefulWidget {
  const DestinationAdminAssignmentsScreen({super.key});
  @override
  State<DestinationAdminAssignmentsScreen> createState() =>
      _DestinationAdminAssignmentsScreenState();
}

class _DestinationAdminAssignmentsScreenState
    extends State<DestinationAdminAssignmentsScreen> {
  final _repository = BusinessRepository();
  late final int _generation;
  List<Destination> _destinations = [];
  List<AdminAccount> _admins = [];
  final Set<String> _selected = {};
  String? _destination;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _assignmentLoaded = false;
  int _request = 0;
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

  void _changed() {
    if (mounted) {
      setState(() {
        if (!_valid) {
          _admins = [];
          _destinations = [];
          _selected.clear();
        }
      });
    }
  }

  Future<void> _load() async {
    if (!_valid) return;
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
        if (!_valid) return;
        destinations.addAll(data.items);
        if (page >= (data.meta?['last_page'] as int? ?? 1)) break;
      }
      for (var page = 1;; page++) {
        final data = await _repository.adminAccounts(
            query: {'role': '1', 'per_page': '100', 'page': '$page'});
        if (!_valid) return;
        admins.addAll(data.items);
        if (page >= (data.meta?['last_page'] as int? ?? 1)) break;
      }
      if (_valid) {
        setState(() {
          _destinations = destinations;
          _admins = admins;
        });
      }
    } catch (e) {
      if (_valid) setState(() => _error = adminErrorMessage(e));
    } finally {
      if (_valid) setState(() => _loading = false);
    }
  }

  Future<void> _select(String guid) async {
    final request = ++_request;
    setState(() {
      _destination = guid;
      _assignmentLoaded = false;
      _selected.clear();
      _error = null;
    });
    try {
      final admins = await _repository.destinationAdmins(guid);
      if (_valid && request == _request) {
        setState(() {
          _selected.addAll(admins);
          _assignmentLoaded = true;
        });
      }
    } catch (e) {
      if (_valid && request == _request) {
        setState(() => _error = adminErrorMessage(e));
      }
    }
  }

  Future<void> _save() async {
    if (!_valid || _saving || !_assignmentLoaded || _destination == null) {
      return;
    }
    final guid = _destination!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.assignDestinationAdmins(guid, _selected.toList());
      if (!mounted || !_valid) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penugasan destinasi disimpan.')));
      await _select(guid);
    } catch (e) {
      if (_valid) setState(() => _error = adminErrorMessage(e));
    } finally {
      if (_valid) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    ++_request;
    _repository.api.session.sessionChanges.removeListener(_changed);
    super.dispose();
  }

  Widget _section(String title, String? caption, List<Widget> children) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption,
                style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 12.5,
                    height: 1.45)),
          ],
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _adminTile(AdminAccount admin) {
    final checked = _selected.contains(admin.guid);
    final locked = _saving || (!admin.isActive && !checked);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AdminColors.blue,
      title: Text(admin.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AdminColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
      subtitle: Text('${admin.email}${admin.isActive ? '' : ' · Nonaktif'}',
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 12.5)),
      value: checked,
      onChanged: locked
          ? null
          : (value) => setState(() {
                if (value == true) {
                  _selected.add(admin.guid);
                } else {
                  _selected.remove(admin.guid);
                }
              }),
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
    final children = <Widget>[
      const Text(
          'Pilih Admin yang boleh memindai tiket destinasi ini. Superadmin memiliki akses global.',
          style: TextStyle(
              color: AdminColors.textMuted, fontSize: 13, height: 1.5)),
      const SizedBox(height: 16),
      if (_loading)
        const LinearProgressIndicator(color: AdminColors.blue)
      else if (_destinations.isEmpty && _error == null)
        _section('Belum ada destinasi',
            'Tambahkan destinasi terlebih dahulu sebelum menugaskan Admin.', [])
      else if (_destinations.isNotEmpty)
        DropdownButtonFormField<String>(
          icon: const Icon(PhosphorIconsRegular.caretDown,
              color: AdminColors.blue),
          initialValue: _destination,
          isExpanded: true,
          decoration:
              adminInputDecoration('Destinasi', hint: 'Pilih destinasi'),
          items: _destinations
              .map((d) => DropdownMenuItem(
                  value: d.guid,
                  child: Text(d.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _saving
              ? null
              : (guid) {
                  if (guid != null) _select(guid);
                },
        ),
      if (_destination != null && !_assignmentLoaded && _error == null)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: AdminColors.blue))),
      if (_assignmentLoaded) ...[
        const SizedBox(height: 16),
        _section(
            'Admin bertugas',
            _admins.isEmpty
                ? null
                : '${_selected.length} dari ${_admins.length} Admin dipilih',
            [
              if (_admins.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('Belum ada akun Admin.',
                        style: TextStyle(
                            color: AdminColors.textMuted, fontSize: 13)))
              else
                for (final admin in _admins) _adminTile(admin),
            ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan Penugasan',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 16),
        AdminNotice(_error!),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      if (_destination != null) {
                        _select(_destination!);
                      } else {
                        _load();
                      }
                    },
              child: const Text('Coba lagi')),
        ),
      ],
    ];
    return AdminPage(
      role: 2,
      title: 'Penugasan Destinasi',
      subtitle: 'Akses pemindaian tiket per destinasi',
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }
}
