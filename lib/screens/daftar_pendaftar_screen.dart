// ============================================================
// lib/screens/daftar_pendaftar_screen.dart
// REDESIGN: Biru terang â€” selaras dengan halaman admin lainnya
// ============================================================
import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import '../data/app_data.dart';

// â”€â”€ Palet (selaras dengan TambahWisataScreen & Dashboard) â”€â”€â”€
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const surface = Colors.white;
  static const tint = Color(0xFFE6F0FC);
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);

  // Alias supaya kode lama tetap jalan
  static const teal = blue;
  static const gold = orange;
}

class DaftarPendaftarScreen extends StatefulWidget {
  const DaftarPendaftarScreen({super.key});

  @override
  State<DaftarPendaftarScreen> createState() => _DaftarPendaftarScreenState();
}

class _DaftarPendaftarScreenState extends State<DaftarPendaftarScreen> {
  final _repository = BusinessRepository();
  final _state = RequestState<List<Pendaftar>>();

  @override
  void initState() {
    super.initState();
    _state.addListener(_changed);
    AuthSession.instance.sessionChanges.addListener(_sessionChanged);
    _muatData();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    _state.reset();
    if (AuthSession.instance.authenticated.value &&
        AuthSession.instance.deviceSessionReady) _muatData();
  }

  @override
  void dispose() {
    AuthSession.instance.sessionChanges.removeListener(_sessionChanged);
    _state.removeListener(_changed);
    _state.dispose();
    super.dispose();
  }

  Future<void> _muatData() => _state.load(() async {
        final items = <String, Pendaftar>{};
        var page = 1;
        while (true) {
          final result =
              await _repository.adminBookings(query: {'page': '$page'});
          for (final booking in result.items) {
            final json = booking.json;
            items[booking.guid] = Pendaftar(
              id: booking.guid,
              userId: '',
              namaPengunjung: booking.visitorName,
              noTelepon: json['visitor_phone'] as String,
              email: json['visitor_email'] as String,
              wisata: booking.destinationName,
              tanggal: json['visit_date'] as String,
              jumlahOrang: json['quantity'] as int,
              nomorBukti: json['booking_number'] as String,
              catatan: json['notes'] as String? ?? '',
              status: booking.status,
            );
          }
          final last = result.meta?['last_page'];
          if (last is! int)
            throw const ApiException('Respons halaman tidak valid.');
          if (page >= last) break;
          page++;
        }
        return items.values.toList();
      });

  @override
  Widget build(BuildContext context) {
    final list = _state.data ?? <Pendaftar>[];
    if (_state.loading && _state.data == null) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.teal)),
      );
    }
    if (_state.error != null) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_state.error.toString(), textAlign: TextAlign.center),
          TextButton(onPressed: _muatData, child: const Text('Coba lagi')),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
        color: _C.teal,
        backgroundColor: _C.surface,
        onRefresh: _muatData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // â”€â”€ SliverAppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverAppBar(
              expandedHeight: 210,
              floating: false,
              pinned: true,
              snap: false,
              backgroundColor: const Color(0xFF1558B0),
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.people_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text('${list.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A93F0),
                        Color(0xFF1976D2),
                        Color(0xFF1558B0)
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Teks header
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 46,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _C.gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'DATA PENGUNJUNG',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Data Pendaftar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              list.isEmpty
                                  ? 'Belum ada pendaftaran'
                                  : '${list.length} pendaftar terdaftar',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tepi bawah melengkung menyatu dengan konten
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: _C.bg,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(26)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // â”€â”€ Ringkasan status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (list.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _RingkasanRow(list: list),
                ),
              ),

            // â”€â”€ Konten â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (list.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.teal.withValues(alpha: 0.08),
                          border: Border.all(
                              color: _C.teal.withValues(alpha: 0.15),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.people_outline_rounded,
                            size: 46, color: _C.teal),
                      ),
                      const SizedBox(height: 24),
                      const Text('Belum Ada Pendaftar',
                          style: TextStyle(
                              color: _C.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                          'Pendaftaran kunjungan wisata\nakan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _C.textMuted, fontSize: 13, height: 1.6)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PendaftarCard(
                        key: ValueKey(list[i].id),
                        pendaftar: list[i],
                        onRefresh: _muatData),
                    childCount: list.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Card Pendaftar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PendaftarCard extends StatefulWidget {
  final Pendaftar pendaftar;
  final Future<void> Function() onRefresh;
  const _PendaftarCard(
      {super.key, required this.pendaftar, required this.onRefresh});

  @override
  State<_PendaftarCard> createState() => _PendaftarCardState();
}

class _PendaftarCardState extends State<_PendaftarCard> {
  bool _isUpdating = false;

  static _statusCfg(String status) {
    switch (status) {
      case 'confirmed':
        return (
          color: const Color(0xFF10B981),
          bg: const Color(0x1A10B981),
          border: const Color(0x4010B981),
          label: 'Disetujui',
          icon: Icons.check_circle_rounded,
        );
      case 'rejected':
        return (
          color: const Color(0xFFEF4444),
          bg: const Color(0x1AEF4444),
          border: const Color(0x40EF4444),
          label: 'Ditolak',
          icon: Icons.cancel_rounded,
        );
      default: // 'menunggu'
        return (
          color: const Color(0xFFF59E0B),
          bg: const Color(0x1AF59E0B),
          border: const Color(0x40F59E0B),
          label: status == 'pending_approval' ? 'Menunggu' : status,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final guid = widget.pendaftar.id;
    if (guid == null ||
        _isUpdating ||
        widget.pendaftar.status != 'pending_approval') return;
    final generation = AuthSession.instance.sessionGeneration;
    setState(() => _isUpdating = true);
    try {
      await BusinessRepository()
          .decideBooking(guid, approve: newStatus == 'disetujui');
      if (generation == AuthSession.instance.sessionGeneration) {
        await widget.onRefresh();
      }
    } catch (error) {
      if (mounted && generation == AuthSession.instance.sessionGeneration) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        await widget.onRefresh();
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _konfirmasiAksi(String aksi) {
    final generation = AuthSession.instance.sessionGeneration;
    final isSetujui = aksi == 'disetujui';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            isSetujui ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color:
                isSetujui ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isSetujui ? 'Setujui Pendaftaran' : 'Tolak Pendaftaran',
            style: const TextStyle(
                color: _C.text, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ]),
        content: RichText(
          text: TextSpan(
            style:
                const TextStyle(color: _C.textMuted, fontSize: 13, height: 1.5),
            children: [
              TextSpan(
                  text: isSetujui
                      ? 'Pendaftaran atas nama '
                      : 'Tolak pendaftaran atas nama '),
              TextSpan(
                text: widget.pendaftar.namaPengunjung,
                style: const TextStyle(
                    color: _C.text, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                  text: isSetujui
                      ? ' akan disetujui. Lanjutkan?'
                      : ' akan ditolak. Lanjutkan?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: TextStyle(color: _C.textMuted, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSetujui ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (generation == AuthSession.instance.sessionGeneration) {
                _updateStatus(aksi);
              }
            },
            child: Text(isSetujui ? 'Setujui' : 'Tolak',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pendaftar;
    final cfg = _statusCfg(p.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Header kartu â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.teal.withValues(alpha: 0.06),
                border: Border(bottom: BorderSide(color: _C.border)),
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
                        p.namaPengunjung.isNotEmpty
                            ? p.namaPengunjung[0].toUpperCase()
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
                        Text(p.namaPengunjung,
                            style: const TextStyle(
                                color: _C.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.phone_rounded,
                              size: 11, color: _C.textDim),
                          const SizedBox(width: 4),
                          Text(p.noTelepon,
                              style: const TextStyle(
                                  color: _C.textMuted, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                  // â”€â”€ Badge status dinamis â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

            // â”€â”€ Detail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.landscape_rounded,
                    label: 'Destinasi',
                    value: p.wisata,
                    valueColor: _C.teal,
                    bold: true,
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Tanggal',
                    value: p.tanggal,
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    icon: Icons.group_rounded,
                    label: 'Pengunjung',
                    value: '${p.jumlahOrang} Orang',
                  ),
                  if (p.catatan.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _infoRow(
                      icon: Icons.notes_rounded,
                      label: 'Catatan',
                      value: p.catatan,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Container(height: 1, color: _C.border),
                  ),
                  // Nomor Bukti
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _C.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _C.gold.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.confirmation_number_rounded,
                            size: 14, color: _C.gold),
                      ),
                      const SizedBox(width: 10),
                      const Text('Nomor Bukti',
                          style: TextStyle(color: _C.textMuted, fontSize: 12)),
                      const Spacer(),
                      Text(p.nomorBukti,
                          style: const TextStyle(
                              color: _C.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ],
                  ),

                  // â”€â”€ Tombol Approve / Reject (hanya saat menunggu) â”€â”€
                  if (p.status == 'pending_approval') ...[
                    const SizedBox(height: 14),
                    _isUpdating
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: _C.teal, strokeWidth: 2.5),
                            ),
                          )
                        : Row(children: [
                            // Tolak
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _konfirmasiAksi('ditolak'),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.close_rounded,
                                          color: Color(0xFFEF4444), size: 16),
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
                            // Setujui
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _konfirmasiAksi('disetujui'),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.border),
          ),
          child: Icon(icon, size: 13, color: _C.textMuted),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(color: _C.textDim, fontSize: 12)),
        ),
        const Text('  Â·  ', style: TextStyle(color: _C.border, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? _C.text,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Ringkasan jumlah per status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _RingkasanRow extends StatelessWidget {
  final List<Pendaftar> list;
  const _RingkasanRow({required this.list});

  @override
  Widget build(BuildContext context) {
    final setuju = list.where((p) => const {'confirmed', 'awaiting_payment', 'payment_verification', 'payment_review'}.contains(p.status)).length;
    final tolak = list.where((p) => p.status == 'rejected').length;
    final tunggu = list.where((p) => p.status == 'pending_approval').length;

    final items = <(String, int, Color, IconData)>[
      ('Total', list.length, _C.blue, Icons.groups_rounded),
      (
        'Menunggu',
        tunggu,
        const Color(0xFFF59E0B),
        Icons.hourglass_top_rounded
      ),
      (
        'Disetujui',
        setuju,
        const Color(0xFF10B981),
        Icons.check_circle_rounded
      ),
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
                color: _C.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                    color: _C.blue.withValues(alpha: 0.06),
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
                      color: _C.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$1,
                    style: const TextStyle(
                      color: _C.textMuted,
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
