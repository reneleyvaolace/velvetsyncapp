import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:velvet_sync/services/backend/profile_service.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
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
  final TextEditingController _linkEmailController = TextEditingController();
  final TextEditingController _linkPasswordController = TextEditingController();
  final TextEditingController _linkConfirmController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoadingProfile = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isLinkingEmail = false;
  bool _isCreateMode = false;
  bool _obscureLinkPassword = true;
  bool _obscureLinkConfirm = true;
  String? _avatarUrl;
  File? _pendingAvatar;

  AuthService get _authService => ref.read(authServiceProvider);

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
            _avatarUrl = profile.avatarUrl;
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      setState(() => _pendingAvatar = File(picked.path));
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_pendingAvatar == null) return _avatarUrl;
    setState(() => _isUploadingAvatar = true);
    final url = await ref.read(profileServiceProvider).uploadAvatar(_pendingAvatar!);
    setState(() => _isUploadingAvatar = false);
    return url ?? _avatarUrl;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final username = _usernameController.text.trim();
      final displayName = _displayNameController.text.trim();
      final avatarUrl = await _uploadAvatar();

      Result<UserProfile, ProfileError> result;
      if (_isCreateMode) {
        result = await ref.read(profileServiceProvider).createProfile(
          username,
          displayName,
          avatarUrl: avatarUrl,
        );
      } else {
        result = await ref.read(profileServiceProvider).updateProfile(
          displayName: displayName,
          avatarUrl: avatarUrl,
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

  Future<void> _linkEmail() async {
    final email = _linkEmailController.text.trim();
    final password = _linkPasswordController.text;
    final confirm = _linkConfirmController.text;

    if (email.isEmpty || password.isEmpty) return;
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: LvsColors.red),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mínimo 6 caracteres'), backgroundColor: LvsColors.red),
      );
      return;
    }

    setState(() => _isLinkingEmail = true);
    final ok = await _authService.linkEmail(email, password);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo vinculado correctamente'), backgroundColor: LvsColors.teal),
        );
        _linkEmailController.clear();
        _linkPasswordController.clear();
        _linkConfirmController.clear();
        setState(() => _isLinkingEmail = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_authService.errorMessage ?? 'Error al vincular correo'),
            backgroundColor: LvsColors.red,
          ),
        );
        setState(() => _isLinkingEmail = false);
      }
    }
  }

  Widget _buildLinkEmailSection() {
    return CardGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VINCULAR CORREO',
            style: TextStyle(
              color: LvsColors.pink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vincula un correo para poder recuperar tu cuenta y sincronizar datos entre dispositivos.',
            style: TextStyle(fontSize: 10, color: LvsColors.text3),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _linkEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: ' Correo electrónico',
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
          const SizedBox(height: 12),
          TextField(
            controller: _linkPasswordController,
            obscureText: _obscureLinkPassword,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: ' Contraseña',
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
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLinkPassword ? Icons.visibility_off : Icons.visibility,
                  size: 18, color: LvsColors.text3,
                ),
                onPressed: () => setState(() => _obscureLinkPassword = !_obscureLinkPassword),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _linkConfirmController,
            obscureText: _obscureLinkConfirm,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: ' Confirmar contraseña',
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
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLinkConfirm ? Icons.visibility_off : Icons.visibility,
                  size: 18, color: LvsColors.text3,
                ),
                onPressed: () => setState(() => _obscureLinkConfirm = !_obscureLinkConfirm),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLinkingEmail ? null : _linkEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: LvsColors.pink.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: LvsColors.pink.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLinkingEmail
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text(
                      'VINCULAR CORREO',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LvsColors.bgCardH,
        title: const Text('Eliminar cuenta', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro? Se eliminará tu perfil, contactos y datos. Esta acción no se puede deshacer.',
          style: TextStyle(color: LvsColors.text3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: LvsColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINAR', style: TextStyle(color: LvsColors.pink, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await ref.read(authServiceProvider).deleteAccount();
    if (mounted) {
      if (ok) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      } else {
        final err = ref.read(authServiceProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Error al eliminar cuenta')),
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
    _linkEmailController.dispose();
    _linkPasswordController.dispose();
    _linkConfirmController.dispose();
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
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                      const SizedBox(height: 32),
                      if (_authService.isAnonymous)
                        _buildLinkEmailSection()
                      else
                        _buildEmailInfoSection(),
                      const SizedBox(height: 12),
                      _buildDeleteButton(),
                      const SizedBox(height: 12),
                      if (!_authService.isAnonymous) _buildChangePasswordButton(),
                      const SizedBox(height: 12),
                      _buildSignOutButton(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final hasImage = _pendingAvatar != null || _avatarUrl != null;

    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          Container(
            width: 120, height: 120,
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
              image: hasImage
                  ? DecorationImage(
                      image: _pendingAvatar != null
                          ? FileImage(_pendingAvatar!)
                          : NetworkImage(_avatarUrl!) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasImage
                ? null
                : Center(
                    child: Text(
                      _displayNameController.text.isNotEmpty
                          ? _displayNameController.text[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: LvsColors.pink,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          if (_isUploadingAvatar)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: LvsColors.pink,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LvsColors.teal,
                border: Border.all(color: LvsColors.bg, width: 3),
              ),
              child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
            ),
          ),
        ],
      ),
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
        onPressed: (_isSaving || _isUploadingAvatar) ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: LvsColors.teal,
          foregroundColor: Colors.black,
          disabledBackgroundColor: LvsColors.teal.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: (_isSaving || _isUploadingAvatar)
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

  Widget _buildEmailInfoSection() {
    return CardGlass(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, size: 18, color: LvsColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CORREO VINCULADO',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.teal),
                ),
                const SizedBox(height: 4),
                Text(
                  _authService.email ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  Future<void> _changePassword() async {
    final email = _authService.email;
    if (email == null) return;

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LvsColors.bgCardH,
        title: const Text('Cambiar contraseña', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: ' Contraseña actual',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true, fillColor: LvsColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: ' Nueva contraseña',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true, fillColor: LvsColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: ' Confirmar nueva contraseña',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true, fillColor: LvsColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: LvsColors.text3))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CAMBIAR', style: TextStyle(color: LvsColors.pink, fontWeight: FontWeight.w900))),
        ],
      ),
    );

    if (ok != true) return;

    final current = currentCtrl.text;
    final newPw = newCtrl.text;
    final confirmPw = confirmCtrl.text;

    if (newPw.length < 6) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mínimo 6 caracteres'), backgroundColor: LvsColors.red));
      return;
    }
    if (newPw != confirmPw) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: LvsColors.red));
      return;
    }

    setState(() => _isSaving = true);
    final reAuthOk = await _authService.signIn(email, current);
    if (reAuthOk) {
      final ok2 = await _authService.changePassword(newPw);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok2 ? 'Contraseña cambiada correctamente' : 'Error al cambiar contraseña'),
          backgroundColor: ok2 ? LvsColors.teal : LvsColors.red,
        ));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actual incorrecta'), backgroundColor: LvsColors.red));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Widget _buildChangePasswordButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton.icon(
        onPressed: _changePassword,
        icon: const Icon(Icons.lock_reset, size: 16),
        label: const Text(
          'CAMBIAR CONTRASEÑA',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
        ),
        style: TextButton.styleFrom(
          foregroundColor: LvsColors.text3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 16),
        label: const Text(
          'CERRAR SESIÓN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
        ),
        style: TextButton.styleFrom(
          foregroundColor: LvsColors.text3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: _deleteAccount,
        style: TextButton.styleFrom(
          foregroundColor: LvsColors.pink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: LvsColors.pink.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'ELIMINAR CUENTA',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
        ),
      ),
    );
  }
}
