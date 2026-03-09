// ═══════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Require package

class LvsColors {
  // Un fondo oscuro mucho más profundo, casi OLED (Midnight Blue / Deep Space)
  static const Color bg         = Color(0xFF05050A);
  static const Color bgCard     = Color(0x1F1A1A2E); // Translúcido para glassmorphism
  static const Color bgCardH    = Color(0x3B1A1A2E);
  static const Color border     = Color(0x1AFFFFFF); // Blanco 10%
  static const Color borderH    = Color(0x33FFFFFF);

  // Colores Neon Cyberpunk / Velvet
  static const Color pink       = Color(0xFFFF2A85); // Rosado neón vibrante
  static const Color violet     = Color(0xFF8A2BE2); // Deep Violet
  static const Color teal       = Color(0xFF00F0FF); // Cyan
  static const Color amber      = Color(0xFFFFB800);
  static const Color green      = Color(0xFF00FF66);
  static const Color red        = Color(0xFFFF2A55);

  static const Color text1      = Color(0xFFF7F7F7);
  static const Color text2      = Color(0xFFB0B0C0);
  static const Color text3      = Color(0xFF6B6B80);

  // Gradientes
  static const Gradient pinkViolet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, violet],
  );
}

class LvsTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LvsColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: LvsColors.pink,
      secondary: LvsColors.teal,
      surface: LvsColors.bgCard,
      error: LvsColors.red,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    cardTheme: const CardThemeData(
      color: LvsColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: LvsColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: LvsColors.pink,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        color: LvsColors.text1,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: const IconThemeData(color: LvsColors.text2),
    ),
    dividerTheme: const DividerThemeData(
      color: LvsColors.border,
      thickness: 1,
    ),
  );
}

// ── CardGlass: Tarjeta con borde y blur style real ─────────────────
class CardGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double borderRadius;

  const CardGlass({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131320).withOpacity(0.35),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          padding: padding ?? const EdgeInsets.all(22),
          child: child,
        ),
      ),
    );
  }
}

// ── SectionLabel: etiqueta uppercase ─────────
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: color ?? LvsColors.text3,
      ),
    );
  }
}
