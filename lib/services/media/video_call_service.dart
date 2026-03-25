// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/video_call_service.dart
// STUB - Agora RTC Engine (Disabled for analysis cleanup)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:velvet_sync/utils/logger.dart';

final videoCallServiceProvider = Provider<VideoCallService>((ref) {
  return VideoCallService();
});

final isVideoCallActiveProvider = StateProvider<bool>((ref) => false);
final videoParticipantsProvider = StateProvider<List<VideoParticipant>>((ref) => []);
final agoraEngineProvider = Provider<dynamic>((ref) => null);

class VideoParticipant {
  final String userId;
  final String displayName;
  final int remoteUid;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isScreenSharing;
  final DateTime joinedAt;

  const VideoParticipant({
    required this.userId,
    required this.displayName,
    this.remoteUid = 0,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.isScreenSharing = false,
    required this.joinedAt,
  });
}

class VideoCallService extends ChangeNotifier {
  static final VideoCallService _instance = VideoCallService._internal();
  factory VideoCallService() => _instance;
  VideoCallService._internal();

  dynamic _engine;
  bool _isInCall = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isScreenSharing = false;
  String? _channelId;
  final int _localUid = 0;
  final List<VideoParticipant> _participants = [];
  String? _lastError;
  bool _isInitialized = false;

  dynamic get engine => _engine;
  bool get isInCall => _isInCall;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isScreenSharing => _isScreenSharing;
  String? get channelId => _channelId;
  int get localUid => _localUid;
  List<VideoParticipant> get participants => List.unmodifiable(_participants);
  String? get lastError => _lastError;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({String? appId, String? token}) async {
    lvsLog('Video service STUB inicializado (Agora desactivado)', tag: 'VIDEO');
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> joinCall({
    required String sessionId,
    required String userId,
    required String displayName,
    String? token,
  }) async {
    lvsLog('Video call STUB: No se puede unir (Agora desactivado)', tag: 'VIDEO');
    return false;
  }

  Future<void> leaveCall() async {
    _isInCall = false;
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    _isVideoEnabled = !_isVideoEnabled;
    notifyListeners();
  }

  Future<void> toggleAudio() async {
    _isAudioEnabled = !_isAudioEnabled;
    notifyListeners();
  }

  Future<void> toggleScreenShare() async {
    _isScreenSharing = !_isScreenSharing;
    notifyListeners();
  }

  Future<void> switchCamera() async {}

  Future<void> enableRemoteVideo(int remoteUid, bool enabled) async {}
  Future<void> enableRemoteAudio(int remoteUid, bool enabled) async {}

  dynamic getLocalVideoView() => null;
  dynamic getRemoteVideoView(int remoteUid) => null;
  
  String getVideoInviteUrl() => '';
  Future<bool> checkPermissions() async => true;
  Future<bool> requestPermissions() async => true;

}
