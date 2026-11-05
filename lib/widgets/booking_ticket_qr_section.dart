import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/business_repository.dart';
import '../data/ticket_models.dart';
import '../theme/app_colors.dart';

class BookingTicketQrSection extends StatefulWidget {
  const BookingTicketQrSection(
      {super.key,
      required this.repository,
      required this.bookingGuid,
      this.onRefreshed});
  final BusinessRepository repository;
  final String bookingGuid;
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
      if (_valid && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _loadQr(BookingTicket ticket) async {
    final request = ++_qrRequest;
    setState(() {
      _selected = ticket.guid;
      _clearQr();
      _error = null;
      _loadingQr = ticket.qrAvailable;
    });
    if (!ticket.qrAvailable) return;
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
      if (_valid && request == _qrRequest) setState(() => _loadingQr = false);
    }
  }

  @override
  void dispose() {
    ++_request;
    ++_qrRequest;
    _clearQr();
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.api.session.sessionChanges.removeListener(_clearSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final tickets = data?.tickets ?? const <BookingTicket>[];
    final selected = tickets.where((t) => t.guid == _selected).firstOrNull;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Tiket masuk',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy))),
          IconButton(
              tooltip: 'Perbarui tiket',
              onPressed: _loading || !_valid
                  ? null
                  : () {
                      _load();
                      widget.onRefreshed?.call();
                    },
              icon: const Icon(Icons.refresh, color: AppColors.blue)),
        ]),
        if (_loading) const LinearProgressIndicator(),
        if (data != null) ...[
          if (data.paymentTestOnly) ...[
            Text(
                '${data.paymentLabel ?? 'DEMO'} / TEST_ONLY · tanpa uang nyata',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blueDeep)),
            const SizedBox(height: 8),
          ],
          Text('${data.checkedInCount}/${data.quantity} tiket sudah check-in'),
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final ticket in tickets)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                            '${ticket.sequence}${ticket.checkedIn ? ' · Sudah masuk' : ''}'),
                        selected: ticket.guid == _selected,
                        selectedColor: AppColors.blue.withValues(alpha: .15),
                        onSelected: _loading ? null : (_) => _loadQr(ticket),
                      )),
              ])),
          const SizedBox(height: 12),
          if (_loadingQr)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator()))
          else if (_qr != null)
            Center(
                child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: SvgPicture.memory(_qr!,
                          key: ValueKey(_selected),
                          semanticsLabel: 'QR tiket ${selected?.sequence}',
                          errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                  'QR gagal ditampilkan. Perbarui tiket.'))))),
            )),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(
                'Tiket ${selected.sequence} dari ${data.quantity} · ${selected.checkedIn ? 'Sudah check-in' : 'Belum check-in'}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (selected.checkedInAt != null)
              Text('Waktu server: ${selected.checkedInAt}'),
          ],
          const SizedBox(height: 6),
          Text(data.message),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_valid)
            TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Coba lagi')),
        ],
      ]),
    );
  }
}
