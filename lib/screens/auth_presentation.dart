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
        scaffoldBackgroundColor: const Color(0xFFF5F8FD),
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

class AuthOtpInput extends StatelessWidget {
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
                border: Border.all(
                    color: hasError
                        ? Theme.of(context).colorScheme.error
                        : AuthTheme.border,
                    width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExcludeSemantics(
                  child: Text(
                      i < controller.text.length ? controller.text[i] : ' ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 24, fontWeight: FontWeight.w600))),
            )),
          ],
        ]),
        Positioned.fill(
            child: Opacity(
                alwaysIncludeSemantics: true,
                opacity: 0,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6)
                  ],
                  onChanged: onChanged,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      labelText: 'Kode verifikasi', counterText: ''),
                  maxLength: 6,
                ))),
      ]);
}
