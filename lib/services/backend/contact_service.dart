// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/contact_service.dart
// Servicio de libreta de contactos para encontrar usuarios por username
//
// SQL Migration (ejecutar en Supabase SQL Editor):
// ═══════════════════════════════════════════════════════════════
// CREATE TABLE IF NOT EXISTS profiles (
//   id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
//   username VARCHAR(20) UNIQUE NOT NULL CHECK (username ~ '^[a-zA-Z0-9_]{3,20}$'),
//   display_name VARCHAR(50) NOT NULL,
//   avatar_url TEXT,
//   last_seen_at TIMESTAMPTZ DEFAULT NOW(),
//   created_at TIMESTAMPTZ DEFAULT NOW()
// );
//
// CREATE TABLE IF NOT EXISTS contacts (
//   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//   user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
//   contact_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
//   created_at TIMESTAMPTZ DEFAULT NOW(),
//   UNIQUE(user_id, contact_user_id)
// );
//
// CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
// CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON profiles(display_name);
// CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON contacts(user_id);
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/devices/models/contact.dart';
import 'package:velvet_sync/devices/models/user_profile.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/utils/logger.dart';

final contactServiceProvider = Provider<ContactService>((ref) {
  return ContactService();
});

enum ContactError {
  notFound,
  alreadyExists,
  cannotAddSelf,
  networkError,
  tableNotFound,
  notAuthenticated,
  unknown,
}

extension ContactErrorExtension on ContactError {
  String get message {
    switch (this) {
      case ContactError.notFound:
        return 'Contact not found';
      case ContactError.alreadyExists:
        return 'Contact already exists';
      case ContactError.cannotAddSelf:
        return 'Cannot add yourself as a contact';
      case ContactError.networkError:
        return 'Network error, please try again';
      case ContactError.tableNotFound:
        return 'Contacts table does not exist';
      case ContactError.notAuthenticated:
        return 'User is not authenticated';
      case ContactError.unknown:
        return 'An unknown error occurred';
    }
  }
}

class ContactService extends ChangeNotifier {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  List<Contact> _contacts = [];
  bool _isLoading = false;

  List<Contact> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;

  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Add a user to contacts by their user ID
  Future<Result<Contact, ContactError>> addContact(String contactUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _currentUserId;
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return const Failure(ContactError.notAuthenticated);
      }

      if (userId == contactUserId) {
        _isLoading = false;
        notifyListeners();
        return const Failure(ContactError.cannotAddSelf);
      }

      final response = await _client.from('contacts').insert({
        'user_id': userId,
        'contact_user_id': contactUserId,
      }).select().single().timeout(const Duration(seconds: 10));

      final contact = Contact.fromJson(response);
      _contacts.add(contact);
      _isLoading = false;
      notifyListeners();
      lvsLog('Contact added: $contactUserId', tag: 'CONTACT');
      return Success(contact);
    } on PostgrestException catch (e) {
      _isLoading = false;
      notifyListeners();

      if (e.message.contains('violates unique constraint')) {
        lvsError('Contact already exists: $contactUserId', tag: 'CONTACT');
        return const Failure(ContactError.alreadyExists);
      }
      if (e.message.contains('relation "contacts" does not exist')) {
        lvsError('Contacts table not found', tag: 'CONTACT');
        return const Failure(ContactError.tableNotFound);
      }
      lvsError('Postgrest error: ${e.message}', tag: 'CONTACT');
      return const Failure(ContactError.unknown);
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      if (e.toString().contains('relation "contacts" does not exist')) {
        return const Failure(ContactError.tableNotFound);
      }
      lvsError('Error adding contact: $e', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    }
  }

  /// Remove a contact by contact record ID
  Future<Result<void, ContactError>> removeContact(String contactId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _currentUserId;
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return const Failure(ContactError.notAuthenticated);
      }

      await _client.from('contacts').delete()
          .eq('id', contactId)
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 10));

      _contacts.removeWhere((c) => c.id == contactId);
      _isLoading = false;
      notifyListeners();
      lvsLog('Contact removed: $contactId', tag: 'CONTACT');
      return const Success(null);
    } on PostgrestException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.message.contains('relation "contacts" does not exist')) {
        return const Failure(ContactError.tableNotFound);
      }
      lvsError('Postgrest error: ${e.message}', tag: 'CONTACT');
      return const Failure(ContactError.unknown);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      lvsError('Error removing contact: $e', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    }
  }

  /// Get all contacts for the current user, joined with profile data
  Future<Result<List<Contact>, ContactError>> getContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _currentUserId;
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return const Failure(ContactError.notAuthenticated);
      }

      final response = await _client.from('contacts').select('''
        *,
        profile:contact_user_id!inner (
          id, username, display_name, avatar_url, last_seen_at
        )
      ''').eq('user_id', userId).order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final contacts = (response as List).map((data) {
        final map = data as Map<String, dynamic>;
        final contact = Contact.fromJson(map);
        if (map['profile'] != null) {
          final profileData = map['profile'] as Map<String, dynamic>;
          final profile = UserProfile.fromJson(profileData);
          return Contact(
            id: contact.id,
            userId: contact.userId,
            contactUserId: contact.contactUserId,
            profile: profile,
            createdAt: contact.createdAt,
            lastSessionAt: contact.lastSessionAt,
          );
        }
        return contact;
      }).toList();

      _contacts = contacts;
      _isLoading = false;
      notifyListeners();
      lvsLog('Contacts loaded: ${contacts.length} contacts', tag: 'CONTACT');
      return Success(contacts);
    } on PostgrestException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.message.contains('relation "contacts" does not exist')) {
        return const Failure(ContactError.tableNotFound);
      }
      lvsError('Postgrest error: ${e.message}', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      lvsError('Error getting contacts: $e', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    }
  }

  /// Search within own contacts by username or display name
  Future<Result<List<Contact>, ContactError>> searchContacts(String query) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const Failure(ContactError.notAuthenticated);
      }

      // Get contacts first, then filter by joined profile data
      final response = await _client.from('contacts').select('''
        *,
        profile:contact_user_id!inner (
          id, username, display_name, avatar_url, last_seen_at
        )
      ''').eq('user_id', userId)
          .or('profile.username.ilike.%$query%,profile.display_name.ilike.%$query%')
          .timeout(const Duration(seconds: 10));

      final contacts = (response as List).map((data) {
        final map = data as Map<String, dynamic>;
        final contact = Contact.fromJson(map);
        if (map['profile'] != null) {
          final profileData = map['profile'] as Map<String, dynamic>;
          final profile = UserProfile.fromJson(profileData);
          return Contact(
            id: contact.id,
            userId: contact.userId,
            contactUserId: contact.contactUserId,
            profile: profile,
            createdAt: contact.createdAt,
            lastSessionAt: contact.lastSessionAt,
          );
        }
        return contact;
      }).toList();

      lvsLog('Contact search "$query": ${contacts.length} results', tag: 'CONTACT');
      return Success(contacts);
    } on PostgrestException catch (e) {
      if (e.message.contains('relation "contacts" does not exist')) {
        return const Failure(ContactError.tableNotFound);
      }
      lvsError('Postgrest error: ${e.message}', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    } catch (e) {
      lvsError('Error searching contacts: $e', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    }
  }

  /// Get a single contact by user ID
  Future<Result<Contact?, ContactError>> getContactByUserId(String userId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        return const Failure(ContactError.notAuthenticated);
      }

      final response = await _client.from('contacts').select('''
        *,
        profile:contact_user_id!inner (
          id, username, display_name, avatar_url, last_seen_at
        )
      ''').eq('user_id', currentUserId)
          .eq('contact_user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
        return const Success(null);
      }

      final map = response;
      final contact = Contact.fromJson(map);
      if (map['profile'] != null) {
        final profileData = map['profile'] as Map<String, dynamic>;
        final profile = UserProfile.fromJson(profileData);
        return Success(Contact(
          id: contact.id,
          userId: contact.userId,
          contactUserId: contact.contactUserId,
          profile: profile,
          createdAt: contact.createdAt,
          lastSessionAt: contact.lastSessionAt,
        ));
      }
      return Success(contact);
    } on PostgrestException catch (e) {
      if (e.message.contains('relation "contacts" does not exist')) {
        return const Failure(ContactError.tableNotFound);
      }
      lvsError('Postgrest error: ${e.message}', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    } catch (e) {
      lvsError('Error getting contact by userId: $e', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    }
  }
}
