import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_icons.dart';

/// Auth uses the blue/Jakarta identity documented in DESIGN.md's local screens.
class AuthTheme extends StatelessWidget {
  const AuthTheme({super.key, required this.child});
  final Widget child;
  static const blue = Color(0xFF1976D2);
  static const navy = Color(0xFF102D59);
  static const border = Color(0xFFDCE4F0);
  static TextStyle get snackBarTextStyle => GoogleFonts.plusJakartaSans();

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: navy,
      displayColor: navy,
    );
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: border, width: 1.5),
    );
    return Theme(
      data: ThemeData(
        actionIconTheme: AppIcons.actionTheme,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
          primary: blue,
          error: const Color(0xFFE5484D),
        ),
        textTheme: text,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: text.titleMedium?.copyWith(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: outline,
          enabledBorder: outline,
          focusedBorder: outline.copyWith(
              borderSide: const BorderSide(color: blue, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: text.bodyMedium,
          hintStyle: text.bodyMedium,
          errorMaxLines: 3,
        ),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: text.labelLarge
              ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        )),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: blue,
          textStyle: text.labelLarge,
        )),
      ),
      child: child,
    );
  }
}

class AuthScenicShell extends StatelessWidget {
  const AuthScenicShell({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AuthTheme(
        child: Builder(
            builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
                  value: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                    systemStatusBarContrastEnforced: false,
                    systemNavigationBarColor: Colors.white,
                    systemNavigationBarIconBrightness: Brightness.dark,
                  ),
                  child: Scaffold(
                    backgroundColor: AuthTheme.navy,
                    body: SafeArea(
                        top: false,
                        bottom: false,
                        child: ColoredBox(
                            color: AuthTheme.navy,
                            child: CustomScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              slivers: [
                                SliverToBoxAdapter(
                                    child: TimeBasedScenicBackground(
                                  child: SafeArea(
                                    bottom: false,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          24, 20, 24, 44),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: .2),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 7),
                                                child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          PhosphorIconsRegular
                                                              .globeHemisphereWest,
                                                          size: 16,
                                                          color: Colors.white),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                          child: Text(
                                                              'Wisata Daerahku',
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .labelMedium
                                                                  ?.copyWith(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700))),
                                                    ]),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium
                                                    ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -.8)),
                                          ]),
                                    ),
                                  ),
                                )),
                                SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Container(
                                      key: const ValueKey('auth-white-sheet'),
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(34))),
                                      child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: ((MediaQuery.sizeOf(
                                                                  context)
                                                              .width -
                                                          460) /
                                                      2)
                                                  .clamp(0, double.infinity)),
                                          child: SafeArea(
                                              top: false,
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          24, 28, 24, 24),
                                                  child: child))),
                                    )),
                              ],
                            ))),
                  ),
                )),
      );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              const SizedBox(width: 10),
              const Icon(PhosphorIconsRegular.arrowRight, size: 20)
            ]));
}

class AuthBackLink extends StatelessWidget {
  const AuthBackLink({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 18),
          label: Text(label)));
}

class AuthHeading extends StatelessWidget {
  const AuthHeading(
      {super.key, required this.title, required this.description});
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF536780), height: 1.5)),
        const SizedBox(height: 24)
      ]);
}

class AuthOtpInput extends StatefulWidget {
  const AuthOtpInput(
      {super.key,
      required this.controller,
      required this.enabled,
      required this.hasError,
      required this.onChanged});
  final TextEditingController controller;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  @override
  State<AuthOtpInput> createState() => _AuthOtpInputState();
}

class _AuthOtpInputState extends State<AuthOtpInput> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Row(children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
                child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: widget.hasError
                                ? Theme.of(context).colorScheme.error
                                : _focus.hasFocus &&
                                        i ==
                                            widget.controller.text.length.clamp(
                                                0, 5)
                                    ? AuthTheme.blue
                                    : AuthTheme.border,
                            width: 1.5),
                        borderRadius: BorderRadius.circular(14)),
                    child: ExcludeSemantics(
                        child: Text(
                            i < widget.controller.text.length
                                ? widget.controller.text[i]
                                : ' ',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: widget.hasError
                                        ? Theme.of(context).colorScheme.error
                                        : AuthTheme.navy))))),
          ]
        ]),
        Positioned.fill(
            child: Opacity(
                alwaysIncludeSemantics: true,
                opacity: 0,
                child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6)
                    ],
                    onChanged: widget.onChanged,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        labelText: 'Kode verifikasi', counterText: ''),
                    maxLength: 6))),
      ]);
}

enum _AuthHeaderPeriod {
  morning,
  day,
  evening,
  night;

  static _AuthHeaderPeriod forTime(DateTime now) {
    if (now.hour < 5 || now.hour >= 19) return night;
    if (now.hour < 11) return morning;
    if (now.hour < 15) return day;
    return evening;
  }
}

class _AuthScene {
  const _AuthScene(this.sky, this.back, this.front, this.sun, this.sunY,
      this.sunOpacity, this.cloudOpacity, this.nightOpacity);

  final List<Color> sky;
  final Color back;
  final List<Color> front;
  final List<Color> sun;
  final double sunY, sunOpacity, cloudOpacity, nightOpacity;

  static const scenes = {
    _AuthHeaderPeriod.morning: _AuthScene(
        [Color(0xFF397EBC), Color(0xFF80BFE5), Color(0xFFF4CDB1)],
        Color(0x661558B0),
        [Color(0xCC286AA4), Color(0xF2102D59)],
        [Color(0xFFFFE9C4), Color(0xFFFFBC78)],
        .42,
        1,
        .18,
        0),
    _AuthHeaderPeriod.day: _AuthScene(
        [Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF90CAF9)],
        Color(0x661558B0),
        [Color(0xCC1558B0), Color(0xF2102D59)],
        [Color(0xFFFFE9B0), Color(0xFFFF9800)],
        .30,
        1,
        .22,
        0),
    _AuthHeaderPeriod.evening: _AuthScene(
        [Color(0xFF555783), Color(0xFFC18DAD), Color(0xFFF4AC7F)],
        Color(0x9960527E),
        [Color(0xDD4A4676), Color(0xF2102D59)],
        [Color(0xFFFFD9AD), Color(0xFFF78E60)],
        .54,
        1,
        .15,
        0),
    _AuthHeaderPeriod.night: _AuthScene(
        [Color(0xFF09172F), Color(0xFF142E55), Color(0xFF365479)],
        Color(0xCC1C365A),
        [Color(0xFF172D4E), Color(0xFF102039)],
        [Color(0xFFFFE9B0), Color(0xFFFF9800)],
        .40,
        0,
        .04,
        1),
  };

  static _AuthScene lerp(_AuthScene a, _AuthScene b, double t) {
    List<Color> colors(List<Color> x, List<Color> y) =>
        [for (var i = 0; i < x.length; i++) Color.lerp(x[i], y[i], t)!];
    double value(double x, double y) => x + (y - x) * t;
    return _AuthScene(
        colors(a.sky, b.sky),
        Color.lerp(a.back, b.back, t)!,
        colors(a.front, b.front),
        colors(a.sun, b.sun),
        value(a.sunY, b.sunY),
        value(a.sunOpacity, b.sunOpacity),
        value(a.cloudOpacity, b.cloudOpacity),
        value(a.nightOpacity, b.nightOpacity));
  }
}

class _AuthSceneTween extends Tween<_AuthScene> {
  _AuthSceneTween({required _AuthScene scene})
      : super(begin: scene, end: scene);

  @override
  _AuthScene lerp(double t) => _AuthScene.lerp(begin!, end!, t);
}

class TimeBasedScenicBackground extends StatefulWidget {
  const TimeBasedScenicBackground({
    super.key,
    required this.child,
    this.active = true,
    this.topInset,
  });
  final Widget child;
  final bool active;
  final double? topInset;

  @override
  State<TimeBasedScenicBackground> createState() =>
      _TimeBasedScenicBackgroundState();
}

class _TimeBasedScenicBackgroundState extends State<TimeBasedScenicBackground>
    with WidgetsBindingObserver {
  late _AuthHeaderPeriod _period;
  Timer? _boundaryTimer;
  Timer? _clockCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _period = _AuthHeaderPeriod.forTime(DateTime.now());
    if (widget.active) {
      _reconcile();
      _startClockCheck();
    }
  }

  @override
  void didUpdateWidget(TimeBasedScenicBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _reconcile();
      _startClockCheck();
    } else if (!widget.active) {
      _boundaryTimer?.cancel();
      _clockCheck?.cancel();
    }
  }

  void _startClockCheck() {
    _clockCheck?.cancel();
    // Manual clock/timezone edits may not emit a lifecycle event.
    _clockCheck =
        Timer.periodic(const Duration(minutes: 1), (_) => _reconcile());
  }

  void _reconcile() {
    final now = DateTime.now();
    final period = _AuthHeaderPeriod.forTime(now);
    if (period != _period) setState(() => _period = period);
    final boundary = [
      for (final hour in [5, 11, 15, 19])
        DateTime(now.year, now.month, now.day, hour),
      DateTime(now.year, now.month, now.day + 1, 5),
    ].firstWhere((time) => time.isAfter(now));
    final delay = boundary.difference(now);
    _boundaryTimer?.cancel();
    _boundaryTimer = Timer(
        delay > Duration.zero ? delay : const Duration(milliseconds: 1),
        _reconcile);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _reconcile();
      _startClockCheck();
    } else {
      _boundaryTimer?.cancel();
      _clockCheck?.cancel();
    }
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    _clockCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: TweenAnimationBuilder<_AuthScene>(
          tween: _AuthSceneTween(scene: _AuthScene.scenes[_period]!),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          child: widget.child,
          builder: (context, scene, child) => ClipRect(
            child: CustomPaint(
                painter: AuthMountainPainter._(scene,
                    widget.topInset ?? MediaQuery.paddingOf(context).top),
                child: child),
          ),
        ),
      );
}

class AuthMountainPainter extends CustomPainter {
  const AuthMountainPainter._(this.scene, this.topInset);
  final _AuthScene scene;
  final double topInset;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - topInset;
    final bounds = Offset.zero & size;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scene.sky,
          ).createShader(bounds));

    // Extend the sky above the original scene without moving its illustration.
    canvas.save();
    canvas.translate(0, topInset);

    // Matahari + cahaya
    final sun = Offset(w * 0.82, h * scene.sunY);
    final r = w * 0.085;
    canvas.drawCircle(
      sun,
      r * 3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            scene.sun.last.withValues(alpha: .5 * scene.sunOpacity),
            scene.sun.last.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 3)),
    );
    canvas.drawCircle(
      sun,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            for (final color in scene.sun)
              color.withValues(alpha: scene.sunOpacity)
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: r)),
    );

    final moon = Offset(w * .83, h * .30);
    final crescent = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: moon, radius: r * .78)),
        Path()
          ..addOval(Rect.fromCircle(
              center: moon.translate(r * .40, -r * .20), radius: r * .72)));
    canvas.drawPath(
        crescent,
        Paint()
          ..color =
              const Color(0xFFF4EBCF).withValues(alpha: scene.nightOpacity));
    const stars = [
      Offset(.60, .13),
      Offset(.73, .43),
      Offset(.93, .14),
      Offset(.95, .51),
      Offset(.52, .34),
      Offset(.69, .08)
    ];
    for (var i = 0; i < stars.length; i++) {
      canvas.drawCircle(
          Offset(w * stars[i].dx, h * stars[i].dy),
          i.isEven ? 1.4 : 1,
          Paint()
            ..color = Colors.white.withValues(alpha: .75 * scene.nightOpacity));
    }

    // Awan sederhana
    final cloud = Paint()
      ..color = Colors.white.withValues(alpha: scene.cloudOpacity);
    void drawCloud(Offset c, double s) {
      canvas.drawCircle(c, 9 * s, cloud);
      canvas.drawCircle(c.translate(11 * s, -5 * s), 12 * s, cloud);
      canvas.drawCircle(c.translate(25 * s, 0), 9 * s, cloud);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - 9 * s, c.dy, 43 * s, 9 * s),
          Radius.circular(9 * s),
        ),
        cloud,
      );
    }

    drawCloud(Offset(w * 0.62, h * 0.20), 1.0);
    drawCloud(Offset(w * 0.42, h * 0.52), 0.75);

    // Gunung belakang
    final back = Path()
      ..moveTo(0, h * 0.74)
      ..lineTo(w * 0.18, h * 0.58)
      ..lineTo(w * 0.36, h * 0.70)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.80, h * 0.72)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = scene.back);

    // Gunung depan
    final front = Path()
      ..moveTo(0, h * 0.84)
      ..lineTo(w * 0.24, h * 0.68)
      ..lineTo(w * 0.48, h * 0.82)
      ..lineTo(w * 0.72, h * 0.67)
      ..lineTo(w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: scene.front,
        ).createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4)),
    );
    canvas.restore();
    // Keep white headings readable while leaving the right-hand sky visible.
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x99102D59), Color(0x00102D59)],
            stops: [0, .8],
          ).createShader(bounds));
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33102D59), Color(0x00102D59)],
            stops: [0, .45],
          ).createShader(bounds));
  }

  @override
  bool shouldRepaint(covariant AuthMountainPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.topInset != topInset;
}
