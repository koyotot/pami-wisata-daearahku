import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import 'admin_dashboard.dart';
import 'main_navigation_screen.dart';
import 'user_login_screen.dart';

Widget sessionDestination() {
  final session = AuthSession.instance;
  if (!session.authenticated.value || !session.deviceSessionReady) {
    return const UserLoginScreen();
  }
  return switch (session.role) {
    0 => const MainNavigationScreen(),
    1 || 2 => const AdminDashboard(),
    _ => const UserLoginScreen(),
  };
}
