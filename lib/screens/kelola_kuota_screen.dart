// ============================================================
// lib/screens/kelola_kuota_screen.dart
// Kuota harian per destinasi (role >= 1). Kapasitas (total),
// teralokasi dan sisa adalah tiga nilai berbeda dari server.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/admin_state.dart';
import '../data/business_repository.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'admin_common.dart';

class KelolaKuotaScreen extends StatefulWidget {
  final String destinationGuid;
  final String destinationName;
  final String? timezone;
  final BusinessRepository? repository;
  final AuthSession? session;
  const KelolaKuotaScreen({
    super.key,
    required this.destinationGuid,
    required this.destinationName,
    this.timezone,
    this.repository,
    this.session,
  });

  @override
  State<KelolaKuotaScreen> createState() => _KelolaKuotaScreenState();
}

class _KelolaKuotaScreenState extends State<KelolaKuotaScreen> {
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<QuotaEntry> _list;

  @override
  void initState() {
    super.initState();
    _list = PagedListController<QuotaEntry>(
      session: _session,
      keyOf: (entry) => entry.visitDate,
      fetchPage: (page, _) =>
          _repository.quotaEntries(widget.destinationGuid, page: page),
    )..addListener(_changed);
    _session.sessionChanges.addListener(_sessionChanged);
    if (canManageQuota(_session.role)) _muat();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (_session.authenticated.value &&
        _session.deviceSessionReady &&
        canManageQuota(_session.role)) {
      _muat();
    }
  }

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_sessionChanged);
    _list
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _muat() => _list.load();

  List<QuotaEntry> get _sorted {
    final items = [..._list.items];
    items.sort((a, b) => a.visitDate.compareTo(b.visitDate));
    return items;
  }

  Future<void> _form([QuotaEntry? entry]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _QuotaFormDialog(
        entry: entry,
        timezone: widget.timezone,
        onSubmit: (payload) async {
          try {
            await _repository.saveQuota(widget.destinationGuid, payload);
            return null;
          } catch (e) {
            return adminErrorMessage(e);
          }
        },
      ),
    );
    if (saved == true && mounted) {
      showAdminSnack(context, 'Kuota disimpan');
      await _muat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _sorted;
    final allowed = canManageQuota(_session.role);
    return AdminPage(
      badge: 'KUOTA KUNJUNGAN',
      title: 'Kelola Kuota',
      subtitle: widget.destinationName,
      onRefresh: allowed ? _muat : null,
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              key: const ValueKey('add-quota'),
              backgroundColor: AdminColors.blue,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Tambah Tanggal',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => _form(),
            )
          : null,
      slivers: [
        if (!allowed)
          adminEmptySliver(Icons.lock_outline_rounded, 'Akses ditolak',
              'Kuota hanya dapat dikelola oleh admin.')
        else if (!_list.hasLoaded && _list.error == null)
          adminLoadingSliver()
        else if (_list.error != null && items.isEmpty)
          adminErrorSliver(adminErrorMessage(_list.error!), _muat)
        else if (items.isEmpty)
          adminEmptySliver(Icons.event_busy_rounded, 'Belum ada kuota',
              'Tambahkan tanggal kunjungan beserta kapasitasnya.')
        else ...[
          if (_list.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: AdminNotice(
                    'Gagal memuat ulang: ${adminErrorMessage(_list.error!)}'),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _QuotaCard(
                  key: ValueKey(items[i].visitDate),
                  entry: items[i],
                  onEdit: () => _form(items[i]),
                ),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  final QuotaEntry entry;
  final VoidCallback onEdit;
  const _QuotaCard({super.key, required this.entry, required this.onEdit});

  Widget _metric(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text('$value',
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final opens = entry.opensAt;
    final closes = entry.closesAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: adminCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_rounded,
                  color: AdminColors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.visitDate,
                    style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
              IconButton(
                key: ValueKey('edit-${entry.visitDate}'),
                tooltip: 'Ubah kuota',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded,
                    color: Color(0xFFA78BFA), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            _metric('Kapasitas', entry.capacity, AdminColors.blue),
            const SizedBox(width: 8),
            _metric('Teralokasi', entry.allocated, AdminColors.orange),
            const SizedBox(width: 8),
            _metric('Sisa', entry.remaining, AdminColors.success),
          ]),
          const SizedBox(height: 10),
          Text(
            'Booking dibuka: ${opens == null ? '-' : formatDateTime(opens)}',
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Booking ditutup: ${closes == null ? '-' : formatDateTime(closes)}',
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Create / update one date. [onSubmit] returns an error message, null on success.
class _QuotaFormDialog extends StatefulWidget {
  final QuotaEntry? entry;
  final String? timezone;
  final Future<String?> Function(Json payload) onSubmit;
  const _QuotaFormDialog(
      {this.entry, this.timezone, required this.onSubmit});

  @override
  State<_QuotaFormDialog> createState() => _QuotaFormDialogState();
}

class _QuotaFormDialogState extends State<_QuotaFormDialog> {
  late final _capacity =
      TextEditingController(text: widget.entry == null ? '' : '${widget.entry!.capacity}');
  DateTime? _visitDate;
  DateTime? _opens;
  DateTime? _closes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      final parsed = DateTime.tryParse(entry.visitDate);
      _visitDate = parsed == null
          ? null
          : DateTime(parsed.year, parsed.month, parsed.day);
      _opens = entry.opensAt?.toLocal();
      _closes = entry.closesAt?.toLocal();
    }
  }

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickVisitDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date != null && mounted) setState(() => _visitDate = date);
  }

  Future<void> _submit() async {
    if (_saving) return;
    final capacity = int.tryParse(_capacity.text.trim());
    final problem = validateQuotaInput(
        visitDate: _visitDate,
        capacity: capacity,
        opensAt: _opens,
        closesAt: _closes);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(buildQuotaPayload(
        visitDate: _visitDate!,
        capacity: capacity!,
        opensAt: _opens!,
        closesAt: _closes!));
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  Widget _pickerTile(String label, String value, VoidCallback? onTap,
      {Key? key}) {
    return InkWell(
      key: key,
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: adminInputDecoration(label),
        child: Text(value,
            style: const TextStyle(color: AdminColors.text, fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    return AlertDialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(editing ? 'Ubah Kuota' : 'Tambah Kuota',
          style: const TextStyle(
              color: AdminColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pickerTile(
              'Tanggal kunjungan',
              _visitDate == null ? 'Pilih tanggal' : formatDate(_visitDate!),
              editing ? null : _pickVisitDate,
              key: const ValueKey('quota-visit-date'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('quota-capacity'),
              controller: _capacity,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: adminInputDecoration('Kapasitas (total)'),
            ),
            const SizedBox(height: 12),
            _pickerTile(
              'Booking dibuka',
              _opens == null ? 'Pilih tanggal & jam' : formatDateTime(_opens!),
              () async {
                final value = await _pickDateTime(_opens);
                if (value != null && mounted) setState(() => _opens = value);
              },
              key: const ValueKey('quota-opens'),
            ),
            const SizedBox(height: 12),
            _pickerTile(
              'Booking ditutup',
              _closes == null
                  ? 'Pilih tanggal & jam'
                  : formatDateTime(_closes!),
              () async {
                final value = await _pickDateTime(_closes);
                if (value != null && mounted) setState(() => _closes = value);
              },
              key: const ValueKey('quota-closes'),
            ),
            const SizedBox(height: 10),
            Text(
              'Waktu mengikuti zona waktu perangkat dan dikirim sebagai UTC. '
              'Jendela booking harus ditutup sebelum hari kunjungan dimulai'
              '${widget.timezone == null ? '' : ' (zona ${widget.timezone})'}.',
              style: const TextStyle(
                  color: AdminColors.textMuted, fontSize: 11.5, height: 1.4),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AdminNotice(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13)),
        ),
        ElevatedButton(
          key: const ValueKey('quota-save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Simpan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }
}
