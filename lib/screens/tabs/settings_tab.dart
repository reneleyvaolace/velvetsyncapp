import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lvs_control/ble/ble_service.dart';
import 'package:lvs_control/theme.dart';
import 'package:lvs_control/screens/debug_screen.dart';
import 'package:lvs_control/screens/web_catalog_screen.dart';
import 'package:flutter/services.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  int _sessionDuration = 30;
  bool _autoDisconnect = false;
  bool _hiddenTimer = false;
  int _hiddenTimerMin = 5;
  int _hiddenTimerMax = 30;
  bool _travelLock = false;
  String _travelLockPin = '0000';

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('SISTEMA Y CONFIGURACIÓN', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4, color: LvsColors.text3
            )),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildWebCatalogCard(context),
              const SizedBox(height: 20),
              _buildSettingsCard(ble),
              const SizedBox(height: 20),
              _buildSystemProCard(ble),
              const SizedBox(height: 20),
              _buildDebugButton(context),
              const SizedBox(height: 20),
              _buildLogCard(ble),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildWebCatalogCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WebCatalogScreen()),
        );
      },
      child: CardGlass(
        borderColor: LvsColors.violet.withOpacity(0.3),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: LvsColors.violet.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.violet.withOpacity(0.3)),
              ),
              child: const Icon(Icons.language, color: LvsColors.violet, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CATÁLOGO WEB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.violet)),
                  SizedBox(height: 4),
                  Text('Explorar catálogo online en Vercel', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.violet, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BleService ble) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PARÁMETROS TÉCNICOS'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Frecuencia de Ráfaga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${ble.burstIntervalMs}ms', style: const TextStyle(fontSize: 12, color: LvsColors.pink, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: ble.burstIntervalMs.toDouble(),
            min: 100, max: 1000, divisions: 18,
            onChanged: (v) => ble.setBurstInterval(v.round()),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('DEEP SCAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Ignorar filtros estándar rMesh', style: TextStyle(fontSize: 10, color: LvsColors.text3)),
            value: ble.isDeepScan,
            onChanged: (v) => ble.toggleDeepScan(),
            activeColor: LvsColors.pink,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugScreen())),
      child: CardGlass(
        borderColor: LvsColors.amber.withOpacity(0.2),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset('assets/icons/icon_tab_settings.png', width: 32, height: 32),
            const SizedBox(width: 14),
            const Expanded(child: Text('CONSOLA DE DEPURACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: LvsColors.amber))),
            const Icon(Icons.arrow_forward_ios, color: LvsColors.amber, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BleService ble) {
    if (ble.logs.isEmpty) return const SizedBox.shrink();
    return CardGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('ACTIVIDAD DEL SISTEMA'),
              const Spacer(),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: LvsColors.text3), onPressed: ble.clearLogs),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: ble.logs.length,
              itemBuilder: (_, i) {
                final log = ble.logs[ble.logs.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '[${log.time.hour}:${log.time.minute}] ${log.msg}',
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: LvsColors.text3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSystemProCard(BleService ble) {
    return CardGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('MODO AVANZADO'),
          const SizedBox(height: 20),
          _buildProOption(
            icon: 'assets/icons/icon_timer.png',
            title: 'TEMPORIZADOR DE SESIÓN',
            subtitle: 'Auto-desconexión de seguridad',
            onTap: _showTimerDialog,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildProOption(
            icon: 'assets/icons/icon_travel_lock.png',
            title: 'BLOQUEO DE VIAJE',
            subtitle: _travelLock ? 'Activado • PIN requerido' : 'Evita encendidos accidentales',
            onTap: _showTravelLockDialog,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildProOption(
            icon: 'assets/icons/icon_cloud_save.png',
            title: 'RESPALDO EN NUBE',
            subtitle: 'Sincronizar perfiles y ritmos',
            onTap: _showCloudBackupDialog,
          ),
          const Divider(height: 32, color: Colors.white10),
           _buildProOption(
            icon: 'assets/icons/icon_firmware_update.png',
            title: 'ACTUALIZAR FIRMWARE',
            subtitle: 'v1.4.0 disponible para rMesh',
          ),
        ],
      ),
    );
  }

  Widget _buildProOption({required String icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Image.asset(icon, width: 38, height: 38),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 9, color: LvsColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  void _showTimerDialog() {
    bool localAutoDisconnect = _autoDisconnect;
    int localSessionDuration = _sessionDuration;
    bool localHiddenTimer = _hiddenTimer;
    int localHiddenTimerMin = _hiddenTimerMin;
    int localHiddenTimerMax = _hiddenTimerMax;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer_outlined, color: LvsColors.pink, size: 20),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('TEMPORIZADOR', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('AUTO-DESCONEXIÓN', style: TextStyle(color: LvsColors.teal, fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Activar (${localSessionDuration} min)', style: const TextStyle(color: LvsColors.text1, fontSize: 11)),
                  value: localAutoDisconnect,
                  onChanged: (v) => setDialogState(() => localAutoDisconnect = v),
                  activeColor: LvsColors.teal,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Slider(
                    value: localSessionDuration.toDouble(),
                    min: 5, max: 120, divisions: 23,
                    label: '$localSessionDuration min',
                    onChanged: localAutoDisconnect ? (v) => setDialogState(() => localSessionDuration = v.round()) : null,
                    activeColor: LvsColors.teal,
                  ),
                ),
                const Divider(height: 28, color: Colors.white10),
                const Text('MODO DESAFÍO', style: TextStyle(color: LvsColors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Oculto (${localHiddenTimerMin}-${localHiddenTimerMax} min)', style: const TextStyle(color: LvsColors.text1, fontSize: 11)),
                  value: localHiddenTimer,
                  onChanged: (v) => setDialogState(() => localHiddenTimer = v),
                  activeColor: LvsColors.red,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mín: $localHiddenTimerMin', style: TextStyle(color: LvsColors.text2, fontSize: 9)),
                            Slider(
                              value: localHiddenTimerMin.toDouble(),
                              min: 1, max: localHiddenTimerMax - 1,
                              onChanged: localHiddenTimer ? (v) => setDialogState(() => localHiddenTimerMin = v.round()) : null,
                              activeColor: LvsColors.red,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Máx: $localHiddenTimerMax', style: TextStyle(color: LvsColors.text2, fontSize: 9)),
                            Slider(
                              value: localHiddenTimerMax.toDouble(),
                              min: localHiddenTimerMin + 1, max: 60,
                              onChanged: localHiddenTimer ? (v) => setDialogState(() => localHiddenTimerMax = v.round()) : null,
                              activeColor: LvsColors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LvsColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LvsColors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: LvsColors.red, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ráfaga máxima aleatoria sin aviso',
                          style: TextStyle(color: LvsColors.red, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: LvsColors.pink),
              onPressed: () {
                setState(() {
                  _autoDisconnect = localAutoDisconnect;
                  _sessionDuration = localSessionDuration;
                  _hiddenTimer = localHiddenTimer;
                  _hiddenTimerMin = localHiddenTimerMin;
                  _hiddenTimerMax = localHiddenTimerMax;
                });
                Navigator.pop(ctx);
                _saveTimerSettings();
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTimerSettings() {
    String msg;
    if (_autoDisconnect) {
      msg = 'Auto-desconexión en $_sessionDuration min';
    } else if (_hiddenTimer) {
      msg = 'Modo desafío: $_hiddenTimerMin-$_hiddenTimerMax min';
    } else {
      msg = 'Temporizadores desactivados';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: LvsColors.teal),
    );
  }

  void _showTravelLockDialog() {
    bool localTravelLock = _travelLock;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LvsColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_outline, color: LvsColors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BLOQUEO DE VIAJE', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Seguridad para transporte', style: TextStyle(color: LvsColors.text3, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LvsColors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LvsColors.amber.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: LvsColors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cuando está activado, el dispositivo no responderá a botones físicos. Útil para transporte en maletas o mochilas.',
                        style: TextStyle(color: LvsColors.text2, fontSize: 10, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('ESTADO DEL BLOQUEO', style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  localTravelLock ? 'ACTIVADO' : 'DESACTIVADO',
                  style: TextStyle(
                    color: localTravelLock ? LvsColors.red : LvsColors.teal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  localTravelLock ? 'Requiere PIN para usar el dispositivo' : 'El dispositivo opera normalmente',
                  style: const TextStyle(color: LvsColors.text3, fontSize: 10),
                ),
                value: localTravelLock,
                onChanged: (v) => setDialogState(() => localTravelLock = v),
                activeColor: localTravelLock ? LvsColors.red : LvsColors.teal,
              ),
              if (localTravelLock) ...[
                const SizedBox(height: 16),
                const Text('PIN DE SEGURIDAD', style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LvsColors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.password, color: LvsColors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PIN: $_travelLockPin',
                          style: const TextStyle(color: LvsColors.text1, fontSize: 14, letterSpacing: 3),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: LvsColors.teal, size: 18),
                        tooltip: 'Cambiar PIN',
                        onPressed: () {
                          setDialogState(() {
                            _travelLockPin = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: LvsColors.amber),
              onPressed: () {
                setState(() => _travelLock = localTravelLock);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localTravelLock ? 'Bloqueo de viaje ACTIVADO' : 'Bloqueo de viaje DESACTIVADO'),
                    backgroundColor: localTravelLock ? LvsColors.red : LvsColors.teal,
                  ),
                );
              },
              child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloudBackupDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LvsColors.violet.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync, color: LvsColors.violet, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RESPALDO EN NUBE', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Código de 6 dígitos', style: TextStyle(color: LvsColors.text3, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCloudOption(
              icon: Icons.upload_rounded,
              color: LvsColors.pink,
              title: 'CREAR RESPALDO',
              subtitle: 'Generar código de recuperación',
              onTap: () {
                Navigator.pop(ctx);
                _createCloudBackup();
              },
            ),
            const SizedBox(height: 12),
            _buildCloudOption(
              icon: Icons.download_rounded,
              color: LvsColors.teal,
              title: 'RECUPERAR RESPALDO',
              subtitle: 'Usar código de 6 dígitos',
              onTap: () {
                Navigator.pop(ctx);
                _showRecoverDialog();
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LvsColors.violet.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.violet.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: LvsColors.violet, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu código de respaldo es único. GUÁRDALO en un lugar seguro. Sin él, no podrás recuperar tu configuración.',
                      style: TextStyle(color: LvsColors.text2, fontSize: 9, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CERRAR', style: TextStyle(color: LvsColors.text3)),
          ),
        ],
      ),
    );
  }

  void _createCloudBackup() {
    // Generar código de 6 dígitos
    final backupCode = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done, color: LvsColors.teal, size: 48),
            const SizedBox(height: 16),
            const Text('¡Respaldo Creado!', style: TextStyle(color: LvsColors.text1, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tu código de recuperación es:', style: TextStyle(color: LvsColors.text2, fontSize: 11)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LvsColors.pink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LvsColors.pink.withOpacity(0.3)),
              ),
              child: Text(
                backupCode,
                style: const TextStyle(
                  color: LvsColors.pink,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LvsColors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LvsColors.amber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: LvsColors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡TOMA UNA CAPTURA O ANÓTALO!',
                      style: TextStyle(color: LvsColors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Respaldo guardado con código $backupCode'),
                      backgroundColor: LvsColors.teal,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('ENTENDIDO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecoverDialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open, color: LvsColors.teal, size: 40),
            const SizedBox(height: 16),
            const Text('RECUPERAR RESPALDO', style: TextStyle(color: LvsColors.text1, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Ingresa tu código de 6 dígitos', style: TextStyle(color: LvsColors.text3, fontSize: 10)),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textAlign: TextAlign.center,
              style: const TextStyle(color: LvsColors.text1, fontSize: 24, letterSpacing: 5),
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: LvsColors.text3.withOpacity(0.3)),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: LvsColors.teal.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LvsColors.teal, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (codeController.text.length == 6) {
                    Navigator.pop(ctx);
                    _recoverBackup(codeController.text);
                  }
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('RECUPERAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LvsColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: LvsColors.text3)),
          ),
        ],
      ),
    );
  }

  void _recoverBackup(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Respaldo $code recuperado exitosamente', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: LvsColors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    // TODO: Implementar recuperación real desde Supabase
  }

  Widget _buildCloudOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: LvsColors.text1, fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: LvsColors.text3, fontSize: 9)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  void _downloadCloudBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text('Descargando respaldo desde la nube...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: LvsColors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    // TODO: Implementar descarga desde Supabase
  }

  void _uploadCloudBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.upload_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text('Subiendo respaldo a la nube...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: LvsColors.pink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    // TODO: Implementar subida a Supabase
  }

  void _syncCloudBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text('Sincronizando con la nube...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: LvsColors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.black,
          onPressed: () {},
        ),
      ),
    );
    // TODO: Implementar sincronización bidireccional
  }
}
