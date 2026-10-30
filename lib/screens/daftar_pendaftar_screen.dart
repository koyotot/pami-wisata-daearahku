// ============================================================
// lib/screens/daftar_pendaftar_screen.dart
// Data pendaftar (booking) dari Laravel: filter status di server,
// seluruh halaman tanpa duplikat, keputusan setujui/tolak tanpa
// perubahan status optimistis.
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import 'admin_common.dart';

class DaftarPendaftarScreen extends StatefulWidget {
  final BusinessRepository? repository;
  final AuthSession? session;
  const DaftarPendaftarScreen({super.key, this.repository, this.session});

  @override
  State<DaftarPendaftarScreen> createState() => _DaftarPendaftarScreenState();
}

class _DaftarPendaftarScreenState extends State<DaftarPendaftarScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<Booking> _list;
  late final AdminBookingDecider _decider;
  String? _status;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _list = PagedListController<Booking>(
      session: _session,
      keyOf: (booking) => booking.guid,
      fetchPage: (page, filters) => _repository.adminBookings(
          query: {...filters, 'page': '$page', 'per_page': '50'}),
    )..addListener(_changed);
    _decider = AdminBookingDecider(_repository, session: _session)
      ..addListener(_changed);
    _session.sessionChanges.addListener(_sessionChanged);
    _muatData();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (_session.authenticated.value && _session.deviceSessionReady) {
      _muatData();
    }
  }

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_sessionChanged);
    _decider
      ..removeListener(_changed)
      ..dispose();
    _list
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _muatData() => _list.load(filters: {
        if (_status != null) 'status': _status!,
      });

  void _setStatus(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _muatData();
  }

  /// Confirmation, then one decision request. The status shown afterwards is
  /// only what the server returned (or re-read) for the booking.
  Future<BookingDecisionResult?> _decide(Booking booking,
      {required bool approve}) async {
    if (_decider.isBusy(booking.guid) || _dialogOpen) return null;
    _dialogOpen = true;
    final input = await showDialog<_DecisionInput>(
      context: context,
      builder: (_) => _DecisionDialog(booking: booking, approve: approve),
    );
    _dialogOpen = false;
    if (input == null || !mounted) return null;
    final result = await _decider.decide(booking.guid,
        approve: approve, reason: input.reason);
    if (!mounted || !result.actionable) return result;
    final updated = result.booking;
    if (updated != null) _list.replaceItem(updated);
    showAdminSnack(context, result.message,
        error: result.kind == DecisionKind.failed ||
            result.kind == DecisionKind.unconfirmed);
    if (result.kind != DecisionKind.failed) unawaited(_muatData());
    return result;
  }

  void _openDetail(Booking booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BookingDetailSheet(
        initial: booking,
        repository: _repository,
        session: _session,
        decider: _decider,
        onDecide: (current, approve) => _decide(current, approve: approve),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _list.items;
    final showSpinner = !_list.hasLoaded && _list.error == null;
    return AdminPage(
      badge: 'DATA PENGUNJUNG',
      title: 'Data Pendaftar',
      subtitle: list.isEmpty
          ? 'Belum ada pendaftaran'
          : '${_list.total ?? list.length} pendaftar terdaftar',
      onRefresh: _muatData,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            const Icon(Icons.people_rounded, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text('${_list.total ?? list.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: AdminFilterChips<String?>(
            options: [
              ('Semua', null),
              for (final s in kBookingStatuses) (bookingStatusLabel(s), s),
            ],
            selected: _status,
            onSelected: _setStatus,
          ),
        ),
        if (list.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _RingkasanRow(list: list, total: _list.total),
            ),
          ),
        if (_list.error != null && list.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: AdminNotice(
                  'Gagal memuat ulang: ${adminErrorMessage(_list.error!)}'),
            ),
          ),
        if (showSpinner)
          adminLoadingSliver()
        else if (_list.error != null && list.isEmpty)
          adminErrorSliver(adminErrorMessage(_list.error!), _muatData)
        else if (list.isEmpty)
          adminEmptySliver(
              Icons.people_outline_rounded,
              'Belum Ada Pendaftar',
              _status == null
                  ? 'Pendaftaran kunjungan wisata\nakan muncul di sini.'
                  : 'Tidak ada pendaftar dengan status ini.')
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PendaftarCard(
                  key: ValueKey(list[i].guid),
                  booking: list[i],
                  busy: _decider.isBusy(list[i].guid),
                  onTap: () => _openDetail(list[i]),
                  onDecide: (approve) => _decide(list[i], approve: approve),
                ),
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }
}

// -- Dialog konfirmasi keputusan --------------------------------------
class _DecisionInput {
  final String? reason;
  const _DecisionInput(this.reason);
}

class _DecisionDialog extends StatefulWidget {
  final Booking booking;
  final bool approve;
  const _DecisionDialog({required this.booking, required this.approve});

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final color = approve ? AdminColors.success : const Color(0xFFEF4444);
    return AlertDialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(approve ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color, size: 22),
        const SizedBox(width: 10),
        Text(
          approve ? 'Setujui Pendaftaran' : 'Tolak Pendaftaran',
          style: const TextStyle(
              color: AdminColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 13, height: 1.5),
                children: [
                  TextSpan(
                      text: approve
                          ? 'Pendaftaran atas nama '
                          : 'Tolak pendaftaran atas nama '),
                  TextSpan(
                    text: widget.booking.visitorName,
                    style: const TextStyle(
                        color: AdminColors.text, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                      text: approve
                          ? ' akan disetujui. Lanjutkan?'
                          : ' akan ditolak. Lanjutkan?'),
                ],
              ),
            ),
            if (!approve) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _reason,
                maxLength: 255,
                maxLines: 2,
                decoration: adminInputDecoration('Alasan (opsional)'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () => Navigator.pop(
              context, _DecisionInput(approve ? null : _reason.text.trim())),
          child: Text(approve ? 'Setujui' : 'Tolak',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}

// -- Konfigurasi tampilan status --------------------------------------
({Color color, Color bg, Color border, String label, IconData icon})
    _statusCfg(String status) {
  Color tone;
  IconData icon;
  switch (status) {
    case 'confirmed':
      tone = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
    case 'rejected':
      tone = const Color(0xFFEF4444);
      icon = Icons.cancel_rounded;
    case 'awaiting_payment':
    case 'payment_verification':
    case 'payment_review':
      tone = AdminColors.blue;
      icon = Icons.payments_rounded;
    case 'expired':
    case 'cancelled':
      tone = AdminColors.textMuted;
      icon = Icons.block_rounded;
    default:
      tone = const Color(0xFFF59E0B);
      icon = Icons.hourglass_top_rounded;
  }
  return (
    color: tone,
    bg: tone.withValues(alpha: 0.10),
    border: tone.withValues(alpha: 0.25),
    label: bookingStatusLabel(status),
    icon: icon,
  );
}

// -- Card Pendaftar ---------------------------------------------------
class _PendaftarCard extends StatelessWidget {
  final Booking booking;
  final bool busy;
  final VoidCallback onTap;
  final void Function(bool approve) onDecide;
  const _PendaftarCard({
    super.key,
    required this.booking,
    required this.busy,
    required this.onTap,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final p = booking;
    final cfg = _statusCfg(p.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: adminCardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header kartu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminColors.blue.withValues(alpha: 0.06),
                    border:
                        const Border(bottom: BorderSide(color: AdminColors.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2A93F0), Color(0xFF1558B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            p.visitorName.isNotEmpty
                                ? p.visitorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.visitorName,
                                style: const TextStyle(
                                    color: AdminColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.phone_rounded,
                                  size: 11, color: AdminColors.textDim),
                              const SizedBox(width: 4),
                              Text(p.visitorPhone,
                                  style: const TextStyle(
                                      color: AdminColors.textMuted,
                                      fontSize: 12)),
                            ]),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: cfg.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cfg.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cfg.icon, size: 11, color: cfg.color),
                            const SizedBox(width: 4),
                            Text(cfg.label,
                                style: TextStyle(
                                    color: cfg.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Detail
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.landscape_rounded,
                        label: 'Destinasi',
                        value: p.destinationName,
                        valueColor: AdminColors.blue,
                        bold: true,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Tanggal',
                        value: visitDay(p.visitDate),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.group_rounded,
                        label: 'Pengunjung',
                        value: '${p.quantity} Orang',
                      ),
                      if ((p.notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.notes_rounded,
                          label: 'Catatan',
                          value: p.notes!,
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: SizedBox(
                            height: 1,
                            width: double.infinity,
                            child: ColoredBox(color: AdminColors.border)),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AdminColors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AdminColors.orange
                                      .withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.confirmation_number_rounded,
                                size: 14, color: AdminColors.orange),
                          ),
                          const SizedBox(width: 10),
                          const Text('Nomor Bukti',
                              style: TextStyle(
                                  color: AdminColors.textMuted, fontSize: 12)),
                          const Spacer(),
                          Text(p.bookingNumber,
                              style: const TextStyle(
                                  color: AdminColors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ],
                      ),

                      // Tombol Approve / Reject (hanya saat menunggu)
                      if (p.status == 'pending_approval') ...[
                        const SizedBox(height: 14),
                        busy
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: AdminColors.blue, strokeWidth: 2.5),
                                ),
                              )
                            : Row(children: [
                                Expanded(
                                  child: GestureDetector(
                                    key: ValueKey('reject-${p.guid}'),
                                    onTap: () => onDecide(false),
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFEF4444)
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.close_rounded,
                                              color: Color(0xFFEF4444),
                                              size: 16),
                                          SizedBox(width: 6),
                                          Text('Tolak',
                                              style: TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    key: ValueKey('approve-${p.guid}'),
                                    onTap: () => onDecide(true),
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669)
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_rounded,
                                              color: Colors.white, size: 16),
                                          SizedBox(width: 6),
                                          Text('Setujui',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AdminColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border),
          ),
          child: Icon(icon, size: 13, color: AdminColors.textMuted),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(color: AdminColors.textDim, fontSize: 12)),
        ),
        const Text('  ·  ',
            style: TextStyle(color: AdminColors.border, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AdminColors.text,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// -- Detail booking (dibaca ulang dari server) -------------------------
class _BookingDetailSheet extends StatefulWidget {
  final Booking initial;
  final BusinessRepository repository;
  final AuthSession session;
  final AdminBookingDecider decider;
  final Future<BookingDecisionResult?> Function(Booking booking, bool approve)
      onDecide;
  const _BookingDetailSheet({
    required this.initial,
    required this.repository,
    required this.session,
    required this.decider,
    required this.onDecide,
  });

  @override
  State<_BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<_BookingDetailSheet> {
  late Booking _booking = widget.initial;
  bool _loading = true;
  bool _authoritative = false;
  String? _error;
  String? _notice;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.decider.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _request++;
    widget.decider.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final request = ++_request;
    final generation = widget.session.sessionGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository.adminBooking(widget.initial.guid);
      if (!mounted ||
          request != _request ||
          !widget.session.isCurrentGeneration(generation)) {
        return;
      }
      setState(() {
        _booking = detail;
        _authoritative = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted ||
          request != _request ||
          !widget.session.isCurrentGeneration(generation)) {
        return;
      }
      setState(() {
        _error = adminErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _decide(bool approve) async {
    final result = await widget.onDecide(_booking, approve);
    if (!mounted || result == null || !result.actionable) return;
    setState(() {
      _booking = result.booking ?? _booking;
      _notice = result.message;
      if (result.booking != null) _authoritative = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final cfg = _statusCfg(b.status);
    final busy = widget.decider.isBusy(b.guid);
    final canDecide =
        b.status == 'pending_approval' && _authoritative && !_loading;
    final created = b.createdAt;
    final deadline =
        DateTime.tryParse(b.json['approval_expires_at'] as String? ?? '');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AdminColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Detail Pendaftaran',
                        style: TextStyle(
                            color: AdminColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                  AdminBadge(cfg.label, cfg.color, icon: cfg.icon),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading) const LinearProgressIndicator(minHeight: 3),
              if (_error != null) ...[
                AdminNotice('Detail terbaru gagal dimuat: $_error'),
                TextButton(onPressed: _load, child: const Text('Muat ulang')),
              ],
              if (_notice != null) ...[
                AdminNotice(_notice!, color: AdminColors.blueDeep),
                const SizedBox(height: 10),
              ],
              _InfoRow(
                  icon: Icons.person_rounded,
                  label: 'Nama',
                  value: b.visitorName,
                  bold: true),
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: b.visitorEmail),
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Telepon',
                  value: b.visitorPhone),
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.landscape_rounded,
                  label: 'Destinasi',
                  value: b.destinationName,
                  valueColor: AdminColors.blue,
                  bold: true),
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Tanggal',
                  value: visitDay(b.visitDate)),
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.group_rounded,
                  label: 'Pengunjung',
                  value: '${b.quantity} Orang'),
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.payments_rounded,
                  label: 'Total',
                  value: formatMoney(b.totalAmount, b.currency)),
              if ((b.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.notes_rounded,
                    label: 'Catatan',
                    value: b.notes!),
              ],
              const SizedBox(height: 10),
              _InfoRow(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Nomor',
                  value: b.bookingNumber),
              if (created != null) ...[
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Dibuat',
                    value: formatDateTime(created)),
              ],
              if (b.status == 'pending_approval' && deadline != null) ...[
                const SizedBox(height: 10),
                _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Batas setuju',
                    value: formatDateTime(deadline)),
              ],
              if (b.status == 'pending_approval') ...[
                const SizedBox(height: 18),
                if (busy)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                else
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('sheet-reject'),
                        onPressed: canDecide ? () => _decide(false) : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('sheet-approve'),
                        onPressed: canDecide ? () => _decide(true) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Setujui'),
                      ),
                    ),
                  ]),
                if (!_authoritative && !_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                        'Keputusan hanya dapat diambil setelah detail terbaru '
                        'berhasil dimuat.',
                        style: TextStyle(
                            color: AdminColors.textMuted, fontSize: 11.5)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -- Ringkasan jumlah per status --------------------------------------
class _RingkasanRow extends StatelessWidget {
  final List<Booking> list;
  final int? total;
  const _RingkasanRow({required this.list, this.total});

  @override
  Widget build(BuildContext context) {
    const approved = {
      'confirmed',
      'awaiting_payment',
      'payment_verification',
      'payment_review'
    };
    final setuju = list.where((p) => approved.contains(p.status)).length;
    final tolak = list.where((p) => p.status == 'rejected').length;
    final tunggu = list.where((p) => p.status == 'pending_approval').length;

    final items = <(String, int, Color, IconData)>[
      ('Total', total ?? list.length, AdminColors.blue, Icons.groups_rounded),
      ('Menunggu', tunggu, const Color(0xFFF59E0B), Icons.hourglass_top_rounded),
      ('Disetujui', setuju, const Color(0xFF10B981), Icons.check_circle_rounded),
      ('Ditolak', tolak, const Color(0xFFEF4444), Icons.cancel_rounded),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AdminColors.blue.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: items[i].$3.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(items[i].$4, size: 15, color: items[i].$3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${items[i].$2}',
                    style: const TextStyle(
                      color: AdminColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$1,
                    style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
