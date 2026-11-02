import 'package:flutter/material.dart';
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
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 8, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Notifikasi',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge(
                          [widget.state.inbox, widget.state.count]),
                      builder: (context, _) {
                        final loading = widget.state.inbox.loading ||
                            widget.state.count.loading;
                        return IconButton(
                          tooltip: 'Muat ulang aktivitas',
                          onPressed: loading ? null : _refresh,
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.refresh_rounded),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor:
                                  Colors.white.withValues(alpha: .18)),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Kabar terbaru tentang kunjungan Anda.',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: widget.state.count,
                    builder: (context, _) {
                      final count = widget.state.count.data;
                      if (count == null || count == 0) {
                        return const SizedBox(height: 30);
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: .4)),
                        ),
                        child: Text('$count belum dibaca',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('Semua'),
              selected: !_unreadOnly,
              onSelected: (_) => setState(() => _unreadOnly = false)),
          ChoiceChip(
              label: const Text('Belum dibaca'),
              selected: _unreadOnly,
              onSelected: (_) => setState(() => _unreadOnly = true)),
        ]),
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
          icon: Icons.cloud_off_outlined,
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
          icon: Icons.notifications_none_rounded,
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
              ? Icons.notifications_none_rounded
              : Icons.done_all_rounded,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.unread ? AppColors.blue : AppColors.border,
                    width: item.unread ? 1.3 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 12),
                      child: Icon(
                        item.bookingGuid == null
                            ? Icons.notifications_none_rounded
                            : Icons.confirmation_number_outlined,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: TextStyle(
                                  fontWeight: item.unread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: AppColors.navy)),
                          const SizedBox(height: 5),
                          Text(item.body),
                          if (date != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                            ),
                          const SizedBox(height: 4),
                          Text(item.unread ? 'Belum dibaca' : 'Sudah dibaca',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (item.bookingGuid != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
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
