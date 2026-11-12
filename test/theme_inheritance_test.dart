import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/main.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/services/fcm_device_manager.dart';
import 'package:wisata_daerahku/theme/app_colors.dart';

const _legacyTeal = Color(0xFF0A6E5E);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final session = AuthSession.instance;

  tearDown(() {
    session.role = null;
    session.deviceSessionReady = false;
    session.authenticated.value = false;
  });

  void expectBlueJakarta(ThemeData theme, {required String where}) {
    expect(theme.colorScheme.primary, AppColors.blue, reason: where);
    expect(theme.colorScheme.primary, isNot(_legacyTeal), reason: where);
    expect(
        theme.textTheme.bodyMedium!.fontFamily, startsWith('PlusJakartaSans'),
        reason: where);
    expect(theme.textTheme.bodyMedium!.fontFamily, isNot('Georgia'),
        reason: where);
    expect(theme.scaffoldBackgroundColor, AppColors.bg, reason: where);
    final focused =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.color, AppColors.blue, reason: where);
  }

  // Unauthenticated (auth routes) plus roles 0/1/2 at the Navigator overlay.
  for (final role in <int?>[null, 0, 1, 2]) {
    testWidgets('role $role dialog, sheet and snackbar inherit blue/Jakarta',
        (tester) async {
      await tester.pumpWidget(
          WisataDaerahkuApp(fcm: FcmDeviceManager(AuthSession.instance)));
      await tester.pump();
      if (role != null) {
        session.role = role;
        session.deviceSessionReady = true;
        session.authenticated.value = true;
        session.sessionChanges.value++;
        await tester.pump();
      }
      final context = tester.element(find.byType(UserLoginScreen));

      showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(content: Text('dialog-probe')));
      await tester.pumpAndSettle();
      final dialogTheme = Theme.of(tester.element(find.text('dialog-probe')));
      expectBlueJakarta(dialogTheme, where: 'dialog role $role');
      expect(dialogTheme.splashFactory == NoSplash.splashFactory, role == 1,
          reason: 'role 1 overlays use operationsTheme');
      expect(
          DefaultTextStyle.of(tester.element(find.text('dialog-probe')))
              .style
              .fontFamily,
          startsWith('PlusJakartaSans'));
      Navigator.of(tester.element(find.text('dialog-probe'))).pop();
      await tester.pumpAndSettle();

      showModalBottomSheet<void>(
          context: context, builder: (_) => const Text('sheet-probe'));
      await tester.pumpAndSettle();
      expectBlueJakarta(Theme.of(tester.element(find.text('sheet-probe'))),
          where: 'sheet role $role');
      Navigator.of(tester.element(find.text('sheet-probe'))).pop();
      await tester.pumpAndSettle();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('snack-probe')));
      await tester.pumpAndSettle();
      expect(
          DefaultTextStyle.of(tester.element(find.text('snack-probe')))
              .style
              .fontFamily,
          startsWith('PlusJakartaSans'));
      expect(Theme.of(tester.element(find.text('snack-probe'))).colorScheme,
          isNot(predicate<ColorScheme>((s) => s.primary == _legacyTeal)));
    });
  }
}
