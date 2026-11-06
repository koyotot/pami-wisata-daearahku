import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/admin_state.dart';
import '../data/approval_queue_state.dart';
import '../data/business_repository.dart';
import '../data/operational_models.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../theme/app_colors.dart';
import '../widgets/operations_chrome.dart';
import 'admin_ticket_scanner_screen.dart';
import 'daftar_wisata_screen.dart';
import 'tambah_wisata_screen.dart';
import 'daftar_pendaftar_screen.dart';
import 'operations_booking_screen.dart';
import 'operations_queue_screen.dart';

part 'operations_reports.dart';
part 'operations_filters.dart';
part 'operations_presentation.dart';
part 'operations_financial.dart';

class OperationsPage extends StatelessWidget {
  const OperationsPage(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children,
      this.onRefresh,
      this.bottomBar,
      this.role,
      this.actions = const [],
      this.embedded = true});
  final String title;
  final String subtitle;
  final Widget? bottomBar;
  final int? role;
  final List<Widget> children;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final content = ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _DashboardHero(
              title: title,
              subtitle: subtitle,
              onBack: embedded ? null : () => Navigator.maybePop(context),
              actions: actions,
              role: role),
          Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  (role ?? AuthSession.instance.role) == 1 && !embedded
                      ? 24
                      : 128),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children)),
        ]);
    return OperationsTheme(
        role: role ?? AuthSession.instance.role,
        child: Scaffold(
            bottomNavigationBar: bottomBar,
            backgroundColor: AppColors.bg,
            body: AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark),
                child: SafeArea(
                    top: false,
                    bottom: false,
                    child: onRefresh == null
                        ? content
                        : RefreshIndicator(
                            onRefresh: onRefresh!, child: content)))));
  }
}

class OperationsDashboard extends StatefulWidget {
  const OperationsDashboard(
      {super.key, this.repository, this.session, this.active = true});
  final BusinessRepository? repository;
  final AuthSession? session;
  final bool active;
  @override
  State<OperationsDashboard> createState() => _OperationsDashboardState();
}

class _OperationsDashboardState extends State<OperationsDashboard>
    with WidgetsBindingObserver {
  late final _session = widget.session ?? AuthSession.instance;
  late final _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final _generation = _session.sessionGeneration;
  late final _role = _session.role;
  OperationalReport? _data;
  OperationalReport? _approvals;
  List<OperationalRow> _actions = [];
  Object? _error;
  bool _loading = true;
  bool _personal = false;
  int _request = 0;
  Map<String, String> _filters = {};
  bool get _valid =>
      mounted &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      _session.isCurrentGeneration(_generation) &&
      _session.role == _role &&
      (_role == 1 || _role == 2);
  @override
  void initState() {
    super.initState();
    _session.sessionChanges.addListener(_sessionChanged);
    operationsDataChanges.addListener(_dataChanged);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _sessionChanged() {
    if (mounted) {
      setState(() {
        _request++;
        _data = null;
        _approvals = null;
        _actions = [];
        _loading = false;
        _error ??= const ApiException(
            'Akses diperbarui. Muat ulang data sesuai akses terbaru.');
      });
    }
  }

  void _dataChanged() {
    if (!_valid) return;
    if (widget.active && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _load();
    } else {
      _sessionChanged();
    }
  }

  @override
  void didUpdateWidget(OperationsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _load();
  }

  @override
  void dispose() {
    _request++;
    _session.sessionChanges.removeListener(_sessionChanged);
    operationsDataChanges.removeListener(_dataChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_valid || !widget.active) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _approvals = null;
      _actions = [];
    });
    try {
      final data =
          await _repository.operationalReport('overview', query: _filters);
      if (!_valid || request != _request) return;
      final actions = await _repository.operationalRows('action-center',
          query: {..._filters, 'per_page': '3'});
      if (!_valid || request != _request) return;
      final approvals = _role == 2
          ? await _repository.operationalReport('approvals', query: _filters)
          : null;
      if (!_valid || request != _request) return;
      setState(() {
        _data = data;
        _actions = actions.items;
        _approvals = approvals;
        _loading = false;
      });
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
        if (_scopeError(e)) _filters = {};
      });
      if (_scopeError(e)) _session.me().catchError((Object _) {});
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (_valid) await _load();
  }

  Future<void> _filter() async {
    final result = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: _filters,
        utc: true);
    if (result != null && _valid) {
      _filters = result;
      await _load();
    }
  }

  Widget _actionCenter(OperationalReport data) => _DashboardActionCenter(
      pending: _value(data.metrics['pending_approvals']),
      executive: _role == 2,
      hasActions: _actions.isNotEmpty,
      onOpen: () => _open(OperationsReportScreen(
          section: 'action-center',
          initialFilters: _filters,
          repository: _repository,
          session: _session)));

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    final data = _data;
    final metrics = _personal ? data?.personal : data?.metrics;
    final noAssignment = !_loading &&
        _error == null &&
        _role == 1 &&
        _number(data?.metrics['assigned_destinations']) == 0;
    return OperationsTheme(
        role: _role,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            child: Scaffold(
              backgroundColor: AppColors.bg,
              body: SafeArea(
                  top: false,
                  bottom: false,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 128),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _DashboardHero(
                          executive: _role == 2,
                          role: _role,
                          onActions: noAssignment
                              ? null
                              : () => _open(OperationsReportScreen(
                                  section: 'action-center',
                                  initialFilters: _filters,
                                  repository: _repository,
                                  session: _session)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_loading)
                                  const OperationsSkeleton()
                                else if (_error != null) ...[
                                  _errorBlock(_error!,
                                      _scopeError(_error) ? _filter : _load,
                                      role: _role),
                                  const SizedBox(height: 16),
                                  OperationsFinancialScreen(
                                      key: ValueKey('finance-$_request'),
                                      repository: _repository,
                                      session: _session,
                                      preview: true,
                                      active: widget.active),
                                ] else if (noAssignment) ...[
                                  const _NoAssignmentState(),
                                  const SizedBox(height: 16),
                                  OperationsFinancialScreen(
                                      key: ValueKey('finance-$_request'),
                                      repository: _repository,
                                      session: _session,
                                      preview: true,
                                      active: widget.active),
                                ] else if (data != null) ...[
                                  if (_role == 1) ...[
                                    SegmentedButton<bool>(
                                      showSelectedIcon: false,
                                      style: SegmentedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFE4ECF8),
                                        selectedBackgroundColor: Colors.white,
                                        selectedForegroundColor:
                                            AppColors.blueDeep,
                                        foregroundColor:
                                            const Color(0xFF526787),
                                        side: BorderSide.none,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      segments: const [
                                        ButtonSegment(
                                            value: false,
                                            label: Text('Destinasi')),
                                        ButtonSegment(
                                            value: true,
                                            label: Text('Kinerja Saya')),
                                      ],
                                      selected: {_personal},
                                      onSelectionChanged: (s) =>
                                          setState(() => _personal = s.first),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _ScopeCard(
                                    executive: _role == 2,
                                    label: _filters['destination_guid'] != null
                                        ? 'Destinasi terpilih'
                                        : _role == 2
                                            ? 'Seluruh destinasi'
                                            : 'Semua destinasi saya',
                                    detail: _role == 2
                                        ? 'Scope global · ${_period(data.period)}'
                                        : 'Scope penugasan · ${_period(data.period)}',
                                    onTap: _filter,
                                  ),
                                  const SizedBox(height: 12),
                                  if (_role == 1) ...[
                                    _DashboardCard(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                          Text(
                                              _personal
                                                  ? 'Keputusan pribadi'
                                                  : 'Prioritas persetujuan',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 12),
                                          Text(
                                              _personal
                                                  ? _value(data.personal[
                                                      'approved_decisions'])
                                                  : _value(data.metrics[
                                                      'pending_approvals']),
                                              style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w800)),
                                          Text(
                                              _personal
                                                  ? 'Booking disetujui pada periode ini'
                                                  : 'Booking menunggu keputusan',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                              onPressed: () => _open(_personal
                                                  ? OperationsReportScreen(
                                                      section: 'approvals',
                                                      personal: true,
                                                      repository: _repository,
                                                      session: _session,
                                                      initialFilters: _filters)
                                                  : OperationsQueueScreen(
                                                      repository: _repository,
                                                      session: _session,
                                                      filters: _filters)),
                                              child: Text(_personal
                                                  ? 'Lihat kinerja saya'
                                                  : 'Tinjau antrean')),
                                        ])),
                                    const SizedBox(height: 12),
                                  ],
                                  OperationsMetrics(
                                    values: _personal
                                        ? (_role == 1
                                            ? _decisionValues(metrics ?? {})
                                                .skip(1)
                                                .toList()
                                            : _decisionValues(metrics ?? {}))
                                        : [
                                            if (_role == 1) ...[
                                              (
                                                'Destinasi ditugaskan',
                                                _value(metrics?[
                                                    'assigned_destinations'])
                                              ),
                                              (
                                                'Claim saya',
                                                _value(data.assignedWorkload[
                                                    'personal_claims'])
                                              ),
                                              (
                                                'Disetujui',
                                                _value(metrics?[
                                                    'approved_decisions'])
                                              ),
                                              (
                                                'Kepatuhan SLA',
                                                _percent(metrics?[
                                                    'sla_compliance_percent'])
                                              ),
                                            ] else ...[
                                              (
                                                _role == 2
                                                    ? 'Pending global'
                                                    : 'Pending approval',
                                                _value(metrics?[
                                                    'pending_approvals'])
                                              ),
                                              (
                                                _role == 2
                                                    ? 'Destinasi global'
                                                    : 'Destinasi ditugaskan',
                                                _value(metrics?[
                                                    'assigned_destinations'])
                                              ),
                                              (
                                                'Disetujui',
                                                _value(metrics?[
                                                    'approved_decisions'])
                                              ),
                                              (
                                                'Ditolak',
                                                _value(metrics?[
                                                    'rejected_decisions'])
                                              ),
                                            ],
                                          ],
                                    icons: _role == 1
                                        ? null
                                        : _personal
                                            ? const [
                                                Icons.task_alt_rounded,
                                                Icons.cancel_outlined,
                                                Icons.percent_rounded,
                                                Icons.timer_outlined,
                                                Icons.verified_outlined
                                              ]
                                            : const [
                                                Icons.schedule_rounded,
                                                Icons.place_outlined,
                                                Icons.task_alt_rounded,
                                                Icons.cancel_outlined,
                                              ],
                                    metadata: _role == 1
                                        ? null
                                        : _personal
                                            ? null
                                            : [
                                                'Snapshot saat ini',
                                                _role == 2
                                                    ? 'Seluruh destinasi'
                                                    : 'Dalam penugasan',
                                                'Periode keputusan',
                                                'Periode keputusan',
                                              ],
                                  ),
                                  if (_personal) ...[
                                    const SizedBox(height: 12),
                                    _Notice(
                                        'Claim aktif saya saat ini: ${_value(data.assignedWorkload['personal_claims'])}. Riwayat keputusan pribadi mencakup penugasan sebelumnya.'),
                                    if (_role != 1)
                                      _routeLink(
                                          'Lihat kinerja saya',
                                          () => _open(OperationsReportScreen(
                                              section: 'approvals',
                                              initialFilters: _filters,
                                              personal: true,
                                              repository: _repository,
                                              session: _session))),
                                  ],
                                  const SizedBox(height: 16),
                                  if (_role != 1 || !_personal)
                                    _actionCenter(data),
                                  const SizedBox(height: 16),
                                  if (_role != 1 || !_personal)
                                    OperationsFinancialScreen(
                                        key: ValueKey('finance-$_request'),
                                        repository: _repository,
                                        session: _session,
                                        preview: true,
                                        active: widget.active),
                                  const SizedBox(height: 12),
                                  if (_approvals != null) ...[
                                    _DashboardCard(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _SectionTitle(
                                            'Tren Keputusan Tim'),
                                        Text(
                                            'Keputusan tim · UTC · ${_period(_approvals!.period)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF526787))),
                                        OperationsTrend(
                                            rows: _approvals!.series,
                                            valueKey: 'approved_decisions',
                                            secondKey: 'rejected_decisions'),
                                        const Text(
                                            'Biru: disetujui · abu-abu: ditolak',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF526787))),
                                        _routeLink(
                                            'Lihat kinerja tim',
                                            () => _open(OperationsReportScreen(
                                                section: 'approvals',
                                                initialFilters: _filters,
                                                repository: _repository,
                                                session: _session))),
                                      ],
                                    )),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_role != 1 || !_personal)
                                    _DashboardCard(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _SectionTitle(
                                            'Aktivitas booking'),
                                        const Text(
                                            'Booking dibuat · tanggal UTC',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF526787))),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Periode: ${_period(data.period)} · basis dibuat (UTC)',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                                color: Color(0xFF526787))),
                                        OperationsTrend(
                                            rows: data.bookingTrend,
                                            valueKey: 'bookings',
                                            bars: true),
                                      ],
                                    )),
                                  const SizedBox(height: 12),
                                  if (_role != 1)
                                    FilledButton.icon(
                                        onPressed: () => _open(
                                            OperationsQueueScreen(
                                                repository: _repository,
                                                session: _session,
                                                filters: _filters)),
                                        icon: const Icon(
                                            Icons.arrow_forward_rounded),
                                        iconAlignment: IconAlignment.end,
                                        label: Text(_role == 2
                                            ? 'Buka Antrean Global'
                                            : 'Buka Antrean Approval')),
                                  if (_actions.isNotEmpty &&
                                      (_role != 1 || !_personal)) ...[
                                    const SizedBox(height: 16),
                                    _DashboardCard(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const _SectionTitle(
                                            'Prioritas tindakan'),
                                        for (final row in _actions)
                                          _actionTile(
                                              row,
                                              () => _open(
                                                  OperationsBookingScreen(
                                                      bookingGuid:
                                                          row.bookingGuid ?? '',
                                                      repository: _repository,
                                                      session: _session))),
                                        _routeLink(
                                            'Lihat seluruh tindakan',
                                            () => _open(OperationsReportScreen(
                                                section: 'action-center',
                                                initialFilters: _filters,
                                                repository: _repository,
                                                session: _session))),
                                      ],
                                    )),
                                  ],
                                  const SizedBox(height: 16),
                                  _DashboardCard(
                                      child: Column(children: [
                                    _routeLink(
                                        'Riwayat seluruh booking',
                                        () => _open(DaftarPendaftarScreen(
                                            repository: _repository,
                                            session: _session))),
                                    _routeLink(
                                        'Kinerja destinasi',
                                        () => _open(OperationsReportScreen(
                                            section: 'destinations',
                                            repository: _repository,
                                            session: _session,
                                            initialFilters: _filters))),
                                    _routeLink(
                                        'Kunjungan dan check-in',
                                        () => _open(OperationsReportScreen(
                                            section: 'visitors',
                                            repository: _repository,
                                            session: _session,
                                            initialFilters: _filters))),
                                  ])),
                                ],
                              ]),
                        ),
                      ],
                    ),
                  )),
            )));
  }
}

class OperationsAnalyticsHub extends StatelessWidget {
  const OperationsAnalyticsHub(
      {super.key, this.repository, this.session, this.active = true});
  final BusinessRepository? repository;
  final AuthSession? session;
  final bool active;
  @override
  Widget build(BuildContext context) => OperationsPage(
          title: 'Analitik',
          subtitle: 'Perbandingan berbasis data Laravel',
          children: [
            for (final entry in [
              (
                'destinations',
                'Perbandingan destinasi',
                'Kapasitas, alokasi, dan konfirmasi'
              ),
              ('approvals', 'Kinerja Admin', 'Keputusan tim dan beban claim'),
              ('visitors', 'Kunjungan', 'Check-in yang teramati')
            ])
              Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      title: Text(entry.$2,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                      subtitle: Text(entry.$3,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF526787))),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.blue),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => OperationsReportScreen(
                                  section: entry.$1,
                                  repository: repository,
                                  session: session))))),
            const SizedBox(height: 20),
            OperationsFinancialScreen(
                repository: repository,
                session: session,
                preview: true,
                active: active),
          ]);
}
