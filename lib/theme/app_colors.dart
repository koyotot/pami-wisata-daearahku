import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visitor V4 tokens; other roles keep their local presentation.
class AppColors {
  AppColors._();
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const bg = Color(0xFFF5F8FD);
  static const surface = Colors.white;
  static const border = Color(0xFFDCE4F0);
  static const textMuted = Color(0xFF728099);
  static const orange = Color(0xFFFF9800);
  static const success = Color(0xFF16784C);
  static const successTint = Color(0xFFEDF9F2);

  static ThemeData get operationsTheme => visitorTheme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: GoogleFonts.plusJakartaSansTextTheme()
            .apply(bodyColor: navy, displayColor: navy),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(
                    kMinInteractiveDimension, kMinInteractiveDimension))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                    kMinInteractiveDimension, kMinInteractiveDimension))),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                minimumSize: const Size(
                    kMinInteractiveDimension, kMinInteractiveDimension))),
        iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
                minimumSize: const Size(
                    kMinInteractiveDimension, kMinInteractiveDimension))),
      );

  static ThemeData get visitorTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue)
            .copyWith(primary: blue, secondary: blueDeep, surface: surface),
        scaffoldBackgroundColor: bg,
        canvasColor: bg,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        appBarTheme: const AppBarTheme(
            backgroundColor: bg,
            foregroundColor: navy,
            elevation: 0,
            surfaceTintColor: Colors.transparent),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: blue, width: 2))),
      );
}
