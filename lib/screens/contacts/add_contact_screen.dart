import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/contact_service.dart';
import 'package:velvet_sync/services/backend/profile_service.dart';
import 'package:velvet_sync/devices/models/user_profile.dart';
import 'package:velvet_sync/theme.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<UserProfile> _results = [];
  Set<String> _existingContactIds = {};
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadExistingContacts();
  }

  Future<void> _loadExistingContacts() async {
    try {
      final result = await ref.read(contactServiceProvider).getContacts();
      if (mounted) {
        result.fold(
          (_) => setState(() => _isLoadingContacts = false),
          (contacts) => setState(() {
            _existingContactIds = contacts.map((c) => c.contactUserId).toSet();
            _isLoadingContacts = false;
          }),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _search(query.trim());
      } else {
        setState(() {
          _results = [];
          _hasSearched = false;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final result = await ref.read(profileServiceProvider).searchProfiles(query);
      if (mounted) {
        result.fold(
          (error) => setState(() { _error = error.message; _isSearching = false; _hasSearched = true; }),
          (profiles) => setState(() { _results = profiles; _isSearching = false; _hasSearched = true; }),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isSearching = false; _hasSearched = true; });
      }
    }
  }

  Future<void> _addContact(UserProfile profile) async {
    try {
      final result = await ref.read(contactServiceProvider).addContact(profile.id);
      if (mounted) {
        result.fold(
          (error) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${error.message}')),
          ),
          (_) {
            setState(() {
              _existingContactIds.add(profile.id);
              _results.removeWhere((r) => r.id == profile.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacto agregado'), backgroundColor: LvsColors.teal),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('AÑADIR CONTACTO'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: CardGlass(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              borderRadius: 16,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Busca usuarios por nombre de usuario',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: LvsColors.text3, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator(color: LvsColors.pink));
    }

    if (!_hasSearched && _searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LvsColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Icon(Icons.search, color: LvsColors.text3, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Busca usuarios por nombre de usuario',
              style: TextStyle(color: LvsColors.text3, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: LvsColors.pink),
            SizedBox(height: 16),
            Text(
              'Buscando...',
              style: TextStyle(color: LvsColors.text3, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: LvsColors.red, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Error al buscar',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: LvsColors.text3, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  final q = _searchController.text.trim();
                  if (q.isNotEmpty) _search(q);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('REINTENTAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LvsColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Icon(Icons.person_off_outlined, color: LvsColors.text3, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron usuarios',
              style: TextStyle(color: LvsColors.text3, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final profile = _results[index];
        final isContact = _existingContactIds.contains(profile.id);
        final initial = (profile.displayName.isNotEmpty
                ? profile.displayName[0]
                : profile.username[0])
            .toUpperCase();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CardGlass(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: LvsColors.pink.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: LvsColors.pink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${profile.username}',
                        style: const TextStyle(color: LvsColors.text3, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: isContact ? null : () => _addContact(profile),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isContact
                          ? Colors.white.withValues(alpha: 0.05)
                          : LvsColors.teal,
                      foregroundColor: isContact ? LvsColors.text3 : Colors.black,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                      disabledForegroundColor: LvsColors.text3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      isContact ? 'AGREGADO' : 'AGREGAR',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
