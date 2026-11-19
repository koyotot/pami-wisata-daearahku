// ============================================================
// Superadmin: booking aktif yang masih memakai zona waktu lama
// setelah zona waktu destinasinya diubah. Hanya baca; batas waktu
// yang sudah dikirim ke penyedia pembayaran tidak bisa diubah.
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../theme/app_colors.dart';
import '../../data/admin_state.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../admin/admin_common.dart';

class TimezoneDriftScreen extends StatefulWidget {
  final BusinessRepository? repository;
  final AuthSession? session;
  const TimezoneDriftScreen({super.key, this.repository, this.session});

  @override
  State<TimezoneDriftScreen> createState() => _TimezoneDriftScreenState();
}

class _TimezoneDriftScreenState extends State<TimezoneDriftScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  List<TimezoneDriftBooking>? _items;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_session.role == 2) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    final generation = _session.sessionGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.timezoneDriftBookings();
      if (!mounted || !_session.isCurrentGeneration(generation)) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted || !_session.isCurrentGeneration(generation)) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final allowed = _session.role == 2;
    return AdminPage(
      title: 'Zona Waktu Booking',
      subtitle: allowed
          ? '${items?.length ?? 0} booking aktif memakai zona lama'
          : 'Khusus Super Administrator',
      onRefresh: allowed ? _load : null,
      slivers: [
        if (!allowed)
          adminEmptySliver(PhosphorIconsRegular.lock, 'Akses ditolak',
              'Daftar ini hanya untuk Super Administrator.')
        else if (items == null && _error == null)
          adminLoadingSliver()
        else if (_error != null && items == null)
          adminErrorSliver(adminErrorMessage(_error!), _load)
        else if (items!.isEmpty)
          adminEmptySliver(PhosphorIconsRegular.clock, 'Tidak ada selisih',
              'Semua booking aktif memakai zona waktu destinasinya saat ini.')
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _DriftCard(item: items[i]),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _DriftCard extends StatelessWidget {
  final TimezoneDriftBooking item;
  const _DriftCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: adminCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.destinationName,
                style: const TextStyle(
                    color: AdminColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Text('${item.bookingNumber} · kunjungan ${item.visitDate}',
                style: const TextStyle(
                    color: AdminColors.textMuted, fontSize: 12)),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Booking memakai ${timezoneLabel(item.bookingTimezone)}; '
                'destinasi kini ${timezoneLabel(item.destinationTimezone)}.',
                style: const TextStyle(color: AdminColors.text, fontSize: 13)),
          ],
        ),
      );
}
