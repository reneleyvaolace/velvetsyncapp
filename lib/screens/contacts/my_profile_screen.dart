import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/profile_service.dart';
import 'package:velvet_sync/devices/models/user_profile.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/main_navigation.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoadingProfile = true;
  bool _isSaving = false;
  bool _isCreateMode = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final result = await ref.read(profileServiceProvider).getMyProfile();
      if (mounted) {
        result.fold(
          (_) => setState(() { _isCreateMode = true; _isLoadingProfile = false; }),
          (profile) {
            _usernameController.text = profile.username;
            _displayNameController.text = profile.displayName;
            setState(() { _isCreateMode = false; _isLoadingProfile = false; });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCreateMode = true; _isLoadingProfile = false; });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final username = _usernameController.text.trim();
      final displayName = _displayNameController.text.trim();

      Result<UserProfile, ProfileError> result;
      if (_isCreateMode) {
        result = await ref.read(profileServiceProvider).createProfile(
          username,
          displayName,
        );
      } else {
        result = await ref.read(profileServiceProvider).updateProfile(
          displayName: displayName,
        );
      }

      if (mounted) {
        result.fold(
          (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.message}')),
            );
            setState(() => _isSaving = false);
          },
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil guardado'),
                backgroundColor: LvsColors.teal,
              ),
            );
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainNavigation()),
              );
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'El nombre de usuario es requerido';
    final trimmed = value.trim();
    if (trimmed.length < 3) return 'Mínimo 3 caracteres';
    if (trimmed.length > 20) return 'Máximo 20 caracteres';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Solo letras, números y guión bajo';
    }
    return null;
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) return 'El nombre es requerido';
    final trimmed = value.trim();
    if (trimmed.length > 50) return 'Máximo 50 caracteres';
    return null;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('MI PERFIL'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(color: LvsColors.pink))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildAvatarSection(),
                      const SizedBox(height: 40),
                      _buildFormFields(),
                      const SizedBox(height: 40),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final text = _displayNameController.text.trim();
    final initial = text.isNotEmpty
        ? text[0].toUpperCase()
        : '?';

    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LvsColors.bgCardH,
            border: Border.all(color: LvsColors.pink.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: LvsColors.pink.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: LvsColors.pink,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isCreateMode ? 'CREAR PERFIL' : 'EDITAR PERFIL',
          style: const TextStyle(
            color: LvsColors.text3,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return CardGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOMBRE DE USUARIO',
            style: TextStyle(
              color: LvsColors.text3,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            readOnly: !_isCreateMode,
            validator: _validateUsername,
            style: TextStyle(
              color: _isCreateMode ? Colors.white : LvsColors.text3,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: ' usuario',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true,
              fillColor: LvsColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LvsColors.pink.withValues(alpha: 0.4)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NOMBRE A MOSTRAR',
            style: TextStyle(
              color: LvsColors.text3,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _displayNameController,
            validator: _validateDisplayName,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: ' Tu nombre',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true,
              fillColor: LvsColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LvsColors.pink.withValues(alpha: 0.4)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: LvsColors.teal,
          foregroundColor: Colors.black,
          disabledBackgroundColor: LvsColors.teal.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : const Text(
                'GUARDAR CAMBIOS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}
