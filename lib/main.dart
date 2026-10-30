import 'services/auth_session.dart';
import 'services/fcm_device_manager.dart';
import 'screens/session_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/user_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          MaterialPageRoute(builder: (_) => const UserLoginScreen()), (_) => false);
    } else if (_routeAfterAccountChange) {
      _routeAfterAccountChange = false;
      _navigator.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => sessionDestination()), (_) => false);
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A6E5E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFF7F4EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A6E5E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A6E5E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0D9CE), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0A6E5E), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF7A7065)),
          hintStyle: const TextStyle(color: Color(0xFFB0A898)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
        ),
      ),
      home: sessionDestination(),
    );
  }
}
