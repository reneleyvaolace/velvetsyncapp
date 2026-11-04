// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/cloud_backup_service.dart
// Servicio de backup en la nube con Firebase Storage (migración desde Supabase)
// ════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velvet_sync/utils/logger.dart';

final cloudBackupServiceProvider = ChangeNotifierProvider<CloudBackupService>((ref) {
  return CloudBackupService(ref);
});

enum BackupMethod { firebase, file }

enum BackupStatus { idle, uploading, downloading, success, error }

class BackupEntry {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final String deviceId;

  BackupEntry({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    required this.deviceId,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory BackupEntry.fromJson(Map<String, dynamic> json) {
    return BackupEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Backup',
      sizeBytes: json['metadata'] is Map ? (json['metadata']['size'] as num? ?? 0).toInt() : 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      deviceId: json['metadata'] is Map ? (json['metadata']['device_id'] as String? ?? '') : '',
    );
  }
}

class BackupData {
  final String deviceId;
  final DateTime timestamp;
  final String appVersion;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> companionSettings;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> contacts;

  BackupData({
    required this.deviceId,
    required this.timestamp,
    required this.appVersion,
    required this.settings,
    required this.companionSettings,
    required this.profiles,
    required this.contacts,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'app_version': appVersion,
    'data': {
      'settings': settings,
      'companion_settings': companionSettings,
      'profiles': profiles,
      'contacts': contacts,
    },
  };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return BackupData(
      deviceId: json['device_id'] as String? ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      appVersion: json['app_version'] as String? ?? '',
      settings: data['settings'] as Map<String, dynamic>? ?? {},
      companionSettings: data['companion_settings'] as Map<String, dynamic>? ?? {},
      profiles: (data['profiles'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      contacts: (data['contacts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }
}

class CloudBackupService extends ChangeNotifier {
  final Ref _ref;
  BackupStatus _status = BackupStatus.idle;
  String? _lastError;
  List<BackupEntry> _backups = [];
  String? _deviceId;

  CloudBackupService(this._ref);

  BackupStatus get status => _status;
  String? get lastError => _lastError;
  List<BackupEntry> get backups => _backups;

  Future<String> _getDeviceId() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      return authUser.uid;
    }
    if (_deviceId != null) return _deviceId!;
    const storage = FlutterSecureStorage();
    _deviceId = await storage.read(key: 'backup_device_id');
    if (_deviceId == null) {
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await storage.write(key: 'backup_device_id', value: _deviceId);
    }
    return _deviceId!;
  }

  static const String _bucketName = 'user_backups';
  static const String _backupPath = 'backups';

  Future<bool> _ensureBucket() async {
    // Firebase Storage no requiere crear buckets explícitamente
    return true;
  }

  Future<BackupData> _collectBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('backup_')) continue;
      settings[key] = prefs.get(key);
    }

    return BackupData(
      deviceId: await _getDeviceId(),
      timestamp: DateTime.now(),
      appVersion: '1.4.0',
      settings: settings,
      companionSettings: {},
      profiles: [],
      contacts: [],
    );
  }

  void _applyBackupData(BackupData data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.settings.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
  }

  void _setStatus(BackupStatus s, {String? error}) {
    _status = s;
    _lastError = error;
    notifyListeners();
  }

  Future<bool> exportToCloud() async {
    _setStatus(BackupStatus.uploading);
    try {
      await _ensureBucket();

      final data = await _collectBackupData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
      final bytes = utf8.encode(jsonStr);
      final fileName = 'backup_${data.timestamp.toIso8601String().replaceAll(':', '-')}_${data.deviceId}.json';
      final filePath = '$_backupPath/$fileName';

      await FirebaseStorage.instance.ref(filePath).putData(bytes);

      lvsLog('Backup subido a Firebase Storage: $fileName (${bytes.length} bytes)', tag: 'BACKUP');
      _setStatus(BackupStatus.success);
      await listBackups();
      return true;
    } catch (e) {
      lvsLog('Error uploading backup: $e', tag: 'BACKUP');
      _setStatus(BackupStatus.error, error: e.toString());
      return false;
    }
  }

  Future<BackupData?> restoreFromCloud(String fileName) async {
    _setStatus(BackupStatus.downloading);
    try {
      final filePath = '$_backupPath/$fileName';
      final bytes = await FirebaseStorage.instance.ref(filePath).getData();
      if (bytes == null) throw Exception('Archivo no encontrado');
      final jsonStr = utf8.decode(bytes);
      final data = BackupData.fromJson(json.decode(jsonStr) as Map<String, dynamic>);

      _applyBackupData(data);
      lvsLog('Backup restaurado: $fileName', tag: 'BACKUP');
      _setStatus(BackupStatus.success);
      return data;
    } catch (e) {
      lvsLog('Error restoring backup: $e', tag: 'BACKUP');
      _setStatus(BackupStatus.error, error: e.toString());
      return null;
    }
  }

  Future<List<BackupEntry>> listBackups() async {
    try {
      final deviceId = await _getDeviceId();

      final result = await FirebaseStorage.instance.ref('backups').listAll();

      _backups = result.items
        .where((ref) => ref.name.contains(deviceId))
        .map((ref) => BackupEntry(
          id: ref.fullPath,
          name: ref.name,
          sizeBytes: 0, // Firebase Storage listAll no devuelve tamaño directamente
          createdAt: DateTime.now(), // Firebase Storage listAll no devuelve fecha directamente
          deviceId: deviceId,
        ))
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      notifyListeners();
      return _backups;
    } catch (e) {
      lvsLog('Error listing backups: $e', tag: 'BACKUP');
      return [];
    }
  }

  Future<bool> deleteCloudBackup(String fileName) async {
    try {
      final filePath = '$_backupPath/$fileName';
      await FirebaseStorage.instance.ref(filePath).delete();
      lvsLog('Backup eliminado: $fileName', tag: 'BACKUP');
      await listBackups();
      return true;
    } catch (e) {
      lvsLog('Error deleting backup: $e', tag: 'BACKUP');
      return false;
    }
  }

  Future<String?> exportToFile() async {
    _setStatus(BackupStatus.uploading);
    try {
      final data = await _collectBackupData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
      final dir = await getTemporaryDirectory();
      final fileName = 'velvet_sync_backup_${data.timestamp.toIso8601String().replaceAll(':', '-')}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);

      lvsLog('Backup exportado: ${file.path} (${jsonStr.length} bytes)', tag: 'BACKUP');
      _setStatus(BackupStatus.success);
      return file.path;
    } catch (e) {
      lvsLog('Error exporting backup: $e', tag: 'BACKUP');
      _setStatus(BackupStatus.error, error: e.toString());
      return null;
    }
  }

  Future<BackupData?> importFromFile(String filePath) async {
    _setStatus(BackupStatus.downloading);
    try {
      final file = File(filePath);
      final jsonStr = await file.readAsString();
      final data = BackupData.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
      _applyBackupData(data);
      lvsLog('Backup importado: $filePath', tag: 'BACKUP');
      _setStatus(BackupStatus.success);
      return data;
    } catch (e) {
      lvsLog('Error importing backup: $e', tag: 'BACKUP');
      _setStatus(BackupStatus.error, error: e.toString());
      return null;
    }
  }

  void resetStatus() {
    _status = BackupStatus.idle;
    _lastError = null;
    notifyListeners();
  }
}
