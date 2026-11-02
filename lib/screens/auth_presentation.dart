import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
                    systemNavigationBarColor: Colors.white,
                    systemNavigationBarIconBrightness: Brightness.dark,
                  ),
                  child: Scaffold(
                    backgroundColor: const Color(0xFF1E88E5),
                    body: SafeArea(
                        bottom: false,
                        child: ColoredBox(
                            color: AuthTheme.navy,
                            child: CustomScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              slivers: [
                                SliverToBoxAdapter(
                                    child: Container(
                                  decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF1E88E5),
                                      Color(0xFF42A5F5),
                                      Color(0xFF90CAF9)
                                    ],
                                  )),
                                  child: Stack(children: [
                                    const Positioned.fill(
                                        child: ClipRect(
                                            child: CustomPaint(
                                                painter:
                                                    AuthMountainPainter()))),
                                    Padding(
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
                                                          Icons
                                                              .travel_explore_rounded,
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
                                  ]),
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
              const Icon(Icons.arrow_forward_rounded, size: 20)
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
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
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

class AuthMountainPainter extends CustomPainter {
  const AuthMountainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Matahari + cahaya
    final sun = Offset(w * 0.82, h * 0.30);
    final r = w * 0.085;
    canvas.drawCircle(
      sun,
      r * 3,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x80FFC46B), Color(0x00FFC46B)],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 3)),
    );
    canvas.drawCircle(
      sun,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE9B0), Color(0xFFFF9800)],
        ).createShader(Rect.fromCircle(center: sun, radius: r)),
    );

    // Awan sederhana
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.22);
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
    canvas.drawPath(back, Paint()..color = const Color(0x661558B0));

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
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC1558B0), Color(0xF2102D59)],
        ).createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
