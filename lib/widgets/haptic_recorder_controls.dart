import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/media/haptic_recorder_service.dart';

class HapticRecorderControls extends StatelessWidget {
  final HapticRecorderService recorder;
  final VoidCallback onToggleRecord;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const HapticRecorderControls({
    super.key,
    required this.recorder,
    required this.onToggleRecord,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = recorder.isRecording;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isRecording
            ? LvsColors.red.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecording
              ? LvsColors.red.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            _pulsingDot(),
            const SizedBox(width: 8),
            Text(
              '${recorder.actionCount} acts',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: LvsColors.red,
              ),
            ),
            const SizedBox(width: 8),
            _miniButton(
              icon: Icons.save_rounded,
              color: LvsColors.teal,
              onTap: onSave,
              tooltip: 'Guardar',
            ),
            const SizedBox(width: 4),
            _miniButton(
              icon: Icons.close_rounded,
              color: LvsColors.text3,
              onTap: onCancel,
              tooltip: 'Cancelar',
            ),
          ] else ...[
            _miniButton(
              icon: Icons.fiber_manual_record_rounded,
              color: LvsColors.red,
              onTap: onToggleRecord,
              tooltip: 'Grabar',
            ),
          ],
        ],
      ),
    );
  }

  Widget _pulsingDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: LvsColors.red,
        boxShadow: [
          BoxShadow(
            color: LvsColors.red.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}
