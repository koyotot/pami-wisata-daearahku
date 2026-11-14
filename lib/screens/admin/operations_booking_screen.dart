import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import '../../data/admin_state.dart';
import '../../data/approval_queue_state.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../services/api_client.dart';
import 'admin_common.dart';
import '../../theme/app_colors.dart';
import '../../widgets/operations_chrome.dart';
import '../../widgets/operations_status.dart';
import 'operations_dashboard/operations_dashboard.dart'
    show OperationsPage, OperationsSkeleton;

class OperationsBookingScreen extends StatefulWidget {
  const OperationsBookingScreen(
      {super.key, required this.bookingGuid, this.repository, this.session});
  final String bookingGuid;
  final BusinessRepository? repository;
  final AuthSession? session;
  @override
  State<OperationsBookingScreen> createState() =>
      _OperationsBookingScreenState();
}

/// Which presentation the booking detail is in. Derived from server state only,
/// except [reassigned] which also needs the reassignment made in this session.
enum _BookingView { unclaimed, mine, other, reassigned, rejected, closed }

enum _ActionKind { claim, approve, reject, release, reassign }

class _BookingAction {
  const _BookingAction(this.kind,
      {this.reason, this.adminGuid, this.adminName});
  final _ActionKind kind;
  final String? reason;
  final String? adminGuid;
  final String? adminName;
}

class _OperationsBookingScreenState extends State<OperationsBookingScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session =
      widget.session ?? widget.repository?.api.session ?? AuthSession.instance;
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final ApprovalDetailState _detail =
      ApprovalDetailState(_repository, widget.bookingGuid, session: _session);
  Timer? _timer;
  bool _dialogOpen = false;
  DateTime? _refetchedExpiry;
  String? _reassignedName;
  bool get _superadmin => _session.role == 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detail.addListener(_changed);
    _detail.refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        final claimExpiry = _detail.claim?.expiresAt;
        final approvalExpiry = _detail.claim?.approvalExpiresAt;
        final expiry = claimExpiry != null &&
                approvalExpiry != null &&
                approvalExpiry.isBefore(claimExpiry)
            ? approvalExpiry
            : claimExpiry;
        if (_session.role == 1 &&
            expiry != null &&
            !expiry.isAfter(DateTime.now().toUtc()) &&
            _refetchedExpiry != expiry &&
            !_detail.busy &&
            !_detail.uncertain) {
          _refetchedExpiry = expiry;
          _detail.refresh();
        }
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _detail.refresh();
  }

  _BookingView get _view {
    final booking = _detail.booking;
    if (booking == null) return _BookingView.closed;
    if (booking.status == 'rejected') return _BookingView.rejected;
    if (!_detail.pending) return _BookingView.closed;
    if (_detail.mine) return _BookingView.mine;
    final active = _detail.claim?.activeAt(DateTime.now().toUtc()) == true;
    if (active) {
      return _reassignedName != null
          ? _BookingView.reassigned
          : _BookingView.other;
    }
    return _BookingView.unclaimed;
  }

  /// Active Admins assigned to this booking's destination (superadmin only).
  Future<List<AdminAccount>> _loadAssignableAdmins() async {
    final generation = _repository.api.session.sessionGeneration;
    try {
      final assigned =
          await _repository.destinationAdmins(_detail.booking!.destinationGuid);
      final admins = <AdminAccount>[];
      for (var page = 1;; page++) {
        final result = await _repository.adminAccounts(query: {
          'role': '1',
          'status': 'active',
          'page': '$page',
          'per_page': '100'
        });
        if (!_detail.valid ||
            !_repository.api.session.isCurrentGeneration(generation)) {
          return const [];
        }
        admins.addAll(result.items.where((account) =>
            account.role == 1 &&
            account.isActive &&
            assigned.contains(account.guid)));
        if (page >= ((result.meta?['last_page'] as num?)?.toInt() ?? 1)) break;
      }
      return admins;
    } catch (e) {
      if (_detail.valid && mounted) await _detail.handleAccessError(e);
      rethrow;
    }
  }

  Future<void> _openActions() async {
    if (_dialogOpen || !_detail.valid || _detail.booking == null) return;
    _dialogOpen = true;
    final action = await showModalBottomSheet<_BookingAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => OperationsTheme(
            role: _session.role,
            child: _BookingActionSheet(
                detail: _detail,
                superadmin: _superadmin,
                loadAdmins: _loadAssignableAdmins)));
    _dialogOpen = false;
    if (action == null || !mounted || !_detail.valid) return;
    switch (action.kind) {
      case _ActionKind.claim:
        await _detail.mutate('claim');
      case _ActionKind.approve:
        await _detail.decide(approve: true);
      case _ActionKind.reject:
        await _detail.decide(approve: false, reason: action.reason);
      case _ActionKind.release:
        await _detail.mutate('release');
      case _ActionKind.reassign:
        await _detail.mutate('reassign',
            adminGuid: action.adminGuid, reason: action.reason);
        if (mounted &&
            _detail.valid &&
            !_detail.uncertain &&
            !_detail.accessRevoked &&
            _detail.claim?.ownerGuid == action.adminGuid) {
          setState(() => _reassignedName = action.adminName);
        }
    }
  }

  Widget? _actionDock() {
    if (!_detail.valid || _detail.accessRevoked) return null;
    final view = _view;
    if (view == _BookingView.closed) return null;
    final idle = !_detail.busy && !_detail.uncertain;
    final (title, subtitle) = switch (view) {
      _BookingView.unclaimed => ('Perlu penanganan', 'Claim belum diambil'),
      _BookingView.mine => ('Claim aktif', 'Tindakan persetujuan tersedia'),
      _BookingView.other => ('Claim aktif', 'Sedang ditinjau Admin lain'),
      _BookingView.reassigned => ('Sudah dialihkan', 'Menunggu admin tujuan'),
      _ => ('Permintaan ditolak', 'Tidak ada tindakan aktif'),
    };
    final enabled = idle &&
        switch (view) {
          _BookingView.unclaimed => _detail.canClaim,
          _BookingView.mine => _detail.canDecide,
          _BookingView.other => _superadmin && _detail.canReassign,
          _ => false,
        };
    final manage = view == _BookingView.unclaimed ||
        view == _BookingView.mine ||
        (view == _BookingView.other && _superadmin);
    final label = _detail.busy
        ? 'Memproses…'
        : _detail.uncertain
            ? 'Menunggu konfirmasi'
            : manage
                ? 'Kelola Booking'
                : 'Lihat Tindakan';
    return Material(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: const Color(0x22102D59),
        child: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                  const SizedBox(width: 12),
                  Opacity(
                      opacity: enabled ? 1 : .5,
                      child: FilledButton(
                          key: const ValueKey('booking-primary-action'),
                          onPressed: enabled ? _openActions : null,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.blue,
                              disabledForegroundColor: Colors.white,
                              minimumSize: const Size(140, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: Text(label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800)))),
                ]))));
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _detail
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  (String, OperationsTone) _statusBadge(_BookingView view, Booking booking) =>
      switch (view) {
        _BookingView.unclaimed => ('Menunggu Persetujuan', OperationsTone.orange),
        _BookingView.mine ||
        _BookingView.other =>
          ('Menunggu Persetujuan', OperationsTone.blue),
        _BookingView.rejected => ('Ditolak', OperationsTone.red),
        _BookingView.reassigned => ('Dialihkan', OperationsTone.grey),
        _BookingView.closed => (
            bookingStatusLabel(booking.status),
            booking.status == 'confirmed' ? OperationsTone.green : OperationsTone.grey
          ),
      };

  Widget _claimPanel(_BookingView view) {
    final claim = _detail.claim;
    final remaining = claim?.expiresAt?.difference(DateTime.now().toUtc());
    final (badge, tone) = switch (view) {
      _BookingView.mine => ('Milik Anda', OperationsTone.blue),
      _BookingView.reassigned => ('Dialihkan', OperationsTone.grey),
      _ => ('Admin lain', OperationsTone.grey),
    };
    final body = switch (view) {
      _BookingView.mine =>
        'Claim aktif hingga ${formatDeadline(claim?.raw['expires_at'])}. '
            'Berlaku maksimal 15 menit, serta tetap tunduk pada batas persetujuan booking.',
      _BookingView.reassigned =>
        'Penanganan ditujukan kepada $_reassignedName. Status aktual harus dikonfirmasi server.',
      _ =>
        'Booking sedang ditinjau Admin lain hingga ${formatDeadline(claim?.raw['expires_at'])}. '
            'Batas persetujuan asli tidak berubah.',
    };
    return _BookingPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
            child: Text('Claim Persetujuan',
                key: ValueKey('claim-status'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
        OperationsStatusBadge(badge, tone, small: true),
      ]),
      const SizedBox(height: 10),
      Text(body,
          style: const TextStyle(
              fontSize: 12, height: 1.6, color: AppColors.textSecondary)),
      if (view == _BookingView.mine && remaining != null) ...[
        const SizedBox(height: 8),
        Text(
            remaining.isNegative
                ? 'Claim kedaluwarsa. Status sedang disinkronkan.'
                : 'Sisa claim ${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}d',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
      ],
    ]));
  }

  Widget? _stateNotice(_BookingView view) => switch (view) {
        _BookingView.unclaimed => const _NoticeCard(
            tone: OperationsTone.orange,
            icon: PhosphorIconsRegular.info,
            title: 'Menunggu admin mengambil claim',
            body:
                'Booking masih berada dalam jendela persetujuan. Ambil claim terlebih dahulu sebelum memutuskan.'),
        _BookingView.mine => _NoticeCard(
            tone: OperationsTone.orange,
            icon: PhosphorIconsRegular.info,
            title: 'Booking sedang dalam claim Anda',
            body: _superadmin
                ? 'Anda dapat menyetujui, menolak, melepaskan claim, atau mengalihkan penanganan. Server menentukan apakah claim masih valid.'
                : 'Anda dapat menyetujui, menolak, atau melepaskan claim. Server menentukan apakah claim masih valid.'),
        _BookingView.rejected => const _NoticeCard(
            tone: OperationsTone.red,
            icon: PhosphorIconsRegular.info,
            title: 'Permintaan kunjungan ditolak',
            body:
                'Permintaan telah ditolak. Tidak ada tindakan claim yang dapat dijalankan.'),
        _BookingView.reassigned => _NoticeCard(
            tone: OperationsTone.blue,
            icon: PhosphorIconsRegular.info,
            title: 'Penanganan telah dialihkan',
            body:
                'Booking ini sudah dialihkan ke $_reassignedName. Menunggu admin tujuan meninjau.'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (!_detail.valid) return const SizedBox.shrink();
    final booking = _detail.booking;
    final view = _view;
    return PopScope(
        canPop: !_detail.valid ||
            _detail.accessRevoked ||
            (!_detail.busy && !_detail.uncertain),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Verifikasi tindakan belum selesai. Periksa ulang dengan kunci yang sama sebelum kembali.')));
          }
        },
        child: OperationsPage(
          role: _session.role,
          bottomBar: _actionDock(),
          title: 'Detail Booking',
          subtitle: 'Permintaan kunjungan & kepemilikan claim',
          embedded: false,
          onRefresh: _detail.refresh,
          children: [
            if (_detail.busy)
              booking == null
                  ? const OperationsSkeleton()
                  : const LinearProgressIndicator(),
            if (_detail.message != null)
              Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF0D6),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(PhosphorIconsRegular.info,
                            color: Color(0xFF795018)),
                        const SizedBox(height: 8),
                        Text(_detail.message!,
                            key: const ValueKey('claim-message'),
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF795018))),
                      ])),
            if (booking != null) ...[
              if (!_detail.fresh && !_detail.busy)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF0D6),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text(
                      'Snapshot lama · belum tersinkron\nTarik turun sebelum melakukan tindakan.',
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: Color(0xFF795018))),
                ),
              _BookingPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Row(children: [
                      const Expanded(
                          child: Text('PERMINTAAN KUNJUNGAN',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: .8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary))),
                      Builder(builder: (_) {
                        final (label, tone) = _statusBadge(view, booking);
                        return OperationsStatusBadge(label, tone);
                      }),
                    ]),
                    const SizedBox(height: 16),
                    Text(booking.destinationName,
                        style: const TextStyle(
                            fontSize: 20,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 14),
                    Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F5FB),
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Expanded(
                              child: Text(booking.bookingNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy))),
                          IconButton(
                              tooltip: 'Salin nomor booking',
                              onPressed: () => Clipboard.setData(
                                  ClipboardData(text: booking.bookingNumber)),
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.blue,
                                  side:
                                      const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              icon: const Icon(PhosphorIconsRegular.copy,
                                  size: 20)),
                        ])),
                  ])),
              const SizedBox(height: 12),
              _BookingPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Informasi Kunjungan',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: _InfoTile(
                              icon: PhosphorIconsRegular.calendarBlank,
                              label: 'Tanggal kunjungan',
                              value: visitDayLabel(booking.visitDate))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _InfoTile(
                              icon: PhosphorIconsRegular.users,
                              label: 'Jumlah tiket',
                              value: '${booking.quantity} orang')),
                    ]),
                    const SizedBox(height: 12),
                    _InfoTile(
                        icon: PhosphorIconsRegular.creditCard,
                        label: 'Total booking',
                        large: true,
                        value:
                            formatMoney(booking.totalAmount, booking.currency)),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Expanded(
                          child: Text('Batas persetujuan',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary))),
                      Text(formatDeadline(booking.json['approval_expires_at']),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy)),
                    ]),
                  ])),
              const SizedBox(height: 12),
              _BookingPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Data Pengunjung',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy))),
                      const Text('Kontak booking',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FD),
                              borderRadius: BorderRadius.circular(16)),
                          child: Text(
                              booking.visitorName.trim().isEmpty
                                  ? '?'
                                  : booking.visitorName
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blue))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(booking.visitorName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy)),
                            const SizedBox(height: 4),
                            const Text('Nama sesuai data booking',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ])),
                    ]),
                    const SizedBox(height: 14),
                    _ContactRow(
                        icon: PhosphorIconsRegular.envelope,
                        text: booking.visitorEmail.isEmpty
                            ? '—'
                            : booking.visitorEmail),
                    const SizedBox(height: 10),
                    _ContactRow(
                        icon: PhosphorIconsRegular.deviceMobile,
                        text: booking.visitorPhone.isEmpty
                            ? '—'
                            : booking.visitorPhone),
                    if (booking.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text('Catatan: ${booking.notes}',
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.textSecondary)),
                    ],
                  ])),
              if (view == _BookingView.mine ||
                  view == _BookingView.other ||
                  view == _BookingView.reassigned) ...[
                const SizedBox(height: 12),
                _claimPanel(view),
              ],
              if (_stateNotice(view) case final notice?) ...[
                const SizedBox(height: 12),
                notice,
              ],
              const SizedBox(height: 14),
              const Text(
                  'Status yang ditampilkan mengikuti data server. Validasi persetujuan, kepemilikan claim, dan deadline tetap menjadi tanggung jawab backend.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary)),
            ],
            if (_detail.uncertain)
              OutlinedButton(
                  onPressed: _detail.busy ? null : _detail.recoverMutation,
                  child: const Text('Periksa ulang tindakan yang sama')),
            if (_detail.accessRevoked)
              TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Kembali ke destinasi')),
            const SizedBox(height: 40),
          ],
        ));
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(
      {required this.tone,
      required this.icon,
      required this.title,
      required this.body});
  final OperationsTone tone;
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    final c = operationsToneColors(tone);
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c.fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: c.fg)),
            const SizedBox(height: 6),
            Text(body,
                style: TextStyle(
                    fontSize: 12, height: 1.6, color: c.fg.withValues(alpha: .9))),
          ])),
        ]));
  }
}

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AdminColors.border),
          borderRadius: BorderRadius.circular(20)),
      child: child);
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.large = false});
  final IconData icon;
  final String label;
  final String value;
  final bool large;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF6F9FD),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: AppColors.blue),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary))),
        ]),
        SizedBox(height: large ? 10 : 8),
        Text(value,
            style: TextStyle(
                fontSize: large ? 22 : 15,
                fontWeight: FontWeight.w800,
                color: large ? AppColors.blue : AppColors.navy)),
      ]));
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17, color: AppColors.blue),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: AppColors.navy))),
      ]);
}

enum _SheetStep { menu, claim, approve, reject, release, reassign }

/// Bottom sheet "Tindakan Booking": action menu plus one confirmation step per action.
/// It only collects the intent; the screen performs the mutation after it closes.
class _BookingActionSheet extends StatefulWidget {
  const _BookingActionSheet(
      {required this.detail,
      required this.superadmin,
      required this.loadAdmins});
  final ApprovalDetailState detail;
  final bool superadmin;
  final Future<List<AdminAccount>> Function() loadAdmins;
  @override
  State<_BookingActionSheet> createState() => _BookingActionSheetState();
}

class _BookingActionSheetState extends State<_BookingActionSheet> {
  _SheetStep _step = _SheetStep.menu;
  final _rejectReason = TextEditingController();
  final _reassignReason = TextEditingController();
  List<AdminAccount>? _admins;
  bool _loadingAdmins = false;
  String? _adminError;
  String? _target;

  ApprovalDetailState get _d => widget.detail;

  @override
  void dispose() {
    _rejectReason.dispose();
    _reassignReason.dispose();
    super.dispose();
  }

  void _go(_SheetStep step) {
    setState(() => _step = step);
    if (step == _SheetStep.reassign && _admins == null && !_loadingAdmins) {
      _fetchAdmins();
    }
  }

  Future<void> _fetchAdmins() async {
    setState(() {
      _loadingAdmins = true;
      _adminError = null;
    });
    try {
      final admins = await widget.loadAdmins();
      if (!mounted) return;
      setState(() {
        _admins = admins;
        _loadingAdmins = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adminError = adminErrorMessage(e);
        _loadingAdmins = false;
      });
    }
  }

  String get _title => switch (_step) {
        _SheetStep.menu => 'Tindakan Booking',
        _SheetStep.claim => 'Ambil Claim',
        _SheetStep.approve => 'Setujui Booking',
        _SheetStep.reject => 'Tolak Booking',
        _SheetStep.release => 'Lepas Claim',
        _SheetStep.reassign => 'Alihkan ke Admin',
      };

  Widget _lead(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, height: 1.6, color: AppColors.textSecondary));

  Widget _toneBox(String text, OperationsTone tone) {
    final c = operationsToneColors(tone);
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14)),
        child: Text(text,
            style: TextStyle(fontSize: 12, height: 1.6, color: c.fg)));
  }

  Widget _option(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback? onTap,
      bool danger = false}) {
    final enabled = onTap != null;
    return Opacity(
        opacity: enabled ? 1 : .5,
        child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: danger
                                  ? const Color(0xFFFDECEC)
                                  : const Color(0xFFE8F1FD),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon,
                              size: 22,
                              color: danger
                                  ? const Color(0xFFB23B3B)
                                  : AppColors.blue)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy)),
                            const SizedBox(height: 3),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ])),
                      const Icon(PhosphorIconsRegular.caretRight,
                          size: 18, color: AppColors.textSecondary),
                    ])))));
  }

  Widget _buttons(
      {required String backLabel,
      required VoidCallback onBack,
      required String okLabel,
      required VoidCallback? onOk,
      bool danger = false}) {
    const radius = 14.0;
    return Row(children: [
      Expanded(
          child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius))),
              child: Text(backLabel,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)))),
      const SizedBox(width: 12),
      Expanded(
          child: FilledButton(
              onPressed: onOk,
              style: FilledButton.styleFrom(
                  backgroundColor:
                      danger ? const Color(0xFFFDECEC) : AppColors.blue,
                  foregroundColor:
                      danger ? const Color(0xFFB23B3B) : Colors.white,
                  disabledBackgroundColor:
                      danger ? const Color(0xFFFDECEC) : AppColors.blue,
                  disabledForegroundColor:
                      danger ? const Color(0xFFB23B3B) : Colors.white,
                  minimumSize: const Size(48, 48),
                  side: danger
                      ? const BorderSide(color: Color(0xFFF3C9C9))
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius))),
              child: Opacity(
                  opacity: onOk == null ? .5 : 1,
                  child: Text(okLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800))))),
    ]);
  }

  List<Widget> _menu() {
    final claimedByOther = !_d.mine &&
        _d.claim?.activeAt(DateTime.now().toUtc()) == true;
    final options = <Widget>[
      _option(
          icon: PhosphorIconsRegular.hand,
          title: 'Ambil Claim',
          subtitle: 'Ambil kepemilikan penanganan sementara',
          onTap: _d.canClaim ? () => _go(_SheetStep.claim) : null),
    ];
    if (_d.mine) {
      options.addAll([
        _option(
            icon: PhosphorIconsRegular.checkCircle,
            title: 'Setujui Booking',
            subtitle: 'Konfirmasi persetujuan permintaan',
            onTap: _d.canDecide ? () => _go(_SheetStep.approve) : null),
        _option(
            icon: PhosphorIconsRegular.xCircle,
            title: 'Tolak Booking',
            subtitle: 'Tolak permintaan dengan alasan',
            danger: true,
            onTap: _d.canDecide ? () => _go(_SheetStep.reject) : null),
        _option(
            icon: PhosphorIconsRegular.briefcase,
            title: 'Lepas Claim',
            subtitle: 'Kembalikan booking ke antrean',
            onTap: _d.canDecide ? () => _go(_SheetStep.release) : null),
      ]);
    }
    if (widget.superadmin && (_d.mine || claimedByOther)) {
      options.add(_option(
          icon: PhosphorIconsRegular.userSwitch,
          title: 'Alihkan ke Admin',
          subtitle: 'Pindahkan penanganan ke admin lain',
          onTap: _d.canReassign ? () => _go(_SheetStep.reassign) : null));
    }
    return [
      _lead('Pilih tindakan operasional untuk permintaan kunjungan ini.'),
      const SizedBox(height: 14),
      _toneBox(
          _d.mine
              ? 'Claim hanya berlaku maksimal 15 menit, dan tidak memperpanjang deadline persetujuan.'
              : 'Claim harus berhasil diverifikasi sebelum tindakan persetujuan tersedia.',
          OperationsTone.blue),
      const SizedBox(height: 14),
      for (final option in options) ...[option, const SizedBox(height: 10)],
    ];
  }

  static const _serverCheck =
      'Server akan memverifikasi status terbaru, kepemilikan claim, serta deadline sebelum tindakan diproses.';

  List<Widget> _content() {
    switch (_step) {
      case _SheetStep.menu:
        return _menu();
      case _SheetStep.claim:
        return [
          _lead(
              'Ambil kepemilikan sementara untuk menangani booking ini. Claim tidak memperpanjang batas persetujuan.'),
          const SizedBox(height: 14),
          _toneBox(_serverCheck, OperationsTone.orange),
          const SizedBox(height: 18),
          _buttons(
              backLabel: 'Batal',
              onBack: () => Navigator.pop(context),
              okLabel: 'Ambil Claim',
              onOk: _d.canClaim
                  ? () => Navigator.pop(
                      context, const _BookingAction(_ActionKind.claim))
                  : null),
        ];
      case _SheetStep.approve:
        return [
          _lead(
              'Persetujuan akan meneruskan booking ke tahapan berikutnya sesuai aturan sistem.'),
          const SizedBox(height: 14),
          _toneBox(_serverCheck, OperationsTone.orange),
          const SizedBox(height: 18),
          _buttons(
              backLabel: 'Batal',
              onBack: () => Navigator.pop(context),
              okLabel: 'Ya, Setujui',
              onOk: _d.canDecide
                  ? () => Navigator.pop(
                      context, const _BookingAction(_ActionKind.approve))
                  : null),
        ];
      case _SheetStep.reject:
        return [
          _lead(
              'Isi alasan penolakan untuk membantu pengunjung memahami keputusan.'),
          const SizedBox(height: 14),
          const Text('Alasan penolakan *',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          TextField(
              controller: _rejectReason,
              maxLength: 1000,
              minLines: 4,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: adminInputDecoration(null,
                  hint: 'Tuliskan alasan penolakan...')),
          const SizedBox(height: 10),
          _buttons(
              backLabel: 'Kembali',
              onBack: () => _go(_SheetStep.menu),
              okLabel: 'Lanjutkan',
              danger: true,
              onOk: _d.canDecide && _rejectReason.text.trim().isNotEmpty
                  ? () => Navigator.pop(
                      context,
                      _BookingAction(_ActionKind.reject,
                          reason: _rejectReason.text.trim()))
                  : null),
        ];
      case _SheetStep.release:
        return [
          _lead(
              'Claim Anda akan dilepaskan dan booking kembali dapat ditangani admin yang berwenang.'),
          const SizedBox(height: 14),
          _toneBox(_serverCheck, OperationsTone.orange),
          const SizedBox(height: 18),
          _buttons(
              backLabel: 'Batal',
              onBack: () => Navigator.pop(context),
              okLabel: 'Lepas Claim',
              onOk: _d.canDecide
                  ? () => Navigator.pop(
                      context, const _BookingAction(_ActionKind.release))
                  : null),
        ];
      case _SheetStep.reassign:
        final admins = _admins ?? const <AdminAccount>[];
        final selected = admins.where((a) => a.guid == _target).firstOrNull;
        return [
          _lead('Pilih admin tujuan untuk menangani permintaan ini.'),
          const SizedBox(height: 14),
          const Text('Admin tujuan',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          if (_loadingAdmins) const LinearProgressIndicator(),
          if (_adminError != null) ...[
            Text(_adminError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB23B3B))),
            TextButton(
                onPressed: _fetchAdmins, child: const Text('Muat ulang admin')),
          ],
          if (!_loadingAdmins && _adminError == null && admins.isEmpty)
            const Text(
                'Tidak ada Admin aktif yang ditugaskan ke destinasi ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (admins.isNotEmpty)
            DropdownButtonFormField<String>(
                icon: const Icon(PhosphorIconsRegular.caretDown),
                isExpanded: true,
                initialValue: _target,
                decoration: adminInputDecoration(null, hint: 'Pilih admin tujuan'),
                items: [
                  for (final account in admins)
                    DropdownMenuItem(
                        value: account.guid,
                        child: Text(account.name,
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) => setState(() => _target = value)),
          const SizedBox(height: 14),
          const Text('Alasan pengalihan *',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          TextField(
              controller: _reassignReason,
              maxLength: 255,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: adminInputDecoration(null,
                  hint: 'Tuliskan alasan pengalihan')),
          const SizedBox(height: 6),
          _toneBox(
              'Admin tujuan harus aktif dan ditugaskan ke destinasi ini. Batas persetujuan asli tidak berubah.',
              OperationsTone.blue),
          const SizedBox(height: 18),
          _buttons(
              backLabel: 'Kembali',
              onBack: () => _go(_SheetStep.menu),
              okLabel: 'Lanjutkan',
              onOk: selected != null &&
                      _reassignReason.text.trim().isNotEmpty &&
                      _d.canReassign
                  ? () => Navigator.pop(
                      context,
                      _BookingAction(_ActionKind.reassign,
                          adminGuid: selected.guid,
                          adminName: selected.name,
                          reason: _reassignReason.text.trim()))
                  : null),
        ];
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _d,
      builder: (context, _) => !_d.valid
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(_title,
                                  style: const TextStyle(
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
                              icon: const Icon(PhosphorIconsRegular.x,
                                  size: 18)),
                        ]),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),
                        ..._content(),
                      ]))));
}
