// ============================================================
// Superadmin view of "Kelola Kuota": schedule cards per visit date,
// month filter, detail sheet and add/edit sheets. Booking windows are
// entered and shown in the destination's time zone and sent as UTC.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/visit_format.dart' show visitMonths;
import '../admin/operations_dashboard/operations_dashboard.dart'
    show OperationsPage, OperationsSkeleton;

const _weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const _danger = Color(0xFFB23B3B);
const _fieldFill = Color(0xFFF7FAFE);

class _Zone {
  const _Zone(this.offset, this.abbr, this.city, this.id);
  final Duration offset;
  final String abbr;
  final String city;
  final String id;

  static _Zone of(String? id) => switch (id) {
        'Asia/Makassar' =>
          const _Zone(Duration(hours: 8), 'WITA', 'Makassar', 'Asia/Makassar'),
        'Asia/Jayapura' =>
          const _Zone(Duration(hours: 9), 'WIT', 'Jayapura', 'Asia/Jayapura'),
        _ => const _Zone(Duration(hours: 7), 'WIB', 'Jakarta', 'Asia/Jakarta'),
      };

  /// Calendar fields of [instant] as seen in this zone (returned as a UTC
  /// DateTime used only for its fields).
  DateTime wall(DateTime instant) => instant.toUtc().add(offset);

  /// The instant for the wall-clock fields of [local] in this zone.
  DateTime instant(DateTime local) => DateTime.utc(
          local.year, local.month, local.day, local.hour, local.minute)
      .subtract(offset);
}

String _two(int v) => v.toString().padLeft(2, '0');
String _shortMonth(int month) => visitMonths[month - 1].substring(0, 3);
String _fieldDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _count(num v) {
  final digits = v.round().abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

String _stamp(DateTime? instant, _Zone zone) {
  if (instant == null) return '—';
  final d = zone.wall(instant);
  return '${d.day} ${_shortMonth(d.month)} ${d.year} · ${_hm(d)} ${zone.abbr}';
}

DateTime? _parseDay(String value) {
  final d = DateTime.tryParse(visitDay(value));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String _monthKey(DateTime d) => '${d.year}-${_two(d.month)}';
String _monthLabel(String key) {
  final parts = key.split('-');
  return '${visitMonths[int.parse(parts[1]) - 1]} ${parts[0]}';
}

class SuperadminQuotaView extends StatefulWidget {
  const SuperadminQuotaView(
      {super.key,
      required this.destinationName,
      required this.timezone,
      required this.items,
      required this.loaded,
      required this.error,
      required this.onRefresh,
      required this.onSave});
  final String destinationName;
  final String? timezone;
  final List<QuotaEntry> items;
  final bool loaded;
  final String? error;
  final Future<void> Function() onRefresh;

  /// Returns an error message, or null when the quota was saved.
  final Future<String?> Function(Json payload) onSave;

  @override
  State<SuperadminQuotaView> createState() => _SuperadminQuotaViewState();
}

class _SuperadminQuotaViewState extends State<SuperadminQuotaView> {
  late final _Zone _zone = _Zone.of(widget.timezone);
  late String _month = _monthKey(_zone.wall(DateTime.now()));

  List<QuotaEntry> get _sorted {
    final list = [...widget.items];
    list.sort((a, b) => a.visitDate.compareTo(b.visitDate));
    return list;
  }

  bool _inMonth(QuotaEntry e, String key) => visitDay(e.visitDate).startsWith(key);

  List<String> _monthKeys() {
    final now = _zone.wall(DateTime.now());
    final next = DateTime(now.year, now.month + 1);
    final keys = <String>{
      _monthKey(now),
      _monthKey(next),
      for (final e in widget.items)
        if (visitDay(e.visitDate).length >= 7)
          visitDay(e.visitDate).substring(0, 7),
    };
    return keys.toList()..sort();
  }

  Future<void> _pickMonth() async {
    final keys = _monthKeys();
    int countOf(String? key) => key == null
        ? widget.items.length
        : widget.items.where((e) => _inMonth(e, key)).length;
    final value = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheet) => _SheetFrame(
            title: 'Pilih Bulan',
            onClose: () => Navigator.pop(sheet),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                          'Tampilkan jadwal kunjungan berdasarkan bulan.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))),
                  for (final option in <(String, String, int)>[
                    ('all', 'Semua Bulan', countOf(null)),
                    for (final key in keys)
                      (key, _monthLabel(key), countOf(key)),
                  ])
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                            color: _month == option.$1
                                ? AppColors.blueTint
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: _month == option.$1
                                        ? AppColors.blue
                                        : AppColors.border)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                                key: ValueKey('quota-month-${option.$1}'),
                                onTap: () => Navigator.pop(sheet, option.$1),
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(option.$2,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.navy)),
                                            const SizedBox(height: 4),
                                            Text('${option.$3} jadwal kunjungan',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary)),
                                          ])),
                                      if (_month == option.$1)
                                        const Icon(PhosphorIconsRegular.check,
                                            size: 20, color: AppColors.blue),
                                    ]))))),
                ])));
    if (value != null && mounted) setState(() => _month = value);
  }

  Future<void> _openForm([QuotaEntry? entry]) async {
    final sorted = _sorted;
    final nowWall = _zone.wall(DateTime.now());
    DateTime visit;
    int? capacity;
    DateTime opens;
    DateTime closes;
    if (entry != null) {
      visit = _parseDay(entry.visitDate) ?? DateTime(nowWall.year, nowWall.month, nowWall.day);
      capacity = entry.capacity;
      opens = entry.opensAt == null ? nowWall : _zone.wall(entry.opensAt!);
      closes = entry.closesAt == null ? nowWall : _zone.wall(entry.closesAt!);
    } else {
      final last = sorted.isEmpty ? null : _parseDay(sorted.last.visitDate);
      final today = DateTime(nowWall.year, nowWall.month, nowWall.day);
      visit = last != null && !last.isBefore(today)
          ? last.add(const Duration(days: 1))
          : today.add(const Duration(days: 1));
      capacity = sorted.isEmpty ? null : sorted.last.capacity;
      opens = nowWall;
      final before = visit.subtract(const Duration(days: 1));
      closes = DateTime(before.year, before.month, before.day, nowWall.hour, nowWall.minute);
    }
    final saved = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _QuotaFormSheet(
            entry: entry,
            zone: _zone,
            initialVisit: visit,
            initialCapacity: capacity,
            initialOpens: opens,
            initialCloses: closes,
            onSubmit: widget.onSave));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Kuota disimpan')));
    }
  }

  Future<void> _openDetail(QuotaEntry entry) async {
    final edit = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _DetailSheet(entry: entry, zone: _zone));
    if (edit == true && mounted) await _openForm(entry);
  }

  @override
  Widget build(BuildContext context) {
    final all = _sorted;
    final visible =
        _month == 'all' ? all : all.where((e) => _inMonth(e, _month)).toList();
    final totalCapacity = visible.fold<int>(0, (s, e) => s + e.capacity);
    final totalRemaining = visible.fold<int>(0, (s, e) => s + e.remaining);
    final ready = widget.loaded;
    return OperationsPage(
        role: 2,
        title: 'Kelola Kuota',
        subtitle: 'Atur jadwal dan kuota kunjungan',
        embedded: false,
        onRefresh: widget.onRefresh,
        bottomBar: ready ? _dock() : null,
        children: [
          _destinationCard(),
          if (!ready && widget.error == null) ...[
            const SizedBox(height: AppSpacing.lg),
            const OperationsSkeleton(),
          ],
          if (!ready && widget.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _errorCard(),
          ],
          if (ready) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              Expanded(child: _Stat('${visible.length}', 'Jadwal kunjungan')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _Stat(_count(totalCapacity), 'Total kapasitas')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _Stat(_count(totalRemaining), 'Kuota tersisa',
                      color: AppColors.success)),
            ]),
            const SizedBox(height: AppSpacing.xl),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Jadwal & Kuota',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${visible.length} tanggal ditemukan',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ])),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                  key: const ValueKey('quota-month-filter'),
                  onPressed: _pickMonth,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.navy,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(PhosphorIconsRegular.calendarBlank, size: 18),
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        _month == 'all'
                            ? 'Semua Bulan'
                            : '${_shortMonth(int.parse(_month.substring(5)))} ${_month.substring(0, 4)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsRegular.caretDown, size: 14),
                  ])),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (widget.error != null) ...[
              _notice('Gagal memuat ulang: ${widget.error}', danger: true),
              const SizedBox(height: AppSpacing.md),
            ],
            if (visible.isEmpty)
              _card(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          all.isEmpty
                              ? 'Belum ada jadwal kuota. Tambahkan tanggal kunjungan beserta kapasitasnya.'
                              : 'Belum ada jadwal pada bulan ini. Pilih bulan lain atau tambahkan tanggal baru.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppColors.textSecondary)))),
            for (final entry in visible) ...[
              _ScheduleCard(
                  key: ValueKey('quota-${entry.visitDate}'),
                  entry: entry,
                  zone: _zone,
                  onEdit: () => _openForm(entry),
                  onDetail: () => _openDetail(entry)),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.xs),
            _notice(
                'Kuota tersedia dihitung dari kapasitas dikurangi alokasi. Booking dibuka dan ditutup mengikuti zona waktu destinasi, yaitu ${_zone.id} (${_zone.abbr}).'),
          ],
        ]);
  }

  Widget _destinationCard() => _card(
      child: Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(PhosphorIconsRegular.buildings,
                size: 22, color: AppColors.blue)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DESTINASI YANG DIKELOLA',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                  color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.destinationName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
        ])),
      ]));

  Widget _errorCard() => _card(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(PhosphorIconsRegular.wifiSlash,
                size: 36, color: AppColors.warningText),
            const SizedBox(height: 16),
            const Text('Data belum dapat dimuat',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy)),
            const SizedBox(height: 10),
            Text(widget.error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 20),
                label: const Text('Coba lagi')),
          ])));

  Widget _dock() => Material(
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
                      const Text('Pengaturan kunjungan',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(widget.destinationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy)),
                    ])),
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                    key: const ValueKey('add-quota'),
                    onPressed: () => _openForm(),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 52),
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(PhosphorIconsRegular.plus, size: 20),
                    label: const Text('Tambah Tanggal',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800))),
              ]))));
}

Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20)),
    child: child);

Widget _notice(String text, {bool danger = false}) {
  final bg = danger ? const Color(0xFFFDECEC) : const Color(0xFFEEF5FD);
  final border = danger ? const Color(0xFFF3C9C9) : const Color(0xFFC9DDF7);
  final fg = danger ? _danger : AppColors.blueDeep;
  return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(danger ? PhosphorIconsRegular.warning : PhosphorIconsRegular.info,
            size: 18, color: fg),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, height: 1.5, color: fg))),
      ]));
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.color = AppColors.navy});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: color))),
        const SizedBox(height: AppSpacing.xs),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ]));
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame(
      {required this.title, required this.onClose, required this.child});
  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy))),
                  IconButton(
                      tooltip: 'Tutup',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF3FA),
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                ]),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                Flexible(child: SingleChildScrollView(child: child)),
              ])));
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(
      {super.key,
      required this.entry,
      required this.zone,
      required this.onEdit,
      required this.onDetail});
  final QuotaEntry entry;
  final _Zone zone;
  final VoidCallback onEdit;
  final VoidCallback onDetail;

  String get _percent {
    if (entry.capacity <= 0) return '—';
    final value = entry.allocated / entry.capacity * 100;
    var text = value.toStringAsFixed(1);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return '${text.replaceAll('.', ',')}%';
  }

  @override
  Widget build(BuildContext context) {
    final day = _parseDay(entry.visitDate);
    final title = day == null
        ? visitDayLabel(entry.visitDate)
        : '${_weekdays[day.weekday - 1]}, ${day.day} ${_shortMonth(day.month)} ${day.year}';
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.blueTint,
                border: Border.all(color: const Color(0xFFC9DDF7)),
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(day == null ? '—' : '${day.day}',
                  style: const TextStyle(
                      fontSize: 20,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue)),
              Text(day == null ? '' : _shortMonth(day.month).toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue)),
            ])),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 2),
          const Text('Tanggal kunjungan',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        IconButton(
            key: ValueKey('edit-${entry.visitDate}'),
            tooltip: 'Ubah kuota',
            onPressed: onEdit,
            style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.blueTint,
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: Color(0xFFC9DDF7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20)),
      ]),
      const SizedBox(height: AppSpacing.lg),
      const Text('Kuota teralokasi',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.xs),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_count(entry.allocated),
            style: const TextStyle(
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const SizedBox(width: 6),
        Expanded(
            child: Text('/ ${_count(entry.capacity)} orang',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary))),
        Text(_percent,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.blue)),
      ]),
      const SizedBox(height: AppSpacing.md),
      ExcludeSemantics(
          child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                  value: entry.capacity <= 0
                      ? 0
                      : (entry.allocated / entry.capacity)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                  minHeight: 8,
                  backgroundColor: AppColors.blueTint,
                  valueColor: const AlwaysStoppedAnimation(AppColors.blue)))),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Expanded(child: _MiniTile('Kapasitas total', _count(entry.capacity))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: _MiniTile('Sisa kuota', _count(entry.remaining),
                color: entry.remaining > 0 ? AppColors.success : _danger)),
      ]),
      const SizedBox(height: AppSpacing.lg),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        const Expanded(
            child: Text('Periode Pemesanan',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFEEF1F6),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${zone.abbr} · ${zone.city}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF526787)))),
      ]),
      const SizedBox(height: AppSpacing.md),
      _TimelineRow('Booking dibuka', _stamp(entry.opensAt, zone)),
      _TimelineRow('Booking ditutup', _stamp(entry.closesAt, zone),
          last: true),
      const SizedBox(height: AppSpacing.md),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Expanded(
            child: Text(
                entry.allocated > 0
                    ? '${_count(entry.allocated)} orang teralokasi'
                    : 'Belum ada tiket teralokasi',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary))),
        TextButton(
            key: ValueKey('detail-${entry.visitDate}'),
            onPressed: onDetail,
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.blue,
                backgroundColor: AppColors.blueTint,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFC9DDF7)),
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Lihat Rincian →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
    ]));
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile(this.label, this.value, {this.color = AppColors.navy});
  final String label;
  final String value;
  final Color color;

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
                fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]));
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            width: 20,
            child: Column(children: [
              Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blue, width: 2))),
              if (!last)
                Expanded(
                    child: Container(width: 1.5, color: AppColors.border)),
            ])),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                ]))),
      ]));
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.entry, required this.zone});
  final QuotaEntry entry;
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final day = _parseDay(entry.visitDate);
    final long = day == null
        ? visitDayLabel(entry.visitDate)
        : '${day.day} ${visitMonths[day.month - 1]} ${day.year}';
    final rows = <(String, String)>[
      ('Tanggal kunjungan', long),
      ('Kapasitas total', '${_count(entry.capacity)} orang'),
      ('Teralokasi', '${_count(entry.allocated)} orang'),
      ('Sisa kapasitas', '${_count(entry.remaining)} orang'),
      ('Booking dibuka', _stamp(entry.opensAt, zone)),
      ('Booking ditutup', _stamp(entry.closesAt, zone)),
    ];
    return _SheetFrame(
        title: 'Rincian Jadwal',
        onClose: () => Navigator.pop(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (day != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${_weekdays[day.weekday - 1]}, $long',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))),
          for (final row in rows) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  Expanded(
                      child: Text(row.$1,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary))),
                  Flexible(
                      child: Text(row.$2,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy))),
                ])),
          ],
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),
          _notice(
              'Perubahan kuota harus menjaga seluruh alokasi yang sudah terpakai. Status booking dan batas tanggal tetap harus diverifikasi oleh backend.'),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    key: const ValueKey('quota-detail-close'),
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Tutup',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: FilledButton(
                    key: const ValueKey('quota-detail-edit'),
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Ubah Kuota',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)))),
          ]),
        ]));
  }
}

/// Keeps digits only and inserts the colon: `1407` → `14:07`. Digits that
/// would make an invalid time are dropped (hour up to 23, minute up to 59);
/// a first digit above 2 becomes the hour `0d` (`5` → `05`).
class _TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var cut = '';
    for (final char in newValue.text.replaceAll(RegExp(r'\D'), '').split('')) {
      final digit = int.parse(char);
      if (cut.length >= 4) break;
      if (cut.isEmpty && digit > 2) {
        cut = '0$digit';
      } else if (cut.length == 1 && cut[0] == '2' && digit > 3) {
        continue;
      } else if (cut.length == 2 && digit > 5) {
        continue;
      } else {
        cut += char;
      }
    }
    final text =
        cut.length > 2 ? '${cut.substring(0, 2)}:${cut.substring(2)}' : cut;
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _QuotaFormSheet extends StatefulWidget {
  const _QuotaFormSheet(
      {required this.entry,
      required this.zone,
      required this.initialVisit,
      required this.initialCapacity,
      required this.initialOpens,
      required this.initialCloses,
      required this.onSubmit});
  final QuotaEntry? entry;
  final _Zone zone;
  final DateTime initialVisit;
  final int? initialCapacity;
  final DateTime initialOpens;
  final DateTime initialCloses;
  final Future<String?> Function(Json payload) onSubmit;

  @override
  State<_QuotaFormSheet> createState() => _QuotaFormSheetState();
}

class _QuotaFormSheetState extends State<_QuotaFormSheet> {
  late final _capacity = TextEditingController(
      text: widget.initialCapacity == null ? '' : '${widget.initialCapacity}');
  late final _opensTime =
      TextEditingController(text: _hm(widget.initialOpens));
  late final _closesTime =
      TextEditingController(text: _hm(widget.initialCloses));
  late DateTime _visit = widget.initialVisit;
  late DateTime _opensDate = DateTime(widget.initialOpens.year,
      widget.initialOpens.month, widget.initialOpens.day);
  late DateTime _closesDate = DateTime(widget.initialCloses.year,
      widget.initialCloses.month, widget.initialCloses.day);
  bool _saving = false;
  String? _error;

  bool get _editing => widget.entry != null;

  @override
  void dispose() {
    _capacity.dispose();
    _opensTime.dispose();
    _closesTime.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime current) {
    final now = DateTime.now();
    return showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5));
  }

  (int, int)? _time(String text) {
    final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(text.trim());
    return match == null
        ? null
        : (int.parse(match[1]!), int.parse(match[2]!));
  }

  Future<void> _submit() async {
    if (_saving) return;
    final capacity = int.tryParse(_capacity.text.trim());
    final open = _time(_opensTime.text);
    final close = _time(_closesTime.text);
    if (open == null || close == null) {
      setState(() => _error =
          'Jam harus berformat 24 jam HH:mm, misalnya 08:00 atau 17:30.');
      return;
    }
    final opens = widget.zone.instant(DateTime(
        _opensDate.year, _opensDate.month, _opensDate.day, open.$1, open.$2));
    final closes = widget.zone.instant(DateTime(_closesDate.year,
        _closesDate.month, _closesDate.day, close.$1, close.$2));
    var problem = validateQuotaInput(
        visitDate: _visit, capacity: capacity, opensAt: opens, closesAt: closes);
    if (problem == null && _editing && capacity! < widget.entry!.allocated) {
      problem =
          'Kapasitas tidak boleh lebih kecil dari jumlah yang sudah teralokasi (${widget.entry!.allocated} orang).';
    }
    if (problem == null &&
        closes.isAfter(widget.zone.instant(
            DateTime(_visit.year, _visit.month, _visit.day)))) {
      problem = 'Booking harus ditutup sebelum hari kunjungan dimulai.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(buildQuotaPayload(
        visitDate: _visit,
        capacity: capacity!,
        opensAt: opens,
        closesAt: closes));
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  InputDecoration _decoration({Widget? suffix, String? hint}) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5)));

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$text *',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy)));

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onPick,
          {bool enabled = true, Key? key}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: _saving || !enabled
                ? null
                : () async {
                    final picked = await _pickDate(value);
                    if (picked != null && mounted) {
                      onPick(DateTime(picked.year, picked.month, picked.day));
                    }
                  },
            child: InputDecorator(
                decoration: _decoration(
                    suffix: Icon(PhosphorIconsRegular.calendarBlank,
                        size: 20,
                        color: enabled
                            ? AppColors.textSecondary
                            : AppColors.textMuted)),
                child: Text(_fieldDate(value),
                    style: TextStyle(
                        fontSize: 14,
                        color: enabled
                            ? AppColors.navy
                            : AppColors.textSecondary)))),
      ]);

  Widget _timeField(String label, TextEditingController controller, Key key) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        TextField(
            key: key,
            controller: controller,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [_TimeFormatter()],
            style: const TextStyle(fontSize: 14, color: AppColors.navy),
            decoration: _decoration(
                hint: 'HH:mm',
                suffix: const Icon(PhosphorIconsRegular.clock,
                    size: 20, color: AppColors.textSecondary))),
      ]);

  Widget _windowRow(String title, DateTime date, ValueChanged<DateTime> onPick,
          TextEditingController time, String keyName) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 3,
            child: _dateField('$title · Tanggal', date, onPick,
                key: ValueKey('quota-$keyName-date'))),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            flex: 2,
            child: _timeField('Jam (HH:mm)', time,
                ValueKey('quota-$keyName-time'))),
      ]);

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return _SheetFrame(
        title: _editing ? 'Ubah Kuota' : 'Tambah Tanggal',
        onClose: () => Navigator.pop(context, false),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              _editing
                  ? 'Perbarui kapasitas dan jendela pemesanan untuk tanggal kunjungan ini.'
                  : 'Tambahkan jadwal kunjungan serta rentang waktu pembukaan booking.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          _dateField('Tanggal kunjungan', _visit,
              (d) => setState(() => _visit = d),
              enabled: !_editing, key: const ValueKey('quota-visit-date')),
          const SizedBox(height: AppSpacing.lg),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Kapasitas total'),
            TextField(
                key: const ValueKey('quota-capacity'),
                controller: _capacity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 14, color: AppColors.navy),
                decoration: _decoration()),
          ]),
          if (_editing) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FD),
                    border: Border.all(color: const Color(0xFFC9DDF7)),
                    borderRadius: BorderRadius.circular(14)),
                child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Teralokasi saat ini: '),
                      TextSpan(
                          text: '${entry!.allocated} orang',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(
                          text:
                              '. Kapasitas tidak boleh lebih kecil dari jumlah yang sudah teralokasi.'),
                    ]),
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.blueDeep))),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
              'JENDELA PEMESANAN · ${widget.zone.id.toUpperCase()} (${widget.zone.abbr})',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                  color: AppColors.blue)),
          const SizedBox(height: AppSpacing.md),
          _windowRow('Booking dibuka', _opensDate,
              (d) => setState(() => _opensDate = d), _opensTime, 'opens'),
          const SizedBox(height: AppSpacing.md),
          _windowRow('Booking ditutup', _closesDate,
              (d) => setState(() => _closesDate = d), _closesTime, 'closes'),
          const SizedBox(height: AppSpacing.md),
          const Text(
              'Jam diketik langsung menggunakan format 24 jam, misalnya 08:00 atau 17:30. Tidak menggunakan analog clock picker.',
              style: TextStyle(
                  fontSize: 11, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          _notice(
              'Booking harus dibuka sebelum ditutup, dan penutupan booking harus berlangsung sebelum hari kunjungan dimulai menurut zona waktu destinasi.'),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _notice(_error!, danger: true),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Batal',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: FilledButton(
                    key: const ValueKey('quota-save'),
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_editing ? 'Simpan Perubahan' : 'Tambah Jadwal',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)))),
          ]),
        ]));
  }
}
