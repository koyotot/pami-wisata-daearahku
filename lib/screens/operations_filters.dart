part of 'operations_dashboard.dart';

Future<Map<String, String>?> showOperationsFilters(BuildContext context,
        {required BusinessRepository repository,
        required AuthSession session,
        required Map<String, String> initial,
        bool financial = false,
        bool utc = false}) =>
    showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.bg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Theme(
            data: session.role == 1
                ? AppColors.operationsTheme
                : Theme.of(context),
            child: _OperationsFilters(
                repository: repository,
                session: session,
                initial: initial,
                financial: financial,
                utc: utc)));

class _OperationsFilters extends StatefulWidget {
  const _OperationsFilters(
      {required this.repository,
      required this.session,
      required this.initial,
      this.financial = false,
      this.utc = false});
  final BusinessRepository repository;
  final AuthSession session;
  final Map<String, String> initial;
  final bool financial;
  final bool utc;
  @override
  State<_OperationsFilters> createState() => _OperationsFiltersState();
}

class _OperationsFiltersState extends State<_OperationsFilters> {
  late final int _generation = widget.session.sessionGeneration;
  late final int? _role = widget.session.role;
  late String? _destination = widget.initial['destination_guid'];
  String? _destinationLabel;
  late DateTime? _from = DateTime.tryParse(widget.initial['from'] ?? '');
  late DateTime? _to = DateTime.tryParse(widget.initial['to'] ?? '');
  late String _financePeriod =
      widget.initial['from'] == null ? 'month' : 'custom';
  final Map<String, Destination> _destinations = {};
  int _page = 0;
  bool _next = true;
  bool _loading = false;
  Object? _error;
  String? _validation;
  int _request = 0;
  bool get _valid =>
      mounted &&
      widget.session.authenticated.value &&
      widget.session.deviceSessionReady &&
      widget.session.isCurrentGeneration(_generation) &&
      widget.session.role == _role;
  @override
  void initState() {
    super.initState();
    widget.session.sessionChanges.addListener(_changed);
    if (widget.financial) operationsDataChanges.addListener(_changed);
    if (_role != 1) _load();
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _request++;
        _destinations.clear();
        _destination = null;
        if (widget.financial) {
          _from = null;
          _to = null;
          _financePeriod = 'month';
          _validation = null;
        }
        _page = 0;
        _next = true;
        _loading = false;
        _error ??= const ApiException(
            'Akses diperbarui. Muat ulang pilihan destinasi.');
      });
    }
  }

  @override
  void dispose() {
    widget.session.sessionChanges.removeListener(_changed);
    if (widget.financial) operationsDataChanges.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_valid || _loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.adminDestinations(
          query: {'page': '${_page + 1}', 'per_page': '100', 'status': 'all'});
      if (!_valid || request != _request) return;
      setState(() {
        for (final d in page.items) {
          _destinations[d.guid] = d;
        }
        _page++;
        _next = page.links?['next'] != null ||
            _page < (_number(page.meta?['last_page']) ?? 1);
        _loading = false;
      });
    } catch (e) {
      if (_valid && request == _request) {
        setState(() {
          _error = e;
          _loading = false;
          if (_scopeError(e)) {
            _destinations.clear();
            _destination = null;
          }
        });
        if (_scopeError(e)) widget.session.me().catchError((Object _) {});
      }
    }
  }

  Future<void> _dates() async {
    final now = DateTime.now();
    final range = _role == 1
        ? await showOperationsDateRangeCalendar(context,
            from: _from, to: _to, financial: widget.financial, utc: widget.utc)
        : await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(now.year + 3, 12, 31),
            initialDateRange: _from != null && _to != null
                ? DateTimeRange(start: _from!, end: _to!)
                : null,
            helpText: 'Pilih periode maksimal 366 hari');
    if (range == null || !_valid) return;
    setState(() {
      final days = DateTime.utc(range.end.year, range.end.month, range.end.day)
          .difference(DateTime.utc(
              range.start.year, range.start.month, range.start.day))
          .inDays;
      if (widget.financial ? days >= 366 : days > 366) {
        _validation =
            'Periode maksimal 366 hari${widget.financial ? ' inklusif' : ''}.';
      } else {
        _from = range.start;
        _to = range.end;
        if (widget.financial) _financePeriod = 'custom';
        _validation = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => _role == 1
      ? _roleOneFilters(context)
      : Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text(widget.financial ? 'Filter Keuangan' : 'Filter Destinasi',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy)),
                const SizedBox(height: 6),
                Text(
                    widget.financial
                        ? 'Periode UTC, maksimal 366 hari inklusif. Scope mengikuti akses Anda.'
                        : 'Sesuaikan destinasi dan periode operasional.',
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xFF526787))),
                const SizedBox(height: 24),
                const Text('Destinasi yang dapat diakses',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                    key: widget.financial
                        ? ValueKey(
                            '$_destination-${_destinations.containsKey(_destination)}')
                        : null,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.place_outlined,
                            color: AppColors.blue),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14))),
                    initialValue: _destinations.containsKey(_destination)
                        ? _destination
                        : null,
                    isExpanded: true,
                    hint: Text(_destination != null &&
                            !_destinations.containsKey(_destination)
                        ? 'Muat pilihan untuk memeriksa filter sebelumnya'
                        : 'Semua destinasi yang dapat diakses'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Semua destinasi yang dapat diakses')),
                      for (final d in _destinations.values)
                        DropdownMenuItem(
                            value: d.guid,
                            child:
                                Text(d.name, overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: _valid
                        ? (value) => setState(
                            () => _destination = value == '' ? null : value)
                        : null),
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator()),
                if (_error != null) _errorBlock(_error!, _load, role: _role),
                if (_next && !_loading)
                  TextButton(
                      onPressed: _load,
                      child: const Text('Muat destinasi berikutnya')),
                if (!_loading && _error == null && _destinations.isEmpty)
                  const _Notice(
                      'Belum ada destinasi ditugaskan. Hubungi Superadmin.'),
                const SizedBox(height: 20),
                const Text('Periode',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                const SizedBox(height: 8),
                if (widget.financial) ...[
                  DropdownButtonFormField<String>(
                      key: ValueKey(_financePeriod),
                      initialValue: _financePeriod,
                      decoration:
                          const InputDecoration(labelText: 'Periode UTC'),
                      items: const [
                        DropdownMenuItem(
                            value: 'month', child: Text('Bulan ini')),
                        DropdownMenuItem(
                            value: 'week', child: Text('7 hari terakhir')),
                        DropdownMenuItem(
                            value: 'custom', child: Text('Rentang khusus')),
                      ],
                      onChanged: !_valid
                          ? null
                          : (value) => setState(() {
                                _financePeriod = value!;
                                _validation = null;
                                if (value == 'month') {
                                  _from = null;
                                  _to = null;
                                } else if (value == 'week') {
                                  final now = DateTime.now().toUtc();
                                  _to = DateTime.utc(
                                      now.year, now.month, now.day);
                                  _from =
                                      _to!.subtract(const Duration(days: 6));
                                }
                              })),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                    onPressed: _valid ? _dates : null,
                    style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.blue,
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(48, 52),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(_from == null
                        ? widget.financial
                            ? _financePeriod == 'custom'
                                ? 'Pilih rentang UTC'
                                : 'Bulan ini · UTC (default)'
                            : 'Pilih periode'
                        : '${isoDay(_from!)} — ${isoDay(_to!)}')),
                if (_validation != null) _Notice(_validation!),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _valid &&
                            !_loading &&
                            _error == null &&
                            _validation == null &&
                            (!widget.financial ||
                                _financePeriod != 'custom' ||
                                (_from != null && _to != null)) &&
                            (_destination == null ||
                                _destinations.containsKey(_destination))
                        ? () => Navigator.pop(context, <String, String>{
                              if (_destination != null)
                                'destination_guid': _destination!,
                              if (_from != null && _to != null)
                                'from': isoDay(_from!),
                              if (_from != null && _to != null)
                                'to': isoDay(_to!)
                            })
                        : null,
                    child: const Text('Terapkan filter')),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: _valid
                        ? () {
                            setState(() {
                              _destination = null;
                              _from = null;
                              _to = null;
                              _financePeriod = 'month';
                              _validation = null;
                            });
                          }
                        : null,
                    child: const Text('Reset filter')),
              ])));

  Widget _roleOneFilters(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OperationsSheetHeading(
                        title: 'Filter destinasi & periode',
                        subtitle: widget.financial
                            ? 'Periode UTC · maksimal 366 hari inklusif'
                            : 'Scope mengikuti penugasan. Tanggal mengikuti basis laporan.'),
                    const SizedBox(height: 24),
                    const Text('Destinasi',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _OperationsFilterField(
                        label: _destination == null
                            ? 'Semua destinasi saya'
                            : _destinationLabel ?? '1 destinasi dipilih',
                        icon: Icons.place_outlined,
                        onPressed: !_valid
                            ? null
                            : () async {
                                final value =
                                    await showOperationsDestinationPicker(
                                        context,
                                        repository: widget.repository,
                                        session: widget.session,
                                        initial: _destination,
                                        onLabelSelected: (label) =>
                                            _destinationLabel = label);
                                if (!_valid || value == null) return;
                                setState(() => _destination =
                                    value.isEmpty ? null : value);
                              }),
                    const SizedBox(height: 24),
                    const Text('Periode',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _OperationsFilterField(
                        label: _from != null && _to != null
                            ? '${isoDay(_from!)} — ${isoDay(_to!)}'
                            : widget.financial
                                ? 'Bulan ini · UTC (default)'
                                : 'Pilih rentang tanggal',
                        icon: Icons.date_range_outlined,
                        onPressed: _valid ? _dates : null),
                    if (_validation != null) _Notice(_validation!),
                    if (!_valid)
                      const _Notice(
                          'Akses berubah. Tutup filter dan buka kembali dari akun aktif.'),
                    const SizedBox(height: 24),
                    FilledButton(
                        key: const ValueKey('operations-apply-filters'),
                        onPressed: _valid && _validation == null
                            ? () => Navigator.pop(context, <String, String>{
                                  if (_destination != null)
                                    'destination_guid': _destination!,
                                  if (_from != null && _to != null)
                                    'from': isoDay(_from!),
                                  if (_from != null && _to != null)
                                    'to': isoDay(_to!),
                                })
                            : null,
                        child: const Text('Terapkan filter')),
                    TextButton(
                        key: const ValueKey('operations-reset-filters'),
                        onPressed: !_valid
                            ? null
                            : () => setState(() {
                                  _destination = null;
                                  _from = null;
                                  _to = null;
                                  _validation = null;
                                  _financePeriod = 'month';
                                }),
                        child: const Text('Reset filter')),
                  ]))));
}

/// Null cancels; an empty string selects all destinations in the current scope.
Future<String?> showOperationsDestinationPicker(BuildContext context,
        {required BusinessRepository repository,
        required AuthSession session,
        String? initial,
        ValueChanged<String>? onLabelSelected}) =>
    showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.bg,
        builder: (_) => Theme(
            data: AppColors.operationsTheme,
            child: _OperationsDestinationPicker(
                repository: repository,
                session: session,
                initial: initial,
                onLabelSelected: onLabelSelected)));

class _OperationsDestinationPicker extends StatefulWidget {
  const _OperationsDestinationPicker(
      {required this.repository,
      required this.session,
      this.initial,
      this.onLabelSelected});
  final BusinessRepository repository;
  final AuthSession session;
  final String? initial;
  final ValueChanged<String>? onLabelSelected;

  @override
  State<_OperationsDestinationPicker> createState() =>
      _OperationsDestinationPickerState();
}

class _OperationsDestinationPickerState
    extends State<_OperationsDestinationPicker> {
  late final _generation = widget.session.sessionGeneration;
  late final _role = widget.session.role;
  final Map<String, Destination> _items = {};
  String _search = '';
  Object? _error;
  bool _loading = true;
  int _request = 0;

  bool get _valid =>
      mounted &&
      widget.session.authenticated.value &&
      widget.session.deviceSessionReady &&
      widget.session.isCurrentGeneration(_generation) &&
      widget.session.role == _role;

  @override
  void initState() {
    super.initState();
    widget.session.sessionChanges.addListener(_changed);
    operationsDataChanges.addListener(_changed);
    _load();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      _request++;
      _items.clear();
      _loading = false;
      _error = const ApiException(
          'Akses destinasi berubah. Tarik ke bawah untuk memperbarui pilihan.');
    });
  }

  @override
  void dispose() {
    _request++;
    widget.session.sessionChanges.removeListener(_changed);
    operationsDataChanges.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_valid) return;
    final request = ++_request;
    setState(() {
      _items.clear();
      _error = null;
      _loading = true;
    });
    try {
      var pageNumber = 1;
      var hasNext = true;
      while (hasNext) {
        final page = await widget.repository.adminDestinations(query: {
          'page': '$pageNumber',
          'per_page': '100',
          'status': 'all',
        });
        if (!_valid || request != _request) return;
        setState(() {
          for (final destination in page.items) {
            _items[destination.guid] = destination;
          }
        });
        hasNext = page.links?['next'] != null ||
            pageNumber < (_number(page.meta?['last_page']) ?? 1);
        pageNumber++;
      }
      if (_valid && request == _request) setState(() => _loading = false);
    } catch (error) {
      if (!_valid || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
        _items.clear();
      });
      if (_scopeError(error)) widget.session.me().catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _items.values
        .where(
            (item) => item.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final enabled = _valid && !_loading && _error == null;
    return SafeArea(
        top: false,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
            child: SizedBox(
                height: math.max(
                    0,
                    MediaQuery.sizeOf(context).height * .8 -
                        MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _OperationsSheetHeading(
                          title: 'Pilih destinasi',
                          subtitle: 'Hanya destinasi dalam penugasan Anda.'),
                      const SizedBox(height: 16),
                      TextField(
                          key: const ValueKey('operations-destination-search'),
                          decoration: const InputDecoration(
                              labelText: 'Cari destinasi',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (value) =>
                              setState(() => _search = value)),
                      const SizedBox(height: 12),
                      if (_loading) const LinearProgressIndicator(),
                      Expanded(
                          child: RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    if (_error != null)
                                      _Notice(_valid
                                          ? 'Pilihan destinasi belum tersedia. Tarik ke bawah untuk mencoba kembali.'
                                          : 'Sesi atau akses berubah. Tutup pemilih destinasi.'),
                                    _option(
                                        'Semua destinasi saya',
                                        '',
                                        widget.initial == null ||
                                            widget.initial!.isEmpty,
                                        enabled),
                                    for (final destination in matches)
                                      _option(
                                          destination.name,
                                          destination.guid,
                                          widget.initial == destination.guid,
                                          enabled),
                                    if (!_loading &&
                                        _error == null &&
                                        matches.isEmpty)
                                      _Notice(_items.isEmpty
                                          ? 'Belum ada destinasi ditugaskan. Hubungi Superadmin.'
                                          : 'Tidak ada destinasi yang cocok dengan pencarian.'),
                                  ]))),
                    ]))));
  }

  Widget _option(String label, String value, bool selected, bool enabled) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
              selected: selected,
              child: TextButton(
                  key: ValueKey('operations-destination-$value'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      backgroundColor: selected
                          ? AppColors.blue.withValues(alpha: .08)
                          : AppColors.surface,
                      minimumSize: const Size(48, 56),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: enabled
                      ? () {
                          widget.onLabelSelected?.call(label);
                          Navigator.pop(context, value);
                        }
                      : null,
                  child: Row(children: [
                    const Icon(Icons.place_outlined, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                    const SizedBox(width: 8),
                    Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: AppColors.blue),
                  ]))));
}

Future<DateTimeRange?> showOperationsDateRangeCalendar(BuildContext context,
        {DateTime? from,
        DateTime? to,
        bool financial = false,
        bool utc = false,
        bool singleDay = false,
        DateTime? firstDate,
        DateTime? lastDate}) =>
    showModalBottomSheet<DateTimeRange>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.bg,
        builder: (_) => Theme(
            data: AppColors.operationsTheme,
            child: _OperationsDateRangeCalendar(
                from: from,
                to: to,
                financial: financial,
                utc: utc,
                singleDay: singleDay,
                firstDate: firstDate,
                lastDate: lastDate)));

class _OperationsDateRangeCalendar extends StatefulWidget {
  const _OperationsDateRangeCalendar(
      {this.from,
      this.to,
      this.financial = false,
      this.utc = false,
      this.singleDay = false,
      this.firstDate,
      this.lastDate});
  final DateTime? from;
  final DateTime? to;
  final bool financial;
  final bool utc;
  final bool singleDay;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_OperationsDateRangeCalendar> createState() =>
      _OperationsDateRangeCalendarState();
}

class _OperationsDateRangeCalendarState
    extends State<_OperationsDateRangeCalendar> {
  late final DateTime _now =
      widget.financial || widget.utc ? DateTime.now().toUtc() : DateTime.now();
  late DateTime? _from = widget.from;
  late DateTime? _to = widget.to;
  late DateTime _month = DateTime((_from ?? _now).year, (_from ?? _now).month);
  bool _selectingStart = false;
  String? _validation;
  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
  late final DateTime _first = widget.firstDate ?? DateTime(2020);
  late final DateTime _last =
      widget.lastDate ?? DateTime(_now.year + 3, 12, 31);

  void _select(DateTime value) {
    setState(() {
      _validation = null;
      if (widget.singleDay) {
        _from = value;
        _to = value;
      } else if (_selectingStart || _from == null || _to != null) {
        _from = value;
        _to = null;
        _selectingStart = false;
      } else if (_day(value).isBefore(_day(_from!))) {
        _to = _from;
        _from = value;
      } else {
        _to = value;
      }
      if (_from != null && _to != null) {
        final days = _day(_to!).difference(_day(_from!)).inDays;
        if (widget.financial ? days >= 366 : days > 366) {
          _validation =
              'Periode maksimal 366 hari${widget.financial ? ' inklusif' : ''}.';
          _to = null;
        }
      }
    });
  }

  void _preset(int? days) => setState(() {
        _to = DateTime(_now.year, _now.month, _now.day);
        _from = days == null
            ? DateTime(_now.year, _now.month)
            : DateTime(_now.year, _now.month, _now.day - days + 1);
        _month = DateTime(_from!.year, _from!.month);
        _selectingStart = false;
        _validation = null;
      });

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .86),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _OperationsSheetHeading(
                    title: widget.singleDay ? 'Pilih tanggal' : 'Pilih periode',
                    subtitle: widget.singleDay
                        ? 'Tanggal kalender destinasi'
                        : widget.financial || widget.utc
                            ? 'Kalender UTC · maksimal 366 hari${widget.financial ? ' inklusif' : ''}'
                            : 'Rentang tanggal · maksimal 366 hari'),
                Flexible(
                    child: SingleChildScrollView(
                        child: Column(children: [
                  const SizedBox(height: 16),
                  if (!widget.singleDay)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final preset in <(String, int?)>[
                        ('7 hari', 7),
                        ('30 hari', 30),
                        ('Bulan ini', null)
                      ])
                        OutlinedButton(
                            key: ValueKey(
                                'operations-preset-${preset.$2 ?? 'month'}'),
                            onPressed: () => _preset(preset.$2),
                            child: Text(preset.$1)),
                    ]),
                  const SizedBox(height: 16),
                  if (!widget.singleDay)
                    Row(children: [
                      Expanded(
                          child: _OperationsFilterField(
                              label:
                                  'Mulai\n${_from == null ? 'Pilih tanggal' : isoDay(_from!)}',
                              onPressed: () => setState(() {
                                    _selectingStart = true;
                                    _validation = null;
                                  }))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _OperationsFilterField(
                              label:
                                  'Selesai\n${_to == null ? 'Pilih tanggal' : isoDay(_to!)}',
                              onPressed: () => setState(() {
                                    _to = null;
                                    _selectingStart = false;
                                    _validation = null;
                                  }))),
                    ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    IconButton(
                        tooltip: 'Bulan sebelumnya',
                        onPressed:
                            _month.isAfter(DateTime(_first.year, _first.month))
                                ? () => setState(() => _month =
                                    DateTime(_month.year, _month.month - 1))
                                : null,
                        icon: const Icon(Icons.chevron_left)),
                    Expanded(
                        child: Text(
                            '${_months[_month.month - 1]} ${_month.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy))),
                    IconButton(
                        tooltip: 'Bulan berikutnya',
                        onPressed:
                            _month.isBefore(DateTime(_last.year, _last.month))
                                ? () => setState(() => _month =
                                    DateTime(_month.year, _month.month + 1))
                                : null,
                        icon: const Icon(Icons.chevron_right)),
                  ]),
                  LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                              width: math.max(constraints.maxWidth, 336),
                              child: _calendar(context)))),
                  if (_validation != null) _Notice(_validation!),
                  TextButton(
                      key: const ValueKey('operations-reset-period'),
                      onPressed: () => setState(() {
                            _from = null;
                            _to = null;
                            _validation = null;
                          }),
                      child: const Text('Pilih ulang tanggal')),
                ]))),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        key: const ValueKey('operations-apply-period'),
                        onPressed:
                            _from != null && _to != null && _validation == null
                                ? () => Navigator.pop(context,
                                    DateTimeRange(start: _from!, end: _to!))
                                : null,
                        child: Text(widget.singleDay
                            ? 'Pilih tanggal'
                            : 'Terapkan periode'))),
              ]))));

  Widget _calendar(BuildContext context) {
    final offset = DateTime(_month.year, _month.month).weekday - 1;
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    return Column(children: [
      Row(children: [
        for (final day in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
          Expanded(
              child: Text(day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.navy)))
      ]),
      const SizedBox(height: 8),
      GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48 +
                  math.max(0, MediaQuery.textScalerOf(context).scale(14) - 14)),
          itemCount: offset + count,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final date =
                DateTime(_month.year, _month.month, index - offset + 1);
            final endpoint = (_from != null && _day(date) == _day(_from!)) ||
                (_to != null && _day(date) == _day(_to!));
            final inRange = _from != null &&
                _to != null &&
                !_day(date).isBefore(_day(_from!)) &&
                !_day(date).isAfter(_day(_to!));
            final today = _day(date) == _day(_now);
            return Semantics(
                selected: endpoint || inRange,
                child: TextButton(
                    key: ValueKey('operations-day-${isoDay(date)}'),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        foregroundColor:
                            endpoint ? AppColors.surface : AppColors.navy,
                        backgroundColor: endpoint
                            ? AppColors.blue
                            : inRange
                                ? AppColors.blue.withValues(alpha: .08)
                                : AppColors.surface,
                        side: today && !endpoint
                            ? const BorderSide(color: AppColors.blue)
                            : BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _day(date).isBefore(_day(_first)) ||
                            _day(date).isAfter(_day(_last))
                        ? null
                        : () => _select(date),
                    child: Tooltip(
                        message: '${isoDay(date)}${today ? ', hari ini' : ''}',
                        child: Text('${date.day}',
                            semanticsLabel:
                                '${isoDay(date)}${today ? ', hari ini' : ''}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)))));
          }),
    ]);
  }
}

class _OperationsSheetHeading extends StatelessWidget {
  const _OperationsSheetHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.navy)),
        ])),
        IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ]);
}

class _OperationsFilterField extends StatelessWidget {
  const _OperationsFilterField(
      {required this.label, this.icon, this.onPressed});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.all(16),
          side: const BorderSide(color: AppColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 12)],
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        const Icon(Icons.keyboard_arrow_down, size: 20),
      ]));
}
