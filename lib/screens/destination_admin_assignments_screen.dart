import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/business_repository.dart';
import '../theme/app_colors.dart';

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
        final data = await _repository.adminAccounts(query: {
          'role': '1',
          'status': 'all',
          'per_page': '100',
          'page': '$page'
        });
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

  @override
  Widget build(BuildContext context) => Theme(
      data: AppColors.visitorTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Penugasan Destinasi')),
        body: SafeArea(
            child: !_valid
                ? const Center(child: Text('Akses Superadmin diperlukan.'))
                : ListView(padding: const EdgeInsets.all(20), children: [
                    const Text(
                        'Pilih Admin yang boleh memindai tiket destinasi ini. Superadmin memiliki akses global.'),
                    const SizedBox(height: 20),
                    if (_loading)
                      const LinearProgressIndicator()
                    else if (_destinations.isEmpty)
                      const Text('Belum ada destinasi.')
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _destination,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Destinasi'),
                        items: _destinations
                            .map((d) => DropdownMenuItem(
                                value: d.guid,
                                child: Text(d.name,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (guid) {
                                if (guid != null) _select(guid);
                              },
                      ),
                    if (_destination != null &&
                        !_assignmentLoaded &&
                        _error == null)
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator())),
                    if (_assignmentLoaded) ...[
                      const SizedBox(height: 16),
                      if (_admins.isEmpty) const Text('Belum ada akun Admin.'),
                      for (final admin in _admins)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(admin.name),
                          subtitle: Text(
                              '${admin.email}${admin.isActive ? '' : ' · Nonaktif'}'),
                          value: _selected.contains(admin.guid),
                          onChanged: _saving ||
                                  (!admin.isActive &&
                                      !_selected.contains(admin.guid))
                              ? null
                              : (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(admin.guid);
                                    } else {
                                      _selected.remove(admin.guid);
                                    }
                                  }),
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                              _saving ? 'Menyimpan...' : 'Simpan Penugasan')),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      TextButton(
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
                    ],
                  ])),
      ));
}
