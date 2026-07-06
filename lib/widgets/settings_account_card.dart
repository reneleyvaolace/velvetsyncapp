import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velvet_sync/services/backend/auth_service.dart';
import 'package:velvet_sync/screens/auth_screen.dart';
import 'package:velvet_sync/screens/main_navigation.dart';
import 'package:velvet_sync/theme.dart';

class SettingsAccountCard extends ConsumerWidget {
  const SettingsAccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final isAnon = auth.isAnonymous;

    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CUENTA'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LvsColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(isAnon ? Icons.person_outline : Icons.person, color: isAnon ? LvsColors.text3 : LvsColors.teal, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnon ? 'INVITADO' : (auth.email ?? 'USUARIO'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAnon ? LvsColors.text3 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAnon ? 'Sin sesión iniciada' : 'Sesión activa',
                        style: const TextStyle(fontSize: 9, color: LvsColors.text3),
                      ),
                    ],
                  ),
                ),
                if (!isAnon)
                  TextButton(
                    onPressed: () async {
                      await auth.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuthScreen(
                            onSkip: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigation()),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('CERRAR\nSESIÓN', style: TextStyle(fontSize: 8, color: LvsColors.red, letterSpacing: 1)),
                  ),
              ],
            ),
          ),
          if (!isAnon) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: LvsColors.bgCard,
                      title: const Text('ELIMINAR CUENTA', style: TextStyle(fontSize: 14, color: LvsColors.red)),
                      content: const Text(
                        'Esta acción eliminará permanentemente tu cuenta y todos tus datos. ¿Estás seguro?',
                        style: TextStyle(fontSize: 12, color: LvsColors.text3),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR', style: TextStyle(color: LvsColors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final ok = await auth.deleteAccount();
                    if (ok && context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuthScreen(
                            onSkip: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigation()),
                            ),
                          ),
                        ),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(auth.errorMessage ?? 'Error al eliminar cuenta'),
                          backgroundColor: LvsColors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever, size: 16, color: LvsColors.red),
                label: const Text('ELIMINAR CUENTA', style: TextStyle(fontSize: 10, color: LvsColors.red, letterSpacing: 1)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
