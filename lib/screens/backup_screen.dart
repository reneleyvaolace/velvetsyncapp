import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:velvet_sync/services/backend/cloud_backup_service.dart';
import 'package:velvet_sync/theme.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cloudBackupServiceProvider).listBackups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(cloudBackupServiceProvider);

    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('RESPALDO EN NUBE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.teal)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: LvsColors.teal),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatusBanner(service),
                const SizedBox(height: 20),
                _buildCloudSection(service),
                const SizedBox(height: 20),
                _buildLocalSection(service),
                if (service.backups.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildExistingBackups(service),
                ],
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(CloudBackupService service) {
    if (service.status == BackupStatus.idle) return const SizedBox.shrink();

    Color bgColor;
    IconData icon;
    String text;
    switch (service.status) {
      case BackupStatus.uploading:
        bgColor = LvsColors.teal.withValues(alpha: 0.1);
        icon = Icons.cloud_upload;
        text = 'Subiendo respaldo...';
        break;
      case BackupStatus.downloading:
        bgColor = LvsColors.teal.withValues(alpha: 0.1);
        icon = Icons.cloud_download;
        text = 'Restaurando respaldo...';
        break;
      case BackupStatus.success:
        bgColor = const Color(0xFF00C853).withValues(alpha: 0.1);
        icon = Icons.check_circle;
        text = 'Operación completada exitosamente';
        break;
      case BackupStatus.error:
        bgColor = LvsColors.red.withValues(alpha: 0.1);
        icon = Icons.error;
        text = service.lastError ?? 'Error en la operación';
        break;
      default:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: service.status == BackupStatus.success || service.status == BackupStatus.error
          ? () => service.resetStatus()
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bgColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: service.status == BackupStatus.error ? LvsColors.red : LvsColors.teal, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  color: service.status == BackupStatus.error ? LvsColors.red : Colors.white,
                ),
              ),
            ),
            if (service.status == BackupStatus.uploading || service.status == BackupStatus.downloading)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: LvsColors.teal)),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSection(CloudBackupService service) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('RESPALDO EN SUPABASE'),
          const SizedBox(height: 8),
          const Text(
            'Guarda tu configuración en la nube de Supabase.\nSolo visible para este dispositivo.',
            style: TextStyle(fontSize: 10, color: LvsColors.text3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.cloud_upload,
                  label: 'SUBIR',
                  color: LvsColors.teal,
                  onTap: service.status == BackupStatus.uploading || service.status == BackupStatus.downloading
                      ? null
                      : () async {
                          final ok = await service.exportToCloud();
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('☁️ Respaldo subido correctamente'), backgroundColor: Color(0xFF00C853)),
                            );
                          } else if (mounted && service.lastError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ ${service.lastError}'), backgroundColor: LvsColors.red),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.cloud_download,
                  label: 'RESTAURAR',
                  color: LvsColors.violet,
                  onTap: service.backups.isEmpty || service.status == BackupStatus.uploading || service.status == BackupStatus.downloading
                      ? null
                      : () async {
                          final data = await service.restoreFromCloud(service.backups.first.name);
                          if (data != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('♻️ Respaldo restaurado correctamente'), backgroundColor: Color(0xFF00C853)),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalSection(CloudBackupService service) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('RESPALDO LOCAL'),
          const SizedBox(height: 8),
          const Text(
            'Exporta tu configuración como archivo .json\npara guardarlo donde quieras.',
            style: TextStyle(fontSize: 10, color: LvsColors.text3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.file_upload,
                  label: 'EXPORTAR',
                  color: LvsColors.pink,
                  onTap: service.status == BackupStatus.uploading || service.status == BackupStatus.downloading
                      ? null
                      : () async {
                          final path = await service.exportToFile();
                          if (path != null && mounted) {
                            await Share.shareXFiles(
                              [XFile(path)],
                              text: 'Respaldo Velvet Sync',
                            );
                          }
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.file_download,
                  label: 'IMPORTAR',
                  color: LvsColors.amber,
                  onTap: service.status == BackupStatus.uploading || service.status == BackupStatus.downloading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                          );
                          if (result != null && result.files.single.path != null && mounted) {
                            final data = await service.importFromFile(result.files.single.path!);
                            if (data != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('♻️ Configuración importada correctamente'), backgroundColor: Color(0xFF00C853)),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExistingBackups(CloudBackupService service) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('RESPALDOS ANTERIORES'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: LvsColors.text3),
                onPressed: () => service.listBackups(),
              ),
            ],
          ),
          ...service.backups.map((backup) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LvsColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done, color: LvsColors.teal, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          backup.name.length > 30 ? '${backup.name.substring(0, 30)}...' : backup.name,
                          style: const TextStyle(fontSize: 9, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${backup.formattedSize} · ${backup.createdAt.day}/${backup.createdAt.month}/${backup.createdAt.year} ${backup.createdAt.hour}:${backup.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 8, color: LvsColors.text3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restore, size: 16, color: LvsColors.violet),
                    onPressed: () async {
                      final data = await service.restoreFromCloud(backup.name);
                      if (data != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('♻️ Respaldo restaurado'), backgroundColor: Color(0xFF00C853)),
                        );
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: LvsColors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: LvsColors.bgCard,
                          title: const Text('ELIMINAR RESPALDO', style: TextStyle(fontSize: 14, color: Colors.white)),
                          content: const Text('¿Eliminar este respaldo de la nube?', style: TextStyle(fontSize: 12, color: LvsColors.text3)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3))),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ELIMINAR', style: TextStyle(color: LvsColors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await service.deleteCloudBackup(backup.name);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.white.withValues(alpha: 0.03) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDisabled ? Colors.white10 : color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isDisabled ? LvsColors.text3 : color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isDisabled ? LvsColors.text3 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
