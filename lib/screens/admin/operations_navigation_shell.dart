import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/app_data.dart';
import '../../data/admin_state.dart';
import '../../data/approval_queue_state.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/floating_bottom_nav.dart';
import '../../widgets/operations_status.dart';
import 'admin_ticket_scanner_screen.dart';
import 'daftar_wisata_screen.dart';
import '../superadmin/destination_admin_assignments_screen.dart';
import '../superadmin/kelola_admin_screen.dart';
import '../superadmin/kelola_fasilitas_screen.dart';
import '../superadmin/kelola_kategori_screen.dart';
import 'operations_dashboard/operations_dashboard.dart';
import 'operations_queue_screen.dart';
import '../shared/session_destination.dart';

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
    final name = currentUser?.namaLengkap;
    const danger = Color(0xFFC85252);
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('Keluar dari Akun',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy))),
                        IconButton(
                            tooltip: 'Tutup',
                            onPressed: () => Navigator.pop(sheetContext, false),
                            style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFEEF3FA),
                                foregroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                      ]),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                border:
                                    Border.all(color: const Color(0xFFF3C9C9)),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(PhosphorIconsRegular.signOut,
                                size: 22, color: danger)),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('Akhiri sesi operasional?',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy))),
                      ]),
                      const SizedBox(height: 16),
                      Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Anda akan keluar dari akun '),
                            if (name != null && name.isNotEmpty)
                              TextSpan(
                                  text: name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                            if (name == null || name.isEmpty)
                              const TextSpan(text: 'ini'),
                            const TextSpan(
                                text:
                                    '. Pastikan pekerjaan yang sedang dilakukan sudah selesai.'),
                          ]),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                key: const ValueKey('operations-logout-cancel'),
                                onPressed: () =>
                                    Navigator.pop(sheetContext, false),
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    foregroundColor: AppColors.blue,
                                    side: const BorderSide(
                                        color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                child: const Text('Batal',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: FilledButton(
                                key:
                                    const ValueKey('operations-logout-confirm'),
                                onPressed: () =>
                                    Navigator.pop(sheetContext, true),
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    backgroundColor: danger,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                child: const Text('Ya, Keluar',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)))),
                      ]),
                    ]))));
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

  String get _initials {
    final words = (currentUser?.namaLengkap ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'SA';
    final letters = words.length == 1
        ? words.first.substring(0, words.first.length > 1 ? 2 : 1)
        : '${words.first[0]}${words[1][0]}';
    return letters.toUpperCase();
  }

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Email disalin')));
  }

  void _showAccessDetail() {
    const items = <(String, String)>[
      ('Cakupan data', 'Seluruh destinasi, tanpa batas penugasan'),
      ('Persetujuan booking',
          'Antrean global, termasuk mengalihkan ke admin lain'),
      ('Pengelolaan', 'Destinasi, kuota, akun admin, kategori, dan fasilitas'),
      ('Laporan', 'Perbandingan destinasi, kinerja admin, dan keuangan'),
    ];
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('Rincian Akses',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy))),
                        IconButton(
                            tooltip: 'Tutup',
                            onPressed: () => Navigator.pop(sheetContext),
                            style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFEEF3FA),
                                foregroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                      ]),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      for (final item in items) ...[
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.$1,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(item.$2,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy)),
                                ])),
                        const Divider(height: 1, color: AppColors.border),
                      ],
                    ]))));
  }

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20)),
      child: child);

  Widget _sectionTitle(String title, [String? trailing]) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
      ]);

  Widget _superadminProfile() {
    final name = currentUser?.namaLengkap ?? 'Superadmin';
    final email = currentUser?.email ?? '';
    return OperationsPage(
        role: 2,
        title: 'Profil',
        subtitle: 'Akun operasional Wisata Daerahku',
        children: [
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(children: [
                  Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.blueDeep,
                                Color(0xFF2077D6)
                              ])),
                      child: Text(_initials,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white))),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('AKUN OPERASIONAL',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .8,
                                color: AppColors.textMuted)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                      ])),
                ]),
                const SizedBox(height: AppSpacing.lg),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppColors.blueTint,
                            border: Border.all(color: const Color(0xFFC9DDF7)),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(PhosphorIconsRegular.shieldCheck,
                              size: 16, color: AppColors.blueDeep),
                          SizedBox(width: 6),
                          Text('Superadmin',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blueDeep)),
                        ]))),
                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Email akun',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(email.isEmpty ? '—' : email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                      ])),
                  const SizedBox(width: AppSpacing.md),
                  IconButton(
                      key: const ValueKey('operations-profile-copy-email'),
                      tooltip: 'Salin email',
                      onPressed: email.isEmpty ? null : () => _copyEmail(email),
                      style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: AppColors.blueTint,
                          foregroundColor: AppColors.blue,
                          side: const BorderSide(color: Color(0xFFC9DDF7)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      icon: const Icon(PhosphorIconsRegular.copy, size: 20)),
                ]),
              ])),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle('Hak Akses', 'Peran akun'),
          const SizedBox(height: AppSpacing.md),
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.blueTint,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(PhosphorIconsRegular.globe,
                          size: 22, color: AppColors.blue)),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Akses Global',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                            'Superadmin dapat mengakses cakupan operasional seluruh destinasi sesuai kebijakan sistem.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.textSecondary)),
                      ])),
                ]),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  const OperationsStatusBadge(
                      'Akses berdasarkan peran', OperationsTone.green,
                      small: true),
                  const Spacer(),
                  TextButton(
                      key: const ValueKey('operations-profile-access-detail'),
                      onPressed: _showAccessDetail,
                      style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: AppColors.blue),
                      child: const Text('Lihat rincian →',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800))),
                ]),
              ])),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle('Informasi Akun'),
          const SizedBox(height: AppSpacing.md),
          _card(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Column(children: [
                for (final (i, detail) in const [
                  ('Tipe akun', 'Operasional'),
                  ('Peran', 'Superadmin'),
                  ('Cakupan', 'Global'),
                ].indexed) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        Expanded(
                            child: Text(detail.$1,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary))),
                        Text(detail.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                      ])),
                ],
              ])),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
              key: const ValueKey('operations-profile-logout'),
              onPressed: _busy ? null : _logout,
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB23B3B),
                  backgroundColor: const Color(0xFFFDF1F1),
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Color(0xFFF3C9C9)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              icon: const Icon(PhosphorIconsRegular.signOut, size: 20),
              label: Text(_busy ? 'Keluar…' : 'Keluar dari Akun',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800))),
        ]);
  }

  @override
  Widget build(BuildContext context) => widget.session.role == 2
      ? _superadminProfile()
      : OperationsPage(
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
          ]);
}
