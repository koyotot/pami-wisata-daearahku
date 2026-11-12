part of 'operations_dashboard.dart';

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    super.key,
    this.executive = false,
    this.role,
    this.title,
    this.subtitle,
    this.onActions,
    this.onBack,
    this.actions = const [],
  });
  final bool executive;
  final int? role;
  final String? title;
  final String? subtitle;
  final VoidCallback? onActions;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => (role ?? AuthSession.instance.role) == 1
      ? OperationsScenicHeader(
          title: title ?? 'Halo, Admin.',
          subtitle: subtitle ?? 'Kegiatan destinasi dalam kendalimu',
          onBack: onBack,
          actions: [
              ...actions,
              if (onActions != null)
                IconButton(
                    tooltip: 'Pusat tindakan',
                    onPressed: onActions,
                    icon: const Icon(PhosphorIconsRegular.bell)),
            ])
      : OperationsDayHeader(
          label: title != null
              ? 'Wisata Daerahku · Operasional'
              : executive
                  ? 'Wisata Daerahku · Superadmin'
                  : 'Wisata Daerahku · Admin',
          title: title ?? (executive ? 'Ringkasan Eksekutif' : 'Halo, Admin.'),
          subtitle: subtitle ??
              (executive
                  ? 'Pengawasan operasional seluruh destinasi'
                  : 'Pengelolaan destinasi & aktivitas pribadi'),
          onBack: onBack,
          actions: [
              ...actions,
              if (onActions != null)
                IconButton.filledTonal(
                    tooltip: 'Pusat tindakan',
                    onPressed: onActions,
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .14),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(PhosphorIconsRegular.bell, size: 24)),
            ]);
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard(
      {required this.label,
      required this.detail,
      this.onTap,
      this.executive = false});
  final String label;
  final String detail;
  final VoidCallback? onTap;
  final bool executive;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(
                    executive
                        ? PhosphorIconsRegular.buildings
                        : PhosphorIconsRegular.mapPin,
                    color: AppColors.blue,
                    size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                      const SizedBox(height: 3),
                      Text(detail,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF526787))),
                    ])),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(PhosphorIconsRegular.caretDown,
                      color: AppColors.blue, size: 22),
                ]
              ]))));
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(17)),
      child: Padding(padding: const EdgeInsets.all(16), child: child));
}

class _DashboardActionCenter extends StatelessWidget {
  const _DashboardActionCenter(
      {required this.pending,
      required this.executive,
      required this.hasActions,
      required this.onOpen});
  final String pending;
  final bool executive;
  final bool hasActions;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFFFFF0D6),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onOpen,
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(PhosphorIconsRegular.warningCircle,
                    color: Color(0xFF98621E), size: 26),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(executive ? 'Perhatian eksekutif' : 'Perlu tindakan',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF795018))),
                      const SizedBox(height: 4),
                      Text('$pending persetujuan menunggu',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF795018))),
                      const SizedBox(height: 3),
                      Text(
                          hasActions
                              ? 'Tinjau antrean & prioritas operasional'
                              : 'Buka antrean persetujuan',
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF795018))),
                    ])),
                const SizedBox(width: 8),
                const Icon(PhosphorIconsRegular.caretRight,
                    color: Color(0xFF98621E), size: 22),
              ]))));
}

class _NoAssignmentState extends StatelessWidget {
  const _NoAssignmentState();
  @override
  Widget build(BuildContext context) => _DashboardCard(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F3FF),
                      borderRadius: BorderRadius.circular(22)),
                  child: const Icon(PhosphorIconsRegular.mapPinLine,
                      color: AppColors.blue, size: 33)),
              const SizedBox(height: 20),
              const Text('Belum ada destinasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: AppColors.navy)),
              const SizedBox(height: 12),
              const Text(
                  'Akun Anda belum ditugaskan ke destinasi mana pun. '
                  'Hubungi Superadmin untuk mendapatkan penugasan. ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.6, color: Color(0xFF526787))),
              const SizedBox(height: 16),
              const Text('Tarik turun untuk memeriksa penugasan.',
                  style: TextStyle(fontSize: 13)),
            ])),
      );
}

class OperationsUnavailableScreen extends StatelessWidget {
  const OperationsUnavailableScreen({super.key, this.audit = false});
  final bool audit;
  @override
  Widget build(BuildContext context) => OperationsPage(
          title: audit ? 'Aktivitas Audit' : 'Keuangan',
          subtitle: 'Ketersediaan data operasional',
          embedded: false,
          children: [
            if (audit)
              _DashboardCard(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(children: [
                        Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                                color: const Color(0xFFE8F3FF),
                                borderRadius: BorderRadius.circular(22)),
                            child: const Icon(
                                PhosphorIconsRegular.clockCounterClockwise,
                                color: AppColors.blue,
                                size: 33)),
                        const SizedBox(height: 20),
                        const Text('Audit Timeline Belum Tersedia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                        const SizedBox(height: 12),
                        const Text(
                            'Riwayat aktivitas global belum tersedia. '
                            'Data audit akan tampil setelah layanan tersedia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF526787))),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: () => Navigator.maybePop(context),
                            child: const Text('Kembali')),
                      ])))
            else
              const FinancialUnavailablePanel(),
          ]);
}

class FinancialUnavailablePanel extends StatelessWidget {
  const FinancialUnavailablePanel({super.key});
  @override
  Widget build(BuildContext context) => _DashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(PhosphorIconsRegular.wallet, color: AppColors.blue, size: 24),
          SizedBox(width: 10),
          Expanded(
              child: Text('Keuangan Belum Tersedia',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.navy))),
        ]),
        const SizedBox(height: 12),
        const Text('Gateway pembayaran belum terhubung',
            style: TextStyle(fontSize: 13, color: Color(0xFF526787))),
        const SizedBox(height: 12),
        for (final label in [
          'Gross revenue',
          'Net revenue',
          'Gateway fees',
          'Refund',
          'Settlement'
        ])
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF526787)))),
                const Text('—',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
              ])),
        const SizedBox(height: 8),
        const Text('Belum tersedia · pembayaran belum terverifikasi',
            style:
                TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF526787))),
      ]));
}

class OperationsSkeleton extends StatelessWidget {
  const OperationsSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Memuat data operasional',
      child: Column(children: [
        Container(
            height: 52,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(14))),
        LayoutBuilder(
            builder: (context, constraints) =>
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                        width: (constraints.maxWidth - 12) / 2,
                        height: 120,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: ColoredBox(color: AppColors.border)),
                              SizedBox(height: 12),
                              SizedBox(
                                  width: 64,
                                  height: 24,
                                  child: ColoredBox(color: AppColors.border)),
                              SizedBox(height: 8),
                              SizedBox(
                                  width: 88,
                                  height: 12,
                                  child: ColoredBox(color: AppColors.border)),
                            ])),
                ])),
        const SizedBox(height: 12),
        Container(
            height: 140,
            decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(17))),
      ]));
}

class OperationsMetrics extends StatelessWidget {
  const OperationsMetrics(
      {super.key,
      required this.values,
      this.compact = false,
      this.icons,
      this.labelStyle,
      this.metadata});
  final List<(String, String)> values;
  final bool compact;
  final List<IconData>? icons;
  final TextStyle? labelStyle;
  final List<String>? metadata;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final stacked = MediaQuery.textScalerOf(context).scale(14) > 20 ||
            constraints.maxWidth < 250;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < values.length; i++)
            SizedBox(
                width:
                    stacked || (values.length.isOdd && i == values.length - 1)
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                child: Container(
                    padding: compact
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.all(14),
                    decoration: compact
                        ? null
                        : BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (icons != null) ...[
                            Icon(icons![i], color: AppColors.blue, size: 22),
                            const SizedBox(height: 10),
                          ],
                          if (icons == null)
                            Text(values[i].$1,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.navy)),
                          if (icons == null) const SizedBox(height: 8),
                          Text(values[i].$2,
                              style: TextStyle(
                                  fontSize:
                                      compact || values[i].$2 == '—' ? 20 : 26,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy)),
                          if (icons != null) ...[
                            const SizedBox(height: 4),
                            Text(values[i].$1,
                                style: labelStyle ??
                                    const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy)),
                          ],
                          if (metadata != null) ...[
                            const SizedBox(height: 2),
                            Text(metadata![i],
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF526787),
                                    height: 1.4)),
                          ],
                        ])))
        ]);
      });
}

class OperationsTrend extends StatelessWidget {
  const OperationsTrend(
      {super.key,
      required this.rows,
      required this.valueKey,
      this.secondKey,
      this.bars = false});
  final List<Json> rows;
  final String valueKey;
  final String? secondKey;
  final bool bars;
  @override
  Widget build(BuildContext context) {
    final first =
        rows.map((r) => _number(r[valueKey])?.toDouble() ?? 0).toList();
    final second = secondKey == null
        ? <double>[]
        : rows.map((r) => _number(r[secondKey])?.toDouble() ?? 0).toList();
    final maxValue = [...first, ...second].fold<double>(1, math.max);
    if (rows.isEmpty) {
      return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(children: [
            SizedBox(
                height: 112,
                width: double.infinity,
                child: CustomPaint(painter: _TrendPainter(first, second))),
            const _Notice('Belum ada aktivitas pada periode ini.'),
          ]));
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
              label:
                  'Grafik $valueKey. ${rows.map((r) => "${r['date']}: ${r[valueKey]}").join(', ')}',
              child: SizedBox(
                  height: 160,
                  child: Row(children: [
                    SizedBox(
                        width: MediaQuery.textScalerOf(context).scale(34),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_value(maxValue),
                                  style: const TextStyle(fontSize: 12)),
                              const Text('0', style: TextStyle(fontSize: 12))
                            ])),
                    Expanded(
                        child: CustomPaint(
                            painter: _TrendPainter(first, second, bars: bars),
                            size: const Size(double.infinity, 160)))
                  ]))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text('${rows.first['date']}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF526787)))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(rows.length < 2 ? '' : '${rows.last['date']}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF526787))))
          ]),
        ]));
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.first, this.second, {this.bars = false});
  final List<double> first;
  final List<double> second;
  final bool bars;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxValue = [...first, ...second].fold<double>(1, math.max);
    void line(List<double> values, Color color) {
      if (values.isEmpty) return;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? size.width / 2
            : size.width * i / (values.length - 1);
        final y = size.height * (1 - values[i] / maxValue);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        if (values.length == 1) {
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    if (bars) {
      final slot = size.width / first.length;
      for (var i = 0; i < first.length; i++) {
        final height = size.height * first[i] / maxValue;
        canvas.drawRRect(
            RRect.fromRectAndCorners(
                Rect.fromLTWH(slot * i + slot * .15, size.height - height,
                    slot * .7, height),
                topLeft: const Radius.circular(4),
                topRight: const Radius.circular(4)),
            Paint()..color = AppColors.blue);
      }
    } else {
      line(first, AppColors.blue);
      line(second, AppColors.textMuted);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      first != oldDelegate.first ||
      second != oldDelegate.second ||
      bars != oldDelegate.bars;
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textMuted, height: 1.5)));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)));
}

Widget _routeLink(String label, VoidCallback action) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 14)),
    trailing: const Icon(PhosphorIconsRegular.caretRight, size: 20),
    onTap: action);
Widget _filterButton(Map<String, String> filters, VoidCallback action) =>
    _ScopeCard(
        label: filters['destination_guid'] == null
            ? 'Semua destinasi yang dapat diakses'
            : 'Destinasi terpilih',
        detail: filters['from'] == null
            ? 'Filter destinasi dan periode'
            : "${filters['from']} — ${filters['to'] ?? '—'} · Filter aktif",
        onTap: action);
Widget _errorBlock(Object error, VoidCallback retry, {required int? role}) =>
    _DashboardCard(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                      _scopeError(error)
                          ? PhosphorIconsRegular.lock
                          : PhosphorIconsRegular.wifiSlash,
                      size: 36,
                      color: _scopeError(error)
                          ? const Color(0xFFAF4B48)
                          : const Color(0xFF98621E)),
                  const SizedBox(height: 16),
                  Text(
                      _scopeError(error)
                          ? 'Akses telah berubah'
                          : 'Data belum dapat dimuat',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                  const SizedBox(height: 10),
                  Text(
                      _scopeError(error)
                          ? 'Akses destinasi berubah. Data lama telah dibersihkan. Pilih ulang destinasi yang dapat diakses.'
                          : adminErrorMessage(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6, color: Color(0xFF526787))),
                  const SizedBox(height: 20),
                  if (role != 1)
                    FilledButton.icon(
                        onPressed: retry,
                        icon: const Icon(PhosphorIconsRegular.arrowsClockwise,
                            size: 20),
                        label: Text(_scopeError(error)
                            ? 'Pilih ulang destinasi'
                            : 'Coba lagi')),
                  if (role == 1)
                    const Text('Tarik turun untuk menyinkronkan data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13)),
                ])));
Widget _actionTile(OperationalRow row, VoidCallback open) => Padding(
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
            leading: Icon(
                row.action == 'upcoming_visit'
                    ? PhosphorIconsRegular.calendarCheck
                    : PhosphorIconsRegular.clock,
                color: row.action == 'upcoming_visit'
                    ? AppColors.blue
                    : const Color(0xFF98621E)),
            title: Text(operationalActionLabel(row.action),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            subtitle: Text(
                '${row.name ?? 'Destinasi'}\n'
                "${row.raw['visit_date'] ?? 'Tanggal belum tersedia'} · "
                "${row.claimState == 'active' ? 'Claim aktif' : 'Belum diambil'}",
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: Color(0xFF526787))),
            isThreeLine: true,
            trailing: const Icon(PhosphorIconsRegular.caretRight,
                color: AppColors.blue),
            onTap: row.bookingGuid == null ? null : open)));
bool _scopeError(Object? e) =>
    e is ApiException && (e.status == 403 || e.status == 404);
num? _number(dynamic value) => value is num ? value : num.tryParse('$value');
String _value(dynamic value) {
  final number = _number(value);
  return number == null
      ? '—'
      : number == number.roundToDouble()
          ? '${number.toInt()}'
          : number.toStringAsFixed(1);
}

String _percent(dynamic value) => value == null ? '—' : '${_value(value)}%';
String _period(Json period) =>
    '${period['from'] ?? '—'} — ${period['to'] ?? '—'}';
List<(String, String)> _decisionValues(Json values) => [
      ('Disetujui', _value(values['approved_decisions'])),
      ('Ditolak', _value(values['rejected_decisions'])),
      ('Tingkat persetujuan', _percent(values['approval_rate_percent'])),
      (
        'Respons rata-rata',
        values['avg_response_seconds'] == null
            ? '—'
            : '${_value(values['avg_response_seconds'])} detik'
      ),
      ('Kepatuhan SLA', _percent(values['sla_compliance_percent']))
    ];
