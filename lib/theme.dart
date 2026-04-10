// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/theme.dart
// Tema centralizado y widgets de UI compartidos
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// Nota: Fuente Outfit cargada desde assets/fonts/ (local)
// para evitar descarga de red en arranque

// ═══════════════════════════════════════════════════════════════
// COLORES DE LA APLICACIÓN
// ═══════════════════════════════════════════════════════════════

class LvsColors {
  // Colores principales (Tokens de Directiva)
  static const Color teal   = Color(0xFF00F5FF); // Electric Cyan (CH2)
  static const Color pink   = Color(0xFFFF006E); // Vivid Raspberry (CH1)
  static const Color violet = Color(0xFF8338EC); // Zomp/Purple (Gradient Target)
  static const Color red    = Color(0xFFFF4D4D); // Neon Red (Emergency)
  static const Color amber  = Color(0xFFFFB800); // Pulse Warning
  
  // Bordes
  static const Color border  = Color(0xFF1E1E2A);
  static const Color borderH = Color(0xFF2A2A3A);
  
  // Colores de fondo (Tokens de Directiva)
  static const Color bg      = Color(0xFF0D0D12); // Deep Black / Dark Navy
  static const Color bgCard  = Color(0xFF161621); // Glass Card Overlay
  static const Color bgCardH = Color(0xFF1C1C29); // Glass Card Hover
  
  // Colores de texto
  static const Color text1 = Color(0xFFFFFFFF); // Pure White
  static const Color text2 = Color(0xFFD1D1D1); // Light Grey
  static const Color text3 = Color(0xFF8E8E9F); // Muted Blueish Grey
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS COMPARTIDOS
// ═══════════════════════════════════════════════════════════════

/// Etiqueta de sección estilizada
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;

  const SectionLabel(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 10,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          color: color ?? LvsColors.text3,
        ),
      ),
    );
  }
}

/// Tarjeta con efecto glassmorphism
class CardGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderRadius;
  final Color? color;
  final double? width;
  final double? height;

  const CardGlass({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.color,
    this.borderRadius = 16,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? LvsColors.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
} 
