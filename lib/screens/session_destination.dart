import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import 'operations_navigation_shell.dart';
import 'main_navigation_screen.dart';
import 'user_login_screen.dart';
import 'verify_email_otp_screen.dart';
import '../data/app_data.dart';

Widget sessionDestination({AuthSession? session}) {
  session ??= AuthSession.instance;
  if (session.verificationRequired && currentUser != null) {
    return VerifyEmailOtpScreen(
        email: currentUser!.email,
        resendAfterSeconds: session.resendAfterSeconds,
        session: session);
  }
  if (!session.authenticated.value || !session.deviceSessionReady) {
    return const UserLoginScreen();
  }
  return switch (session.role) {
    0 => const MainNavigationScreen(),
    1 || 2 => OperationsNavigationShell(session: session),
    _ => const UserLoginScreen(),
  };
}
