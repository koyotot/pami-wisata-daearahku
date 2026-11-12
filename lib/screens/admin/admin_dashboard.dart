import 'package:flutter/material.dart';
import 'operations_navigation_shell.dart';
import '../../services/auth_session.dart';
import '../shared/session_destination.dart';

/// Compatibility entry point for existing admin login and navigation callers.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    if (!session.authenticated.value ||
        !session.deviceSessionReady ||
        (session.role != 1 && session.role != 2)) {
      return sessionDestination(session: session);
    }
    return const OperationsNavigationShell();
  }
}
