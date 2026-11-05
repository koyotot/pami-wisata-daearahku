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
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _error = e;
        _financial = null;
        _loading = false;
        if (_scopeError(e)) _filters = {};
      });
      if (_scopeError(e)) _session.me().catchError((Object _) {});
    }
  }

  Future<void> _filter() async {
    final request = _request;
    final filters = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: _filters,
        financial: true);
    if (filters == null || !_valid || request != _request) return;
    _filters = filters;
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
    final financial = _financial;
    final period = financial?['period'];
    return Theme(
        data: AppColors.visitorTheme,
        child: OperationsPage(
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
                _errorBlock(_error!, _scopeError(_error) ? _filter : _load),
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
                    IconButton(
                        tooltip: 'Perbarui keuangan',
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 20)),
                  ]),
              ],
            ]));
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

  Widget _preview() => _DashboardCard(
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
