// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/firestore_service.dart
// Servicio de Firestore (migración desde Supabase)
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/config/app_env.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/utils/logger.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

class FirestoreService {
  static bool _isInitialized = false;

  FirestoreService();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Canales de comunicación (reemplaza Realtime Channels de Supabase)
  StreamSubscription? _sessionSubscription;
  String? _currentSessionId;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      lvsLog('Firestore inicializado OK', tag: 'FIRESTORE');
    } catch (e) {
      lvsLog('❌ Error crítico inicializando Firestore: $e', tag: 'FIRESTORE');
      rethrow;
    }
  }

  String? get currentUserId => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  // 1. Catálogo de dispositivos (device_catalog → devices collection)
  // ─────────────────────────────────────────────────────────────

  /// Obtiene el catálogo de dispositivos desde Firestore
  Future<List<ToyModel>> fetchDeviceCatalog({int limit = 2000}) async {
    if (!_isInitialized) return [];
    try {
      final snapshot = await _db
          .collection('devices')
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs
          .map((doc) => ToyModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      lvsLog('Error fetchCatalog: $e', tag: 'FIRESTORE');
      return [];
    }
  }

  /// Busca dispositivo individual por ID
  Future<ToyModel?> fetchDeviceById(String id) async {
    if (!_isInitialized) return null;
    try {
      final doc = await _db
          .collection('devices')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) return null;
      return ToyModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      lvsLog('Error fetchDeviceById: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Sesiones Compartidas (shared_sessions → sessions collection)
  // ─────────────────────────────────────────────────────────────

  /// Crea una nueva sesión compartida en Firestore
  Future<Map<String, dynamic>?> createSharedSession(
    String deviceId, {
    String? hostName,
  }) async {
    if (!_isInitialized) return null;

    try {
      final docRef = await _db.collection('sessions').add({
        'device_id': deviceId,
        'is_active': true,
        if (hostName != null) 'host_name': hostName,
        if (currentUserId != null) 'host_user_id': currentUserId,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final doc = await docRef.get();
      lvsLog('Sesión creada: ID ${doc.id}', tag: 'FIRESTORE');
      return doc.data();
    } catch (e) {
      lvsLog('❌ Error fatal en createSharedSession ($deviceId): $e', tag: 'FIRESTORE');
      rethrow;
    }
  }

  /// Obtiene una sesión por token de acceso
  Future<Map<String, dynamic>?> fetchSessionByToken(String token) async {
    if (!_isInitialized) return null;

    try {
      final snapshot = await _db
          .collection('sessions')
          .where('access_token', isEqualTo: token)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        lvsLog('Sesión no encontrada, expirada o inactiva', tag: 'FIRESTORE');
        return null;
      }

      return snapshot.docs.first.data();
    } catch (e) {
      lvsLog('Error fetchSessionByToken: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  /// Obtiene el historial de sesiones
  Future<List<Map<String, dynamic>>> fetchSessionHistory({int limit = 50}) async {
    if (!_isInitialized) return const [];
    try {
      final snapshot = await _db
          .collection('sessions')
          .where('ended_at', isNotEqualTo: null)
          .orderBy('started_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      lvsLog('Error fetchSessionHistory: $e', tag: 'FIRESTORE');
      return const [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Tiempo de sesión (autoritativo en servidor - Firestore)
  // ─────────────────────────────────────────────────────────────

  Future<DateTime?> startSessionTiming(String sessionId, int durationSeconds) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'started_at': FieldValue.serverTimestamp(),
        'duration_seconds': durationSeconds,
        'ended_at': null,
        'ended_reason': null,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return DateTime.now();
    } catch (e) {
      lvsLog('Error startSessionTiming: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  Future<void> endSessionTiming(String sessionId, String reason) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'ended_at': FieldValue.serverTimestamp(),
        'ended_reason': reason,
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      lvsLog('Error endSessionTiming: $e', tag: 'FIRESTORE');
    }
  }

  Future<int?> fetchRemainingSeconds(String sessionId) async {
    try {
      final doc = await _db.collection('sessions').doc(sessionId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final duration = data['duration_seconds'] as int? ?? 0;
      if (duration <= 0) return null;

      final startedAt = data['started_at'] as Timestamp?;
      if (startedAt == null) return null;

      final endedAt = data['ended_at'] as Timestamp?;
      final now = DateTime.now();
      final endTime = endedAt != null ? endedAt.toDate() : now;

      final elapsed = endTime.difference(startedAt.toDate()).inSeconds;
      final remaining = duration - elapsed;

      return remaining > 0 ? remaining : 0;
    } catch (e) {
      lvsLog('Error fetchRemainingSeconds: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  Future<void> pauseSessionTiming(String sessionId) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'paused_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      lvsLog('Error pauseSessionTiming: $e', tag: 'FIRESTORE');
    }
  }

  Future<int?> resumeSessionTiming(String sessionId) async {
    try {
      final doc = await _db.collection('sessions').doc(sessionId).get();
      if (!doc.exists) return null;

      final pausedAt = doc.data()?['paused_at'] as Timestamp?;
      if (pausedAt == null) return null;

      final pauseMs = DateTime.now().difference(pausedAt.toDate()).inMilliseconds;

      await _db.collection('sessions').doc(sessionId).update({
        'paused_total_ms': FieldValue.increment(pauseMs),
        'paused_at': null,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return fetchRemainingSeconds(sessionId);
    } catch (e) {
      lvsLog('Error resumeSessionTiming: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  /// Envía un comando de transmisión a la sesión (alias para sendSessionCommand)
  Future<void> sendBroadcastCommand(String sessionId, String key, int value) async {
    await sendSessionCommand(sessionId, key, value);
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Comunicación en tiempo real (reemplaza Realtime Channels)
  // ─────────────────────────────────────────────────────────────

  /// Se une a una sala de sesión en tiempo real vía Firestore
  Stream<Map<String, dynamic>> joinSessionRoom(
    String sessionId,
  ) async* {
    _currentSessionId = sessionId;

    yield* _db
        .collection('sessions')
        .doc(sessionId)
        .collection('commands')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return <String, dynamic>{};
    });
  }

  /// Envía un comando a la sesión vía Firestore
  Future<void> sendSessionCommand(
    String sessionId,
    String key,
    int value, {
    String senderId = 'client',
  }) async {
    if (!_isInitialized) return;

    try {
      await _db
          .collection('sessions')
          .doc(sessionId)
          .collection('commands')
          .add({
        'key': key,
        'value': value,
        'sender_id': senderId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      lvsLog('Error sendSessionCommand: $e', tag: 'FIRESTORE');
    }
  }

  /// Envía parada remota
  Future<void> sendRemoteStop(String sessionId, [String reason = 'manual']) async {
    await sendSessionCommand(sessionId, 'stop', 1, senderId: 'client');
    lvsLog('STOP remoto enviado ($reason)', tag: 'FIRESTORE');
  }

  /// Abandona la sala de sesión
  void leaveSessionRoom() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _currentSessionId = null;
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Perfiles de usuario (profiles → users collection)
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (!_isInitialized) return null;
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      lvsLog('Error getUserProfile: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  Future<void> saveUserProfile(String userId, Map<String, dynamic> data) async {
    if (!_isInitialized) return;
    try {
      await _db.collection('users').doc(userId).set(data, SetOptions(merge: true));
    } catch (e) {
      lvsLog('Error saveUserProfile: $e', tag: 'FIRESTORE');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Contactos
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getContacts(String userId) async {
    if (!_isInitialized) return const [];
    try {
      final snapshot = await _db
          .collection('contacts')
          .where('user_id', isEqualTo: userId)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      lvsLog('Error getContacts: $e', tag: 'FIRESTORE');
      return const [];
    }
  }

  Future<void> addContact({
    required String userId,
    required String contactUserId,
  }) async {
    if (!_isInitialized) return;
    try {
      await _db.collection('contacts').add({
        'user_id': userId,
        'contact_user_id': contactUserId,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      lvsLog('Error addContact: $e', tag: 'FIRESTORE');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Backup en la nube (reemplaza Supabase Storage)
  // ─────────────────────────────────────────────────────────────

  /// Sube un archivo de backup a Firestore (metadata) + Firebase Storage (archivo)
  /// Nota: Para archivos grandes, usar Firebase Storage directamente
  Future<String?> uploadBackupMetadata({
    required String userId,
    required String fileName,
    required int fileSize,
    required String downloadUrl,
  }) async {
    if (!_isInitialized) return null;
    try {
      final docRef = await _db.collection('backups').add({
        'user_id': userId,
        'file_name': fileName,
        'file_size': fileSize,
        'download_url': downloadUrl,
        'created_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      lvsLog('Error uploadBackupMetadata: $e', tag: 'FIRESTORE');
      return null;
    }
  }

  void dispose() {
    _sessionSubscription?.cancel();
  }
}
