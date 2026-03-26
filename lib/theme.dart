// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/theme.dart · v3.0.0 (The Neon Nocturne)
// ═══════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LvsColors {
  // --- Basic Palette (Neon Nocturne) ---
  static const Color background = Color(0xFF000000);   // surface_lowest
  static const Color bg = Color(0xFF0E0E0E);           // surface_dim
  static const Color bgCard = Color(0xFF131313);       // surface_low
  static const Color bgCardH = Color(0xFF262626);      // surface_container_highest
  
  // Aliases for legacy support
  static const Color border = Color(0x0DFFFFFF);       // white @ 5%
  static const Color borderH = Color(0x33FFFFFF);      // white @ 20%

  // --- Brand Accents ---
  static const Color pink = Color(0xFFFF8BA1);         // Primary: Velvet Pink
  static const Color violet = Color(0xFFBC83FF);       // Secondary: Electric Violet
  static const Color teal = Color(0xFF16FEFE);         // Tertiary: Cyan Neon
  
  static const Color red = Color(0xFFFF4444);
  static const Color amber = Color(0xFFFFB300);
  
  // --- Text Hierarchy ---
  static const Color text1 = Color(0xFFFFFFFF);        // Pure White
  static const Color text2 = Color(0xFFD1D1D1);        // Medium Grey
  static const Color text3 = Color(0xFFADAAAA);        // Dim Grey
}

// ── Glassmorphism Component ─────────────────────────────────────
class CardGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final double borderRadius;

  const CardGlass({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.blur = 30.0,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (color ?? LvsColors.bgCardH).withOpacity(0.4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: (borderColor ?? Colors.white).withOpacity(0.08),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Section Label ───────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.0,
          color: color ?? LvsColors.text3,
        ),
      ),
    );
  }
}
