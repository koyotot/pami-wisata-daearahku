import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/notification_state.dart';
import '../../data/business_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/scroll_aware_status_bar.dart';
import '../../widgets/visit_format.dart' show visitMonths;
import '../admin/admin_common.dart' show showAdminSnack;
import '../auth/auth_presentation.dart';
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
  String _filter = 'all';
  final _search = TextEditingController();
  String _query = '';
  bool _opening = false;
  bool _markingAll = false;

  /// General notices without a booking route can expand in place.
  final _expanded = <String>{};

  static const _importantTypes = {
    'booking.approved_awaiting_payment',
    'booking.payment_cycle_expired',
    'booking.payment_review',
    'booking.expired',
    'booking.rejected',
    'booking.ticket_issued',
    'booking.refund_approved',
    'booking.refund_rejected',
    'booking.refunded',
  };

  bool get _busy =>
      _opening ||
      _markingAll ||
      widget.state.inbox.loading ||
      widget.state.count.loading;

  List<InboxItem> get _visibleItems =>
      (widget.state.inbox.data ?? const <InboxItem>[]).where((item) {
        final matchesFilter = switch (_filter) {
          'unread' => item.unread,
          'important' => _importantTypes.contains(item.json['type']),
          _ => true,
        };
        return matchesFilter &&
            (_query.isEmpty ||
                item.title.toLowerCase().contains(_query) ||
                item.body.toLowerCase().contains(_query) ||
                (item.bookingGuid?.toLowerCase().contains(_query) ?? false));
      }).toList();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_markingAll || widget.state.inbox.loading || widget.state.count.loading)
      return;
    await widget.state.refresh();
  }

  Future<void> _open(InboxItem item) async {
    if (_busy) return;
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
      } else {
        setState(() {
          if (!_expanded.remove(item.guid)) _expanded.add(item.guid);
        });
      }
    } catch (_) {
      if (mounted && session.isCurrentGeneration(generation)) {
        showAdminSnack(
            context, 'Aktivitas belum dapat dibuka. Silakan coba lagi.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_busy) return;
    final session = widget.state.api.session;
    final generation = session.sessionGeneration;
    setState(() => _markingAll = true);
    try {
      await widget.state.markAllRead();
    } catch (_) {
      if (mounted && session.isCurrentGeneration(generation)) {
        showAdminSnack(
            context, 'Sebagian notifikasi belum dapat ditandai. Coba lagi.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  // Light icons over the scenic hero; once it scrolls away the icons turn
  // dark over a page-coloured strip so cards never run under them.
  Widget build(BuildContext context) => ScrollAwareStatusBar(
        scrimColor: AppColors.bg,
        builder: (context, heroKey) => Scaffold(
          backgroundColor: AppColors.bg,
          body: ListenableBuilder(
            listenable:
                Listenable.merge([widget.state.inbox, widget.state.count]),
            builder: (context, _) => RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                      child: KeyedSubtree(
                          key: heroKey, child: _buildHero(context))),
                  SliverToBoxAdapter(child: _buildSummary()),
                  SliverToBoxAdapter(child: _buildFilters()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                          AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                      child: Row(children: [
                        Expanded(
                            child: Text('Aktivitas terbaru',
                                style: _jakarta(const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)))),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                            widget.state.inbox.data == null
                                ? 'Belum dimuat'
                                : '${_visibleItems.length} notifikasi',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                  _buildActivitySliver(context),
                ],
              ),
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
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.md, 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 94),
                Text('Notifikasi',
                    style: _jakarta(const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800))),
                const SizedBox(height: AppSpacing.xs),
                Text('Kabar terbaru tentang kunjungan Anda.',
                    style: _jakarta(const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final unread = widget.state.count.data;
    final total = widget.state.inbox.data?.length;
    final canMark = !_busy &&
        (unread ?? 0) > 0 &&
        (widget.state.inbox.data?.any((item) => item.unread) ?? false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ringkasan notifikasi',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.xs),
            Text.rich(TextSpan(
              text: unread == null ? 'Belum tersedia' : '$unread belum dibaca',
              style: _jakarta(const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blueDeep)),
              children: [
                TextSpan(
                  text: total == null
                      ? ' / total belum tersedia'
                      : ' / $total total',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary),
                )
              ],
            )),
          ]),
          TextButton.icon(
            key: const ValueKey('notifications-mark-all-read'),
            onPressed: canMark ? _markAllRead : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.blueDeep,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              textStyle: _jakarta(
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            icon: _markingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(PhosphorIconsRegular.checks, size: 18),
            label: Text(_markingAll ? 'Menandai…' : 'Tandai semua dibaca'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final (value, label) in const [
              ('all', 'Semua'),
              ('unread', 'Belum dibaca'),
              ('important', 'Penting')
            ])
              Semantics(
                selected: _filter == value,
                child: OutlinedButton(
                  key: ValueKey('notification-filter-$value'),
                  onPressed: () => setState(() => _filter = value),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor:
                        _filter == value ? AppColors.blue : AppColors.surface,
                    foregroundColor: _filter == value
                        ? AppColors.surface
                        : AppColors.textSecondary,
                    side: BorderSide(
                        color: _filter == value
                            ? AppColors.blue
                            : AppColors.border),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    textStyle: _jakarta(const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.md)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label),
                    if (value == 'unread' &&
                        widget.state.count.data != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.blueTint,
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                        ),
                        child: Text('${widget.state.count.data}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blueDeep)),
                      ),
                    ],
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const ValueKey('notification-search'),
            controller: _search,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            style: const TextStyle(fontSize: 13, color: AppColors.navy),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari notifikasi atau kode booking',
              hintStyle:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              constraints:
                  const BoxConstraints(minHeight: kMinInteractiveDimension),
              contentPadding: const EdgeInsets.all(AppSpacing.lg),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 20, color: AppColors.textSecondary),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () => setState(() {
                        _query = '';
                        _search.clear();
                      }),
                      icon: const Icon(PhosphorIconsRegular.x, size: 20),
                    ),
            ),
          ),
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
    final items = _visibleItems;
    if (items.isEmpty) {
      final noneExist = allItems.isEmpty;
      final noMatch = _query.isNotEmpty || _filter == 'important';
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyMessage(
          icon: noneExist
              ? PhosphorIconsRegular.bell
              : PhosphorIconsRegular.magnifyingGlass,
          title: noneExist
              ? 'Belum ada aktivitas.'
              : noMatch
                  ? 'Tidak ada notifikasi yang sesuai.'
                  : 'Semua aktivitas sudah dibaca.',
          detail: noneExist
              ? 'Pembaruan pendaftaran akan muncul di sini.'
              : 'Coba kata kunci atau filter yang lain.',
          action: null,
        ),
      );
    }

    final showRefreshError = state.error != null;
    return SliverSafeArea(
      top: false,
      left: false,
      right: false,
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        sliver: SliverList.separated(
          itemCount: items.length + (showRefreshError ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (showRefreshError && index == 0) {
              return Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  title: const Text('Aktivitas belum berhasil diperbarui.',
                      style: TextStyle(fontSize: 12)),
                  trailing: TextButton(
                      onPressed: _busy ? null : _refresh,
                      child: const Text('Coba lagi')),
                ),
              );
            }
            final itemIndex = index - (showRefreshError ? 1 : 0);
            final item = items[itemIndex];
            final date = item.createdAt?.toLocal();
            final firstInDay = itemIndex == 0 ||
                !DateUtils.isSameDay(
                    date, items[itemIndex - 1].createdAt?.toLocal());
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (firstInDay)
                    Padding(
                      padding: EdgeInsets.only(
                          top: itemIndex == 0 ? AppSpacing.xs : AppSpacing.md,
                          bottom: AppSpacing.md),
                      child: Row(children: [
                        Flexible(
                            child: Text(_dateGroup(date),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .8,
                                    color: AppColors.textSecondary))),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                            child: Divider(height: 1, color: AppColors.border)),
                      ]),
                    ),
                  _notificationCard(item),
                ]);
          },
        ),
      ),
    );
  }

  String _dateGroup(DateTime? date) {
    if (date == null) return 'TANGGAL BELUM TERSEDIA';
    final day = '${date.day} ${visitMonths[date.month - 1].toUpperCase()}';
    return DateUtils.isSameDay(date, DateTime.now())
        ? 'HARI INI · $day'
        : '$day ${date.year}';
  }

  String _timestamp(DateTime? date) {
    if (date == null) return 'Waktu belum tersedia';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _notificationCard(InboxItem item) {
    final date = item.createdAt?.toLocal();
    final expanded = _expanded.contains(item.guid);
    final (icon, tint, background) = switch (item.json['type']) {
      'booking.demo_paid' => (
          PhosphorIconsRegular.wallet,
          AppColors.blueDeep,
          AppColors.blueTint
        ),
      'booking.rejected' || 'booking.refund_rejected' => (
          PhosphorIconsRegular.x,
          AppColors.danger,
          AppColors.dangerTint
        ),
      'booking.approved' ||
      'booking.approved_awaiting_payment' ||
      'booking.refund_approved' ||
      'booking.refunded' =>
        (PhosphorIconsRegular.check, AppColors.success, AppColors.successTint),
      'booking.expired' || 'booking.payment_cycle_expired' => (
          PhosphorIconsRegular.clock,
          AppColors.warningText,
          AppColors.warningTint
        ),
      'booking.payment_review' => (
          PhosphorIconsRegular.bell,
          AppColors.warningText,
          AppColors.warningTint
        ),
      _ => (PhosphorIconsRegular.bell, AppColors.blue, AppColors.blueTint),
    };
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: item.unread
                  ? AppColors.blue.withValues(alpha: .3)
                  : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('notification-${item.guid}'),
          onTap: _busy ? null : () => _open(item),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: AppSpacing.xl + AppSpacing.lg,
                height: AppSpacing.xl + AppSpacing.lg,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppSpacing.md)),
                child: Icon(icon, color: tint, size: 20),
              ),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _jakarta(const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)))),
                          const SizedBox(width: AppSpacing.sm),
                          Column(children: [
                            Semantics(
                              label:
                                  item.unread ? 'Belum dibaca' : 'Sudah dibaca',
                              child: SizedBox.square(
                                dimension: AppSpacing.sm,
                                child: item.unread
                                    ? const DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: AppColors.blue,
                                            shape: BoxShape.circle))
                                    : null,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Icon(PhosphorIconsRegular.caretRight,
                                color: AppColors.textMuted, size: 18),
                          ]),
                        ]),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.body,
                        maxLines: expanded ? null : 2,
                        overflow: expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                          child: Text(_timestamp(date),
                              style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.5,
                                  color: AppColors.textSecondary))),
                      const SizedBox(width: AppSpacing.sm),
                      Text(expanded ? 'Ringkas' : 'Lihat detail',
                          style: _jakarta(const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.blueDeep))),
                    ]),
                  ])),
            ]),
          ),
        ),
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12, height: 1.6)),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action
            ],
          ],
        ),
      );
}

TextStyle _jakarta(TextStyle style) =>
    GoogleFonts.plusJakartaSans(textStyle: style);
