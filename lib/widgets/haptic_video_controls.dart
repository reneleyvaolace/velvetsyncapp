import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:velvet_sync/theme.dart';

class HapticVideoControls extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final bool funscriptLoaded;
  final bool isFunscriptLoading;
  final bool isBleConnected;
  final int funscriptActionCount;
  final double currentCh1Intensity;
  final double currentCh2Intensity;
  final bool showFunscriptInfo;
  final int bleDeviceCount;

  const HapticVideoControls({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    this.funscriptLoaded = false,
    this.isFunscriptLoading = false,
    this.isBleConnected = false,
    this.funscriptActionCount = 0,
    this.currentCh1Intensity = 0.0,
    this.currentCh2Intensity = 0.0,
    this.showFunscriptInfo = true,
    this.bleDeviceCount = 0,
  });

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFunscriptInfo)
          _buildInfoBar(),
        _buildControls(progress),
      ],
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          _buildBleIndicator(),
          const SizedBox(width: 12),
          _buildFunscriptIndicator(),
          const Spacer(),
          _buildIntensityIndicator(),
        ],
      ),
    );
  }

  Widget _buildBleIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBleConnected ? LvsColors.teal : LvsColors.text3,
            boxShadow: isBleConnected
                ? [BoxShadow(color: LvsColors.teal.withValues(alpha: 0.6), blurRadius: 6)]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isBleConnected
              ? 'BLE${bleDeviceCount > 1 ? " ($bleDeviceCount)" : ""}'
              : 'BLE OFF',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isBleConnected ? LvsColors.teal : LvsColors.text3,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFunscriptIndicator() {
    if (isFunscriptLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'SCRIPT...',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: LvsColors.text3,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    if (!funscriptLoaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LvsColors.amber,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'NO SCRIPT',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: LvsColors.amber,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LvsColors.pink,
            boxShadow: [BoxShadow(color: LvsColors.pink.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$funscriptActionCount acts',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: LvsColors.pink,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _intensityBar(LvsColors.pink, currentCh1Intensity, 'CH1'),
        const SizedBox(width: 8),
        _intensityBar(LvsColors.teal, currentCh2Intensity, 'CH2'),
      ],
    );
  }

  Widget _intensityBar(Color color, double value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: LvsColors.text3,
          ),
        ),
        const SizedBox(width: 3),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color,
                boxShadow: value > 0
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: LvsColors.pink,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: LvsColors.pink,
              overlayColor: LvsColors.pink.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: onSeek,
            ),
          ),
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: LvsColors.text2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LvsColors.pink.withValues(alpha: 0.2),
                    border: Border.all(
                      color: LvsColors.pink.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: LvsColors.pink,
                    size: 24,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(duration),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: LvsColors.text2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
