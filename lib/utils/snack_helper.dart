// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/utils/snack_helper.dart · v1.0.0
// Helper centralizado para SnackBars premium con tema de la app
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class LvsColors {
  static const Color teal = Color(0xFF00FFC2);
  static const Color red = Color(0xFFFF1493);
}

class LvsSnack {
  static void show(
    BuildContext context, {
    required bool ok,
    required String message,
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ok
                  ? const Color(0xFF0D2A26)
                  : const Color(0xFF2A0D16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ok ? LvsColors.teal : LvsColors.red,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (ok ? LvsColors.teal : LvsColors.red).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: ok ? LvsColors.teal : LvsColors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: ok ? LvsColors.teal : LvsColors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
