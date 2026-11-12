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
import 'operations_dashboard/operations_dashboard.dart' show OperationsPage, OperationsSkeleton;

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

  Future<void> _decision(bool approve) async {
    if (!_detail.canDecide || _dialogOpen) return;
    _dialogOpen = true;
    var reason = '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AnimatedBuilder(
            animation: _detail,
            builder: (context, _) => !_detail.valid
                ? const SizedBox.shrink()
                : AlertDialog(
                    title:
                        Text(approve ? 'Setujui booking?' : 'Tolak booking?'),
                    content: approve
                        ? const Text(
                            'Keputusan akan divalidasi kembali oleh server. Status pembayaran tetap mengikuti Laravel.')
                        : TextField(
                            onChanged: (value) => reason = value,
                            maxLength: 1000,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Alasan penolakan (opsional)')),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal')),
                        FilledButton(
                            onPressed: _detail.canDecide
                                ? () => Navigator.pop(context, true)
                                : null,
                            child: Text(approve ? 'Setujui' : 'Tolak'))
                      ])));
    _dialogOpen = false;
    if (confirmed == true && _detail.valid) {
      await _detail.decide(approve: approve, reason: reason);
    }
  }

  Future<void> _reviewDecision() async {
    if (!_detail.canDecide || _dialogOpen) return;
    _dialogOpen = true;
    bool? approve;
    var reason = '';
    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => OperationsTheme(
            role: _session.role,
            child: StatefulBuilder(
                builder: (context, update) => AnimatedBuilder(
                    animation: _detail,
                    builder: (context, _) => !_detail.valid ||
                            _detail.booking == null
                        ? const SizedBox.shrink()
                        : SafeArea(
                            top: false,
                            child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    MediaQuery.viewInsetsOf(context).bottom +
                                        24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text('Tinjau Keputusan',
                                          style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      Text(_detail.booking?.visitorName ??
                                          'Booking'),
                                      Text(_detail.booking?.destinationName ??
                                          ''),
                                      const SizedBox(height: 8),
                                      Text(
                                          '${visitDay(_detail.booking!.visitDate)} · ${_detail.booking!.quantity} tiket'),
                                      Text(bookingStatusLabel(
                                          _detail.booking!.status)),
                                      if (_detail.booking!
                                              .json['payment_status'] !=
                                          null)
                                        Text(
                                            'Pembayaran: ${_detail.booking!.json['payment_status']}'),
                                      const SizedBox(height: 16),
                                      const Text(
                                          'Pilih keputusan. Server memeriksa claim, kuota, dan status terbaru.'),
                                      const SizedBox(height: 12),
                                      RadioGroup<bool>(
                                          groupValue: approve,
                                          onChanged: (value) =>
                                              update(() => approve = value),
                                          child: Column(children: [
                                            RadioListTile<bool>(
                                                value: true,
                                                title: const Text('Setujui'),
                                                enabled: _detail.canDecide),
                                            RadioListTile<bool>(
                                                value: false,
                                                title: const Text('Tolak'),
                                                enabled: _detail.canDecide),
                                          ])),
                                      if (approve == false)
                                        TextField(
                                            maxLength: 1000,
                                            minLines: 2,
                                            maxLines: 4,
                                            onChanged: (value) =>
                                                reason = value,
                                            decoration: const InputDecoration(
                                                labelText:
                                                    'Alasan penolakan (opsional)')),
                                      if (!_detail.canDecide)
                                        const Text(
                                            'Claim atau akses berubah. Tutup sheet dan tarik turun untuk melihat status terbaru.'),
                                      const SizedBox(height: 16),
                                      FilledButton(
                                          key: const ValueKey(
                                              'confirm-booking-decision'),
                                          onPressed: approve != null &&
                                                  _detail.canDecide
                                              ? () => Navigator.pop(
                                                  sheetContext, true)
                                              : null,
                                          child: Text(approve == false
                                              ? 'Konfirmasi penolakan'
                                              : 'Konfirmasi persetujuan')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(sheetContext),
                                          child: const Text('Batal')),
                                    ])))))));
    _dialogOpen = false;
    if (result == true && approve != null && _detail.canDecide) {
      await _detail.decide(approve: approve!, reason: reason);
    }
  }

  Future<void> _claimOptions() async {
    if (!_detail.canDecide || _dialogOpen) return;
    _dialogOpen = true;
    final release = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => OperationsTheme(
            role: _session.role,
            child: AnimatedBuilder(
                animation: _detail,
                builder: (context, _) => !_detail.valid
                    ? const SizedBox.shrink()
                    : SafeArea(
                        top: false,
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Claim booking',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Lepaskan agar Admin lain dapat meninjau. Batas persetujuan tetap.'),
                                  const SizedBox(height: 12),
                                  TextButton(
                                      onPressed: _detail.canDecide
                                          ? () => Navigator.pop(context, true)
                                          : null,
                                      child: const Text('Lepas Claim')),
                                ]))))));
    _dialogOpen = false;
    if (release == true && _detail.canDecide) await _detail.mutate('release');
  }

  Widget? _actionDock() {
    if (_session.role != 1 || !_detail.valid || _detail.accessRevoked)
      return null;
    final actionable = _detail.canClaim || _detail.canDecide;
    if (!actionable && !_detail.busy && !_detail.uncertain) return null;
    return SafeArea(
        top: false,
        child: Material(
            color: AppColors.surface,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: FilledButton(
                          key: const ValueKey('booking-primary-action'),
                          onPressed: _detail.canClaim
                              ? () => _detail.mutate('claim')
                              : _detail.canDecide
                                  ? _reviewDecision
                                  : null,
                          child: Text(_detail.busy
                              ? 'Memproses…'
                              : _detail.uncertain
                                  ? 'Menunggu konfirmasi'
                                  : _detail.canClaim
                                      ? 'Ambil Claim'
                                      : 'Tinjau Keputusan'))),
                  if (_detail.canDecide)
                    IconButton(
                        tooltip: 'Pilihan claim',
                        onPressed: _claimOptions,
                        icon: const Icon(PhosphorIconsRegular.dotsThree)),
                ]))));
  }

  Future<void> _reassign() async {
    if (!_detail.canReassign || _dialogOpen) return;
    _dialogOpen = true;
    final generation = _repository.api.session.sessionGeneration;
    try {
      final assigned =
          await _repository.destinationAdmins(_detail.booking!.destinationGuid);
      if (!_detail.valid ||
          !_repository.api.session.isCurrentGeneration(generation)) {
        return;
      }
      final admins = <AdminAccount>[];
      for (var page = 1;; page++) {
        final result = await _repository.adminAccounts(query: {
          'role': '1',
          'status': 'active',
          'page': '$page',
          'per_page': '100'
        });
        if (!_detail.valid) return;
        admins.addAll(result.items.where((account) =>
            account.role == 1 &&
            account.isActive &&
            assigned.contains(account.guid)));
        if (page >= ((result.meta?['last_page'] as num?)?.toInt() ?? 1)) break;
      }
      if (!_detail.valid || !mounted) return;
      String? target;
      var reason = '';
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AnimatedBuilder(
              animation: _detail,
              builder: (context, _) => !_detail.valid
                  ? const SizedBox.shrink()
                  : StatefulBuilder(
                      builder: (context, update) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Text('Alihkan claim',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AdminColors.navy)),
                              content: SingleChildScrollView(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    const Text('Admin tujuan',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AdminColors.navy)),
                                    const SizedBox(height: 8),
                                    if (admins.isEmpty)
                                      const Text(
                                          'Tidak ada Admin aktif yang ditugaskan ke destinasi ini.'),
                                    DropdownButtonFormField<String>(
                                        icon: const Icon(
                                            PhosphorIconsRegular.caretDown),
                                        isExpanded: true,
                                        decoration:
                                            adminInputDecoration('Admin tujuan')
                                                .copyWith(
                                                    labelText: null,
                                                    hintText:
                                                        'Pilih Admin assigned'),
                                        items: [
                                          for (final account in admins)
                                            DropdownMenuItem(
                                                value: account.guid,
                                                child: Text(account.name,
                                                    overflow:
                                                        TextOverflow.ellipsis))
                                        ],
                                        onChanged: (value) =>
                                            update(() => target = value)),
                                    const SizedBox(height: 16),
                                    const Text('Alasan pengalihan · wajib',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AdminColors.navy)),
                                    const SizedBox(height: 8),
                                    TextField(
                                        maxLength: 255,
                                        minLines: 3,
                                        maxLines: 4,
                                        decoration: adminInputDecoration(
                                                'Alasan pengalihan wajib')
                                            .copyWith(
                                                labelText: null,
                                                hintText:
                                                    'Tuliskan alasan pengalihan'),
                                        onChanged: (value) =>
                                            update(() => reason = value)),
                                    Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: AdminColors.tint,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: const Text(
                                            'Claim dialihkan ke Admin aktif yang ditugaskan. Batas persetujuan asli tidak berubah.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                                color: AdminColors.blueDeep))),
                                  ])),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Batal')),
                                FilledButton(
                                    onPressed: target != null &&
                                            reason.trim().isNotEmpty &&
                                            _detail.canReassign
                                        ? () => Navigator.pop(context, true)
                                        : null,
                                    child: const Text('Alihkan'))
                              ]))));
      if (confirmed == true && _detail.valid) {
        await _detail.mutate('reassign', adminGuid: target, reason: reason);
      }
    } catch (e) {
      if (_detail.valid && mounted) {
        await _detail.handleAccessError(e);
        if (_detail.valid && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(adminErrorMessage(e))));
        }
      }
    } finally {
      _dialogOpen = false;
    }
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

  @override
  Widget build(BuildContext context) {
    if (!_detail.valid) return const SizedBox.shrink();
    final booking = _detail.booking;
    final claim = _detail.claim;
    final remaining = claim?.expiresAt?.difference(DateTime.now().toUtc());
    final claimLabel = _detail.mine
        ? 'Claim Anda'
        : claim?.active == true
            ? _session.role == 1
                ? 'Sedang ditinjau Admin lain'
                : 'Claim Admin lain · ${claim!.ownerGuid}'
            : !_detail.pending
                ? 'Booking selesai atau batas persetujuan lewat'
                : claim == null
                    ? 'Status claim belum tersedia'
                    : 'Tersedia untuk diambil';
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
          actions: [
            if (_session.role != 1)
              IconButton(
                  tooltip: 'Muat status terbaru',
                  onPressed: _detail.busy ? null : _detail.refresh,
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise))
          ],
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
                        if (_session.role != 1)
                          TextButton.icon(
                              onPressed: _detail.busy ? null : _detail.refresh,
                              icon: const Icon(
                                  PhosphorIconsRegular.arrowsClockwise,
                                  size: 18),
                              label: const Text('Muat status terbaru')),
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
                    const Text('Permintaan kunjungan',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF526787))),
                    const SizedBox(height: 6),
                    if (_session.role == 1)
                      Row(children: [
                        Expanded(
                            child: Text(booking.bookingNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700))),
                        IconButton(
                            tooltip: 'Salin nomor booking',
                            onPressed: () => Clipboard.setData(
                                ClipboardData(text: booking.bookingNumber)),
                            icon: const Icon(PhosphorIconsRegular.copy,
                                size: 20)),
                      ])
                    else
                      Text(booking.bookingNumber,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.navy)),
                    const SizedBox(height: 14),
                    Text(booking.destinationName,
                        style: const TextStyle(
                            fontSize: 20,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.navy)),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: AdminBadge(bookingStatusLabel(booking.status),
                            AdminColors.blueDeep)),
                    const SizedBox(height: 14),
                    _BookingField('Kunjungan', visitDay(booking.visitDate)),
                    _BookingField('Tiket', '${booking.quantity} orang'),
                    _BookingField('Total booking',
                        formatMoney(booking.totalAmount, booking.currency)),
                    _BookingField('Batas persetujuan',
                        '${booking.json['approval_expires_at'] ?? '—'}'),
                  ])),
              const SizedBox(height: 12),
              _BookingPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Pengunjung',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.navy)),
                    const SizedBox(height: 10),
                    Text(
                        '${booking.visitorName}\n${booking.visitorEmail}\n${booking.visitorPhone}',
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: Color(0xFF526787))),
                    if (booking.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text('Catatan: ${booking.notes}',
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                    ],
                  ])),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: claim?.active == true && !_detail.mine
                          ? const Color(0xFFFFF0D6)
                          : AdminColors.tint,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            _detail.mine
                                ? PhosphorIconsRegular.shieldCheck
                                : claim?.active == true
                                    ? PhosphorIconsRegular.lock
                                    : PhosphorIconsRegular.info,
                            color: AdminColors.blueDeep),
                        const SizedBox(height: 10),
                        Text(claimLabel,
                            key: const ValueKey('claim-status'),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.navy)),
                        if (remaining != null && claim?.active == true) ...[
                          const SizedBox(height: 6),
                          Text(
                              remaining.isNegative
                                  ? 'Claim kedaluwarsa. Status sedang disinkronkan.'
                                  : 'Sisa claim ${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}d',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                            'Claim maksimal 15 menit; batas persetujuan asli tetap. Waktu perangkat hanya penunjuk. Server memvalidasi status terbaru.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Color(0xFF526787))),
                      ])),
              const SizedBox(height: 20),
              if (_session.role != 1) ...[
                FilledButton(
                    key: const ValueKey('claim-booking'),
                    onPressed:
                        _detail.canClaim ? () => _detail.mutate('claim') : null,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Ambil claim')),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton(
                      key: const ValueKey('approve-booking'),
                      onPressed:
                          _detail.canDecide ? () => _decision(true) : null,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Setujui')),
                  OutlinedButton(
                      key: const ValueKey('reject-booking'),
                      onPressed:
                          _detail.canDecide ? () => _decision(false) : null,
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: const Color(0xFFA64040),
                          backgroundColor: const Color(0xFFFFF1F1),
                          side: const BorderSide(color: Color(0xFFF3D1D1))),
                      child: const Text('Tolak')),
                  TextButton(
                      key: const ValueKey('release-booking'),
                      onPressed: _detail.canDecide
                          ? () => _detail.mutate('release')
                          : null,
                      style:
                          TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: const Text('Lepas claim')),
                ]),
              ],
              if (_repository.api.session.role == 2)
                OutlinedButton(
                    onPressed:
                        _detail.canReassign && !_dialogOpen ? _reassign : null,
                    child: const Text('Alihkan ke Admin')),
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

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AdminColors.border),
          borderRadius: BorderRadius.circular(17)),
      child: child);
}

class _BookingField extends StatelessWidget {
  const _BookingField(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF526787)))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.navy))),
      ]));
}
