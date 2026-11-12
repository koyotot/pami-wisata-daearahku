import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/screens/admin/admin_common.dart';
import 'package:wisata_daerahku/screens/admin/operations_dashboard/operations_dashboard.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final role in <int?>[null, 1, 2]) {
    testWidgets('role $role navbar exposes actionable labeled tabs',
        (tester) async {
      final semantics = tester.ensureSemantics();
      int? selected;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              bottomNavigationBar: FloatingBottomNav(
                  index: 0,
                  operationsRole: role,
                  onSelected: (value) => selected = value))));
      final labels = role == null
          ? ['Beranda', 'Riwayat', 'Jelajah', 'Notifikasi', 'Profil']
          : role == 1
              ? ['Beranda', 'Booking', 'Scan QR', 'Destinasi', 'Profil']
              : ['Ringkasan', 'Operasi', 'Analitik', 'Kelola', 'Profil'];
      for (var index = 0; index < labels.length; index++) {
        final node = tester.getSemantics(find.bySemanticsLabel(labels[index]));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        tester
            .renderObject(find.byType(FloatingBottomNav))
            .owner!
            .semanticsOwner!
            .performAction(node.id, SemanticsAction.tap);
        expect(selected, index);
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('role1 nested page and snackbar inherit Jakarta over Georgia',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Georgia'),
        home:
            OperationsPage(role: 1, title: 'Nested', subtitle: 'QA', children: [
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => showAdminSnack(context, 'QA feedback'),
                  child: const Text('Feedback')))
        ])));
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.text('Nested')))
            .textTheme
            .bodyMedium!
            .fontFamily,
        startsWith('PlusJakartaSans'));
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    expect(
        DefaultTextStyle.of(tester.element(find.text('QA feedback')))
            .style
            .fontFamily,
        startsWith('PlusJakartaSans'));
  });
}
