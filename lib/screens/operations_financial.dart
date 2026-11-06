part of 'operations_dashboard.dart';

/// A09/E07 share the same server-scoped report; home uses its DEMO preview.
class OperationsFinancialScreen extends StatefulWidget {
  const OperationsFinancialScreen(
      {super.key,
      this.repository,
      this.session,
      this.preview = false,
      this.active = true});
  final BusinessRepository? repository;
  final AuthSession? session;
  final bool preview;
  final bool active;
  @override
  State<OperationsFinancialScreen> createState() => _OperationsFinancialState();
}

class _OperationsFinancialState extends State<OperationsFinancialScreen>
    with WidgetsBindingObserver {
  late final _session = widget.session ?? AuthSession.instance;
  late final _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final _generation = _session.sessionGeneration;
  late final _role = _session.role;
  String _environment = 'demo';
  bool _analytics = false;
  Map<String, String> _filters = {};
  Json? _financial;
  List<Json>? _bookingTrend;
  Object? _activityError;
  bool _activityLoading = false;
  String? _destinationLabel;
  DateTime? _receivedAt;
  Object? _error;
  bool _loading = true;
  int _request = 0;
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
    _session.sessionChanges.addListener(_changed);
    operationsDataChanges.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      _request++;
      _financial = null;
      _bookingTrend = null;
      _activityError = null;
      _activityLoading = false;
      _destinationLabel = null;
      _receivedAt = null;
      _filters = {};
      _environment = 'demo';
      _loading = false;
      _error = const ApiException(
          'Akses diperbarui. Muat ulang keuangan sesuai penugasan terbaru.');
    });
  }

  @override
  void didUpdateWidget(OperationsFinancialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _session.sessionChanges.removeListener(_changed);
    operationsDataChanges.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_valid || !widget.active) return;
    final request = ++_request;
    final environment = _environment;
    final filters = Map<String, String>.of(_filters);
    setState(() {
      _loading = true;
      _error = null;
      _financial = null;
      _receivedAt = null;
      _bookingTrend = null;
      _activityError = null;
      _activityLoading = _role == 1 && !widget.preview;
    });
    try {
      final report = await _repository.operationalReport('financial',
          query: {'environment': environment, ...filters});
      if (!_valid || request != _request) return;
      final financial = report.financial;
      final scope = financial['scope'];
      final unavailable = financial['availability'] == 'unavailable';
      if (financial['environment'] != environment ||
          financial['provider'] != (environment == 'demo' ? 'demo' : 'doku') ||
          financial['test_only'] != (environment != 'production') ||
          financial['currency'] != 'IDR' ||
          !const ['partial', 'available', 'unavailable']
              .contains(financial['availability']) ||
          (!unavailable &&
              financial['source'] !=
                  (environment == 'demo'
                      ? 'simulated_demo_events'
                      : 'verified_${environment}_events')) ||
          scope is! Json ||
          scope['mode'] != (_role == 2 ? 'global' : 'assigned_destinations') ||
          scope['destination_guid'] != filters['destination_guid']) {
        throw const ApiException(
            'Sumber atau scope data keuangan tidak sesuai. Muat ulang data.',
            null,
            'invalid_response');
      }
      setState(() {
        _financial = financial;
        _receivedAt = DateTime.now();
        _loading = false;
      });
      if (_role == 1 && !widget.preview) {
        final period = financial['period'];
        await _loadActivity(request, {
          ...filters,
          if (period is Json) ...{
            'from': '${period['from']}',
            'to': '${period['to']}',
          },
        });
      }
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _error = e;
        _financial = null;
        _loading = false;
        _activityLoading = false;
        if (_scopeError(e)) {
          _filters = {};
          _destinationLabel = null;
        }
      });
      if (_scopeError(e)) _session.me().catchError((Object _) {});
    }
  }

  Future<void> _loadActivity(int request, Map<String, String> filters) async {
    try {
      final report =
          await _repository.operationalReport('overview', query: filters);
      if (!_valid || request != _request) return;
      setState(() {
        _bookingTrend = report.bookingTrend;
        _activityLoading = false;
      });
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _activityError = e;
        _activityLoading = false;
        if (_scopeError(e)) {
          _financial = null;
          _receivedAt = null;
          _error = e;
          _filters = {};
          _destinationLabel = null;
        }
      });
      if (_scopeError(e)) _session.me().catchError((Object _) {});
    }
  }

  Future<void> _filter() async {
    final request = _request;
    final period = _financial?['period'];
    String? destinationLabel = _destinationLabel;
    final filters = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: {
          if (_role == 1 && period is Json)
            for (final key in ['from', 'to']) key: '${period[key]}',
          ..._filters,
        },
        home: _role == 1,
        destinationLabel: _destinationLabel,
        onDestinationLabelSelected: (label) => destinationLabel = label,
        financial: true);
    if (filters == null || !_valid || request != _request) return;
    _filters = filters;
    _destinationLabel =
        filters['destination_guid'] == null ? null : destinationLabel;
    await _load();
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperationsFinancialScreen(
            repository: _repository, session: _session)));
    if (_valid) await _load();
  }

  bool get _available =>
      _financial != null && _financial!['availability'] != 'unavailable';

  String _metric(String key, {bool money = false}) => !_available
      ? 'Belum Tersedia'
      : money
          ? _financialMoney(_financial![key])
          : _financialNumber(_financial![key]);

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    if (widget.preview) return _preview();
    if (_role == 1) return _adminPage();
    final financial = _financial;
    final period = financial?['period'];
    return Theme(
        data: AppColors.visitorTheme,
        child: OperationsPage(
            role: _role,
            title: 'Ringkasan Keuangan',
            subtitle: _role == 2
                ? 'Seluruh destinasi · scope global'
                : 'Destinasi yang ditugaskan kepada Anda',
            embedded: false,
            onRefresh: _load,
            children: [
              _provenance(),
              const SizedBox(height: 12),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                          minimumSize: const Size(44, 44)),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'demo', label: Text('DEMO')),
                        ButtonSegment(value: 'sandbox', label: Text('Sandbox')),
                        ButtonSegment(
                            value: 'production', label: Text('Production')),
                      ],
                      selected: {_environment},
                      onSelectionChanged: (values) {
                        _environment = values.first;
                        _load();
                      })),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Text(
                        '${period is Json ? _period(period) : _filters['from'] == null ? 'Bulan ini · UTC' : '${_filters['from']} — ${_filters['to']}'}\n'
                        '${_filters['destination_guid'] == null ? _role == 2 ? 'Semua destinasi' : 'Semua destinasi saya' : 'Destinasi terpilih'}',
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: Color(0xFF526787)))),
                OutlinedButton.icon(
                    onPressed: _filter,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Filter')),
              ]),
              const SizedBox(height: 12),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<bool>(
                      style: SegmentedButton.styleFrom(
                          minimumSize: const Size(44, 44)),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Ringkasan')),
                        ButtonSegment(
                            value: true, label: Text('Analitik Pembayaran')),
                      ],
                      selected: {_analytics},
                      onSelectionChanged: (values) =>
                          setState(() => _analytics = values.first))),
              const SizedBox(height: 16),
              if (_loading) const OperationsSkeleton(),
              if (_error != null)
                _errorBlock(_error!, _scopeError(_error) ? _filter : _load,
                    role: _role),
              if (!_loading && financial != null) ...[
                if (!_available) ...[
                  _DashboardCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        const _SectionTitle(
                            'Belum ada sumber pembayaran tersedia'),
                        Text(_financialReason(financial['reason']),
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF526787))),
                      ])),
                  const SizedBox(height: 12),
                ],
                if (financial['availability'] == 'partial') ...[
                  _Notice(_financialReason(financial['reason'])),
                  const SizedBox(height: 12),
                ],
                if (_analytics)
                  ..._analyticsContent(financial)
                else
                  ..._summaryContent(financial),
                const SizedBox(height: 16),
                _DashboardCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      const _SectionTitle('Sumber & kelengkapan'),
                      _financialRow(
                          'Environment', '${financial['environment']}'),
                      _financialRow('Provider', '${financial['provider']}'),
                      _financialRow('Label', '${financial['label'] ?? '—'}'),
                      _financialRow(
                          'Sumber', '${financial['source'] ?? 'unavailable'}'),
                      _financialRow(
                          'Ketersediaan', '${financial['availability']}'),
                      _financialRow(
                          'Basis nominal', '${financial['date_basis'] ?? '—'}'),
                      Text(_financialReason(financial['reason']),
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Color(0xFF526787))),
                      if (financial['missing_fields'] is List &&
                          (financial['missing_fields'] as List).isNotEmpty)
                        Text(
                            'Belum tersedia: ${(financial['missing_fields'] as List).join(', ')}',
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Color(0xFF526787))),
                    ])),
                if (_receivedAt != null)
                  Row(children: [
                    Expanded(
                        child: Text('Diterima: ${formatDateTime(_receivedAt!)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF526787)))),
                    if (_role != 1)
                      IconButton(
                          tooltip: 'Perbarui keuangan',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 20)),
                  ]),
              ],
            ]));
  }

  Widget _adminPage() {
    final financial = _financial;
    final period = financial?['period'];
    final filters = {
      if (period is Json)
        for (final key in ['from', 'to']) key: '${period[key]}',
      ..._filters,
    };
    return OperationsPage(
        role: _role,
        title: 'Keuangan',
        subtitle: 'Ringkasan pencatatan transaksi',
        embedded: false,
        onRefresh: _load,
        children: [
          OperationsFilterBar(
              filters: filters,
              keyPrefix: 'financial',
              destinationLabel: _destinationLabel,
              dateTooltip: 'Periode pembayaran dan aktivitas booking (UTC)',
              onDestinationPressed: _filter,
              onDatePressed: _filter),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle,
                      size: AppSpacing.sm,
                      color: _receivedAt == null
                          ? AppColors.textMuted
                          : AppColors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                      child: Text(
                          _loading
                              ? 'Memuat data…'
                              : _receivedAt == null
                                  ? 'Data belum tersinkron'
                                  : 'Snapshot · ${formatDateTime(_receivedAt!)}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary))),
                ]),
                const Text('Tarik untuk sinkron',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ]),
          const SizedBox(height: AppSpacing.md),
          Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  border: Border.all(color: AppColors.warningBorder),
                  borderRadius: BorderRadius.circular(AppSpacing.lg)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('DEMO / TEST_ONLY · Bukan uang nyata',
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningText)),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                        'Angka berasal dari simulasi pembayaran DEMO, '
                        'bukan transaksi uang nyata atau settlement DOKU.',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.warningText)),
                  ])),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const OperationsSkeleton()
          else if (_error != null)
            _errorBlock(_error!, _scopeError(_error) ? _filter : _load,
                role: _role)
          else if (financial != null) ...[
            _DashboardCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const Text('GROSS TERCATAT',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_metric('gross_revenue', money: true),
                      style: TextStyle(
                          fontSize: _available ? 32 : 20,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                      _available
                          ? '${_metric('successful_transactions')} transaksi sukses'
                          : _financialReason(financial['reason']),
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textSecondary)),
                ])),
            const SizedBox(height: AppSpacing.md),
            OperationsMetrics(
                values: [
                  ('Pembayaran berhasil', _metric('successful_transactions')),
                  ('Tiket terkait booking', _metric('tickets_sold')),
                ],
                icons: const [
                  Icons.payments_outlined,
                  Icons.confirmation_number_outlined
                ],
                labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy)),
            const SizedBox(height: AppSpacing.md),
            _DashboardCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const _AdminHomeHeading('Aktivitas booking'),
                  const Text('Booking dibuat · tanggal UTC',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xl),
                  if (_activityLoading)
                    const LinearProgressIndicator()
                  else if (_activityError != null) ...[
                    Text(adminErrorMessage(_activityError!),
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.textSecondary)),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: _load,
                            child: const Text('Muat ulang aktivitas'))),
                  ] else if (_bookingTrend?.isEmpty ?? true)
                    const _Notice('Belum ada aktivitas pada periode ini.')
                  else
                    _FinancialBookingChart(rows: _bookingTrend!),
                ])),
            const SizedBox(height: AppSpacing.md),
            _DashboardCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const _AdminHomeHeading('Sumber data'),
                  Text(
                      '${financial['source'] ?? 'unavailable'} · '
                      '${financial['availability']}. '
                      'Jangan tafsirkan sebagai saldo tersedia atau net settlement.',
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textSecondary)),
                ])),
          ],
        ]);
  }

  Widget _provenance() => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7E9),
          borderRadius: BorderRadius.circular(12)),
      child: Text(
          _environment == 'demo'
              ? 'DEMO / TEST_ONLY · Simulasi, bukan uang nyata atau pendapatan Production.'
              : _environment == 'sandbox'
                  ? 'SANDBOX / TEST_ONLY · Data uji terpisah dari Production.'
                  : 'PRODUCTION · Hanya sumber pembayaran terverifikasi.',
          style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF795018))));

  Widget _preview() => _role == 1
      ? _adminPreview()
      : _DashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _SectionTitle('Ringkasan Keuangan'),
          const Text('DEMO / TEST_ONLY · Bukan uang nyata',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blueDeep)),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
                height: 40, child: Center(child: LinearProgressIndicator()))
          else if (_error != null) ...[
            Text(adminErrorMessage(_error!),
                style: const TextStyle(fontSize: 13, height: 1.5)),
            if (_role != 1)
              TextButton(
                  onPressed: _load, child: const Text('Muat ulang keuangan')),
          ] else if (!_available)
            Text(_financialReason(_financial?['reason']),
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF526787)))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _financialFigure(
                      'Gross tercatat', _metric('gross_revenue', money: true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _financialFigure(
                      'Transaksi sukses', _metric('successful_transactions'))),
            ]),
          const SizedBox(height: 8),
          if (_financial != null)
            Text(
                'Sumber: ${_financial!['source']} · ${_financial!['availability']}',
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: Color(0xFF526787))),
          _routeLink('Buka Financial Dashboard', _open),
        ]));

  Widget _adminPreview() => _DashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('Ringkasan Keuangan',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy))),
          Tooltip(
              message: 'Ringkasan DEMO bulan ini (UTC), seluruh penugasan. '
                  'Filter keuangan tersedia di dashboard. '
                  'Sumber: ${_financial?['source'] ?? 'belum tersedia'}',
              child: const Icon(Icons.payments_outlined,
                  size: 20, color: AppColors.navy)),
        ]),
        const SizedBox(height: AppSpacing.xs),
        const Text('DEMO / TEST_ONLY · Bukan uang nyata',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const LinearProgressIndicator()
        else if (_error != null) ...[
          Text(adminErrorMessage(_error!),
              style: const TextStyle(fontSize: 13, height: 1.5)),
          TextButton(
              onPressed: _load, child: const Text('Muat ulang keuangan')),
        ] else if (!_available)
          Text(_financialReason(_financial?['reason']),
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.textSecondary))
        else ...[
          _financialRow(
              'Gross tercatat', _metric('gross_revenue', money: true)),
          const Divider(height: AppSpacing.sm, color: AppColors.border),
          _financialRow('Transaksi sukses', _metric('successful_transactions')),
          if (_financial?['availability'] == 'partial')
            Text('Sumber: ${_financial!['source']} · partial',
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
        ],
        const Divider(height: AppSpacing.sm, color: AppColors.border),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                key: const ValueKey('home-financial-dashboard'),
                onPressed: _open,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.blueDeep),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Buka dashboard keuangan',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))),
      ]));

  List<Widget> _summaryContent(Json financial) => [
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.blueDeep,
                borderRadius: BorderRadius.circular(18)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      _environment == 'demo'
                          ? 'Gross revenue · Simulasi DEMO'
                          : 'Gross revenue · ${_environment.toUpperCase()}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(_metric('gross_revenue', money: true),
                      style: TextStyle(
                          fontSize: _available ? 28 : 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(height: 6),
                  const Text('Nominal recognized · paid_utc',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ])),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final figures = [
            ('Transaksi sukses', _metric('successful_transactions')),
            ('Tiket terjual', _metric('tickets_sold')),
            ('Gross collected', _metric('gross_collected', money: true)),
            ('Payment attempts', _metric('payment_attempts')),
          ];
          final columns = constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18
              ? 1
              : 2;
          return Column(children: [
            for (var i = 0; i < figures.length; i += columns) ...[
              if (i > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(
                          child: _DashboardCard(
                              child: _financialFigure(
                                  figures[j].$1, figures[j].$2))),
                    ],
                  ])),
            ],
          ]);
        }),
        const SizedBox(height: 12),
        _DashboardCard(
            child: _financialRow('Collected belum diterapkan',
                _metric('unapplied_collected', money: true))),
        const SizedBox(height: 12),
        _DashboardCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const _SectionTitle('Komponen keuangan'),
              _financialRow(
                  'Gateway fees', _metric('gateway_fees', money: true)),
              _financialRow('Net revenue', _metric('net_revenue', money: true)),
              _financialRow('Settlement', _metric('settlement', money: true)),
              _financialRow('Refund tercatat', _metric('refunds', money: true)),
              _financialRow(
                  'Kelengkapan refund',
                  financial['refunds_complete'] == true
                      ? 'Lengkap'
                      : 'Belum lengkap'),
              Text(
                  'Refund: ${financial['refunds_basis'] ?? '—'} · ${financial['refund_date_basis'] ?? '—'}',
                  style: const TextStyle(
                      fontSize: 12, height: 1.5, color: Color(0xFF526787))),
              const Text('Data yang belum tersedia tidak dihitung sebagai Rp0.',
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: Color(0xFF526787))),
            ])),
      ];

  List<Widget> _analyticsContent(Json financial) {
    final attempt = financial['attempt_conversion'];
    final booking = financial['booking_conversion'];
    final mix = financial['method_mix'];
    return [
      _conversionCard('Konversi per attempt', attempt, 'successful_attempts',
          'completed_attempts', 'Attempt sukses / selesai'),
      const SizedBox(height: 12),
      _conversionCard('Konversi per booking', booking, 'paid_bookings',
          'payment_eligible_bookings', 'Booking paid / eligible'),
      const SizedBox(height: 12),
      _DashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _SectionTitle('Percobaan pembayaran'),
        _financialRow('Total attempt', _metric('payment_attempts')),
        _financialRow('Capture sukses · paid_utc',
            _metric('successful_payment_attempts')),
        _financialRow(
            'Gagal · attempt_started_utc', _metric('failed_attempts')),
        _financialRow(
            'Expired · attempt_started_utc', _metric('expired_attempts')),
        _financialRow(
            'Unknown · attempt_started_utc', _metric('unknown_attempts')),
        _financialRow(
            'Rata-rata durasi',
            !_available || financial['avg_payment_seconds'] == null
                ? 'Belum Tersedia'
                : '${_financialNumber(financial['avg_payment_seconds'])} detik'),
      ])),
      const SizedBox(height: 12),
      _DashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _SectionTitle('Metode & channel'),
        if (!_available || mix is! List)
          const Text('Belum Tersedia', style: TextStyle(fontSize: 14))
        else if (mix.isEmpty)
          const Text('Belum ada capture pada periode ini.',
              style: TextStyle(fontSize: 14))
        else
          for (final item in mix.whereType<Json>()) ...[
            _financialRow(
                '${item['method'] ?? '—'} · ${item['channel'] ?? '—'}',
                _financialMoney(item['gross_collected'])),
            Text(
                '${_financialNumber(item['successful_attempts'])} capture sukses · paid_utc',
                style: const TextStyle(fontSize: 12, color: Color(0xFF526787))),
            const SizedBox(height: 8),
          ],
        if (financial['method_mix_truncated'] == true)
          Text(
              'Rincian dibatasi ${financial['method_mix_limit']} grup; total tetap mencakup seluruh grup.',
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: Color(0xFF795018))),
      ])),
    ];
  }

  Widget _conversionCard(String title, dynamic value, String numerator,
      String denominator, String countLabel) {
    final conversion =
        _available && value is Json ? value : <String, dynamic>{};
    final percent = _number(conversion['percent']);
    return _DashboardCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(title),
      Text(percent == null ? 'Belum Tersedia' : '${_financialNumber(percent)}%',
          style: TextStyle(
              fontSize: percent == null ? 14 : 24,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontFeatures: const [FontFeature.tabularFigures()])),
      if (percent != null) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.border,
            color: AppColors.blue),
      ],
      const SizedBox(height: 8),
      _financialRow(countLabel,
          '${_financialNumber(conversion[numerator])} / ${_financialNumber(conversion[denominator])}'),
      Text('Basis: ${conversion['date_basis'] ?? 'Belum Tersedia'}',
          style: const TextStyle(
              fontSize: 12, height: 1.5, color: Color(0xFF526787))),
      if (conversion['denominator_scope'] != null)
        const Text(
            'Pembagi: booking berbayar yang disetujui dan memiliki intent pada environment ini.',
            style:
                TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF526787))),
    ]));
  }
}

class _FinancialBookingChart extends StatelessWidget {
  const _FinancialBookingChart({required this.rows});
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    final values = rows.map((row) => _number(row['bookings'])).toList();
    if (values.any((value) => value == null || !value.isFinite || value < 0)) {
      return const _Notice('Data aktivitas booking belum tersedia.');
    }
    final maximum = values.fold<num>(1, (max, value) => math.max(max, value!));
    return Semantics(
        label: 'Aktivitas booking. '
            '${rows.map((row) => "${row['date']}: ${_value(row['bookings'])} booking").join(', ')}',
        excludeSemantics: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final slot = math.max(
              MediaQuery.textScalerOf(context).scale(kMinInteractiveDimension),
              constraints.maxWidth / rows.length);
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: slot * rows.length,
                  child: Column(children: [
                    SizedBox(
                        height: 112,
                        child: Stack(children: [
                          Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (var i = 0; i < 4; i++)
                                  const Divider(
                                      height: 1, color: AppColors.border),
                              ]),
                          Positioned.fill(
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                for (final value in values)
                                  Expanded(
                                      child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                              widthFactor: .42,
                                              heightFactor:
                                                  value! / maximum * .92,
                                              child: const DecoratedBox(
                                                  decoration: BoxDecoration(
                                                      color: AppColors.blue,
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                              top: Radius.circular(
                                                                  AppSpacing
                                                                      .xs))))))),
                              ])),
                        ])),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      for (final row in rows)
                        Expanded(
                            child: Text(
                                DateTime.tryParse('${row['date']}') == null
                                    ? '${row['date']}'
                                    : operationsPeriodLabel({
                                        'from': '${row['date']}',
                                        'to': '${row['date']}'
                                      }),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary))),
                    ]),
                  ])));
        }));
  }
}

Widget _financialFigure(String label, String value) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF526787))),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              fontFeatures: [FontFeature.tabularFigures()])),
    ]);

Widget _financialRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          flex: 5,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: Color(0xFF526787)))),
      const SizedBox(width: 12),
      Expanded(
          flex: 4,
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  fontFeatures: [FontFeature.tabularFigures()]))),
    ]));

String _financialNumber(dynamic value) {
  final number = _number(value);
  if (number == null || !number.isFinite) return 'Belum Tersedia';
  return number == number.roundToDouble()
      ? number
          .toInt()
          .toString()
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')
      : number.toStringAsFixed(2).replaceAll('.', ',');
}

String _financialMoney(dynamic value) {
  final number = _number(value);
  return number == null || !number.isFinite
      ? 'Belum Tersedia'
      : 'Rp${_financialNumber(number)}';
}

String _financialReason(dynamic reason) => switch (reason) {
      'no_verified_payment_source' =>
        'Belum ada sumber pembayaran terverifikasi pada environment dan scope ini.',
      'fees_and_refunds_unavailable' =>
        'Data tersedia sebagian. Biaya gateway, net, settlement, dan kelengkapan refund belum tersedia.',
      'fees_unavailable_refunds_incomplete' =>
        'Data tersedia sebagian. Refund tercatat belum membuktikan kelengkapan; biaya gateway, net, dan settlement belum tersedia.',
      null => 'Sumber pembayaran belum tersedia.',
      _ => 'Keterangan sumber: $reason',
    };
