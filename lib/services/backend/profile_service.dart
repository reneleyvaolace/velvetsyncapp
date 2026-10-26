// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/profile_service.dart
// Servicio de perfiles de usuario para la libreta de contactos
//
// SQL Migration en: supabase/migrations/001_init.sql
// Ejecutar en Supabase SQL Editor (Dashboard > SQL Editor)
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        return 'Profiles table does not exist';
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

  UserProfile? _myProfile;
  bool _isLoading = false;

  UserProfile? get myProfile => _myProfile;
  bool get isLoading => _isLoading;

  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

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
          await _client.auth.signInAnonymously();
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

      final response = await _client.from('profiles').insert({
        'id': userId,
        'username': username.toLowerCase(),
        'display_name': displayName,
        'avatar_url': avatarUrl,
      }).select().single().timeout(const Duration(seconds: 10));

      final profile = UserProfile.fromJson(response);
      _myProfile = profile;
      await _cacheProfile(profile);
      _isLoading = false;
      notifyListeners();
      lvsLog('Profile created: ${profile.username}', tag: 'PROFILE');
      return Success(profile);
    } on PostgrestException catch (e) {
      _isLoading = false;
      notifyListeners();

      if (e.message.contains('violates unique constraint') &&
          e.message.contains('username')) {
        lvsError('Username taken: $username', tag: 'PROFILE');
        return const Failure(ProfileError.usernameTaken);
      }
      if (e.message.contains('relation "profiles" does not exist')) {
        lvsError('Profiles table not found', tag: 'PROFILE');
        return const Failure(ProfileError.tableNotFound);
      }
      if (e.message.contains('violates check constraint')) {
        lvsError('Invalid username format (check constraint): $username', tag: 'PROFILE');
        return const Failure(ProfileError.invalidUsername);
      }
      lvsError('Postgrest error: ${e.message}', tag: 'PROFILE');
      return const Failure(ProfileError.unknown);
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      if (e.toString().contains('relation "profiles" does not exist')) {
        return const Failure(ProfileError.tableNotFound);
      }
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

      final response = await _client.from('profiles').select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
      return const Failure(ProfileError.notFound);
      }

      final profile = UserProfile.fromJson(response);
      _myProfile = profile;
      await _cacheProfile(profile);
      notifyListeners();
      return Success(profile);
    } on PostgrestException catch (e) {
      if (e.message.contains('relation "profiles" does not exist')) {
        return const Failure(ProfileError.tableNotFound);
      }
      lvsError('Error getting my profile: ${e.message}', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    } catch (e) {
      lvsError('Error getting my profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Get a profile by user ID
  Future<Result<UserProfile?, ProfileError>> getProfile(String userId) async {
    try {
      final response = await _client.from('profiles').select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
      return const Success(null);
      }

      final profile = UserProfile.fromJson(response);
      return Success(profile);
    } on PostgrestException catch (e) {
      if (e.message.contains('relation "profiles" does not exist')) {
        return const Failure(ProfileError.tableNotFound);
      }
      return const Failure(ProfileError.networkError);
    } catch (e) {
      lvsError('Error getting profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Get a profile by username (case-insensitive)
  Future<Result<UserProfile?, ProfileError>> getProfileByUsername(String username) async {
    try {
      final response = await _client.from('profiles').select()
          .eq('username', username.trim().toLowerCase())
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
      return const Success(null);
      }

      final profile = UserProfile.fromJson(response);
      return Success(profile);
    } on PostgrestException catch (e) {
      if (e.message.contains('relation "profiles" does not exist')) {
      return const Failure(ProfileError.tableNotFound);
      }
      return const Failure(ProfileError.networkError);
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
      final response = await _client.from('profiles').select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(limit)
          .timeout(const Duration(seconds: 10));

      final profiles = (response as List)
          .map((data) => UserProfile.fromJson(data as Map<String, dynamic>))
          .toList();

      lvsLog('Search "$query": ${profiles.length} results', tag: 'PROFILE');
      return Success(profiles);
    } on PostgrestException catch (e) {
      if (e.message.contains('relation "profiles" does not exist')) {
        return const Failure(ProfileError.tableNotFound);
      }
      return const Failure(ProfileError.networkError);
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

      final response = await _client.from('profiles').update(updates)
          .eq('id', userId)
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      final profile = UserProfile.fromJson(response);
      _myProfile = profile;
      await _cacheProfile(profile);
      _isLoading = false;
      notifyListeners();
      lvsLog('Profile updated: ${profile.username}', tag: 'PROFILE');
      return Success(profile);
    } on PostgrestException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.message.contains('relation "profiles" does not exist')) {
        return const Failure(ProfileError.tableNotFound);
      }
      return const Failure(ProfileError.networkError);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      lvsError('Error updating profile: $e', tag: 'PROFILE');
      return const Failure(ProfileError.networkError);
    }
  }

  /// Upload avatar image to Supabase Storage and return public URL
  Future<String?> uploadAvatar(File image) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;

      final ext = p.extension(image.path).toLowerCase();
      final fileName = 'avatars/$userId$ext';

      await _client.storage.from('user_backups').upload(
        fileName,
        image,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _client.storage.from('user_backups').getPublicUrl(fileName);
      lvsLog('Avatar uploaded: $publicUrl', tag: 'PROFILE');
      return publicUrl;
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

      await _client.from('profiles').update({
        'last_seen_at': DateTime.now().toIso8601String(),
      }).eq('id', userId).timeout(const Duration(seconds: 5));

      if (_myProfile != null) {
        _myProfile = _myProfile!.copyWith(lastSeenAt: DateTime.now());
        await _cacheProfile(_myProfile!);
      }
    } catch (e) {
      // Silently fail - non-critical operation
    }
  }
}
