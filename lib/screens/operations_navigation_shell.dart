import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../data/app_data.dart';
import '../data/admin_state.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _tabTransition;
  late final Animation<double> _tabOpacity;
  late final Animation<Offset> _tabOffset;
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
    _tabTransition = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300), value: 1);
    _tabOpacity = _tabTransition.drive(CurveTween(curve: Curves.easeOut));
    _tabOffset = _tabOpacity
        .drive(Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero));
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
    _tabTransition.dispose();
    super.dispose();
  }

  Future<void> _select(int index) async {
    if (!_valid) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (index == 2 && _role == 1) {
      await showAdminTicketScannerSheet(context,
          repository: _repository, builder: widget.scannerBuilder);
      if (mounted && _valid) operationsDataChanges.value++;
      return;
    }
    if (index != _index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _tabTransition.value = 1;
      } else {
        _tabTransition.forward(from: 0);
      }
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
          repository: _repository,
          session: _session,
          active: _index == 0,
          onOpenQueue: () => _select(1),
          onOpenDestinations: () => _select(3)),
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
      _ => _OperationsProfile(
          repository: _repository,
          session: _session,
          onRefresh: _revalidateSession),
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
                : FadeTransition(
                    opacity: _tabOpacity,
                    child: SlideTransition(
                        position: _tabOffset,
                        child: IndexedStack(
                            index: _index,
                            children: List.generate(
                                5,
                                (i) => TickerMode(
                                    enabled: _index == i,
                                    child: KeyedSubtree(
                                        key: ValueKey(
                                            'operations-$_revision-$i'),
                                        child: _pages.contains(i)
                                            ? _page(i)
                                            : const SizedBox.shrink())))))),
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
              trailing: const Icon(PhosphorIconsRegular.caretRight,
                  color: AppColors.blue),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => page))));
}

class _OperationsProfile extends StatefulWidget {
  const _OperationsProfile(
      {required this.repository,
      required this.session,
      required this.onRefresh});
  final BusinessRepository repository;
  final AuthSession session;
  final Future<void> Function() onRefresh;
  @override
  State<_OperationsProfile> createState() => _OperationsProfileState();
}

class _OperationsProfileState extends State<_OperationsProfile> {
  bool _busy = false;
  bool _logoutDialogOpen = false;
  late final PagedListController<Destination> _destinations;

  @override
  void initState() {
    super.initState();
    _destinations = PagedListController<Destination>(
        session: widget.session,
        keyOf: (destination) => destination.guid,
        fetchPage: (page, _) => widget.repository.adminDestinations(query: {
              'page': '$page',
              'per_page': '100',
              'status': 'all',
            }))
      ..addListener(_changed);
    if (widget.session.role == 1) _destinations.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _destinations.removeListener(_changed);
    _destinations.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await widget.onRefresh();
    if (mounted && widget.session.role == 1) await _destinations.load();
  }

  Future<void> _logout() async {
    if (_busy || _logoutDialogOpen) return;
    final generation = widget.session.sessionGeneration;
    _logoutDialogOpen = true;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                  side: const BorderSide(color: AppColors.border)),
              title: const Text('Keluar dari akun?',
                  style: TextStyle(
                      color: AppColors.navy, fontWeight: FontWeight.w700)),
              content: const Text(
                  'Anda perlu masuk kembali untuk mengakses akun ini.',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.5)),
              actions: [
                TextButton(
                    key: const ValueKey('operations-logout-cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Batal')),
                TextButton(
                    key: const ValueKey('operations-logout-confirm'),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Keluar',
                        style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ));
    _logoutDialogOpen = false;
    if (confirmed != true ||
        !mounted ||
        !widget.session.isCurrentGeneration(generation) ||
        !widget.session.authenticated.value) return;
    setState(() => _busy = true);
    await widget.session.logout();
    if (mounted) setState(() => _busy = false);
  }

  String get _location {
    if (_destinations.loading) return 'Memuat destinasi…';
    if (_destinations.error != null) {
      return 'Belum tersedia · tarik untuk mencoba lagi';
    }
    if (_destinations.items.isEmpty) return 'Belum ada penugasan';
    return _destinations.items
        .map((destination) => destination.name)
        .join(' & ');
  }

  @override
  Widget build(BuildContext context) => OperationsPage(
          role: widget.session.role,
          onRefresh: widget.session.role == 1 ? _refresh : null,
          title: 'Profil',
          subtitle: 'Akun operasional Wisata Daerahku',
          children: [
            if (widget.session.role == 1) ...[
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Icon(PhosphorIconsRegular.userCircle,
                            size: 24, color: AppColors.blue)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(currentUser?.namaLengkap ?? 'Admin',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy)),
                          const SizedBox(height: 4),
                          Text(currentUser?.email ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          const Text('Admin · destinasi yang ditugaskan',
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textMuted)),
                        ])),
                  ])),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Akses akun',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy)),
                        for (final detail in [
                          ('Role', 'Admin'),
                          ('Cakupan', 'Destinasi assigned'),
                          ('Lokasi', _location),
                        ]) ...[
                          const Divider(height: 1, color: AppColors.border),
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Text(detail.$1,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        flex: 2,
                                        child: Text(detail.$2,
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.navy))),
                                  ])),
                        ],
                      ])),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  key: const ValueKey('operations-profile-logout'),
                  onPressed: _busy ? null : _logout,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      backgroundColor: AppColors.surface,
                      minimumSize: const Size(48, 48),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
                  label: Text(_busy ? 'Keluar…' : 'Keluar akun',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
            ],
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
            if (widget.session.role != 1) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                  onPressed: _busy ? null : _logout,
                  icon: const Icon(PhosphorIconsRegular.signOut),
                  label: Text(_busy ? 'Keluar…' : 'Keluar akun')),
            ],
          ]);
}
