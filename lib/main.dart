import 'services/auth_session.dart';
import 'core/config/app_config.dart';
import 'services/fcm_device_manager.dart';
import 'screens/shared/ticket_link_screen.dart';
import 'screens/shared/session_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/user_login_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final fcm = FcmDeviceManager(AuthSession.instance)..attach();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await AuthSession.instance.restore();
  runApp(WisataDaerahkuApp(fcm: fcm));
}

class WisataDaerahkuApp extends StatefulWidget {
  const WisataDaerahkuApp({super.key, required this.fcm});
  final FcmDeviceManager fcm;

  @override
  State<WisataDaerahkuApp> createState() => _WisataDaerahkuAppState();
}

class _WisataDaerahkuAppState extends State<WisataDaerahkuApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _routeAfterAccountChange = false;
  @override
  void initState() {
    super.initState();
    AuthSession.instance.authenticated.addListener(_sessionChanged);
    AuthSession.instance.sessionChanges.addListener(_sessionStateChanged);
    widget.fcm.start(onForeground: (message) {
      if (AuthSession.instance.authenticated.value &&
          message.data['notification_guid'] is String) {
        _messenger.currentState?.showSnackBar(
          const SnackBar(content: Text('Anda menerima notifikasi baru.')),
        );
      }
    });
  }

  void _sessionChanged() {
    final session = AuthSession.instance;
    if (!session.authenticated.value) {
      _routeAfterAccountChange = session.authenticating;
      _navigator.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UserLoginScreen()),
          (_) => false);
    } else if (_routeAfterAccountChange) {
      _routeAfterAccountChange = false;
      _navigator.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => sessionDestination()),
          (_) => false);
    }
  }

  void _sessionStateChanged() {
    final session = AuthSession.instance;
    if (!session.authenticated.value && !session.authenticating) {
      _routeAfterAccountChange = false;
    }
  }

  @override
  void dispose() {
    AuthSession.instance.authenticated.removeListener(_sessionChanged);
    AuthSession.instance.sessionChanges.removeListener(_sessionStateChanged);
    widget.fcm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      title: 'Wisata Daerahku',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ListenableBuilder(
        listenable: AuthSession.instance.sessionChanges,
        builder: (context, _) {
          final session = AuthSession.instance;
          // Cap the system font scale so layouts keep the intended density.
          final content = MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.0, maxScaleFactor: 1.15, child: child!);
          if (session.authenticated.value &&
              session.deviceSessionReady &&
              (session.role == 1 || session.role == 2)) {
            // Admin and superadmin dialogs, sheets and route flights share the operations shell theme.
            return Theme(data: AppColors.operationsTheme, child: content);
          }
          return content;
        },
      ),
      // Blue/navy + Plus Jakarta Sans root for every role, auth and overlay route.
      theme: AppColors.visitorTheme,
      home: sessionDestination(),
      // HTTPS App Link: /tickets/{booking_guid} (e-ticket email). A navigation hint; the server decides.
      onGenerateRoute: (settings) => ticketLinkRoute(settings),
    );
  }
}
