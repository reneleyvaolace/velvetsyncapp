// ═══════════════════════════════════════════════════════════════
// Velvet Sync · Companion Settings
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CompanionGender {
  female('Mujer', 'Femenino'),
  male('Hombre', 'Masculino'),
  nonbinary('No binario', 'Neutro/Universal'),
  android('Androide', 'Sintético');

  final String displayName;
  final String description;
  const CompanionGender(this.displayName, this.description);
}

enum CompanionPersonality {
  submissive('Sumisa', 'Dulce, complaciente y cariñosa'),
  dominant('Dominante', 'Autoritaria, exigente y controladora'),
  playful('Juguetona', 'Divertida, traviesa y energética'),
  caring('Cariñosa', 'Protectora, maternal y tierna'),
  neutral('Neutral', 'Equilibrada y adaptable');

  final String displayName;
  final String description;
  const CompanionPersonality(this.displayName, this.description);
}

class CompanionSettings {
  String name;
  CompanionGender gender;
  CompanionPersonality personality;
  bool saveConversations;
  bool syncWithSupabase;

  CompanionSettings({
    this.name = 'Velvet',
    this.gender = CompanionGender.female,
    this.personality = CompanionPersonality.neutral,
    this.saveConversations = true,
    this.syncWithSupabase = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender.name,
    'personality': personality.name,
    'saveConversations': saveConversations,
    'syncWithSupabase': syncWithSupabase,
  };

  factory CompanionSettings.fromJson(Map<String, dynamic> json) => CompanionSettings(
    name: json['name'] ?? 'Velvet',
    gender: CompanionGender.values.firstWhere(
      (e) => e.name == json['gender'],
      orElse: () => CompanionGender.female,
    ),
    personality: CompanionPersonality.values.firstWhere(
      (e) => e.name == json['personality'],
      orElse: () => CompanionPersonality.neutral,
    ),
    saveConversations: json['saveConversations'] ?? true,
    syncWithSupabase: json['syncWithSupabase'] ?? false,
  );
}

class CompanionService {
  static final CompanionService _instance = CompanionService._internal();
  factory CompanionService() => _instance;
  CompanionService._internal();

  final _storage = const FlutterSecureStorage();
  final supabase = Supabase.instance.client;
  CompanionSettings? _settings;
  static const String _settingsKey = 'companion_settings';

  Future<CompanionSettings> getSettings() async {
    if (_settings != null) return _settings!;
    final jsonStr = await _storage.read(key: _settingsKey);
    if (jsonStr != null) {
      _settings = CompanionSettings.fromJson(json.decode(jsonStr));
    } else {
      _settings = CompanionSettings();
      await saveSettings(_settings!);
    }
    return _settings!;
  }

  Future<void> saveSettings(CompanionSettings settings) async {
    _settings = settings;
    await _storage.write(key: _settingsKey, value: json.encode(settings.toJson()));
    if (settings.syncWithSupabase) {
      await _syncToSupabase(settings);
    }
  }

  Future<void> _syncToSupabase(CompanionSettings settings) async {
    try {
      // 🔒 SECURITY: Require proper authentication - reject anonymous sync
      final userId = await _storage.read(key: 'user_id');

      if (userId == null || userId.isEmpty || userId == 'anonymous') {
        throw StateError('Cannot sync companion settings: User not authenticated. Please log in first.');
      }

      // Validate userId format (prevent injection attacks)
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,255}$').hasMatch(userId)) {
        throw FormatException('Invalid user_id format: User ID contains invalid characters');
      }

      await supabase.from('companion_settings').upsert({
        'user_id': userId,
        'name': settings.name,
        'gender': settings.gender.name,
        'personality': settings.personality.name,
        'save_conversations': settings.saveConversations,
        'sync_with_supabase': settings.syncWithSupabase,
        'updated_at': DateTime.now().toIso8601String(),
      });

      lvsLog('Companion settings synced for user: $userId', tag: 'COMPANION');
    } catch (e) {
      lvsLog('Error syncing Companion to Supabase: $e', tag: 'COMPANION');
      rethrow;
    }
  }
}
