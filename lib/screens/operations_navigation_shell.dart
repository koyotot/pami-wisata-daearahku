import 'package:flutter/material.dart';
import '../data/app_data.dart';
import '../data/approval_queue_state.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_bottom_nav.dart';
import 'admin_ticket_scanner_screen.dart';
import 'daftar_wisata_screen.dart';
import 'destination_admin_assignments_screen.dart';
import 'kelola_admin_screen.dart';
import 'kelola_fasilitas_screen.dart';
import 'kelola_kategori_screen.dart';
import 'operations_dashboard.dart';
import 'operations_queue_screen.dart';
import 'session_destination.dart';
import 'tambah_wisata_screen.dart';

class OperationsNavigationShell extends StatefulWidget {
  const OperationsNavigationShell(
      {super.key, this.repository, this.session, this.scannerBuilder});
  final BusinessRepository? repository;
  final AuthSession? session;
  final WidgetBuilder? scannerBuilder;
  @override
  State<OperationsNavigationShell> createState() =>
      _OperationsNavigationShellState();
}

class _OperationsNavigationShellState extends State<OperationsNavigationShell>
    with WidgetsBindingObserver {
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final int _generation = _session.sessionGeneration;
  late final int? _role = _session.role;
  final Set<int> _pages = {};
  int _index = 0;
  int _revision = 0;
  bool _accessChanged = false;
  bool _checkingSession = false;
  bool _redirecting = false;
  bool get _valid =>
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      _session.isCurrentGeneration(_generation) &&
      _session.role == _role &&
      (_role == 1 || _role == 2);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.sessionChanges.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (_valid) {
      setState(() {
        _pages.clear();
        _revision++;
        _accessChanged = !_checkingSession;
      });
      return;
    }
    if (!_valid && !_redirecting) {
      _pages.clear();
      _redirecting = true;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                  builder: (_) => sessionDestination(session: _session)),
              (_) => false);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _valid) {
      _revalidateSession();
    }
  }

  Future<void> _revalidateSession() async {
    if (_checkingSession) return;
    _checkingSession = true;
    try {
      await _session.me();
    } catch (_) {
      // AuthSession handles invalid sessions; report screens handle read errors.
    } finally {
      _checkingSession = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _select(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (index == 2 && _role == 1) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: widget.scannerBuilder ??
              (_) => const AdminTicketScannerScreen()));
      if (mounted && _valid) operationsDataChanges.value++;
      return;
    }
    setState(() {
      _index = index;
      _accessChanged = false;
    });
  }

  Widget _page(int index) {
    _pages.add(index);
    return switch (index) {
      0 => OperationsDashboard(
          repository: _repository, session: _session, active: _index == 0),
      1 => OperationsQueueScreen(
          repository: _repository,
          session: _session,
          embedded: true,
          active: _index == 1),
      2 => OperationsAnalyticsHub(
          repository: _repository, session: _session, active: _index == 2),
      3 => _role == 1
          ? OperationsReportScreen(
              section: 'destinations',
              repository: _repository,
              session: _session,
              embedded: true,
              active: _index == 3)
          : _ManagementPage(repository: _repository, session: _session),
      _ => _OperationsProfile(session: _session, onRefresh: _revalidateSession),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) {
      return sessionDestination(session: _session);
    }
    if (!_accessChanged) _page(_index);
    return Theme(
        data: _role == 1 ? AppColors.operationsTheme : AppColors.visitorTheme,
        child: PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _select(0);
          },
          child: Scaffold(
            extendBody: true,
            body: _accessChanged
                ? OperationsPage(
                    role: _role,
                    onRefresh: _role == 1 ? () => _select(_index) : null,
                    title: 'Akses diperbarui',
                    subtitle: 'Data operasional sebelumnya telah dibersihkan.',
                    children: [
                        const Text(
                            'Pilih ulang destinasi atau muat data sesuai akses terbaru.'),
                        if (_role != 1)
                          TextButton(
                              onPressed: () => _select(_index),
                              child: const Text('Muat sesuai akses terbaru')),
                      ])
                : IndexedStack(
                    index: _index,
                    children: List.generate(
                        5,
                        (i) => KeyedSubtree(
                            key: ValueKey('operations-$_revision-$i'),
                            child: _pages.contains(i)
                                ? _page(i)
                                : const SizedBox.shrink()))),
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : FloatingBottomNav(
                    index: _index, onSelected: _select, operationsRole: _role),
          ),
        ));
  }
}

class _ManagementPage extends StatelessWidget {
  const _ManagementPage({required this.repository, required this.session});
  final BusinessRepository repository;
  final AuthSession session;
  @override
  Widget build(BuildContext context) => OperationsPage(
          title: 'Kelola',
          subtitle: 'Destinasi dan akses operasional',
          children: [
            _link(context, 'Destinasi', 'Lihat dan kelola destinasi',
                DaftarWisataScreen(repository: repository, session: session)),
            _link(
                context,
                'Ubah destinasi',
                'Edit data destinasi',
                DaftarWisataScreen(
                    mode: 'edit', repository: repository, session: session)),
            _link(
                context,
                'Hapus destinasi',
                'Kelola penghapusan destinasi',
                DaftarWisataScreen(
                    mode: 'hapus', repository: repository, session: session)),
            _link(context, 'Tambah destinasi', 'Buat destinasi wisata',
                const TambahWisataScreen()),
            _link(
                context,
                'Kuota kunjungan',
                'Kapasitas dan jadwal booking',
                DaftarWisataScreen(
                    mode: 'kuota', repository: repository, session: session)),
            if (session.role == 2) ...[
              _link(context, 'Penugasan Admin', 'Atur Admin per destinasi',
                  const DestinationAdminAssignmentsScreen()),
              _link(context, 'Akun Admin', 'Kelola akses akun operasional',
                  KelolaAdminScreen(repository: repository, session: session)),
              _link(
                  context,
                  'Kategori',
                  'Kelola kategori destinasi',
                  KelolaKategoriScreen(
                      repository: repository, session: session)),
              _link(
                  context,
                  'Fasilitas',
                  'Kelola fasilitas destinasi',
                  KelolaFasilitasScreen(
                      repository: repository, session: session)),
              _link(
                  context,
                  'Aktivitas audit',
                  'Ketersediaan riwayat aktivitas',
                  const OperationsUnavailableScreen(audit: true)),
            ],
          ]);
  Widget _link(
          BuildContext context, String title, String subtitle, Widget page) =>
      Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              title: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              subtitle: Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, height: 1.5, color: Color(0xFF526787))),
              trailing: const Icon(Icons.chevron_right, color: AppColors.blue),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => page))));
}

class _OperationsProfile extends StatefulWidget {
  const _OperationsProfile({required this.session, required this.onRefresh});
  final AuthSession session;
  final Future<void> Function() onRefresh;
  @override
  State<_OperationsProfile> createState() => _OperationsProfileState();
}

class _OperationsProfileState extends State<_OperationsProfile> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => OperationsPage(
          role: widget.session.role,
          onRefresh: widget.session.role == 1 ? widget.onRefresh : null,
          title: 'Profil',
          subtitle: 'Akun operasional Wisata Daerahku',
          children: [
            if (widget.session.role == 1)
              Card(
                  elevation: 0,
                  color: AppColors.surface,
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.person_outline,
                                color: AppColors.blue, size: 32),
                            const SizedBox(height: 16),
                            Text(currentUser?.namaLengkap ?? 'Admin',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(currentUser?.email ?? ''),
                            const SizedBox(height: 16),
                            const Text('Admin · Role 1',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            const Text(
                                'Akses hanya untuk destinasi yang ditugaskan oleh Superadmin.'),
                          ]))),
            if (widget.session.role != 1) ...[
              Text(currentUser?.namaLengkap ?? 'Akun operasional',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(currentUser?.email ?? ''),
              const SizedBox(height: 8),
              Text(widget.session.role == 2
                  ? 'Superadmin · akses global'
                  : 'Admin · destinasi yang ditugaskan'),
            ],
            SizedBox(height: widget.session.role == 1 ? 24 : 32),
            ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await widget.session.logout();
                        if (mounted) setState(() => _busy = false);
                      },
                icon: const Icon(Icons.logout),
                label: Text(_busy ? 'Keluar…' : 'Keluar akun')),
          ]);
}
