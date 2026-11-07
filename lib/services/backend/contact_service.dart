// ════════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/backend/contact_service.dart
// Servicio de libreta de contactos con Firebase Firestore
// ════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        return 'Contacts collection does not exist';
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

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Contact> _contacts = [];
  bool _isLoading = false;

  List<Contact> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;

  String? get _currentUserId => _auth.currentUser?.uid;

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

      // Verificar si ya existe
      final existing = await _firestore
          .collection('contacts')
          .where('user_id', isEqualTo: userId)
          .where('contact_user_id', isEqualTo: contactUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        lvsError('Contact already exists: $contactUserId', tag: 'CONTACT');
        _isLoading = false;
        notifyListeners();
        return const Failure(ContactError.alreadyExists);
      }

      final docRef = await _firestore.collection('contacts').add({
        'user_id': userId,
        'contact_user_id': contactUserId,
        'created_at': FieldValue.serverTimestamp(),
      });

      final contact = Contact(
        id: docRef.id,
        userId: userId,
        contactUserId: contactUserId,
        profile: null,
        createdAt: DateTime.now(),
        lastSessionAt: null,
      );
      _contacts.add(contact);
      _isLoading = false;
      notifyListeners();
      lvsLog('Contact added: $contactUserId', tag: 'CONTACT');
      return Success(contact);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
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

      await _firestore.collection('contacts').doc(contactId).delete();

      _contacts.removeWhere((c) => c.id == contactId);
      _isLoading = false;
      notifyListeners();
      lvsLog('Contact removed: $contactId', tag: 'CONTACT');
      return const Success(null);
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

      final snapshot = await _firestore
          .collection('contacts')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      final contacts = <Contact>[];
      for (final doc in snapshot.docs) {
        final map = doc.data();
        final contactUserId = map['contact_user_id'] as String?;
        UserProfile? profile;

        if (contactUserId != null) {
          final profileDoc = await _firestore.collection('users').doc(contactUserId).get();
          if (profileDoc.exists) {
            profile = UserProfile.fromJson(profileDoc.data()!);
          }
        }

        contacts.add(Contact(
          id: doc.id,
          userId: map['user_id'] as String? ?? userId,
          contactUserId: contactUserId ?? '',
          profile: profile,
          createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastSessionAt: null,
        ));
      }

      _contacts = contacts;
      _isLoading = false;
      notifyListeners();
      lvsLog('Contacts loaded: ${contacts.length} contacts', tag: 'CONTACT');
      return Success(contacts);
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

      final snapshot = await _firestore
          .collection('contacts')
          .where('user_id', isEqualTo: userId)
          .get();

      final contacts = <Contact>[];
      final lowerQuery = query.toLowerCase();

      for (final doc in snapshot.docs) {
        final map = doc.data();
        final contactUserId = map['contact_user_id'] as String?;
        if (contactUserId == null) continue;

        final profileDoc = await _firestore.collection('users').doc(contactUserId).get();
        if (profileDoc.exists) {
          final profileData = profileDoc.data()!;
          final username = (profileData['username'] as String? ?? '').toLowerCase();
          final displayName = (profileData['display_name'] as String? ?? '').toLowerCase();

          if (username.contains(lowerQuery) || displayName.contains(lowerQuery)) {
            final profile = UserProfile.fromJson(profileData);
            contacts.add(Contact(
              id: doc.id,
              userId: map['user_id'] as String? ?? userId,
              contactUserId: contactUserId,
              profile: profile,
              createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
              lastSessionAt: null,
            ));
          }
        }
      }

      lvsLog('Contact search "$query": ${contacts.length} results', tag: 'CONTACT');
      return Success(contacts);
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

      final snapshot = await _firestore
          .collection('contacts')
          .where('user_id', isEqualTo: currentUserId)
          .where('contact_user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return const Success(null);
      }

      final doc = snapshot.docs.first;
      final map = doc.data();

      UserProfile? profile;
      final profileDoc = await _firestore.collection('users').doc(userId).get();
      if (profileDoc.exists) {
        profile = UserProfile.fromJson(profileDoc.data()!);
      }

      return Success(Contact(
        id: doc.id,
        userId: map['user_id'] as String? ?? currentUserId,
        contactUserId: map['contact_user_id'] as String? ?? userId,
        profile: profile,
        createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastSessionAt: null,
      ));
    } catch (e) {
      lvsError('Error getting contact by userId: $e', tag: 'CONTACT');
      return const Failure(ContactError.networkError);
    }
  }
}
