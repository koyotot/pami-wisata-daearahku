part of 'operations_dashboard.dart';

class _AdminPersonalSummary extends StatelessWidget {
  const _AdminPersonalSummary({required this.approvalRate});
  final String approvalRate;

  @override
  Widget build(BuildContext context) => _DashboardCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('KINERJA INDIVIDU',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: .8,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: approvalRate,
              style: const TextStyle(
                  fontSize: 36,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const TextSpan(
              text: ' tingkat persetujuan',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ])),
        const SizedBox(height: AppSpacing.xs),
        const Text('Ringkasan keputusan Admin pada periode aktif.',
            style: TextStyle(
                fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
      ]));
}

class _AdminApprovalPerformance extends StatelessWidget {
  const _AdminApprovalPerformance({required this.data, required this.response});
  final OperationalReport data;
  final String response;

  @override
  Widget build(BuildContext context) {
    final approved = _number(data.personal['approved_decisions']);
    final rejected = _number(data.personal['rejected_decisions']);
    final total =
        approved == null || rejected == null ? null : approved + rejected;
    return _DashboardCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            const Text('Performa approval',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                    color: AppColors.successTint,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('SLA 24 jam',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success))),
          ]),
      const SizedBox(height: AppSpacing.md),
      Text(
          total == null
              ? 'Jumlah keputusan belum tersedia pada periode aktif.'
              : '${_value(total)} keputusan selesai pada periode aktif. '
                  'Waktu respons dihitung sejak booking dibuat.',
          style: const TextStyle(
              fontSize: 12, height: 1.6, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.md),
      for (final entry in [
        (
          'Claim aktif saat ini',
          _value(data.assignedWorkload['personal_claims'])
        ),
        ('Waktu respons rata-rata', response),
      ]) ...[
        if (entry.$1 == 'Waktu respons rata-rata')
          const Divider(height: AppSpacing.lg, color: AppColors.border),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: Text(entry.$1,
                  style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(entry.$2,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy))),
        ]),
      ],
      const SizedBox(height: AppSpacing.md),
      const Text('Riwayat keputusan mencakup penugasan sebelumnya.',
          style: TextStyle(
              fontSize: 11, height: 1.5, color: AppColors.textSecondary)),
    ]));
  }
}

class _AdminHomeHeading extends StatelessWidget {
  const _AdminHomeHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy)));
}

class _AdminAssignmentSummary extends StatelessWidget {
  const _AdminAssignmentSummary(
      {required this.data, required this.destinations, this.destinationLabel});
  final OperationalReport data;
  final List<Destination> destinations;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final count = _number(data.metrics['assigned_destinations']);
    final names = destinationLabel ??
        (destinations.isEmpty
            ? 'Destinasi dalam penugasan Anda'
            : '${destinations.map((d) => d.name).join(' & ')}'
                '${count != null && count > destinations.length ? ' dan lainnya' : ''}');
    return _DashboardCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            const Text('LINGKUP PENUGASAN',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                    color: AppColors.blueTint,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('ADMIN ROLE 1',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueDeep))),
          ]),
      const SizedBox(height: AppSpacing.md),
      Text.rich(TextSpan(children: [
        TextSpan(
            text: _value(data.metrics['assigned_destinations']),
            style: const TextStyle(
                fontSize: 36,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const TextSpan(
            text: ' destinasi ditugaskan',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      ])),
      const SizedBox(height: AppSpacing.xs),
      Text(
          '$names · periode ${operationsPeriodLabel(data.period.map((k, v) => MapEntry(k, '$v')), includeYear: true)}',
          style: const TextStyle(
              fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Divider(color: AppColors.border)),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            const Text('Keputusan berhasil',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('${_value(data.metrics['approved_decisions'])} disetujui',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ]),
    ]));
  }
}

class _AdminAttentionTile extends StatelessWidget {
  const _AdminAttentionTile({required this.row, required this.onTap});
  final OperationalRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visit = DateTime.tryParse('${row.raw['visit_date']}');
    // The API classifies upcoming visits using each destination's timezone.
    final upcoming = row.action == 'upcoming_visit';
    return Material(
        color: AppColors.warningTint,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.warningBorder)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            leading: Icon(
                upcoming ? Icons.calendar_today_outlined : Icons.schedule,
                color: AppColors.warningText,
                size: 20),
            title: Text(operationalActionLabel(row.action),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningText)),
            subtitle: Text(
                '${row.name ?? 'Destinasi'} · '
                '${visit == null ? 'Tanggal belum tersedia' : visitDateLabel(visit)}'
                '${upcoming ? '' : row.claimState == 'active' ? ' · Claim aktif' : ' · Belum diambil'}',
                style: const TextStyle(
                    fontSize: 11, height: 1.5, color: AppColors.warningText)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.warningText),
            onTap: row.bookingGuid == null ? null : onTap));
  }
}

class _AdminHomeShortcut extends StatelessWidget {
  const _AdminHomeShortcut(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
          key: ValueKey('home-shortcut-$title'),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          leading: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.blue, size: 20)),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary))),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.navy, size: 20),
          onTap: onTap));
}
