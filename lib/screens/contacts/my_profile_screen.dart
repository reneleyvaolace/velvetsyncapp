import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velvet_sync/services/backend/profile_service.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
import 'package:velvet_sync/devices/models/user_profile.dart';
import 'package:velvet_sync/types/result_types.dart';
import 'package:velvet_sync/theme.dart';
import 'package:velvet_sync/screens/main_navigation.dart';
import 'package:velvet_sync/screens/auth_screen.dart';

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

  Future<void> _skipAsGuest() async {
    final rng = Random();
    final guestName = 'invitado_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final displayName = 'Invitado ${rng.nextInt(999)}';
    setState(() => _isSaving = true);
    final result = await ref.read(profileServiceProvider).createProfile(guestName, displayName);
    setState(() => _isSaving = false);
    if (mounted) {
      result.fold(
        (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${err.message}')),
          );
        },
        (_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        },
      );
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
                      const SizedBox(height: 32),
                      _buildAccountSection(),
                      if (_isCreateMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextButton(
                            onPressed: _skipAsGuest,
                            child: Text(
                              'CONTINUAR COMO INVITADO',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1,
                                color: LvsColors.text3.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
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
            validator: _validateUsername,
            style: const TextStyle(
              color: Colors.white,
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

  Widget _buildAccountSection() {
    final auth = ref.watch(authServiceProvider);
    final isAnonymous = auth.isAnonymous;
    final hasEmail = auth.email != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CUENTA',
          style: TextStyle(
            color: LvsColors.text3,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (isAnonymous && !hasEmail)
          _AccountButton(
            icon: Icons.login,
            label: 'INICIAR SESIÓN / VINCULAR CORREO',
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => AuthScreen(
                    onSkip: () => Navigator.pop(context),
                  ),
                ),
              );
              if (result == true && mounted) {
                await _loadProfile();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión iniciada'),
                      backgroundColor: LvsColors.teal,
                    ),
                  );
                }
              }
            },
          ),
        if (hasEmail) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: LvsColors.bgCardH,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.email, size: 14, color: LvsColors.teal.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    auth.email ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: LvsColors.text3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LvsColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'VINCULADO',
                    style: TextStyle(fontSize: 9, color: LvsColors.teal, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _AccountButton(
          icon: Icons.logout,
          label: 'CERRAR SESIÓN',
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: LvsColors.bgCard,
                title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white, fontSize: 16)),
                content: const Text('¿Estás seguro?', style: TextStyle(color: LvsColors.text3, fontSize: 13)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: LvsColors.text3))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión', style: TextStyle(color: LvsColors.red))),
                ],
              ),
            );
            if (confirmed == true) {
              await auth.signOut();
              (await SharedPreferences.getInstance()).setBool('skip_auth', false);
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreen(
                      onSkip: () async {
                        (await SharedPreferences.getInstance()).setBool('skip_auth', true);
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 8),
        if (hasEmail)
          _AccountButton(
            icon: Icons.delete_forever,
            label: 'ELIMINAR CUENTA',
            color: LvsColors.red,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: LvsColors.bgCard,
                  title: const Text('Eliminar cuenta', style: TextStyle(color: Colors.white, fontSize: 16)),
                  content: const Text('Esta acción es irreversible. Todos tus datos serán eliminados.', style: TextStyle(color: LvsColors.text3, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: LvsColors.text3))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: LvsColors.red))),
                  ],
                ),
              );
              if (confirmed == true) {
                final ok = await auth.deleteAccount();
                if (ok && mounted) {
                  (await SharedPreferences.getInstance()).setBool('skip_auth', false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MyProfileScreen()),
                  );
                }
              }
            },
          ),
      ],
    );
  }
}

class _AccountButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _AccountButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? LvsColors.text3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: LvsColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: effectiveColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
