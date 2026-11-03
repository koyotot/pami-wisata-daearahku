import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/notification_state.dart';
import '../services/auth_session.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_bottom_nav.dart';
import 'beranda_user_screen.dart';
import 'bukti_pendaftaran_screen.dart';
import 'cari_wisata_screen.dart';
import 'notifikasi_screen.dart';
import 'profil_user_screen.dart';
import 'session_destination.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  static _MainNavigationScreenState? _activeShell;

  /// Reuse the mounted shell and remove detail/completed booking routes above it.
  static void returnToTab(BuildContext context, int index) {
    final navigator = Navigator.of(context);
    final shell = _activeShell;
    if (shell != null &&
        shell.mounted &&
        shell._route != null &&
        shell._route!.navigator == navigator &&
        shell._sessionGeneration == AuthSession.instance.sessionGeneration &&
        AuthSession.instance.authenticated.value &&
        AuthSession.instance.role == 0 &&
        AuthSession.instance.deviceSessionReady) {
      shell._gotoTab(index);
      navigator.popUntil((route) => identical(route, shell._route));
    } else {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _tabTransition;
  late final Animation<double> _tabOpacity;
  late final Animation<Offset> _tabOffset;
  late final int _sessionGeneration;
  final _notifications = NotificationState();
  int _selectedIndex = 0;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    MainNavigationScreen._activeShell = this;
  }

  @override
  void initState() {
    super.initState();
    _tabTransition = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300), value: 1);
    _tabOpacity = _tabTransition.drive(CurveTween(curve: Curves.easeOut));
    _tabOffset = _tabOpacity
        .drive(Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero));
    WidgetsBinding.instance.addObserver(this);
    _sessionGeneration = AuthSession.instance.sessionGeneration;
    AuthSession.instance.sessionChanges.addListener(_sessionChanged);
    _notifications.refreshCount();
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_selectedIndex == 3) {
        _notifications.refresh();
      } else {
        _notifications.refreshCount();
      }
    }
  }

  @override
  void dispose() {
    if (identical(MainNavigationScreen._activeShell, this)) {
      MainNavigationScreen._activeShell = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.instance.sessionChanges.removeListener(_sessionChanged);
    _notifications.dispose();
    _tabTransition.dispose();
    super.dispose();
  }

  void _gotoTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (index != _selectedIndex) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _tabTransition.value = 1;
      } else {
        _tabTransition.forward(from: 0);
      }
    }
    setState(() => _selectedIndex = index);
    if (index == 3) {
      _notifications.refresh();
    } else {
      _notifications.refreshCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    if (!session.authenticated.value ||
        !session.deviceSessionReady ||
        session.role != 0 ||
        session.sessionGeneration != _sessionGeneration) {
      return sessionDestination();
    }
    return Theme(
      data: AppColors.visitorTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PopScope(
          canPop: _selectedIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _gotoTab(0);
          },
          child: Scaffold(
            extendBody: true,
            backgroundColor: AppColors.bg,
            body: FadeTransition(
              opacity: _tabOpacity,
              child: SlideTransition(
                position: _tabOffset,
                child: IndexedStack(index: _selectedIndex, children: [
                  BerandaUserScreen(
                      active: _selectedIndex == 0,
                      onExplore: () => _gotoTab(2),
                      onHistory: () => _gotoTab(1)),
                  BuktiPendaftaranScreen(
                      embedded: true,
                      active: _selectedIndex == 1,
                      onExploreWisata: () => _gotoTab(2),
                      onKembali: () => _gotoTab(0)),
                  CariWisataScreen(
                      embedded: true,
                      active: _selectedIndex == 2,
                      onKembali: () => _gotoTab(0)),
                  NotifikasiScreen(
                      state: _notifications, active: _selectedIndex == 3),
                  ProfilUserScreen(
                      active: _selectedIndex == 4,
                      onNotifications: () => _gotoTab(3),
                      onKembali: () => _gotoTab(0)),
                ]),
              ),
            ),
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : ListenableBuilder(
                    listenable: _notifications,
                    builder: (_, __) => FloatingBottomNav(
                        index: _selectedIndex,
                        onSelected: _gotoTab,
                        unreadCount: _notifications.count.error == null
                            ? _notifications.count.data ?? 0
                            : 0),
                  ),
          ),
        ),
      ),
    );
  }
}
