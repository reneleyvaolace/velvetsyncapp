import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
import 'package:velvet_sync/theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final VoidCallback onSkip;

  const AuthScreen({super.key, required this.onSkip});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoverEmailController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        ref.read(authServiceProvider).clearError();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _recoverEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: LvsColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Image.asset(
              'assets/images/logo_neon.png',
              height: 100,
              errorBuilder: (_, __, ___) => const Icon(Icons.sync, size: 60, color: LvsColors.pink),
            ),
            const SizedBox(height: 12),
            const Text(
              'VELVET SYNC',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Inicia sesión para sincronizar tus datos',
              style: TextStyle(fontSize: 10, color: LvsColors.text3, letterSpacing: 1),
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: LvsColors.bgCard.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: LvsColors.pink,
                unselectedLabelColor: LvsColors.text3,
                indicatorColor: LvsColors.pink,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'INICIAR\nSESIÓN'),
                  Tab(text: 'CREAR\nCUENTA'),
                  Tab(text: 'RECUPERAR\nCONTRASEÑA'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(auth),
                  _buildRegisterTab(auth),
                  _buildRecoverTab(auth),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: widget.onSkip,
            child: const Text(
              'OMITIR Y CONTINUAR COMO INVITADO',
              style: TextStyle(fontSize: 9, letterSpacing: 1, color: LvsColors.text3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab(AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CardGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('ACCEDER A MI CUENTA'),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: _inputDecoration('Correo electrónico', Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: _inputDecoration('Contraseña', Icons.lock_outlined).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: LvsColors.text3),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.errorMessage!, style: const TextStyle(fontSize: 10, color: LvsColors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _PrimaryButton(
                    label: 'INICIAR SESIÓN',
                    isLoading: auth.status == AuthStatus.authenticating,
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text;
                      if (email.isEmpty || password.isEmpty) return;
                      final ok = await auth.signIn(email, password);
                      if (ok && mounted) Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CardGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('CREAR CUENTA NUEVA'),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: _inputDecoration('Correo electrónico', Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: _inputDecoration('Contraseña', Icons.lock_outlined).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: LvsColors.text3),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: _inputDecoration('Confirmar contraseña', Icons.lock_outlined).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18, color: LvsColors.text3),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.errorMessage!, style: const TextStyle(fontSize: 10, color: LvsColors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _PrimaryButton(
                    label: 'CREAR CUENTA',
                    isLoading: auth.status == AuthStatus.authenticating,
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text;
                      final confirm = _confirmPasswordController.text;
                      if (email.isEmpty || password.isEmpty) return;
                      if (password != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: LvsColors.red),
                        );
                        return;
                      }
                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: LvsColors.red),
                        );
                        return;
                      }
                      final ok = await auth.signUp(email, password);
                      if (ok && mounted) Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoverTab(AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CardGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('RECUPERAR CONTRASEÑA'),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tu correo electrónico y te enviaremos\nun enlace para restablecer tu contraseña.',
                  style: TextStyle(fontSize: 10, color: LvsColors.text3),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _recoverEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: _inputDecoration('Correo electrónico', Icons.email_outlined),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.errorMessage!, style: const TextStyle(fontSize: 10, color: LvsColors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _PrimaryButton(
                    label: 'ENVIAR ENLACE',
                    isLoading: auth.status == AuthStatus.authenticating,
                    onPressed: () async {
                      final email = _recoverEmailController.text.trim();
                      if (email.isEmpty) return;
                      final ok = await auth.resetPassword(email);
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📧 Revisa tu correo para restablecer la contraseña'),
                            backgroundColor: Color(0xFF00C853),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(fontSize: 11, color: LvsColors.text3),
      prefixIcon: Icon(icon, size: 18, color: LvsColors.text3),
      filled: true,
      fillColor: LvsColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LvsColors.pink),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LvsColors.pink.withValues(alpha: isLoading ? 0.3 : 0.8),
              LvsColors.violet.withValues(alpha: isLoading ? 0.3 : 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
      ),
    );
  }
}
