// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/profile_service.dart
// Servicio de perfiles de usuario con Firebase Firestore
// ════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velvet_sync/devices/models/user_profile.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:path/path.dart' as p;

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

enum ProfileError {
  notFound,
  usernameTaken,
  invalidUsername,
  networkError,
  tableNotFound,
  notAuthenticated,
  unknown,
}

extension ProfileErrorExtension on ProfileError {
  String get message {
    switch (this) {
      case ProfileError.notFound:
        return 'Profile not found';
      case ProfileError.usernameTaken:
        return 'Username is already taken';
      case ProfileError.invalidUsername:
        return 'Username must be 3-20 characters, alphanumeric with underscores';
      case ProfileError.networkError:
        return 'Network error, please try again';
      case ProfileError.tableNotFound:
        return 'Profiles collection does not exist';
      case ProfileError.notAuthenticated:
        return 'User is not authenticated';
      case ProfileError.unknown:
        return 'An unknown error occurred';
    }
  }
}

class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  UserProfile? _myProfile;
  bool _isLoading = false;

  UserProfile? get myProfile => _myProfile;
  bool get isLoading => _isLoading;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ── SharedPreferences keys ──────────────────────────────────
  static const String _prefsKey = 'profile_cache';

  /// Load cached profile from SharedPreferences
  Future<void> loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        _myProfile = UserProfile.fromJson(json);
        lvsLog('Cached profile loaded: ${_myProfile?.username}', tag: 'PROFILE');
        notifyListeners();
      }
    } catch (e) {
      lvsError('Error loading cached profile: $e', tag: 'PROFILE');
    }
  }

  /// Save profile to SharedPreferences cache
  Future<void> _cacheProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(profile.toJson()));
    } catch (e) {
      lvsError('Error caching profile: $e', tag: 'PROFILE');
    }
  }

  /// Clear cached profile
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      _myProfile = null;
      notifyListeners();
    } catch (e) {
      lvsError('Error clearing profile cache: $e', tag: 'PROFILE');
    }
  }

  /// Validate username format
  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    return regex.hasMatch(username);
  }

  /// Create a new profile for the current user
  Future<Result<UserProfile, ProfileError>> createProfile(
    String username,
    String displayName, {
    String? avatarUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      var userId = _currentUserId;
      if (userId == null) {
        lvsLog('Intentando auth anónima de respaldo...', tag: 'PROFILE');
        try {
          await _auth.signInAnonymously();
          userId = _currentUserId;
        } catch (e) {
          lvsError('Fallo auth anónima de respaldo: $e', tag: 'PROFILE');
        }

        if (userId == null) {
          lvsError('Not authenticated', tag: 'PROFILE');
          _isLoading = false;
          notifyListeners();
          return const Failure(ProfileError.notAuthenticated);
        }
      }

      if (!_isValidUsername(username)) {
        lvsError('Invalid username format: $username', tag: 'PROFILE');
        _isLoading = false;
        notifyListeners();
        return const Failure(ProfileError.invalidUsername);
      }

      // Verificar si el username ya existe
      final existing = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        lvsError('Username taken: $username', tag: 'PROFILE');
        _isLoading = false;
        notifyListeners();
        return const Failure(ProfileError.usernameTaken);
      }

      final profile = UserProfile(
        id: userId,
        username: username.toLowerCase(),
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

      await _firestore.collection('users').doc(userId).set(profile.toJson());

      _myProfile = profile;
      await _cacheProfile(profile);
      _isLoading = false;
      notifyListeners();
      lvsLog('Profile created: ${profile.username}', tag: 'PROFILE');
      return Success(profile);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      lvsError('Error creating profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Get the profile of the currently authenticated user
  Future<Result<UserProfile, ProfileError>> getMyProfile() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const Failure(ProfileError.notAuthenticated);
      }

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return const Failure(ProfileError.notFound);
      }

      final profile = UserProfile.fromJson(doc.data()!);
      _myProfile = profile;
      await _cacheProfile(profile);
      notifyListeners();
      return Success(profile);
    } catch (e) {
      lvsError('Error getting my profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Get a profile by user ID
  Future<Result<UserProfile?, ProfileError>> getProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return const Success(null);
      }

      final profile = UserProfile.fromJson(doc.data()!);
      return Success(profile);
    } catch (e) {
      lvsError('Error getting profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Get a profile by username (case-insensitive)
  Future<Result<UserProfile?, ProfileError>> getProfileByUsername(String username) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Success(null);
      }

      final profile = UserProfile.fromJson(snapshot.docs.first.data());
      return Success(profile);
    } catch (e) {
      lvsError('Error getting profile by username: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Search profiles by username or display name (case-insensitive)
  Future<Result<List<UserProfile>, ProfileError>> searchProfiles(
    String query, {
    int limit = 20,
  }) async {
    try {
      final lowerQuery = query.toLowerCase();

      // Firestore no soporta OR en consultas, así que buscamos por username
      // y luego filtramos por display_name en cliente
      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowerQuery)
          .where('username', isLessThanOrEqualTo: lowerQuery + '\uffff')
          .limit(limit)
          .get();

      final profiles = <UserProfile>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final displayName = (data['display_name'] as String? ?? '').toLowerCase();
        if (displayName.contains(lowerQuery) || data['username'] == lowerQuery) {
          profiles.add(UserProfile.fromJson(data));
        }
      }

      lvsLog('Search "$query": ${profiles.length} results', tag: 'PROFILE');
      return Success(profiles);
    } catch (e) {
      lvsError('Error searching profiles: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Update current user's profile
  Future<Result<UserProfile, ProfileError>> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _currentUserId;
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return const Failure(ProfileError.notAuthenticated);
      }

      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return const Failure(ProfileError.unknown);
      }

      await _firestore.collection('users').doc(userId).update(updates);

      // Obtener perfil actualizado
      final doc = await _firestore.collection('users').doc(userId).get();
      final profile = UserProfile.fromJson(doc.data()!);
      _myProfile = profile;
      await _cacheProfile(profile);
      _isLoading = false;
      notifyListeners();
      lvsLog('Profile updated: ${profile.username}', tag: 'PROFILE');
      return Success(profile);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      lvsError('Error updating profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Upload avatar image to Firebase Storage and return public URL
  Future<String?> uploadAvatar(File image) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;

      final ext = p.extension(image.path).toLowerCase();
      final fileName = 'avatars/$userId$ext';

      await FirebaseStorage.instance.ref(fileName).putFile(image);
      final downloadUrl = await FirebaseStorage.instance.ref(fileName).getDownloadURL();

      lvsLog('Avatar uploaded: $downloadUrl', tag: 'PROFILE');
      return downloadUrl;
    } catch (e) {
      lvsError('Error uploading avatar: $e', tag: 'PROFILE');
      return null;
    }
  }

  /// Update last_seen_at timestamp to now
  Future<void> updateLastSeen() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'last_seen_at': FieldValue.serverTimestamp(),
      });

      if (_myProfile != null) {
        _myProfile = _myProfile!.copyWith(lastSeenAt: DateTime.now());
        await _cacheProfile(_myProfile!);
      }
    } catch (e) {
      // Silently fail - non-critical operation
    }
  }
}
