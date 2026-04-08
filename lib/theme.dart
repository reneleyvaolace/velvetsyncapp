// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/theme.dart
// Tema centralizado y widgets de UI compartidos
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// COLORES DE LA APLICACIÓN
// ═══════════════════════════════════════════════════════════════

class LvsColors {
  // Colores principales
  static const Color teal = Color(0xFF00FFC2);
  static const Color pink = Color(0xFFFF1493);
  static const Color red = Color(0xFFFF1493);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFFFB800);
  
  // Bordes
  static const Color border = Color(0xFF2A2A4A);
  static const Color borderH = Color(0xFF3A3A5A);
  
  // Colores de fondo
  static const Color bg = Color(0xFF0A0A14);
  static const Color bgCard = Color(0xFF1A1A2E);
  static const Color bgCardH = Color(0xFF252542);
  
  // Colores de texto
  static const Color text1 = Color(0xFFEEEEEE);
  static const Color text2 = Color(0xFFCCCCCC);
  static const Color text3 = Color(0xFF888899);
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
        color: color ?? LvsColors.bgCard.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha:0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
} 
