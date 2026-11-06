part of 'operations_dashboard.dart';

class OperationsReportScreen extends StatefulWidget {
  const OperationsReportScreen(
      {super.key,
      required this.section,
      this.repository,
      this.session,
      this.embedded = false,
      this.active = true,
      this.personal = false,
      this.initialFilters = const {},
      this.adminGuid,
      this.adminName});
  final String section;
  final BusinessRepository? repository;
  final AuthSession? session;
  final bool embedded;
  final bool personal;
  final bool active;
  final Map<String, String> initialFilters;
  final String? adminGuid;
  final String? adminName;
  @override
  State<OperationsReportScreen> createState() => _OperationsReportScreenState();
}

class _OperationsReportScreenState extends State<OperationsReportScreen>
    with WidgetsBindingObserver {
  late final _session = widget.session ?? AuthSession.instance;
  late final _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final _generation = _session.sessionGeneration;
  late final _role = _session.role;
  late Map<String, String> _filters = Map.of(widget.initialFilters);
  String? _destinationLabel;
  OperationalReport? _data;
  ApiPage<OperationalRow>? _rows;
  ApiPage<AdminAccount>? _accounts;
  final Map<String, String> _names = {};
  Object? _error;
  bool _loading = true;
  int _page = 1;
  bool _manage = false;
  int _accountPage = 0;
  int _request = 0;
  bool get _valid =>
      mounted &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      _session.isCurrentGeneration(_generation) &&
      _session.role == _role &&
      (_role == 1 || _role == 2) &&
      (widget.adminGuid == null || _role == 2);
  bool get _paginated =>
      widget.section == 'destinations' || widget.section == 'action-center';
  @override
  void initState() {
    super.initState();
    _session.sessionChanges.addListener(_changed);
    operationsDataChanges.addListener(_dataChanged);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _request++;
        _data = null;
        _rows = null;
        _accounts = null;
        _names.clear();
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
      _changed();
    }
  }

  @override
  void didUpdateWidget(OperationsReportScreen oldWidget) {
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
    _session.sessionChanges.removeListener(_changed);
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
      _rows = null;
      _accounts = null;
      _names.clear();
      _accountPage = 0;
    });
    try {
      final query = {
        ..._filters,
        if (widget.adminGuid != null) 'admin_guid': widget.adminGuid!,
        if (_paginated) 'page': '$_page',
        if (_paginated) 'per_page': '15'
      };
      if (_paginated) {
        final rows =
            await _repository.operationalRows(widget.section, query: query);
        if (!_valid || request != _request) return;
        setState(() {
          _rows = rows;
          _loading = false;
        });
      } else {
        final data =
            await _repository.operationalReport(widget.section, query: query);
        if (!_valid || request != _request) return;
        setState(() {
          _data = data;
          _loading = false;
        });
        if (_role == 2 &&
            widget.section == 'approvals' &&
            widget.adminGuid == null &&
            !widget.personal) {
          await _loadAccounts(request);
        }
      }
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _data = null;
        _rows = null;
        _names.clear();
        _error = e;
        _loading = false;
        if (_scopeError(e)) {
          _filters = {};
          _destinationLabel = null;
        }
      });
      if (_scopeError(e)) _session.me().catchError((Object _) {});
    }
  }

  Future<void> _loadAccounts(int request) async {
    try {
      final accounts = await _repository.adminAccounts(
          query: {'page': '${_accountPage + 1}', 'per_page': '100'});
      if (!_valid || request != _request) return;
      setState(() {
        _accounts = accounts;
        _accountPage++;
        for (final account in accounts.items) {
          _names[account.guid] = account.name;
        }
      });
    } catch (e) {
      if (_valid && request == _request) {
        setState(() {
          _error = e;
          if (_scopeError(e)) {
            _data = null;
            _rows = null;
            _names.clear();
          }
        });
      }
    }
  }

  Future<void> _filter() async {
    final filters = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: _filters,
        utc: widget.section != 'destinations' && widget.section != 'visitors');
    if (filters != null && _valid) {
      _filters = filters;
      _destinationLabel = null;
      _page = 1;
      await _load();
    }
  }

  Future<void> _destinationFilter() async {
    if (!_valid) return;
    String? label;
    final destination = await showOperationsDestinationPicker(context,
        repository: _repository,
        session: _session,
        initial: _filters['destination_guid'],
        onLabelSelected: (value) => label = value);
    if (!_valid || destination == null) return;
    setState(() {
      _destinationLabel = destination.isEmpty ? null : label;
      if (destination.isEmpty) {
        _filters.remove('destination_guid');
      } else {
        _filters['destination_guid'] = destination;
      }
      _page = 1;
    });
    await _load();
  }

  Future<void> _dateFilter() async {
    if (!_valid) return;
    final range = await showOperationsDateRangeCalendar(context,
        from: DateTime.tryParse(_filters['from'] ?? ''),
        to: DateTime.tryParse(_filters['to'] ?? ''));
    if (!_valid || range == null) return;
    setState(() {
      _filters['from'] = isoDay(range.start);
      _filters['to'] = isoDay(range.end);
      _page = 1;
    });
    await _load();
  }

  Future<void> _booking(OperationalRow row) async {
    if (row.bookingGuid == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperationsBookingScreen(
            bookingGuid: row.bookingGuid!,
            repository: _repository,
            session: _session)));
    if (_valid) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    final title = widget.adminName ??
        switch (widget.section) {
          'destinations' =>
            _role == 2 ? 'Perbandingan Destinasi' : 'Kinerja Destinasi',
          'approvals' => widget.personal ? 'Kinerja Saya' : 'Kinerja Admin',
          'visitors' => 'Kunjungan',
          _ => 'Pusat Tindakan'
        };
    final data = _data;
    final values = widget.adminGuid != null
        ? data?.raw['team_operational_totals'] as Json? ?? {}
        : widget.personal || _role == 1
            ? data?.personal ?? {}
            : data?.raw['team_operational_totals'] as Json? ?? {};
    return OperationsPage(
        role: _role,
        title: title,
        subtitle:
            widget.section == 'destinations' || widget.section == 'visitors'
                ? 'Basis tanggal kunjungan · kalender lokal destinasi'
                : widget.section == 'action-center'
                    ? 'Prioritas operasional dari server'
                    : 'Basis tanggal keputusan · UTC',
        embedded: widget.embedded,
        onRefresh: _load,
        children: [
          if (_role == 1 && widget.section == 'destinations') ...[
            OperationsFilterBar(
                filters: _filters,
                keyPrefix: 'destinations',
                destinationLabel: _destinationLabel,
                dateTooltip: 'Tanggal kunjungan · kalender lokal destinasi',
                onDestinationPressed: _destinationFilter,
                onDatePressed: _dateFilter),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  for (final tab in const [(false, 'Kinerja'), (true, 'Kelola')])
                    Expanded(
                        child: Semantics(
                            selected: _manage == tab.$1,
                            child: TextButton(
                                key: ValueKey('destinations-tab-${tab.$1}'),
                                style: TextButton.styleFrom(
                                    foregroundColor: _manage == tab.$1
                                        ? AppColors.blue
                                        : AppColors.textMuted,
                                    backgroundColor: _manage == tab.$1
                                        ? AppColors.surface
                                        : Colors.transparent,
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                onPressed: () =>
                                    setState(() => _manage = tab.$1),
                                child: Text(tab.$2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700))))),
                ])),
            if (_filters.isNotEmpty)
              TextButton(
                  onPressed: () {
                    setState(() {
                      _filters = {};
                      _destinationLabel = null;
                      _page = 1;
                    });
                    _load();
                  },
                  child: const Text('Reset filter')),
            const SizedBox(height: 16),
          ],
          if (!_manage) ...[
            if (_role != 1 || widget.section != 'destinations') ...[
              _filterButton(_filters, _filter),
              const SizedBox(height: 16),
            ],
            if (_loading) const OperationsSkeleton(),
            if (_error != null)
              _errorBlock(_error!, _scopeError(_error) ? _filter : _load,
                  role: _role),
            if (!_loading && _rows != null) ...[
              if (_rows!.items.isEmpty)
                _Notice(_filters.isEmpty
                    ? 'Tidak ada data operasional pada rentang ini.'
                    : 'Tidak ada hasil untuk filter tanggal atau destinasi ini. Atur ulang filter untuk mencoba lagi.'),
              for (final row in _rows!.items)
                widget.section == 'destinations'
                    ? _destination(row)
                    : _actionTile(row, () => _booking(row)),
              _pagination(_rows!.meta, _rows!.links),
            ],
            if (!_loading && data != null) ...[
              Text('Periode: ${_period(data.period)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              if (widget.section == 'visitors') ...[
                if (_role == 1) ...[
                  _DashboardCard(
                      child: Column(children: [
                    Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F3FF),
                            borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.blue, size: 33)),
                    const SizedBox(height: 16),
                    const Text('Verifikasi Tiket QR',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 8),
                    const Text('Scan → Preview → Konfirmasi',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF526787))),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: () => showAdminTicketScannerSheet(
                                context, repository: _repository),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Buka Scan QR'))),
                  ])),
                  const SizedBox(height: 16),
                ],
                const _SectionTitle('Kunjungan teramati'),
                OperationsMetrics(icons: const [
                  Icons.qr_code_scanner_rounded,
                  Icons.confirmation_number_outlined,
                  Icons.percent_rounded,
                  Icons.person_off_outlined,
                ], values: [
                  (
                    'Tiket check-in',
                    _value(data.metrics['checked_in_tickets'])
                  ),
                  (
                    'Booking check-in',
                    _value(data.metrics['checked_in_bookings'])
                  ),
                  (
                    'Tingkat kehadiran',
                    _percent(data.metrics['attendance_rate'])
                  ),
                  ('Tidak hadir', _value(data.metrics['no_show_count']))
                ]),
                const SizedBox(height: 12),
                const _Notice(
                    'Tingkat kehadiran dan no-show belum tersedia karena data kelayakan tiket belum terverifikasi.'),
              ] else ...[
                if (_role == 1) ...[
                  _DashboardCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        const _SectionTitle('Keputusan pribadi'),
                        Text(_value(values['approved_decisions']),
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w800)),
                        const Text('Booking disetujui pada periode ini'),
                      ])),
                  const SizedBox(height: 12),
                ],
                OperationsMetrics(
                    values: _role == 1
                        ? _decisionValues(values).skip(1).toList()
                        : _decisionValues(values),
                    icons: _role == 1
                        ? null
                        : const [
                            Icons.task_alt_rounded,
                            Icons.cancel_outlined,
                            Icons.percent_rounded,
                            Icons.timer_outlined,
                            Icons.verified_outlined,
                          ]),
                const SizedBox(height: 20),
                if (widget.personal || _role == 1)
                  const _Notice(
                      'Grafik menunjukkan keputusan tim pada destinasi yang dapat diakses. Metrik pribadi ditampilkan di atas.'),
                _DashboardCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      const _SectionTitle('Tren keputusan'),
                      Text('Periode: ${_period(data.period)} · UTC',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF526787))),
                      OperationsTrend(
                          rows: data.series,
                          valueKey: 'approved_decisions',
                          secondKey: 'rejected_decisions'),
                      const Text('Disetujui: biru · Ditolak: abu-abu',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF526787))),
                    ])),
                if (widget.personal || _role == 1)
                  const _Notice(
                      'Riwayat pribadi mencakup keputusan Anda pada penugasan sebelumnya.'),
                if (_role == 2 && widget.adminGuid == null && !widget.personal)
                  ..._staff(data),
              ],
            ],
          ],
          if (widget.section == 'destinations' && _role == 1 && _manage) ...[
            const Text('Pengelolaan destinasi',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Kelola destinasi dan kuota sesuai penugasan Anda.',
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final item in const [
                    ('view', 'Kelola destinasi dan kuota', Icons.place_outlined),
                    ('edit', 'Ubah destinasi', Icons.tune_rounded),
                    ('hapus', 'Hapus destinasi', Icons.warning_amber_rounded),
                    ('kuota', 'Kelola kuota', Icons.calendar_today_outlined),
                  ]) ...[
                    ListTile(
                        key: ValueKey('destinations-manage-${item.$1}'),
                        minTileHeight: 52,
                        minLeadingWidth: 20,
                        horizontalTitleGap: 12,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading:
                            Icon(item.$3, size: 20, color: AppColors.blue),
                        title: Text(item.$2,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy)),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textMuted),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => DaftarWisataScreen(
                                    mode: item.$1,
                                    repository: _repository,
                                    session: _session)))),
                    if (item.$1 != 'kuota')
                      const Divider(height: 1, color: AppColors.border),
                  ],
                ])),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: .06),
                    border: Border.all(
                        color: AppColors.blue.withValues(alpha: .18)),
                    borderRadius: BorderRadius.circular(16)),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Hak akses tetap dijaga',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blueDeep)),
                      SizedBox(height: 8),
                      Text(
                          'Anda hanya dapat mengelola destinasi yang ditugaskan kepada akun Anda.',
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.textMuted)),
                    ])),
          ],
          if (widget.section == 'destinations' && _role != 1) ...[
            const SizedBox(height: 16),
            _routeLink(
                'Kelola destinasi dan kuota',
                () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DaftarWisataScreen(
                        repository: _repository, session: _session)))),
            for (final mode in [
              ('edit', 'Ubah destinasi'),
              ('hapus', 'Hapus destinasi'),
              ('kuota', 'Kelola kuota')
            ])
              _routeLink(
                  mode.$2,
                  () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => DaftarWisataScreen(
                          mode: mode.$1,
                          repository: _repository,
                          session: _session)))),
          ],
        ]);
  }

  List<Widget> _staff(OperationalReport data) {
    final decisions = {
      for (final row in data.staff)
        row['admin_guid'] as String: row['decisions']
    };
    final workload = {
      for (final row in data.staffWorkload)
        row['admin_guid'] as String: row['active_claims']
    };
    final guids = {...decisions.keys, ...workload.keys};
    return [
      const SizedBox(height: 24),
      const _SectionTitle('Perbandingan Admin'),
      if (guids.isEmpty)
        const _Notice(
            'Belum ada keputusan atau claim aktif untuk ditampilkan.'),
      for (final guid in guids)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border)),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF3FF),
                        child: Icon(Icons.person_outline_rounded,
                            color: AppColors.blue)),
                    title: Text(_names[guid] ?? 'Admin · $guid',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        'Keputusan: ${_value(decisions[guid])} · claim aktif: ${_value(workload[guid])}\nSLA individu tersedia di detail.'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => OperationsReportScreen(
                                section: 'approvals',
                                adminGuid: guid,
                                adminName: _names[guid] ?? 'Detail Admin',
                                repository: _repository,
                                session: _session,
                                initialFilters: _filters)))))),
      if (_accounts?.links?['next'] != null ||
          (_accountPage < (_number(_accounts?.meta?['last_page']) ?? 0)))
        TextButton(
            onPressed: () => _loadAccounts(_request),
            child: const Text('Muat nama Admin berikutnya')),
    ];
  }

  Widget _destination(OperationalRow row) {
    final raw = row.raw;
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(17)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.place_outlined, color: AppColors.blue, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text(row.name ?? 'Destinasi',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy))),
          ]),
          const SizedBox(height: 12),
          OperationsMetrics(values: [
            ('Kapasitas', _value(raw['capacity'])),
            ('Teralokasi', _value(raw['allocated'])),
            ('Terkonfirmasi', _value(raw['confirmed_quantity'])),
            ('Sisa kapasitas', _value(raw['remaining']))
          ], compact: true),
          const SizedBox(height: 14),
          if ((_role != 1 || (_number(raw['capacity']) ?? 0) > 0) &&
              _number(raw['reserved_occupancy_percent']) != null) ...[
            Text(
                'Alokasi terhadap kapasitas · ${_percent(raw['reserved_occupancy_percent'])}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF526787))),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: (_number(raw['reserved_occupancy_percent'])! / 100)
                    .clamp(0.0, 1.0)
                    .toDouble(),
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: const Color(0xFFEDF2F9),
                color: AppColors.blue),
            const SizedBox(height: 14),
          ],
          Text(
              'Booking: ${_value(raw['bookings'])} · Jumlah diminta: ${_value(raw['quantity_requested'])}',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(
              _role == 1 && (_number(raw['capacity']) ?? 0) <= 0
                  ? 'Okupansi: — · Belum tersedia'
                  : 'Okupansi alokasi: ${_percent(raw['reserved_occupancy_percent'])} · konfirmasi: ${_percent(raw['confirmed_occupancy_percent'])}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          const Text('Tiket layak hadir: — · Belum tersedia',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]));
  }

  Widget _pagination(Json? meta, Json? links) {
    final last = _number(meta?['last_page']);
    final hasNext = links?['next'] != null || (last != null && _page < last);
    return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
              onPressed: _page > 1
                  ? () {
                      _page--;
                      _load();
                    }
                  : null,
              child: const Text('Sebelumnya')),
          Text('Halaman $_page', style: const TextStyle(fontSize: 12)),
          TextButton(
              onPressed: hasNext
                  ? () {
                      _page++;
                      _load();
                    }
                  : null,
              child: const Text('Berikutnya'))
        ]);
  }
}
