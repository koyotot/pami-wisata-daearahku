import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/business_repository.dart';
import '../data/admin_state.dart' show visitDayLabel;
import '../data/ticket_models.dart';
import '../theme/app_colors.dart';

class BookingTicketQrSection extends StatefulWidget {
  const BookingTicketQrSection(
      {super.key,
      required this.repository,
      required this.bookingGuid,
      this.booking,
      this.onRefreshed});
  final BusinessRepository repository;
  final String bookingGuid;
  final Booking? booking;
  final Future<void> Function()? onRefreshed;
  @override
  State<BookingTicketQrSection> createState() => _BookingTicketQrSectionState();
}

class _BookingTicketQrSectionState extends State<BookingTicketQrSection>
    with WidgetsBindingObserver {
  BookingTickets? _data;
  Uint8List? _qr;
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _loadingQr = false;
  late final int _generation;
  int _request = 0;
  int _qrRequest = 0;
  bool _foreground = true;
  bool _showingTicket = false;
  final _sheetUpdates = ValueNotifier<int>(0);
  bool get _valid =>
      mounted && widget.repository.api.session.isCurrentGeneration(_generation);

  @override
  void initState() {
    super.initState();
    _generation = widget.repository.api.session.sessionGeneration;
    widget.repository.api.session.sessionChanges.addListener(_clearSession);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _clearQr() {
    _qr = null;
    svg.cache.clear();
    _sheetUpdates.value++;
  }

  void _clearSession() {
    if (!_valid && mounted) {
      ++_request;
      ++_qrRequest;
      setState(() {
        _clearQr();
        _data = null;
        _loading = false;
        _loadingQr = false;
        _error = 'Sesi berubah. Silakan buka kembali tiket.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    ++_qrRequest;
    if (!_foreground) {
      if (mounted) setState(_clearQr);
    } else if (_valid) {
      _load();
      widget.onRefreshed?.call();
    }
  }

  Future<void> _load() async {
    if (!_valid || !_foreground) return;
    final request = ++_request;
    ++_qrRequest;
    setState(() {
      _loading = true;
      _error = null;
      _clearQr();
    });
    try {
      final data = await widget.repository.bookingTickets(widget.bookingGuid);
      if (!_valid || request != _request || !_foreground) return;
      if (data.bookingGuid != widget.bookingGuid) {
        throw StateError('Invalid booking');
      }
      final tickets = data.tickets;
      setState(() {
        _data = data;
        if (!tickets.any((t) => t.guid == _selected)) {
          _selected = tickets.isEmpty ? null : tickets.first.guid;
        }
      });
      if (_selected != null) {
        await _loadQr(tickets.firstWhere((t) => t.guid == _selected));
      }
    } catch (e) {
      if (_valid && request == _request) {
        setState(() => _error = ticketErrorMessage(e));
      }
    } finally {
      if (_valid && request == _request) {
        setState(() => _loading = false);
        _sheetUpdates.value++;
      }
    }
  }

  Future<void> _loadQr(BookingTicket ticket) async {
    final request = ++_qrRequest;
    setState(() {
      _selected = ticket.guid;
      _clearQr();
      _error = null;
      _loadingQr = ticket.qrAvailable && _data?.admissionAllowed == true;
    });
    if (!ticket.qrAvailable || _data?.admissionAllowed != true) return;
    try {
      final image =
          await widget.repository.ticketQr(widget.bookingGuid, ticket.guid);
      if (!_valid || request != _qrRequest || !_foreground) return;
      if (!image.contentType.contains('image/svg+xml')) {
        throw StateError('Invalid image');
      }
      setState(() => _qr = image.bytes);
    } catch (e) {
      if (_valid && request == _qrRequest) {
        setState(() => _error = ticketErrorMessage(e));
      }
    } finally {
      if (_valid && request == _qrRequest) {
        setState(() => _loadingQr = false);
        _sheetUpdates.value++;
      }
    }
  }

  @override
  void dispose() {
    ++_request;
    ++_qrRequest;
    _clearQr();
    _sheetUpdates.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.api.session.sessionChanges.removeListener(_clearSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final tickets = data?.tickets ?? const <BookingTicket>[];
    final selected = tickets.where((t) => t.guid == _selected).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text('Tiket Masuk', style: _text(16, FontWeight.w800))),
          TextButton.icon(
              key: const ValueKey('entry-ticket-refresh'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _loading || !_valid || !_foreground
                  ? null
                  : () {
                      _load();
                      widget.onRefreshed?.call();
                    },
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
              label: Text('Perbarui',
                  style: _text(13, FontWeight.w800, color: AppColors.blue))),
        ]),
        _panel(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(AppSpacing.md)),
              child: const Icon(PhosphorIconsRegular.qrCode,
                  size: 20, color: AppColors.blue),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Tiket Kunjungan', style: _text(16, FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('1 QR tiket untuk setiap pengunjung',
                      style: _text(12, FontWeight.w500,
                          color: AppColors.textSecondary)),
                ])),
            if (data != null)
              Flexible(
                  child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                    color: AppColors.successTint,
                    borderRadius: BorderRadius.circular(AppSpacing.md)),
                child: Text(
                    data.checkedInCount == data.quantity
                        ? 'Semua sudah check-in'
                        : '${data.quantity - data.checkedInCount} belum check-in',
                    textAlign: TextAlign.center,
                    style:
                        _text(11, FontWeight.w700, color: AppColors.success)),
              )),
          ]),
          const SizedBox(height: AppSpacing.lg),
          if (_loading) const LinearProgressIndicator(),
          if (data != null) ...[
            if (data.paymentTestOnly) ...[
              _panel(
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(PhosphorIconsRegular.warning,
                        size: 16, color: AppColors.warningText),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: Text(
                            '${data.paymentLabel ?? 'DEMO'} / TEST_ONLY · Tanpa uang nyata',
                            style: _text(12, FontWeight.w700,
                                color: AppColors.warningText))),
                  ]),
                  color: AppColors.warningTint,
                  border: AppColors.warningBorder),
              const SizedBox(height: AppSpacing.lg),
            ],
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text('Progres Check-in',
                      style: _text(12, FontWeight.w700,
                          color: AppColors.blueDeep)),
                  Text('${data.checkedInCount} dari ${data.quantity} tiket',
                      style: _text(12, FontWeight.w500,
                          color: AppColors.textSecondary)),
                ]),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: data.quantity > 0
                  ? (data.checkedInCount / data.quantity).clamp(0.0, 1.0)
                  : 0,
              minHeight: AppSpacing.sm,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              color: AppColors.blue,
              backgroundColor: AppColors.bg,
              semanticsLabel: 'Progres check-in',
              semanticsValue:
                  '${data.checkedInCount} dari ${data.quantity} tiket',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Pilih tiket pengunjung',
                style: _text(12, FontWeight.w700, color: AppColors.blueDeep)),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final ticket in tickets)
                    Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Semantics(
                          selected: ticket.guid == _selected,
                          child: SizedBox(
                            width: AppSpacing.xl * 2 + AppSpacing.sm,
                            child: OutlinedButton(
                              key: ValueKey('entry-ticket-${ticket.sequence}'),
                              onPressed: _loading || !_valid || !_foreground
                                  ? null
                                  : () => _loadQr(ticket),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                foregroundColor: ticket.guid == _selected
                                    ? Colors.white
                                    : AppColors.blueDeep,
                                backgroundColor: ticket.guid == _selected
                                    ? AppColors.blue
                                    : AppColors.surface,
                                side: BorderSide(
                                    color: ticket.guid == _selected
                                        ? AppColors.blue
                                        : AppColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppSpacing.md)),
                              ),
                              child: Text(
                                  '${ticket.checkedIn ? '✓ ' : ''}${ticket.sequence}',
                                  semanticsLabel:
                                      'Tiket ${ticket.sequence}, ${_ticketStatus(ticket)}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        )),
                ])),
            const SizedBox(height: AppSpacing.md),
            if (selected != null) ...[
              _panel(
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              Text(
                                  'Tiket ${selected.sequence} dari ${data.quantity}',
                                  style: _text(12, FontWeight.w700,
                                      color: AppColors.blueDeep)),
                              Text('QR Tiket Masuk',
                                  style: _text(11, FontWeight.w500,
                                      color: AppColors.blue)),
                            ]),
                        const SizedBox(height: AppSpacing.md),
                        _qrContent(selected),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                            'Tiket ${selected.sequence} · ${_ticketStatus(selected)}',
                            textAlign: TextAlign.center,
                            style: _text(14, FontWeight.w800)),
                        if (selected.checkedInAt != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text('Waktu check-in: ${selected.checkedInAt}',
                              textAlign: TextAlign.center,
                              style: _text(12, FontWeight.w500,
                                  color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(data.message,
                            textAlign: TextAlign.center,
                            style: _text(12, FontWeight.w500,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          key: const ValueKey('entry-ticket-enlarge'),
                          onPressed: _qr == null ||
                                  _loadingQr ||
                                  !_valid ||
                                  !_foreground
                              ? null
                              : _enlargeTicket,
                          style: _outlineStyle(),
                          child: const Text('Perbesar Tiket'),
                        ),
                      ]),
                  color: AppColors.bg),
            ],
            if (selected == null)
              Text(data.message,
                  style: _text(12, FontWeight.w500,
                      color: AppColors.textSecondary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style:
                    _text(12, FontWeight.w500, color: AppColors.warningText)),
            if (_valid)
              TextButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Coba lagi')),
          ],
        ])),
      ]),
    );
  }

  String _ticketStatus(BookingTicket ticket) =>
      ticket.checkedIn ? 'Sudah check-in' : 'Belum check-in';

  TextStyle _text(double size, FontWeight weight,
          {Color color = AppColors.navy}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: weight, color: color, height: 1.5);

  Widget _panel(Widget child,
          {Color color = AppColors.surface, Color border = AppColors.border}) =>
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
              color: color,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(AppSpacing.lg)),
          child: child);

  ButtonStyle _outlineStyle() => OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.blue,
      side: const BorderSide(color: AppColors.blue),
      textStyle: _text(13, FontWeight.w800, color: AppColors.blue),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md)));

  Widget _qrContent(BookingTicket ticket, {double maxWidth = 240}) {
    if (_loadingQr) {
      return const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()));
    }
    final qr = _qr;
    if (qr == null ||
        !_valid ||
        !_foreground ||
        _data?.admissionAllowed != true ||
        !ticket.qrAvailable) {
      return Text(
          ticket.checkedIn
              ? 'Tiket ini sudah digunakan.'
              : 'QR tiket belum tersedia untuk ditampilkan.',
          textAlign: TextAlign.center,
          style: _text(12, FontWeight.w500, color: AppColors.textSecondary));
    }
    return Center(
        child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AspectRatio(
          aspectRatio: 1,
          child: SvgPicture.memory(
            qr,
            key: ValueKey(ticket.guid),
            semanticsLabel: 'QR tiket ${ticket.sequence}',
            errorBuilder: (_, __, ___) => Center(
                child: Text('QR gagal ditampilkan. Perbarui tiket.',
                    textAlign: TextAlign.center,
                    style: _text(12, FontWeight.w500))),
          ),
        ),
      ),
    ));
  }

  Future<void> _enlargeTicket() async {
    if (_showingTicket || _qr == null || !_valid || !_foreground) return;
    _showingTicket = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSpacing.xl))),
        builder: (sheet) => SafeArea(
          top: false,
          child: Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.sheetPadding),
              child: ValueListenableBuilder<int>(
                valueListenable: _sheetUpdates,
                builder: (context, _, __) {
                  final data = _data;
                  final selected = data?.tickets
                      .where((ticket) => ticket.guid == _selected)
                      .firstOrNull;
                  if (!_valid || selected == null || data == null) {
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Tiket tidak dapat ditampilkan. Buka kembali tiket dari akun Anda.'),
                      TextButton(
                          onPressed: () => Navigator.pop(sheet),
                          child: const Text('Tutup')),
                    ]);
                  }
                  final booking = widget.booking?.guid == widget.bookingGuid
                      ? widget.booking
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                'Tiket ${selected.sequence} dari ${data.quantity}',
                                style: _text(20, FontWeight.w800))),
                        IconButton(
                            tooltip: 'Tutup tiket',
                            style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                backgroundColor: AppColors.sheetCloseBackground,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppSpacing.md))),
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                      ]),
                      const Divider(
                          height: AppSpacing.xl, color: AppColors.border),
                      Text(data.message,
                          style: _text(12, FontWeight.w500,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.lg),
                      _qrContent(selected, maxWidth: 320),
                      const SizedBox(height: AppSpacing.xl),
                      _sheetRow('Destinasi',
                          booking?.destinationName ?? 'Belum tersedia'),
                      _sheetRow(
                          'Tanggal',
                          booking == null || booking.visitDate.isEmpty
                              ? 'Belum tersedia'
                              : visitDayLabel(booking.visitDate)),
                      _sheetRow('Status', _ticketStatus(selected)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      _showingTicket = false;
    }
  }

  Widget _sheetRow(String label, String value) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Text(label,
                      style: _text(12, FontWeight.w500,
                          color: AppColors.textSecondary))),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                  flex: 2,
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: _text(13, FontWeight.w700))),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ]);
}
