// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/multimedia_player_screen.dart
// Reproductor multimedia con sincronización háptica (GamePath)
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/services/ble/ble_types.dart';
import 'package:velvet_sync/services/media/haptic_video_sync_service.dart';
import 'package:velvet_sync/services/media/video_cache_service.dart';
import 'package:velvet_sync/services/media/funscript_loader.dart';
import 'package:velvet_sync/devices/models/funscript.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:velvet_sync/widgets/haptic_video_controls.dart';

class MultimediaPlayerScreen extends ConsumerStatefulWidget {
  final ToyModel toy;
  final String gamePath;
  final String? funscriptPath; // Opcional: funscript local para sincronización precisa

  const MultimediaPlayerScreen({
    super.key,
    required this.toy,
    required this.gamePath,
    this.funscriptPath,
  });

  @override
  ConsumerState<MultimediaPlayerScreen> createState() => _MultimediaPlayerScreenState();
}

class _MultimediaPlayerScreenState extends ConsumerState<MultimediaPlayerScreen> {
  VideoPlayerController? _controller;
  final HapticVideoSyncService _syncService = HapticVideoSyncService();
  final VideoCacheService _cacheService = VideoCacheService();

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Funscript? _funscript;
  bool _funscriptLoaded = false;
  bool _isFunscriptLoading = false;
  int _funscriptActionCount = 0;
  double _currentCh1Intensity = 0.0;
  double _currentCh2Intensity = 0.0;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);

    try {
      // Inicializar caché de video
      await _cacheService.init();

      // Descargar y preparar video
      lvsLog('Cargando multimedia: ${widget.gamePath}', tag: 'MULTIMEDIA');
      final localPath = await _cacheService.getVideoPath(widget.gamePath);

      if (localPath == null) {
        throw Exception('No se pudo descargar el video');
      }

      // Cargar video
      final controller = VideoPlayerController.file(File(localPath));
      _controller = controller;
      controller.addListener(_onVideoUpdate);
      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _duration = controller.value.duration;
      });

      // Buscar funscript local si no se proporcionó
      if (widget.funscriptPath == null) {
        await _discoverFunscript(localPath);
      } else {
        await _loadFunscript(widget.funscriptPath!);
      }

      // Configurar sincronización háptica
      _initSync();

      // Iniciar reproducción
      controller.play();
      setState(() => _isPlaying = true);

      lvsLog('Multimedia iniciado: ${widget.toy.name}', tag: 'MULTIMEDIA');
    } catch (e) {
      lvsLog('Error iniciando multimedia: $e', tag: 'MULTIMEDIA');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _discoverFunscript(String videoPath) async {
    setState(() => _isFunscriptLoading = true);
    try {
      final scriptPath = await FunscriptLoader.findScriptForVideo(videoPath);
      if (scriptPath != null) {
        await _loadFunscript(scriptPath);
      }
    } catch (e) {
      lvsLog('Error buscando funscript: $e', tag: 'MULTIMEDIA');
    } finally {
      if (mounted) setState(() => _isFunscriptLoading = false);
    }
  }

  Future<void> _loadFunscript(String path) async {
    try {
      final loader = FunscriptLoader();
      final script = await loader.load(path: path, useCache: true);
      if (script != null && mounted) {
        setState(() {
          _funscript = script;
          _funscriptLoaded = true;
          _funscriptActionCount = script.actionCount;
        });
        _initSync();
      }
    } catch (e) {
      lvsLog('Error cargando funscript: $e', tag: 'MULTIMEDIA');
    }
  }

  void _initSync() {
    if (_controller == null || _funscript == null) return;
    final ble = ref.read(bleProvider);
    _syncService.configure(
      controller: _controller!,
      funscript: _funscript!,
      ble: ble,
      enableP2P: false, // Modo local
    );
    if (_isPlaying) _syncService.start();
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

  @override
  void dispose() {
    _positionTimer?.cancel();
    _syncService.dispose();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
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
    setState(() => _isPlaying = !_isPlaying);
  }

  void _onSeek(double value) {
    if (_controller == null || !_isInitialized) return;
    final newPosition = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    _controller!.seekTo(newPosition);
  }

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
    final ble = ref.watch(bleProvider);

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: Text(widget.toy.name),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_funscriptLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.psychology, size: 14, color: LvsColors.pink),
                label: Text('$_funscriptActionCount acciones',
                    style: GoogleFonts.outfit(fontSize: 10, color: LvsColors.pink)),
                backgroundColor: LvsColors.pink.withValues(alpha: 0.15),
                side: BorderSide(color: LvsColors.pink.withValues(alpha: 0.3)),
              ),
            ),
          if (ble.state == BleState.connected)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.bluetooth_connected, size: 14, color: LvsColors.teal),
                label: Text('BLE',
                    style: GoogleFonts.outfit(fontSize: 10, color: LvsColors.teal)),
                backgroundColor: LvsColors.teal.withValues(alpha: 0.15),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.bluetooth_disabled, size: 14, color: LvsColors.text3),
                label: Text('OFFLINE',
                    style: GoogleFonts.outfit(fontSize: 10, color: LvsColors.text3)),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _hasError
              ? _buildError()
              : _buildPlayer(ble),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: LvsColors.pink, strokeWidth: 3),
          const SizedBox(height: 24),
          Text('CARGANDO MULTIMEDIA',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: LvsColors.text2, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Descargando video...',
              style: GoogleFonts.outfit(fontSize: 12, color: LvsColors.text3)),
          const SizedBox(height: 8),
          Text(widget.toy.name,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: LvsColors.pink)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: LvsColors.red),
            const SizedBox(height: 16),
            Text('ERROR CARGANDO MULTIMEDIA',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: LvsColors.red, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Text(_errorMessage,
                style: GoogleFonts.outfit(fontSize: 12, color: LvsColors.text3),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _init(),
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LvsColors.pink,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(BleService ble) {
    return Stack(
      children: [
        // Video Player
        _isInitialized && _controller != null
            ? GestureDetector(
                onTap: _togglePlayPause,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_controller!),
                    // Overlay play/pause
                    Center(
                      child: _isPlaying
                          ? const SizedBox.shrink()
                          : GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.5),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
                              ),
                            ),
                    ),
                    // Controles
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
            : _buildEmptyState(),
        // Indicador de error
        if (_hasError)
          Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Card(
              color: LvsColors.red.withValues(alpha: 0.9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errorMessage,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_creation_rounded, size: 64, color: LvsColors.text3.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('VIDEO NO DISPONIBLE',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: LvsColors.text3, letterSpacing: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _init,
            icon: const Icon(Icons.refresh),
            label: const Text('REINTENTAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LvsColors.pink,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}