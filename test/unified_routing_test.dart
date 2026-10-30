import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/screens/admin_dashboard.dart';
import 'package:wisata_daerahku/screens/main_navigation_screen.dart';
import 'package:wisata_daerahku/screens/session_destination.dart';
import 'package:wisata_daerahku/screens/user_login_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

void main() {
  final session = AuthSession.instance;

  tearDown(() {
    session.role = null;
    session.deviceSessionReady = false;
    session.authenticated.value = false;
  });

  test('destination requires a validated session and exact role', () {
    session.authenticated.value = true;
    session.deviceSessionReady = false;
    session.role = 1;
    expect(sessionDestination(), isA<UserLoginScreen>());
    session.deviceSessionReady = true;
    session.role = 0;
    expect(sessionDestination(), isA<MainNavigationScreen>());
    for (final role in [1, 2]) {
      session.role = role;
      expect(sessionDestination(), isA<AdminDashboard>());
    }
    session.role = 3;
    expect(sessionDestination(), isA<UserLoginScreen>());
  });

  testWidgets('unvalidated routes do not render admin or user dashboard',
      (tester) async {
    session.authenticated.value = false;
    session.deviceSessionReady = false;
    session.role = 0;
    await tester.pumpWidget(const MaterialApp(home: AdminDashboard()));
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.byType(AdminDashboard), findsNothing);
  });

  testWidgets('role 0 opening admin is routed to the user shell', (tester) async {
    session.authenticated.value = true;
    session.deviceSessionReady = true;
    session.role = 0;
    await tester.pumpWidget(const MaterialApp(home: AdminDashboard()));
    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.text('Kelola Admin'), findsNothing);
  });

  testWidgets('admin opening user shell is routed to admin', (tester) async {
    session.authenticated.value = true;
    session.deviceSessionReady = true;
    session.role = 1;
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
    expect(find.byType(AdminDashboard), findsOneWidget);
  });
}
