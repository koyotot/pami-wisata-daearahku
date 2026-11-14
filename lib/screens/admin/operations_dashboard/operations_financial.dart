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
  // Fixed (no selector): the full page always reads SANDBOX; the home preview
  // keeps its DEMO source.
  late String _environment = _defaultEnvironment;
  String get _defaultEnvironment => widget.preview ? 'demo' : 'sandbox';
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

  /// Superadmin opens on the current UTC month, like the home summary.
  Map<String, String> get _defaultFilters =>
      _role == 2 && !widget.preview ? _homeMonthFilters() : {};

  @override
  void initState() {
    super.initState();
    _filters = _defaultFilters;
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
      _filters = _defaultFilters;
      _environment = _defaultEnvironment;
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
    // The superadmin home card is just a menu entry; it shows no figures.
    if (widget.preview && _role == 2) {
      _loading = false;
      return;
    }
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
          !(environment == 'demo'
                  ? const ['demo']
                  : const ['doku', 'midtrans', 'mixed'])
              .contains(financial['provider']) ||
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
          _filters = _defaultFilters;
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
          if (period is Json)
            for (final key in ['from', 'to']) key: '${period[key]}',
          ..._filters,
        },
        home: true,
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
    return _superadminPage();
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
                  Icon(PhosphorIconsFill.circle,
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
                        'bukan transaksi uang nyata atau settlement gateway.',
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
                  PhosphorIconsRegular.money,
                  PhosphorIconsRegular.ticket
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
                      '${_financialSourceLine(financial)}. '
                      'Jangan tafsirkan sebagai saldo tersedia atau net settlement.',
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textSecondary)),
                ])),
          ],
        ]);
  }

  Widget _preview() => _role == 1
      ? _adminPreview()
      : _financeMenuCard();

  /// Superadmin home entry point to the full finance page (no figures here).
  Widget _financeMenuCard() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('MENU KEUANGAN',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB9CCEA))),
                SizedBox(height: 10),
                Text('Ringkasan Keuangan',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                SizedBox(height: 8),
                Text('Kelola dan pantau laporan keuangan dalam satu tempat.',
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: Color(0xFFDCE6F7))),
              ])),
          const SizedBox(width: 12),
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(PhosphorIconsRegular.chartBar,
                  color: Colors.white, size: 24)),
        ]),
        const SizedBox(height: 20),
        Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
                key: const ValueKey('finance-menu-open'),
                borderRadius: BorderRadius.circular(14),
                onTap: _open,
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(children: [
                      Expanded(
                          child: Text('Buka Financial Dashboard',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy))),
                      Icon(PhosphorIconsRegular.arrowRight,
                          size: 18, color: AppColors.navy),
                    ])))),
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
                  'Sumber: ${_financialSourceLabel(_financial?['source'])}',
              child: const Icon(PhosphorIconsRegular.money,
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
            Text(
                'Sumber: ${_financialSourceLabel(_financial!['source'])} · '
                '${_financialAvailabilityLabel('partial')}',
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
                icon: const Icon(PhosphorIconsRegular.arrowRight, size: 20),
                label: const Text('Buka dashboard keuangan',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))),
      ]));

  // ── Superadmin finance page ─────────────────────────────────────────────
  bool _sourceOpen = false;

  Widget _superadminPage() {
    final financial = _financial;
    final period = financial?['period'];
    final filters = {
      if (period is Json)
        for (final key in ['from', 'to']) key: '${period[key]}',
      ..._filters,
    };
    return Theme(
        data: AppColors.visitorTheme,
        child: OperationsPage(
            role: _role,
            title: 'Ringkasan Keuangan',
            subtitle: 'Seluruh destinasi · scope global',
            embedded: false,
            onRefresh: _load,
            children: [
              Row(children: [
                Expanded(
                    child: _FinanceFilterCard(
                        key: const ValueKey('financial-destination-filter'),
                        icon: PhosphorIconsRegular.mapPin,
                        caption: 'DESTINASI',
                        value: filters['destination_guid'] == null
                            ? 'Semua destinasi'
                            : _destinationLabel ?? 'Destinasi terpilih',
                        onTap: _filter)),
                const SizedBox(width: 12),
                Expanded(
                    child: _FinanceFilterCard(
                        key: const ValueKey('financial-date-filter'),
                        icon: PhosphorIconsRegular.calendarBlank,
                        caption: 'PERIODE',
                        value: operationsPeriodLabel(filters),
                        onTap: _filter)),
              ]),
              const SizedBox(height: 16),
              _FinanceTabs(
                  analytics: _analytics,
                  onChanged: (value) => setState(() => _analytics = value)),
              const SizedBox(height: 20),
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
                  const SizedBox(height: 16),
                ],
                if (_analytics)
                  ..._analyticsContent(financial)
                else
                  ..._summaryContent(financial),
                const SizedBox(height: 16),
                _sourceCard(financial),
              ],
            ]));
  }

  List<Widget> _summaryContent(Json financial) {
    final figures = [
      ('Transaksi sukses', _metric('successful_transactions'),
          'Pembayaran berhasil'),
      ('Tiket terjual', _metric('tickets_sold'), 'Total tiket'),
      ('Payment attempts', _metric('payment_attempts'), 'Percobaan pembayaran'),
      ('Gross collected', _metric('gross_collected', money: true),
          'Nominal terkumpul'),
    ];
    final unapplied = _number(financial['unapplied_collected']);
    final components = [
      ('Gateway fees', 'gateway_fees'),
      ('Net revenue', 'net_revenue'),
      ('Settlement', 'settlement'),
      ('Refund tercatat', 'refunds'),
    ];
    final missing = !_available ||
        components.any((c) => _number(financial[c.$2]) == null) ||
        financial['refunds_complete'] != true;
    return [
      _financeHeading('Performa Keuangan',
          'Ringkasan pembayaran berhasil pada periode terpilih.'),
      const SizedBox(height: 14),
      Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.blueDeep, Color(0xFF2077D6)])),
          child: Stack(children: [
            Positioned(
                right: -36,
                top: -28,
                child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .06)))),
            Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                'Gross revenue - ${_environment.toUpperCase()}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white))),
                        _financeInfo(
                            'Total nominal pembayaran berhasil pada periode '
                            'terpilih, diakui menurut tanggal pembayaran '
                            'berhasil (UTC).',
                            onDark: true),
                      ]),
                      const SizedBox(height: 18),
                      Text(_metric('gross_revenue', money: true),
                          style: TextStyle(
                              fontSize: _available ? 36 : 20,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(height: 14),
                      Text(
                          'Nominal pembayaran berhasil yang diakui berdasarkan '
                          '${_financialDateBasisLabel(financial['date_basis'] ?? 'paid_utc')}.',
                          style: const TextStyle(
                              fontSize: 13, height: 1.5, color: Colors.white)),
                    ])),
          ])),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
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
                        child: _financeFigureCard(
                            figures[j].$1, figures[j].$2, figures[j].$3)),
                  ],
                ])),
          ],
        ]);
      }),
      const SizedBox(height: 12),
      _DashboardCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            _financeCardHeader('Rekonsiliasi collected',
                trailing: _financeInfo(
                    'Membandingkan nominal yang terkumpul dengan nominal yang '
                    'sudah diterapkan ke booking.')),
            const SizedBox(height: 14),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F6FE),
                    borderRadius: BorderRadius.circular(14)),
                child: IntrinsicHeight(
                    child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Gross collected',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF526787))),
                        const SizedBox(height: 6),
                        Text(_metric('gross_collected', money: true),
                            style: _financeValueStyle(18)),
                      ])),
                  const VerticalDivider(width: 24, color: AppColors.border),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        const Text('Belum diterapkan',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF526787))),
                        const SizedBox(height: 6),
                        Text(_metric('unapplied_collected', money: true),
                            style: _financeValueStyle(18)),
                      ])),
                ]))),
            const SizedBox(height: 12),
            Text(
                _available && unapplied == 0
                    ? 'Angka Rp0 di sini memang tersedia pada snapshot. '
                        'Metrik yang tidak tersedia tetap ditandai terpisah.'
                    : 'Metrik yang tidak tersedia ditandai terpisah dan tidak '
                        'dihitung sebagai Rp0.',
                style: const TextStyle(
                    fontSize: 12, height: 1.6, color: Color(0xFF526787))),
          ])),
      const SizedBox(height: 12),
      _DashboardCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            _financeCardHeader('Komponen Keuangan',
                trailing: _financeInfo(
                    'Komponen yang belum tersedia tidak dihitung sebagai Rp0.')),
            const SizedBox(height: 6),
            for (final component in components) ...[
              _financeComponentRow(
                  component.$1,
                  _available && _number(financial[component.$2]) != null
                      ? Text(_financialMoney(financial[component.$2]),
                          style: _financeValueStyle(13))
                      : _financeChip('Belum tersedia')),
              const Divider(height: 1, color: AppColors.border),
            ],
            _financeComponentRow(
                'Kelengkapan refund',
                !_available
                    ? _financeChip('Belum tersedia')
                    : financial['refunds_complete'] == true
                        ? _financeChip('Lengkap', good: true)
                        : _financeChip('Belum lengkap')),
            const SizedBox(height: 6),
            Text(
                missing
                    ? 'Tidak dihitung sebagai Rp0. Informasi biaya gateway, '
                        'settlement, dan refund belum lengkap.'
                    : 'Seluruh komponen keuangan tersedia pada snapshot ini.',
                style: const TextStyle(
                    fontSize: 12, height: 1.6, color: Color(0xFF526787))),
          ])),
    ];
  }

  Widget _sourceCard(Json financial) {
    final reason = financial['reason'];
    final missingFields = financial['missing_fields'];
    final rows = [
      ('Lingkungan snapshot', _financialCap('${financial['environment']}')),
      ('Provider', '${financial['provider'] ?? '—'}'),
      ('Label', '${financial['label'] ?? '—'}'),
      ('Sumber', _financialSourceLabel(financial['source'])),
      (
        'Kelengkapan',
        _financialCap(_financialAvailabilityLabel(financial['availability']))
      ),
      (
        'Pengakuan nominal',
        _financialCap(_financialDateBasisLabel(financial['date_basis']))
      ),
    ];
    return _DashboardCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
          key: const ValueKey('financial-source-toggle'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _sourceOpen = !_sourceOpen),
          child: Row(children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Sumber & Kelengkapan Data',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                  SizedBox(height: 4),
                  Text('Rincian asal data dan batasan pelaporan',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF526787))),
                ])),
            const SizedBox(width: 12),
            Icon(
                _sourceOpen
                    ? PhosphorIconsRegular.caretUp
                    : PhosphorIconsRegular.caretDown,
                size: 18,
                color: AppColors.textSecondary),
          ])),
      if (_sourceOpen) ...[
        const SizedBox(height: 12),
        for (final row in rows) ...[
          const Divider(height: 1, color: AppColors.border),
          _financeComponentRow(
              row.$1,
              Text(row.$2,
                  textAlign: TextAlign.right, style: _financeValueStyle(13))),
        ],
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        if (reason != null)
          Text(_financialReason(reason),
              style: const TextStyle(
                  fontSize: 12, height: 1.6, color: Color(0xFF526787))),
        if (missingFields is List && missingFields.isNotEmpty)
          Text(
              'Belum tersedia: ${missingFields.map(_financialFieldLabel).join(', ')}',
              style: const TextStyle(
                  fontSize: 12, height: 1.6, color: Color(0xFF526787))),
      ],
    ]));
  }

  List<Widget> _analyticsContent(Json financial) {
    final attempt = financial['attempt_conversion'];
    final booking = financial['booking_conversion'];
    return [
      _financeHeading('Analitik Pembayaran',
          'Evaluasi performa proses pembayaran dan konversi.'),
      const SizedBox(height: 14),
      _conversionCard(
          'Konversi per attempt',
          attempt,
          'successful_attempts',
          'completed_attempts',
          'Attempts sukses / selesai',
          'Persentase percobaan pembayaran yang berhasil dari seluruh '
              'percobaan yang sudah selesai.'),
      const SizedBox(height: 12),
      _conversionCard(
          'Konversi per booking',
          booking,
          'paid_bookings',
          'payment_eligible_bookings',
          'Booking paid / eligible',
          'Persentase booking yang sudah dibayar dari booking yang memenuhi '
              'syarat pembayaran.'),
      const SizedBox(height: 12),
      _attemptsCard(financial),
      const SizedBox(height: 12),
      _methodCard(financial),
    ];
  }

  Widget _conversionCard(String title, dynamic value, String numerator,
      String denominator, String countLabel, String info) {
    final conversion =
        _available && value is Json ? value : <String, dynamic>{};
    final percent = _number(conversion['percent']);
    return _DashboardCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _financeCardHeader(title, trailing: _financeInfo(info)),
      const SizedBox(height: 10),
      Text(percent == null ? 'Belum Tersedia' : '${_financialNumber(percent)}%',
          style: TextStyle(
              fontSize: percent == null ? 14 : 36,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.blueDeep,
              fontFeatures: const [FontFeature.tabularFigures()])),
      if (percent != null) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.border,
            color: AppColors.blue),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: Text(countLabel,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF526787)))),
        Text(
            '${_financialNumber(conversion[numerator])} / ${_financialNumber(conversion[denominator])}',
            style: _financeValueStyle(12)),
      ]),
      const SizedBox(height: 8),
      Text(
          [
            conversion['date_basis'] == null
                ? 'Basis tanggal: Belum Tersedia.'
                : 'Basis tanggal: ${_financialDateBasisLabel(conversion['date_basis'])}.',
            if (conversion['denominator_scope'] != null)
              'Pembagi: booking yang disetujui dan memiliki intent pada '
                  'environment ini.',
          ].join(' '),
          style: const TextStyle(
              fontSize: 12, height: 1.6, color: Color(0xFF526787))),
    ]));
  }

  Widget _attemptsCard(Json financial) {
    final total = _number(financial['payment_attempts']);
    final rows = [
      ('Berhasil', 'successful_payment_attempts', AppColors.blue),
      ('Gagal', 'failed_attempts', const Color(0xFFE5484D)),
      ('Kedaluwarsa', 'expired_attempts', AppColors.orange),
      ('Status belum diketahui', 'unknown_attempts', AppColors.textMuted),
    ];
    final average = _number(financial['avg_payment_seconds']);
    return _DashboardCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _financeCardHeader('Percobaan Pembayaran',
          trailing: _available && total != null
              ? Text('${_financialNumber(total)} attempts',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF526787)))
              : null),
      const SizedBox(height: 14),
      if (!_available)
        const Text('Belum Tersedia', style: TextStyle(fontSize: 14))
      else ...[
        for (final row in rows)
          _financeAttemptBar(
              row.$1, _number(financial[row.$2]) ?? 0, total ?? 0, row.$3),
        const SizedBox(height: 4),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F6FE),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Rata-rata durasi pembayaran',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF526787))),
                    const SizedBox(height: 6),
                    Text(
                        average == null
                            ? 'Belum Tersedia'
                            : '${_financialNumber(average)} detik',
                        style: _financeValueStyle(18)),
                  ])),
              _financeInfo('Rata-rata waktu dari percobaan dimulai sampai '
                  'pembayaran berhasil.'),
            ])),
      ],
      const SizedBox(height: 12),
      Text(
          'Berhasil dihitung menurut ${_financialDateBasisLabel('paid_utc')}; '
          'status lainnya menurut ${_financialDateBasisLabel('attempt_started_utc')}.',
          style: const TextStyle(
              fontSize: 12, height: 1.6, color: Color(0xFF526787))),
    ]));
  }

  Widget _financeAttemptBar(String label, num count, num total, Color color) {
    final share = total > 0 ? (count / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF526787)))),
              Text('${(share * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF526787))),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(
                value: share,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFFEEF2F8),
                color: color),
          ])),
          SizedBox(
              width: 36,
              child: Text(_financialNumber(count),
                  textAlign: TextAlign.right, style: _financeValueStyle(13))),
        ]));
  }

  Widget _methodCard(Json financial) {
    final mix = financial['method_mix'];
    final items = mix is List ? mix.whereType<Json>().toList() : <Json>[];
    final total = items.fold<num>(
        0, (sum, item) => sum + (_number(item['gross_collected']) ?? 0));
    const palette = [
      AppColors.blue,
      AppColors.orange,
      AppColors.success,
      AppColors.blueDeep,
    ];
    return _DashboardCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _financeCardHeader('Metode & Channel',
          trailing: const Text('Distribusi nominal',
              style: TextStyle(fontSize: 12, color: Color(0xFF526787)))),
      const SizedBox(height: 14),
      if (!_available || mix is! List)
        const Text('Belum Tersedia', style: TextStyle(fontSize: 14))
      else if (items.isEmpty)
        const Text('Belum ada capture pada periode ini.',
            style: TextStyle(fontSize: 14))
      else
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _financeMethodItem(items[i], palette[i % palette.length],
              total > 0 ? (_number(items[i]['gross_collected']) ?? 0) / total : 0,
              single: items.length == 1),
        ],
      if (financial['method_mix_truncated'] == true) ...[
        const SizedBox(height: 12),
        Text(
            'Rincian dibatasi ${financial['method_mix_limit']} grup; total tetap mencakup seluruh grup.',
            style: const TextStyle(
                fontSize: 12, height: 1.5, color: Color(0xFF795018))),
      ],
    ]));
  }

  Widget _financeMethodItem(Json item, Color color, num share,
      {required bool single}) {
    final method = '${item['method'] ?? '—'}';
    final channel = '${item['channel'] ?? '—'}';
    final name =
        '${channel == '—' ? '' : '${channel.toUpperCase()} '}${method.split('_').map(_financialCap).join(' ')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy))),
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(
          value: share.clamp(0.0, 1.0).toDouble(),
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: const Color(0xFFEEF2F8),
          color: color),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: Text(
                '${_financialNumber(item['successful_attempts'])} pembayaran berhasil',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF526787)))),
        Text(_financialMoney(item['gross_collected']),
            style: _financeValueStyle(13)),
      ]),
      const SizedBox(height: 8),
      Text(
          'Channel: $method - $channel.'
          '${single ? ' Seluruh nominal yang teridentifikasi pada snapshot berasal dari channel ini.' : ''}',
          style: const TextStyle(
              fontSize: 12, height: 1.6, color: Color(0xFF526787))),
    ]);
  }
}

// ── Superadmin finance page building blocks ───────────────────────────────

class _FinanceFilterCard extends StatelessWidget {
  const _FinanceFilterCard(
      {super.key,
      required this.icon,
      required this.caption,
      required this.value,
      required this.onTap});
  final IconData icon;
  final String caption;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 20, color: AppColors.blue),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(caption,
                          style: const TextStyle(
                              fontSize: 9.5,
                              letterSpacing: .5,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                    ])),
                const SizedBox(width: 6),
                const Icon(PhosphorIconsRegular.caretDown,
                    size: 16, color: AppColors.blue),
              ]))));
}

class _FinanceTabs extends StatelessWidget {
  const _FinanceTabs({required this.analytics, required this.onChanged});
  final bool analytics;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFE6EDF8),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (final tab in <(String, bool)>[
          ('Ringkasan', false),
          ('Analitik Pembayaran', true),
        ])
          Expanded(
              child: Semantics(
                  selected: analytics == tab.$2,
                  button: true,
                  child: Material(
                      color: analytics == tab.$2
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                          key: ValueKey(
                              'financial-tab-${tab.$2 ? 'analytics' : 'summary'}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onChanged(tab.$2),
                          child: SizedBox(
                              height: 44,
                              child: Center(
                                  child: Text(tab.$1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: analytics == tab.$2
                                              ? AppColors.blue
                                              : const Color(0xFF7F90AD))))))))),
      ]));
}

Widget _financeHeading(String title, String subtitle) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
      const SizedBox(height: 4),
      Text(subtitle,
          style: const TextStyle(
              fontSize: 13, height: 1.5, color: Color(0xFF526787))),
    ]);

Widget _financeCardHeader(String title, {Widget? trailing}) => Row(children: [
      Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy))),
      if (trailing != null) ...[const SizedBox(width: 8), trailing],
    ]);

/// Small "i" badge; tap to read what the figure means.
Widget _financeInfo(String message, {bool onDark = false}) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    showDuration: const Duration(seconds: 5),
    margin: const EdgeInsets.symmetric(horizontal: 24),
    child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
            child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onDark
                        ? Colors.white.withValues(alpha: .2)
                        : AppColors.blueTint),
                child: Icon(PhosphorIconsRegular.info,
                    size: 14,
                    color: onDark ? Colors.white : AppColors.blue)))));

TextStyle _financeValueStyle(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: AppColors.navy,
    fontFeatures: const [FontFeature.tabularFigures()]);

Widget _financeFigureCard(String label, String value, String caption) {
  final money = value.startsWith('Rp');
  return _DashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF526787))),
    const SizedBox(height: 10),
    Text(value, style: _financeValueStyle(money ? 20 : 28)),
    const SizedBox(height: 6),
    Text(caption,
        style: const TextStyle(fontSize: 12, color: Color(0xFF526787))),
  ]));
}

Widget _financeComponentRow(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
          flex: 4,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF526787)))),
      const SizedBox(width: 12),
      // Value sits flush right (space-between), wrapping right-aligned.
      Expanded(
          flex: 5, child: Align(alignment: Alignment.centerRight, child: value)),
    ]));

Widget _financeChip(String text, {bool good = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: good ? AppColors.successTint : const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: good ? AppColors.success : AppColors.textMuted)),
      const SizedBox(width: 6),
      Flexible(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: good ? AppColors.success : AppColors.textSecondary))),
    ]));

String _financialCap(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

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

// Operational wording for server codes. Unknown codes are shown as received
// rather than guessed, so a new backend value is never mislabelled.

String _financialSourceLabel(dynamic source) => switch (source) {
      'simulated_demo_events' => 'Simulasi DEMO',
      'verified_sandbox_events' => 'Pembayaran sandbox terverifikasi',
      'verified_production_events' => 'Pembayaran produksi terverifikasi',
      null || 'unavailable' => 'Belum tersedia',
      _ => '$source',
    };

String _financialAvailabilityLabel(dynamic availability) =>
    switch (availability) {
      'available' => 'data lengkap',
      'partial' => 'data sebagian',
      'unavailable' => 'belum tersedia',
      null => '—',
      _ => '$availability',
    };

/// Which date places a figure in the period; all bases are in UTC.
String _financialDateBasisLabel(dynamic basis) => switch (basis) {
      'paid_utc' => 'tanggal pembayaran berhasil (UTC)',
      'attempt_started_utc' => 'tanggal percobaan dimulai (UTC)',
      'refund_utc' => 'tanggal refund (UTC)',
      'verified_receipts' => 'bukti refund terverifikasi',
      null => '—',
      _ => '$basis',
    };

/// Names of server fields that are not available yet.
String _financialFieldLabel(dynamic field) => switch (field) {
      'verified_capture_source' => 'sumber pembayaran terverifikasi',
      'gateway_fees' => 'biaya gateway',
      'net_revenue' => 'net revenue',
      'settlement' => 'settlement',
      'refunds' => 'refund',
      _ => '$field',
    };

/// `Sumber · kelengkapan`, said once when both mean "not available".
String _financialSourceLine(Json? financial) {
  final source = _financialSourceLabel(financial?['source']);
  if (financial?['availability'] == 'unavailable' &&
      source == _financialSourceLabel(null)) {
    return source;
  }
  return '$source · ${_financialAvailabilityLabel(financial?['availability'])}';
}

String _financialReason(dynamic reason) => switch (reason) {
      'no_verified_payment_source' =>
        'Belum ada pembayaran terverifikasi untuk lingkungan dan cakupan ini.',
      'fees_and_refunds_unavailable' =>
        'Data tersedia sebagian. Biaya gateway, net, settlement, dan kelengkapan refund belum tersedia.',
      'fees_unavailable_refunds_incomplete' =>
        'Data tersedia sebagian. Refund tercatat belum membuktikan kelengkapan; biaya gateway, net, dan settlement belum tersedia.',
      null => 'Sumber pembayaran belum tersedia.',
      _ => 'Keterangan sumber: $reason',
    };
