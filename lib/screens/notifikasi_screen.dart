import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import '../data/notification_state.dart';
import '../data/business_repository.dart';
import '../theme/app_colors.dart';
import 'auth_presentation.dart';
import 'bukti_pendaftaran_screen.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({
    super.key,
    required this.state,
    this.active = true,
  });
  final NotificationState state;
  final bool active;

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  bool _unreadOnly = false;
  bool _opening = false;

  Future<void> _refresh() async {
    if (widget.state.inbox.loading || widget.state.count.loading) return;
    await widget.state.refresh();
  }

  Future<void> _open(InboxItem item) async {
    if (_opening || widget.state.inbox.loading || widget.state.count.loading)
      return;
    setState(() => _opening = true);
    final session = widget.state.api.session;
    final generation = session.sessionGeneration;
    try {
      await widget.state.markRead(item);
      if (!mounted ||
          !session.isCurrentGeneration(generation) ||
          session.role != 0) {
        return;
      }
      final guid = item.bookingGuid;
      if (guid != null && guid.isNotEmpty) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BookingTicketScreen(
              bookingGuid: guid,
              repository: BusinessRepository(widget.state.api)),
        ));
        if (mounted && session.isCurrentGeneration(generation))
          await _refresh();
      }
    } catch (_) {
      if (mounted && session.isCurrentGeneration(generation)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aktivitas belum dapat dibuka. Silakan coba lagi.')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildHero(context)),
                SliverToBoxAdapter(child: _buildFilters()),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text('Aktivitas terbaru',
                        style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                ListenableBuilder(
                  listenable: Listenable.merge(
                      [widget.state.inbox, widget.state.count]),
                  builder: (context, _) => _buildActivitySliver(context),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildHero(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 184 + topInset),
      child: Stack(
        children: [
          Positioned.fill(
            child: TimeBasedScenicBackground(
              active: widget.active,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 8, 12, 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 94),
                const Text('Notifikasi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('Kabar terbaru tentang kunjungan Anda.',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final unread in [false, true])
              ChoiceChip(
                label: unread
                    ? ListenableBuilder(
                        listenable: widget.state.count,
                        builder: (context, _) {
                          final count = widget.state.count.data;
                          return Text(count == null || count == 0
                              ? 'Belum dibaca'
                              : '$count Belum dibaca');
                        },
                      )
                    : const Text('Semua'),
                selected: _unreadOnly == unread,
                onSelected: (_) => setState(() => _unreadOnly = unread),
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: AppColors.blue,
                surfaceTintColor: Colors.transparent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      _unreadOnly == unread ? FontWeight.w700 : FontWeight.w500,
                  color: _unreadOnly == unread ? Colors.white : AppColors.navy,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: BorderSide(
                  color: _unreadOnly == unread
                      ? AppColors.blue
                      : const Color(0xFFD3E0F5),
                ),
                elevation: _unreadOnly == unread ? 3 : 0,
                shadowColor: AppColors.blue.withValues(alpha: .18),
              ),
          ],
        ),
      );

  Widget _buildActivitySliver(BuildContext context) {
    final state = widget.state.inbox;
    if (state.loading && state.data == null) {
      return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null && state.data == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyMessage(
          icon: PhosphorIconsRegular.cloudSlash,
          title: 'Aktivitas belum dapat dimuat.',
          detail: 'Periksa koneksi lalu coba lagi.',
          action:
              TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
        ),
      );
    }
    if (state.data == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyMessage(
          icon: PhosphorIconsRegular.bell,
          title: 'Aktivitas belum dimuat.',
          detail: 'Muat ulang untuk melihat pembaruan pendaftaran.',
          action:
              TextButton(onPressed: _refresh, child: const Text('Muat ulang')),
        ),
      );
    }

    final allItems = state.data!;
    final items =
        allItems.where((item) => !_unreadOnly || item.unread).toList();
    if (items.isEmpty) {
      final noneExist = allItems.isEmpty;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyMessage(
          icon: noneExist
              ? PhosphorIconsRegular.bell
              : PhosphorIconsRegular.checks,
          title: noneExist
              ? 'Belum ada aktivitas.'
              : 'Semua aktivitas sudah dibaca.',
          detail: 'Pembaruan pendaftaran akan muncul di sini.',
          action: null,
        ),
      );
    }

    final showRefreshError = state.error != null;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      sliver: SliverList.separated(
        itemCount: items.length + (showRefreshError ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (showRefreshError && index == 0) {
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                dense: true,
                title: const Text('Aktivitas belum berhasil diperbarui.'),
                trailing: TextButton(
                    onPressed: _refresh, child: const Text('Coba lagi')),
              ),
            );
          }
          final item = items[index - (showRefreshError ? 1 : 0)];
          final date = item.createdAt?.toLocal();
          final (icon, tint, iconBackground) = switch (item.json['type']) {
            'booking.demo_paid' => (
                PhosphorIconsRegular.wallet,
                AppColors.blueDeep,
                const Color(0xFFECF4FF)
              ),
            'booking.rejected' => (
                PhosphorIconsRegular.x,
                const Color(0xFFFF5252),
                const Color(0xFFFFECEC)
              ),
            'booking.approved' => (
                PhosphorIconsRegular.check,
                const Color(0xFF16A36D),
                const Color(0xFFE9F8F0)
              ),
            'booking.expired' => (
                PhosphorIconsRegular.clock,
                const Color(0xFFF58A00),
                const Color(0xFFFFF4E2)
              ),
            'booking.payment_review' => (
                PhosphorIconsRegular.bell,
                const Color(0xFFF58A00),
                const Color(0xFFFFF4E2)
              ),
            _ => (
                PhosphorIconsRegular.bell,
                AppColors.blue,
                const Color(0xFFECF4FF)
              ),
          };
          String twoDigits(int value) => value.toString().padLeft(2, '0');
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _opening ||
                      widget.state.inbox.loading ||
                      widget.state.count.loading
                  ? null
                  : () => _open(item),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.unread
                        ? const Color(0xFFBED7FF)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: tint, size: 21),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy)),
                          const SizedBox(height: 5),
                          Text(item.body,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: AppColors.textMuted)),
                          if (date != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                  '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} \u2022 ${twoDigits(date.hour)}:${twoDigits(date.minute)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted)),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(children: [
                        Semantics(
                          label: item.unread ? 'Belum dibaca' : 'Sudah dibaca',
                          child: SizedBox.square(
                            dimension: 8,
                            child: item.unread
                                ? const DecoratedBox(
                                    decoration: BoxDecoration(
                                        color: AppColors.blue,
                                        shape: BoxShape.circle))
                                : null,
                          ),
                        ),
                        if (item.bookingGuid != null) ...[
                          const SizedBox(height: 5),
                          const Icon(PhosphorIconsRegular.caretRight,
                              color: Color(0xFF9AAEC9), size: 18),
                        ],
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyMessage({
    required IconData icon,
    required String title,
    required String detail,
    required Widget? action,
  }) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      );
}
