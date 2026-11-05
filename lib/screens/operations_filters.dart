part of 'operations_dashboard.dart';

Future<Map<String, String>?> showOperationsFilters(BuildContext context,
        {required BusinessRepository repository,
        required AuthSession session,
        required Map<String, String> initial,
        bool financial = false}) =>
    showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.bg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _OperationsFilters(
            repository: repository,
            session: session,
            initial: initial,
            financial: financial));

class _OperationsFilters extends StatefulWidget {
  const _OperationsFilters(
      {required this.repository,
      required this.session,
      required this.initial,
      this.financial = false});
  final BusinessRepository repository;
  final AuthSession session;
  final Map<String, String> initial;
  final bool financial;
  @override
  State<_OperationsFilters> createState() => _OperationsFiltersState();
}

class _OperationsFiltersState extends State<_OperationsFilters> {
  late final int _generation = widget.session.sessionGeneration;
  late final int? _role = widget.session.role;
  late String? _destination = widget.initial['destination_guid'];
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
    _load();
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
    final range = await showDateRangePicker(
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
  Widget build(BuildContext context) => Padding(
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
                    prefixIcon:
                        const Icon(Icons.place_outlined, color: AppColors.blue),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border)),
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
                        child: Text(d.name, overflow: TextOverflow.ellipsis))
                ],
                onChanged: _valid
                    ? (value) => setState(
                        () => _destination = value == '' ? null : value)
                    : null),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator()),
            if (_error != null) _errorBlock(_error!, _load),
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
                  decoration: const InputDecoration(labelText: 'Periode UTC'),
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('Bulan ini')),
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
                              _to = DateTime.utc(now.year, now.month, now.day);
                              _from = _to!.subtract(const Duration(days: 6));
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
                          if (_from != null && _to != null) 'to': isoDay(_to!)
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
}
