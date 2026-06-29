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
import 'package:velvet_sync/services/media/remote_haptic_receiver.dart';
import 'package:velvet_sync/widgets/haptic_video_controls.dart';
import 'package:velvet_sync/utils/logger.dart';

enum RemoteVideoRole { host, guest }

class RemoteVideoSyncScreen extends ConsumerStatefulWidget {
  final RemoteVideoRole role;
  final String? accessToken;

  const RemoteVideoSyncScreen({
    super.key,
    required this.role,
    this.accessToken,
  });

  @override
  ConsumerState<RemoteVideoSyncScreen> createState() => _RemoteVideoSyncScreenState();
}

class _RemoteVideoSyncScreenState extends ConsumerState<RemoteVideoSyncScreen> {
  VideoPlayerController? _controller;
  Funscript? _funscript;
  final HapticVideoSyncService _syncService = HapticVideoSyncService();
  final RemoteHapticReceiver _receiver = RemoteHapticReceiver();
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _funscriptLoaded = false;
  bool _isFunscriptLoading = false;
  int _funscriptActionCount = 0;
  double _currentCh1Intensity = 0.0;
  double _currentCh2Intensity = 0.0;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isHostSyncing = false;
  Timer? _positionSyncTimer;

  @override
  void initState() {
    super.initState();
    _syncService.onIntensityUpdate = _onIntensityUpdate;
    _syncService.onSyncStateChange = _onSyncStateChange;

    if (widget.role == RemoteVideoRole.guest) {
      _startGuestReceiver();
    }
  }

  @override
  void dispose() {
    _positionSyncTimer?.cancel();
    _syncService.dispose();
    _receiver.dispose();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _startGuestReceiver() {
    final p2p = ref.read(p2pConnectionManagerProvider);
    final ble = ref.read(bleProvider);
    _receiver.onHapticReceived = () {
      if (mounted) setState(() {});
    };
    _receiver.onConnectionChange = () {
      if (mounted) setState(() {});
    };
    _receiver.startListening(p2p: p2p, ble: ble);
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

  void _onVideoUpdate() {
    if (!mounted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _position = _controller!.value.position;
      _duration = _controller!.value.duration;
      _isPlaying = _controller!.value.isPlaying;
    });
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'],
      );
      if (result == null || result.files.single.path == null) return;
      await _loadVideo(result.files.single.path!, result.files.single.name);
    } catch (e) {
      setState(() { _hasError = true; _errorMessage = 'Error: $e'; });
    }
  }

  Future<void> _loadVideo(String path, String fileName) async {
    _syncService.stop();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();

    setState(() {
      _controller = null; _funscript = null; _isInitialized = false;
      _isPlaying = false; _position = Duration.zero; _duration = Duration.zero;
      _funscriptLoaded = false; _funscriptActionCount = 0;
      _currentCh1Intensity = 0.0; _currentCh2Intensity = 0.0;
      _hasError = false;
    });

    try {
      final controller = VideoPlayerController.file(File(path));
      _controller = controller;
      controller.addListener(_onVideoUpdate);
      await controller.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
      await _discoverFunscript(path);
      controller.play();
      setState(() => _isPlaying = true);
      if (widget.role == RemoteVideoRole.host) _startPositionSync();
      lvsLog('Remote video loaded: $fileName', tag: 'REMOTE_VIDEO');
    } catch (e) {
      setState(() { _hasError = true; _errorMessage = 'Error: $e'; });
    }
  }

  Future<void> _discoverFunscript(String videoPath) async {
    setState(() => _isFunscriptLoading = true);
    try {
      final scriptPath = await FunscriptLoader.findScriptForVideo(videoPath);
      if (scriptPath == null || !mounted) {
        setState(() { _isFunscriptLoading = false; _funscriptLoaded = false; });
        return;
      }
      final loader = FunscriptLoader();
      final script = await loader.load(path: scriptPath, useCache: true);
      if (script == null || !mounted) {
        setState(() { _isFunscriptLoading = false; _funscriptLoaded = false; });
        return;
      }
      setState(() {
        _funscript = script; _funscriptLoaded = true;
        _isFunscriptLoading = false; _funscriptActionCount = script.actionCount;
      });
      _initSync();
    } catch (e) {
      setState(() { _isFunscriptLoading = false; _funscriptLoaded = false; });
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
      enableP2P: widget.role == RemoteVideoRole.host && p2p.isConnected,
    );
    if (_isPlaying) _syncService.start();
  }

  void _startPositionSync() {
    _positionSyncTimer?.cancel();
    _isHostSyncing = true;
    _positionSyncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_controller == null || !_isHostSyncing) return;
      final p2p = ref.read(p2pConnectionManagerProvider);
      if (!p2p.isConnected) return;
      p2p.sendCommand(
        intensityCh1: _controller!.value.position.inMilliseconds,
        intensityCh2: _isPlaying ? 1 : 0,
        commandType: 'video_position',
      );
    });
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
      if (_funscriptLoaded) _syncService.resume();
    }
  }

  void _onSeek(double value) {
    if (_controller == null || !_isInitialized) return;
    final newPosition = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    _controller!.seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    final p2p = ref.watch(p2pConnectionManagerProvider);
    final ble = ref.watch(bleProvider);

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: Text(widget.role == RemoteVideoRole.host ? 'VIDEO HOST' : 'VIDEO GUEST'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.role == RemoteVideoRole.host)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildConnectionChip(p2p),
            ),
          if (widget.role == RemoteVideoRole.guest)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildReceiverChip(),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _isInitialized && _controller != null
                ? GestureDetector(
                    onTap: () {},
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
                                    width: 72, height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.5),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                  ),
                                ),
                        ),
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: HapticVideoControls(
                            isPlaying: _isPlaying,
                            position: _position,
                            duration: _duration,
                            onPlayPause: _togglePlayPause,
                            onSeek: _onSeek,
                            funscriptLoaded: _funscriptLoaded,
                            isFunscriptLoading: _isFunscriptLoading,
                            isBleConnected: ble.state == BleState.connected,
                            funscriptActionCount: _funscriptActionCount,
                            currentCh1Intensity: _currentCh1Intensity,
                            currentCh2Intensity: _currentCh2Intensity,
                            bleDeviceCount: ble.connectedDevices.length,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildGuestOrEmpty(p2p),
            if (_hasError)
              Positioned(
                bottom: 100, left: 20, right: 20,
                child: CardGlass(
                  padding: const EdgeInsets.all(12),
                  borderColor: LvsColors.red.withValues(alpha: 0.4),
                  child: Text(_errorMessage, style: GoogleFonts.outfit(fontSize: 11, color: LvsColors.text2)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionChip(P2PConnectionManager p2p) {
    final connected = p2p.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: connected ? LvsColors.teal.withValues(alpha: 0.15) : LvsColors.text3.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: connected ? LvsColors.teal.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? LvsColors.teal : LvsColors.text3,
              boxShadow: connected ? [const BoxShadow(color: LvsColors.teal, blurRadius: 4)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'P2P' : 'OFF',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: connected ? LvsColors.teal : LvsColors.text3,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverChip() {
    final active = _receiver.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? LvsColors.pink.withValues(alpha: 0.15) : LvsColors.text3.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? LvsColors.pink.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? LvsColors.pink : LvsColors.text3,
              boxShadow: active ? [const BoxShadow(color: LvsColors.pink, blurRadius: 4)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'RECIBIENDO' : 'ESPERANDO',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: active ? LvsColors.pink : LvsColors.text3,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestOrEmpty(P2PConnectionManager p2p) {
    if (widget.role == RemoteVideoRole.guest) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, size: 64, color: _receiver.isActive ? LvsColors.pink : LvsColors.text3),
            const SizedBox(height: 16),
            Text(
              _receiver.isActive ? 'RECIBIENDO HAPTICS' : 'ESPERANDO SEÑAL',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: LvsColors.text2),
            ),
            if (!_receiver.isActive) ...[
              const SizedBox(height: 8),
              Text(
                'Conéctate a una sesión P2P para recibir',
                style: GoogleFonts.outfit(fontSize: 11, color: LvsColors.text3),
              ),
            ],
          ],
        ),
      );
    }

    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_creation_rounded, size: 64, color: LvsColors.text3.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('SELECCIONA UN VIDEO', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: LvsColors.text3, letterSpacing: 1.5)),
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
              child: Text('ABRIR ARCHIVO', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: LvsColors.pink, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }
}
