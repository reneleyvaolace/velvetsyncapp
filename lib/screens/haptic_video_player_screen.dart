// NOTE: Requires 'video_player' package in pubspec.yaml:
//   video_player: ^2.9.2

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/p2p/p2p_connection_manager.dart';
import 'package:velvet_sync/services/media/funscript_loader.dart';
import 'package:velvet_sync/devices/models/funscript.dart';
import 'package:velvet_sync/services/media/haptic_video_sync_service.dart';
import 'package:velvet_sync/services/media/haptic_recorder_service.dart';
import 'package:velvet_sync/widgets/haptic_video_controls.dart';
import 'package:velvet_sync/widgets/haptic_recorder_controls.dart';
import 'package:velvet_sync/utils/logger.dart';

class HapticVideoPlayerScreen extends ConsumerStatefulWidget {
  const HapticVideoPlayerScreen({super.key});

  @override
  ConsumerState<HapticVideoPlayerScreen> createState() => _HapticVideoPlayerScreenState();
}

class _HapticVideoPlayerScreenState extends ConsumerState<HapticVideoPlayerScreen> {
  VideoPlayerController? _controller;
  Funscript? _funscript;
  final HapticVideoSyncService _syncService = HapticVideoSyncService();
  final HapticRecorderService _recorder = HapticRecorderService();
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _funscriptLoaded = false;
  bool _isFunscriptLoading = false;
  int _funscriptActionCount = 0;
  double _currentCh1Intensity = 0.0;
  double _currentCh2Intensity = 0.0;
  bool _showControls = true;
  Timer? _controlsTimer;
  String? _videoFileName;
  bool _hasError = false;
  String _errorMessage = '';
  bool _p2pEnabled = false;

  @override
  void initState() {
    super.initState();
    _syncService.onIntensityUpdate = _onIntensityUpdate;
    _syncService.onSyncStateChange = _onSyncStateChange;
    _recorder.onRecordingStateChange = _onRecordingStateChange;
    _recorder.onActionCountChange = _onActionCountChange;
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _syncService.dispose();
    _recorder.dispose();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _onIntensityUpdate() {
    if (!mounted) return;
    setState(() {
      _currentCh1Intensity = _syncService.currentCh1;
      _currentCh2Intensity = _syncService.currentCh2;
    });
  }

  void _onSyncStateChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _onRecordingStateChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _onActionCountChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _position = _controller!.value.position;
      _duration = _controller!.value.duration;
      _isPlaying = _controller!.value.isPlaying;

      if (_controller!.value.isCompleted) {
        _onVideoComplete();
      }
    });
  }

  void _onVideoComplete() {
    _syncService.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'],
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final fileName = result.files.single.name;

      await _loadVideo(path, fileName);
    } catch (e) {
      lvsLog('Error picking file: $e', tag: 'VIDEO_PLAYER');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error al seleccionar archivo: $e';
      });
    }
  }

  Future<void> _loadVideo(String path, String fileName) async {
    _syncService.stop();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();

    setState(() {
      _controller = null;
      _funscript = null;
      _isInitialized = false;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _funscriptLoaded = false;
      _funscriptActionCount = 0;
      _currentCh1Intensity = 0.0;
      _currentCh2Intensity = 0.0;
      _videoFileName = fileName;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final controller = VideoPlayerController.file(File(path));
      _controller = controller;
      controller.addListener(_onVideoUpdate);
      await controller.initialize();

      if (!mounted) return;

      setState(() => _isInitialized = true);

      _discoverFunscript(path);

      controller.play();
      setState(() => _isPlaying = true);

      _showControlsTemporarily();
      lvsLog('Video loaded: $fileName', tag: 'VIDEO_PLAYER');
    } catch (e) {
      lvsLog('Error loading video: $e', tag: 'VIDEO_PLAYER');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error al cargar video: $e';
        });
      }
    }
  }

  Future<void> _discoverFunscript(String videoPath) async {
    setState(() => _isFunscriptLoading = true);

    try {
      final scriptPath = await FunscriptLoader.findScriptForVideo(videoPath);

      if (scriptPath == null || !mounted) {
        setState(() {
          _isFunscriptLoading = false;
          _funscriptLoaded = false;
        });
        return;
      }

      final loader = FunscriptLoader();
      final script = await loader.load(path: scriptPath, useCache: true);

      if (script == null || !mounted) {
        setState(() {
          _isFunscriptLoading = false;
          _funscriptLoaded = false;
        });
        return;
      }

      setState(() {
        _funscript = script;
        _funscriptLoaded = true;
        _isFunscriptLoading = false;
        _funscriptActionCount = script.actionCount;
      });

      _initSync();

      lvsLog(
        'Funscript loaded: ${script.actionCount} actions, ${script.duration.inSeconds}s',
        tag: 'VIDEO_PLAYER',
      );
    } catch (e) {
      lvsLog('Error discovering funscript: $e', tag: 'VIDEO_PLAYER');
      if (mounted) {
        setState(() {
          _isFunscriptLoading = false;
          _funscriptLoaded = false;
        });
      }
    }
  }

  void _initSync() {
    if (_controller == null || _funscript == null) return;

    final ble = ref.read(bleProvider);
    final p2p = ref.read(p2pConnectionManagerProvider);

    _syncService.configure(
      controller: _controller!,
      funscript: _funscript!,
      ble: ble,
      p2p: p2p,
      enableP2P: _p2pEnabled,
    );

    if (_isPlaying) {
      _syncService.start();
    }
  }

  void _toggleP2P() {
    setState(() {
      _p2pEnabled = !_p2pEnabled;
      _syncService.setP2PEnabled(_p2pEnabled);
    });
  }

  void _toggleRecord() {
    if (_recorder.isRecording) {
      _recorder.cancelRecording();
    } else {
      _recorder.startRecording();
    }
  }

  Future<void> _saveRecording() async {
    final nameController = TextEditingController(
      text: 'grabacion_${DateTime.now().millisecondsSinceEpoch}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('GUARDAR GRABACIÓN',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre del archivo',
            hintStyle: TextStyle(color: LvsColors.text3),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: LvsColors.text3),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: LvsColors.pink),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('GUARDAR', style: TextStyle(color: LvsColors.pink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final path = await _recorder.stopAndSave(fileName: name);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grabación guardada: $path')),
        );
      }
    }
  }

  void _cancelRecording() {
    _recorder.cancelRecording();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_isPlaying) {
      _controller!.pause();
      _syncService.pause();
    } else {
      if (_controller!.value.isCompleted) {
        _controller!.seekTo(Duration.zero);
        _syncService.stop();
      }
      _controller!.play();
      if (_funscriptLoaded) {
        _syncService.resume();
      }
    }
    _showControlsTemporarily();
  }

  void _onSeek(double value) {
    if (_controller == null || !_isInitialized) return;

    final newPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );

    _controller!.seekTo(newPosition);
    _showControlsTemporarily();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_creation_rounded,
            size: 64,
            color: LvsColors.text3.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'SELECCIONA UN VIDEO',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: LvsColors.text3,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'mp4, mov, avi, mkv, webm, flv',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: LvsColors.text3.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: LvsColors.pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.pink.withValues(alpha: 0.4)),
              ),
              child: Text(
                'ABRIR ARCHIVO',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LvsColors.pink,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_isInitialized) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (_showControls) {
          _controlsTimer?.cancel();
          setState(() => _showControls = false);
        } else {
          _showControlsTemporarily();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_controller!),

          Center(
            child: _isPlaying
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
          ),

          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: HapticVideoControls(
                isPlaying: _isPlaying,
                position: _position,
                duration: _duration,
                onPlayPause: _togglePlayPause,
                onSeek: _onSeek,
                funscriptLoaded: _funscriptLoaded,
                isFunscriptLoading: _isFunscriptLoading,
                isBleConnected: ref.watch(bleProvider).state == BleState.connected,
                funscriptActionCount: _funscriptActionCount,
                currentCh1Intensity: _currentCh1Intensity,
                currentCh2Intensity: _currentCh2Intensity,
                bleDeviceCount: ref.watch(bleProvider).connectedDevices.length,
              ),
            ),

          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final p2p = ref.read(p2pConnectionManagerProvider);
    final isP2PConnected = p2p.isConnected;

    return Container(
      padding: EdgeInsets.fromLTRB(
        4,
        MediaQuery.of(context).padding.top + 4,
        4,
        8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _videoFileName ?? 'Video',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isP2PConnected)
                _topIconButton(
                  icon: _p2pEnabled ? Icons.sensors : Icons.sensors_off,
                  color: _p2pEnabled ? LvsColors.teal : LvsColors.text3,
                  tooltip: _p2pEnabled ? 'P2P activo' : 'Activar P2P',
                  onTap: _toggleP2P,
                ),
              _topIconButton(
                icon: Icons.folder_open_rounded,
                color: LvsColors.text2,
                tooltip: 'Abrir otro video',
                onTap: _pickVideo,
              ),
            ],
          ),
          if (_isInitialized)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
              child: Row(
                children: [
                  _buildBleStatus(),
                  const Spacer(),
                  HapticRecorderControls(
                    recorder: _recorder,
                    onToggleRecord: _toggleRecord,
                    onSave: _saveRecording,
                    onCancel: _cancelRecording,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBleStatus() {
    final ble = ref.watch(bleProvider);
    final isConnected = ble.state == BleState.connected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? LvsColors.teal : LvsColors.text3,
            boxShadow: isConnected
                ? [BoxShadow(color: LvsColors.teal.withValues(alpha: 0.6), blurRadius: 6)]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'BLE${isConnected ? " ${ble.connectedDevices.length}" : ""}',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isConnected ? LvsColors.teal : LvsColors.text3,
          ),
        ),
      ],
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildFunscriptInfoPanel() {
    if (!_funscriptLoaded && !_isFunscriptLoading) return const SizedBox.shrink();

    return Positioned(
      top: kToolbarHeight + 50,
      right: 12,
      child: CardGlass(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 10,
        borderColor: _funscriptLoaded
            ? LvsColors.pink.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _funscriptLoaded
                  ? '$_funscriptActionCount ACCIONES'
                  : 'BUSCANDO SCRIPT...',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _funscriptLoaded ? LvsColors.pink : LvsColors.text3,
                letterSpacing: 1,
              ),
            ),
            if (_funscriptLoaded && _funscript != null) ...[
              const SizedBox(height: 2),
              Text(
                '${(_funscript!.averageSpeed).toStringAsFixed(1)} acts/s',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  color: LvsColors.text3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            _isInitialized && _controller != null
                ? _buildVideoPlayer()
                : _buildEmptyState(),

            if (_hasError)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: CardGlass(
                  padding: const EdgeInsets.all(12),
                  borderColor: LvsColors.red.withValues(alpha: 0.4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: LvsColors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: LvsColors.text2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _hasError = false;
                          _errorMessage = '';
                        }),
                        child: const Icon(Icons.close, color: LvsColors.text3, size: 16),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isInitialized) _buildFunscriptInfoPanel(),
          ],
        ),
      ),
    );
  }
}

