// ════════════════════════════════════════════════════════════════
// Velvet Sync · Companion Settings (Firebase Firestore)
// ════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:velvet_sync/utils/logger.dart';

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
  bool syncWithFirestore;

  CompanionSettings({
    this.name = 'Velvet',
    this.gender = CompanionGender.female,
    this.personality = CompanionPersonality.neutral,
    this.saveConversations = true,
    this.syncWithFirestore = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender.name,
    'personality': personality.name,
    'saveConversations': saveConversations,
    'syncWithFirestore': syncWithFirestore,
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
    syncWithFirestore: json['syncWithFirestore'] ?? false,
  );
}

class CompanionService {
  static final CompanionService _instance = CompanionService._internal();
  factory CompanionService() => _instance;
  CompanionService._internal();

  final _storage = const FlutterSecureStorage();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  CompanionSettings? _settings;
  static const String _settingsKey = 'companion_settings';

  String? get _currentUserId => _auth.currentUser?.uid;

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
    if (settings.syncWithFirestore) {
      await _syncToFirestore(settings);
    }
  }

  Future<void> _syncToFirestore(CompanionSettings settings) async {
    try {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        throw StateError('Cannot sync companion settings: User not authenticated. Please log in first.');
      }

      await _firestore.collection('companion_settings').doc(userId).set({
        'user_id': userId,
        'name': settings.name,
        'gender': settings.gender.name,
        'personality': settings.personality.name,
        'save_conversations': settings.saveConversations,
        'sync_with_firestore': settings.syncWithFirestore,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      lvsLog('Companion settings synced for user: $userId', tag: 'COMPANION');
    } catch (e) {
      lvsLog('Error syncing Companion to Firestore: $e', tag: 'COMPANION');
      rethrow;
    }
  }
}
