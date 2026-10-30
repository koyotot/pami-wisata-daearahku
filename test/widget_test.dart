// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

// Pastikan import ini mengarah ke file main.dart proyek Anda
import 'package:wisata_daerahku/main.dart';
import 'package:wisata_daerahku/screens/user_login_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/services/fcm_device_manager.dart';

void main() {
  testWidgets('Wisata Daerahku App smoke test', (WidgetTester tester) async {
    // PERBAIKAN: Mengganti 'const MyApp()' menjadi 'const WisataDaerahkuApp()'
    await tester.pumpWidget(WisataDaerahkuApp(
      fcm: FcmDeviceManager(AuthSession.instance),
    ));

    // Memastikan aplikasi berhasil dimuat dengan mendeteksi teks judul utama di HomeScreen
    expect(find.text('Wisata Daerahku'), findsOneWidget);
    expect(find.byType(UserLoginScreen), findsOneWidget);
  });
}
