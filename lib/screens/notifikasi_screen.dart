import 'package:flutter/material.dart';
import '../data/notification_state.dart';
import '../theme/app_colors.dart';
import 'bukti_pendaftaran_screen.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key, required this.state});
  final NotificationState state;
  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  bool _unreadOnly = false;
  bool _opening = false;

  Future<void> _open(InboxItem item) async {
    if (_opening) return;
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
          builder: (_) => BookingTicketScreen(bookingGuid: guid),
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
            bottom: false,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Notifikasi',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy))),
                    IconButton(
                        tooltip: 'Muat ulang aktivitas',
                        onPressed: widget.state.refresh,
                        icon: const Icon(Icons.refresh_rounded)),
                  ])),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Kabar terbaru tentang kunjungan Anda.',
                      style: TextStyle(color: AppColors.textMuted))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Wrap(spacing: 8, children: [
                    ChoiceChip(
                        label: const Text('Semua'),
                        selected: !_unreadOnly,
                        onSelected: (_) => setState(() => _unreadOnly = false)),
                    ChoiceChip(
                        label: const Text('Belum dibaca'),
                        selected: _unreadOnly,
                        onSelected: (_) => setState(() => _unreadOnly = true)),
                  ])),
              Expanded(
                  child: ListenableBuilder(
                      listenable: widget.state.inbox,
                      builder: (context, _) {
                        final state = widget.state.inbox;
                        if (state.loading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (state.error != null) {
                          return Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                            'Aktivitas belum dapat dimuat.',
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 12),
                                        TextButton(
                                            onPressed: widget.state.refresh,
                                            child: const Text('Coba lagi')),
                                      ])));
                        }
                        final items = (state.data ?? [])
                            .where((item) => !_unreadOnly || item.unread)
                            .toList();
                        if (items.isEmpty) {
                          return Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.notifications_none_rounded,
                                            size: 48,
                                            color: AppColors.textMuted),
                                        const SizedBox(height: 16),
                                        Text(
                                            _unreadOnly
                                                ? 'Semua aktivitas sudah dibaca.'
                                                : 'Belum ada aktivitas.',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        const Text(
                                            'Pembaruan pendaftaran akan muncul di sini.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: AppColors.textMuted)),
                                      ])));
                        }
                        return RefreshIndicator(
                            onRefresh: widget.state.refresh,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final date = item.createdAt?.toLocal();
                                return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                      enabled: !_opening,
                                      onTap: () => _open(item),
                                      leading: Icon(
                                          item.unread
                                              ? Icons
                                                  .notifications_active_outlined
                                              : Icons
                                                  .notifications_none_rounded,
                                          color: item.unread
                                              ? AppColors.blue
                                              : AppColors.textMuted),
                                      title: Text(item.title,
                                          style: TextStyle(
                                              fontWeight: item.unread
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: AppColors.navy)),
                                      subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 6),
                                            Text(item.body),
                                            if (date != null)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8),
                                                  child: Text(
                                                      '${date.day}/${date.month}/${date.year}',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors
                                                              .textMuted))),
                                            if (item.unread)
                                              const Text('Belum dibaca',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.blue)),
                                          ]),
                                      trailing: item.bookingGuid == null
                                          ? null
                                          : const Icon(
                                              Icons.chevron_right_rounded),
                                    ));
                              },
                            ));
                      })),
            ])),
      );
}
