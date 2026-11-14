part of 'operations_dashboard.dart';

/// Superadmin "Perbandingan Destinasi": capacity, allocation and confirmation
/// per destination for the selected period.

String _thousands(num value) {
  final digits = value.round().abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Up to two decimals with a comma, trailing zeros trimmed (0,33% / 12,5% / 100%).
String _decimalPercent(num? value) {
  if (value == null) return '—';
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return '${text.replaceAll('.', ',')}%';
}

String _longPeriodLabel(Map<String, String> filters) {
  final from = DateTime.tryParse(filters['from'] ?? '');
  final to = DateTime.tryParse(filters['to'] ?? '');
  if (from == null || to == null) return 'Semua tanggal';
  final fromMonth = visitMonths[from.month - 1];
  final toMonth = visitMonths[to.month - 1];
  if (from.year == to.year && from.month == to.month) {
    return from.day == to.day
        ? '${to.day} $toMonth ${to.year}'
        : '${from.day}–${to.day} $toMonth ${to.year}';
  }
  if (from.year == to.year) {
    return '${from.day} $fromMonth–${to.day} $toMonth ${to.year}';
  }
  return '${from.day} $fromMonth ${from.year}–${to.day} $toMonth ${to.year}';
}

enum _CapacityState { allocated, unallocated, noQuota }

class _CapacityRow {
  _CapacityRow(this.row);
  final OperationalRow row;
  Json get raw => row.raw;
  String get name => row.name ?? 'Destinasi';
  num get capacity => _number(raw['capacity']) ?? 0;
  num get allocated => _number(raw['allocated']) ?? 0;
  num get confirmed => _number(raw['confirmed_quantity']) ?? 0;
  bool get hasQuota => capacity > 0;
  num get remaining =>
      _number(raw['remaining']) ?? (capacity - allocated).clamp(0, capacity);
  num? get allocatedPercent => !hasQuota
      ? null
      : _number(raw['reserved_occupancy_percent']) ??
          allocated / capacity * 100;
  num? get confirmedPercent => !hasQuota
      ? null
      : _number(raw['confirmed_occupancy_percent']) ??
          confirmed / capacity * 100;
  _CapacityState get state => !hasQuota
      ? _CapacityState.noQuota
      : allocated > 0
          ? _CapacityState.allocated
          : _CapacityState.unallocated;
}

class _DestinationComparison extends StatefulWidget {
  const _DestinationComparison(
      {required this.rows,
      required this.loading,
      required this.error,
      required this.filters,
      required this.destinationLabel,
      required this.role,
      required this.onRefresh,
      required this.onRetry,
      required this.onPickDestination,
      required this.onPickPeriod,
      required this.onReset,
      required this.onManage});
  final List<OperationalRow>? rows;
  final bool loading;
  final Object? error;
  final Map<String, String> filters;
  final String? destinationLabel;
  final int role;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onPickDestination;
  final VoidCallback onPickPeriod;
  final VoidCallback onReset;
  final VoidCallback onManage;

  @override
  State<_DestinationComparison> createState() => _DestinationComparisonState();
}

class _DestinationComparisonState extends State<_DestinationComparison> {
  _CapacityState? _chip;
  String _sort = 'default';

  static const _sortLabels = {
    'default': 'Urutan awal',
    'allocated': 'Alokasi tertinggi',
    'remaining': 'Sisa kapasitas terbesar',
    'name': 'Nama A–Z',
  };

  List<_CapacityRow> get _all =>
      [for (final row in widget.rows ?? const <OperationalRow>[]) _CapacityRow(row)];

  List<_CapacityRow> _visible(List<_CapacityRow> all) {
    final list = [
      for (final item in all)
        if (_chip == null || item.state == _chip) item
    ];
    switch (_sort) {
      case 'allocated':
        list.sort((a, b) => b.allocated.compareTo(a.allocated));
      case 'remaining':
        list.sort((a, b) => b.remaining.compareTo(a.remaining));
      case 'name':
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  Future<void> _pickSort() async {
    final value = await showOperationsOptionSheet(context,
        title: 'Urutkan destinasi',
        options: _sortLabels,
        selected: _sort,
        keyPrefix: 'comparison-sort');
    if (value != null && mounted) setState(() => _sort = value);
  }

  void _reset() {
    setState(() {
      _chip = null;
      _sort = 'default';
    });
    widget.onReset();
  }

  void _showDetail(_CapacityRow item) {
    showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _CapacityDetailSheet(item: item));
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final ready = !widget.loading && widget.error == null && widget.rows != null;
    final visible = ready ? _visible(all) : const <_CapacityRow>[];
    return OperationsPage(
        role: widget.role,
        title: 'Perbandingan Destinasi',
        subtitle: 'Basis tanggal kunjungan · kalender lokal destinasi',
        embedded: false,
        onRefresh: widget.onRefresh,
        bottomBar: ready ? _bottomBar(all.length) : null,
        children: [
          if (widget.loading) const OperationsSkeleton(),
          if (widget.error != null)
            _errorBlock(widget.error!, widget.onRetry, role: widget.role),
          if (ready) ...[
            _CapacityHero(items: all),
            const SizedBox(height: AppSpacing.lg),
            _totals(all),
            const SizedBox(height: AppSpacing.lg),
            _scopeCard(),
            const SizedBox(height: AppSpacing.xl),
            _listHeader(visible.length),
            const SizedBox(height: AppSpacing.md),
            _chips(all),
            const SizedBox(height: AppSpacing.lg),
            if (visible.isEmpty)
              _DashboardCard(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          all.isEmpty
                              ? 'Tidak ada destinasi pada cakupan ini. Atur ulang filter untuk mencoba lagi.'
                              : 'Tidak ada destinasi untuk filter ini.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppColors.textSecondary)))),
            for (final item in visible) ...[
              _CapacityCard(item: item, onDetail: () => _showDetail(item)),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),
            _HomeLinkCard(
                icon: PhosphorIconsRegular.buildings,
                title: 'Kelola destinasi dan kuota',
                subtitle: 'Atur kapasitas dan data destinasi',
                onTap: widget.onManage),
          ],
        ]);
  }

  Widget _totals(List<_CapacityRow> all) {
    final allocated = all.fold<num>(0, (sum, item) => sum + item.allocated);
    final confirmed = all.fold<num>(0, (sum, item) => sum + item.confirmed);
    final remaining = all
        .where((item) => item.hasQuota)
        .fold<num>(0, (sum, item) => sum + item.remaining);
    return Row(children: [
      Expanded(child: _TotalTile('Dialokasikan', _thousands(allocated))),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _TotalTile('Terkonfirmasi', _thousands(confirmed))),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _TotalTile('Sisa kapasitas', _thousands(remaining))),
    ]);
  }

  Widget _scopeCard() => _DashboardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CAKUPAN LAPORAN',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        _ScopeRow(
            key: const ValueKey('comparison-destination'),
            icon: PhosphorIconsRegular.mapPin,
            title: widget.filters['destination_guid'] == null
                ? 'Semua destinasi yang dapat diakses'
                : widget.destinationLabel ?? 'Destinasi terpilih',
            subtitle: 'Filter destinasi',
            onTap: widget.onPickDestination),
        const Divider(height: 1, color: AppColors.border),
        _ScopeRow(
            key: const ValueKey('comparison-period'),
            icon: PhosphorIconsRegular.calendarBlank,
            title: _longPeriodLabel(widget.filters),
            subtitle: 'Basis tanggal kunjungan · waktu lokal destinasi',
            onTap: widget.onPickPeriod),
      ]));

  Widget _listHeader(int count) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Performa per Destinasi',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: AppSpacing.xs),
          Text('$count destinasi ditemukan',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ])),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
            key: const ValueKey('comparison-sort'),
            onPressed: _pickSort,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            icon: const Icon(PhosphorIconsRegular.arrowsDownUp, size: 18),
            label: Text(_sortLabels[_sort]!,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700))),
      ]);

  Widget _chips(List<_CapacityRow> all) {
    int count(_CapacityState s) => all.where((item) => item.state == s).length;
    final options = <(String, _CapacityState?, int)>[
      ('Semua', null, all.length),
      ('Ada alokasi', _CapacityState.allocated, count(_CapacityState.allocated)),
      (
        'Belum teralokasi',
        _CapacityState.unallocated,
        count(_CapacityState.unallocated)
      ),
      ('Tanpa kuota', _CapacityState.noQuota, count(_CapacityState.noQuota)),
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final option in options)
            if (option.$2 == null || option.$3 > 0 || _chip == option.$2)
              Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                      key: ValueKey('comparison-chip-${option.$2?.name ?? 'all'}'),
                      label: Text('${option.$1} (${option.$3})'),
                      selected: _chip == option.$2,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _chip = option.$2),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.blue,
                      side: BorderSide(
                          color: _chip == option.$2
                              ? AppColors.blue
                              : AppColors.border),
                      labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _chip == option.$2
                              ? Colors.white
                              : AppColors.navy),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)))),
        ]));
  }

  Widget _bottomBar(int total) => Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('$total destinasi',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy)),
                      const SizedBox(height: 2),
                      const Text('Perbandingan kapasitas',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton(
                    key: const ValueKey('comparison-reset'),
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Reset Filter',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800))),
              ]))));
}

class _CapacityHero extends StatelessWidget {
  const _CapacityHero({required this.items});
  final List<_CapacityRow> items;

  @override
  Widget build(BuildContext context) {
    final capacity = items.fold<num>(0, (sum, i) => sum + (i.hasQuota ? i.capacity : 0));
    final allocated = items.fold<num>(0, (sum, i) => sum + i.allocated);
    final percent = capacity > 0 ? allocated / capacity * 100 : null;
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blueDeep, Color(0xFF2077D6)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Total Kapasitas Destinasi',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white))),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${items.length} destinasi',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(_thousands(capacity),
              key: const ValueKey('comparison-total-capacity'),
              style: const TextStyle(
                  fontSize: 36,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: AppSpacing.xs),
          Text('Kuota pengunjung pada periode pilihan',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: .85))),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                  value: capacity > 0
                      ? (allocated / capacity).clamp(0, 1).toDouble()
                      : 0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: .22),
                  valueColor: const AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
                child: Text('${_thousands(allocated)} dialokasikan',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white))),
            Text(percent == null ? '—' : '${_decimalPercent(percent)} kapasitas',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ]));
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
      ]));
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.blueTint,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 20, color: AppColors.blue)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ])),
            const SizedBox(width: AppSpacing.sm),
            const Icon(PhosphorIconsRegular.caretRight,
                size: 18, color: AppColors.textSecondary),
          ])));
}

({String label, OperationsTone tone}) _stateBadge(_CapacityState state) =>
    switch (state) {
      _CapacityState.allocated => (
          label: 'Ada alokasi',
          tone: OperationsTone.blue
        ),
      _CapacityState.unallocated => (
          label: 'Belum teralokasi',
          tone: OperationsTone.grey
        ),
      _CapacityState.noQuota => (
          label: 'Tanpa kuota',
          tone: OperationsTone.orange
        ),
    };

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.item, required this.onDetail});
  final _CapacityRow item;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final badge = _stateBadge(item.state);
    final footer = !item.hasQuota
        ? 'Kapasitas belum diatur'
        : item.allocated <= 0
            ? 'Belum ada alokasi pada periode ini'
            : 'Konfirmasi ${_decimalPercent(item.confirmedPercent)} dari kapasitas';
    return _DashboardCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
        const SizedBox(width: AppSpacing.sm),
        OperationsStatusBadge(badge.label, badge.tone, small: true),
      ]),
      const SizedBox(height: AppSpacing.md),
      const Text('Alokasi / Kapasitas',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.xs),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Text(
                '${_thousands(item.allocated)} / ${_thousands(item.capacity)}',
                style: const TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
        Text(_decimalPercent(item.allocatedPercent),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.blue)),
      ]),
      const SizedBox(height: AppSpacing.md),
      ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
              value: item.hasQuota
                  ? (item.allocated / item.capacity).clamp(0, 1).toDouble()
                  : 0,
              minHeight: 8,
              backgroundColor: AppColors.blueTint,
              valueColor: const AlwaysStoppedAnimation(AppColors.blue))),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(
            child: _MiniTile('Terkonfirmasi', _thousands(item.confirmed))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: _MiniTile('Sisa kapasitas',
                item.hasQuota ? _thousands(item.remaining) : '—')),
      ]),
      const SizedBox(height: AppSpacing.md),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(
            child: Text(footer,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary))),
        TextButton(
            key: ValueKey('comparison-detail-${item.name}'),
            onPressed: onDetail,
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.blue),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Lihat Rincian',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              SizedBox(width: 4),
              Icon(PhosphorIconsRegular.arrowRight, size: 16),
            ])),
      ]),
    ]));
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
      ]));
}

class _CapacityDetailSheet extends StatelessWidget {
  const _CapacityDetailSheet({required this.item});
  final _CapacityRow item;

  @override
  Widget build(BuildContext context) {
    final badge = _stateBadge(item.state);
    final rows = <(String, String)>[
      ('Kapasitas', _thousands(item.capacity)),
      ('Teralokasi', _thousands(item.allocated)),
      ('Terkonfirmasi', _thousands(item.confirmed)),
      ('Sisa kapasitas', item.hasQuota ? _thousands(item.remaining) : '—'),
      ('Alokasi / kapasitas', _decimalPercent(item.allocatedPercent)),
      ('Konfirmasi / kapasitas', _decimalPercent(item.confirmedPercent)),
      ('Booking', _value(item.raw['bookings'])),
      ('Jumlah diminta', _value(item.raw['quantity_requested'])),
      ('Tiket layak hadir', 'Belum tersedia'),
    ];
    final info = operationsToneColors(OperationsTone.blue);
    return SafeArea(
        top: false,
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Rincian Kapasitas',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy))),
                    IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF3FA),
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    Expanded(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy))),
                    const SizedBox(width: AppSpacing.sm),
                    OperationsStatusBadge(badge.label, badge.tone,
                        small: true),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: AppColors.border),
                  for (final row in rows) ...[
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          Expanded(
                              child: Text(row.$1,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary))),
                          Text(row.$2,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy)),
                        ])),
                    const Divider(height: 1, color: AppColors.border),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                          color: info.bg,
                          border: Border.all(color: info.border),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(PhosphorIconsRegular.info,
                                size: 18, color: info.fg),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                                child: Text(
                                    'Alokasi dan konfirmasi merupakan metrik berbeda. Tiket layak hadir yang belum tersedia tidak boleh diasumsikan bernilai 0.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: info.fg))),
                          ])),
                ])));
  }
}
