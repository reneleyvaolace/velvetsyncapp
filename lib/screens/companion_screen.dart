import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../services/ai_service.dart';
import '../services/companion_settings.dart';
import '../theme.dart';
import '../utils/logger.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, {required this.isUser});
}

class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late AnimationController _shakeController;

  bool _isLoading = false;
  String? _avatarPath;
  CompanionSettings _settings = CompanionSettings();

  // Variables sensoriales
  int _currentM1 = 0;
  int _currentM2 = 0;

  final _storage = const FlutterSecureStorage();
  final _companionService = CompanionService();

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadSettings();

    // Controlador de Shake que fluye continuamente
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  Future<void> _loadSettings() async {
    final settings = await _companionService.getSettings();
    if (mounted) {
      setState(() => _settings = settings);
    }
  }

  Future<void> _loadAvatar() async {
    final path = await _storage.read(key: 'companion_avatar');
    setState(() {
      _avatarPath = path;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    // 🔒 SECURITY: Validate avatar path to prevent path traversal attacks
    final path = pickedFile.path;

    // Validate path doesn't contain suspicious patterns
    if (path.contains('..') ||
        path.contains('/') && path.startsWith('/') ||
        path.contains('\\\\') ||
        path.contains('%') ||
        path.contains(';')) {
      lvsLog('⚠️ Invalid avatar path detected: possible path traversal attack', tag: 'COMPANION');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Imagen inválida'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Validate file extension
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final fileExt = path.substring(path.lastIndexOf('.')).toLowerCase();
    if (!validExtensions.contains(fileExt)) {
      lvsLog('⚠️ Invalid avatar file type: $fileExt', tag: 'COMPANION');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Formato de imagen no válido'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Store only the file name, not the full path (more secure)
    final fileName = path.split('/').last.split('\\').last;
    await _storage.write(key: 'companion_avatar', value: fileName);

    if (mounted) {
      setState(() {
        _avatarPath = fileName;
      });
      lvsLog('Avatar updated: $fileName', tag: 'COMPANION');
    }
  }

  void _sendMessage() async {
    final aiService = ref.read(aiServiceProvider);
    if (_textController.text.trim().isEmpty) return;

    final userText = _textController.text.trim();
    _textController.clear();

    // 🔒 PERFORMANCE: Single setState - batch all changes
    if (mounted) {
      setState(() {
        _messages.insert(0, ChatMessage(userText, isUser: true));
        _messages.insert(0, ChatMessage('🔄 Enviando...', isUser: false));
        _isLoading = true;
      });
    }

    final response = await aiService.sendMessage(userText);

    if (mounted) {
      // 🔒 PERFORMANCE: Single setState - batch all changes
      setState(() {
        _messages.removeWhere((m) => m.text == '🔄 Enviando...');

        // Agregar emoji según proveedor
        String emoji = '💬';
        if (response.provider == 'openrouter') emoji = '🤖';
        else if (response.provider == 'timeout') emoji = '⏰';
        else if (response.provider == 'error_404') emoji = '❌';
        else if (response.provider == 'fallback_local') emoji = '💭';

        _messages.insert(0, ChatMessage('$emoji ${response.text}', isUser: false));
        _currentM1 = response.motor1;
        _currentM2 = response.motor2;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _stopHardware() {
    setState(() {
      _currentM1 = 0;
      _currentM2 = 0;
    });
    ref.read(bleProvider).emergencyStop(); // Mucho más robusto que shutdownHardwareEmergency
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔒 PERFORMANCE: Solo animar cuando esta ruta está visible
    final isActive = ModalRoute.of(context)?.isCurrent == true;
    if (isActive && !_shakeController.isAnimating) {
      _shakeController.repeat();
    } else if (!isActive && _shakeController.isAnimating) {
      _shakeController.stop();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    // Hardware Kill al salir
    ref.read(bleProvider).emergencyStop();
    super.dispose();
  }

  void _showSettingsDialog() {
    final nameController = TextEditingController(text: _settings.name);
    CompanionGender selectedGender = _settings.gender;
    CompanionPersonality selectedPersonality = _settings.personality;
    bool saveConversations = _settings.saveConversations;
    bool syncWithSupabase = _settings.syncWithSupabase;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          content: SingleChildScrollView(
            child: Column(
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
                      child: const Icon(Icons.person_rounded, color: LvsColors.violet, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text('CONFIGURAR COMPANION', style: TextStyle(color: LvsColors.text1, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 20),
                // Nombre
                const Text('NOMBRE', style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: LvsColors.text1, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ej: Velvet, Luna, AI...',
                    hintStyle: TextStyle(color: LvsColors.text3.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: LvsColors.violet.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LvsColors.violet, width: 2),
                    ),
                  ),
                  onChanged: (v) => setDialogState(() {}),
                ),
                const SizedBox(height: 20),
                // Género
                const Text('GÉNERO', style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...CompanionGender.values.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<CompanionGender>(
                    title: Text(g.displayName, style: const TextStyle(color: LvsColors.text1, fontSize: 12)),
                    subtitle: Text(g.description, style: TextStyle(color: LvsColors.text3, fontSize: 9)),
                    value: g,
                    groupValue: selectedGender,
                    onChanged: (v) => setDialogState(() => selectedGender = v!),
                    activeColor: LvsColors.violet,
                    contentPadding: EdgeInsets.zero,
                  ),
                )),
                const SizedBox(height: 20),
                // Personalidad
                const Text('PERSONALIDAD', style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...CompanionPersonality.values.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<CompanionPersonality>(
                    title: Text(p.displayName, style: const TextStyle(color: LvsColors.text1, fontSize: 12)),
                    subtitle: Text(p.description, style: TextStyle(color: LvsColors.text3, fontSize: 9)),
                    value: p,
                    groupValue: selectedPersonality,
                    onChanged: (v) => setDialogState(() => selectedPersonality = v!),
                    activeColor: LvsColors.violet,
                    contentPadding: EdgeInsets.zero,
                  ),
                )),
                const SizedBox(height: 20),
                const Divider(height: 32, color: Colors.white10),
                // Privacidad
                const Text('PRIVACIDAD', style: TextStyle(color: LvsColors.text3, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Guardar conversaciones', style: TextStyle(color: LvsColors.text1, fontSize: 12)),
                  subtitle: const Text('Almacenar historial localmente', style: TextStyle(color: LvsColors.text3, fontSize: 9)),
                  value: saveConversations,
                  onChanged: (v) => setDialogState(() => saveConversations = v),
                  activeColor: LvsColors.teal,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Row(
                    children: [
                      const Text('Sincronizar con nube', style: TextStyle(color: LvsColors.text1, fontSize: 12)),
                      const SizedBox(width: 6),
                      Icon(Icons.cloud, size: 14, color: syncWithSupabase ? LvsColors.pink : LvsColors.text3),
                    ],
                  ),
                  subtitle: Text(
                    syncWithSupabase ? 'Activado en Supabase' : 'Solo almacenamiento local',
                    style: TextStyle(color: LvsColors.text3, fontSize: 9),
                  ),
                  value: syncWithSupabase,
                  onChanged: saveConversations
                      ? (v) => setDialogState(() => syncWithSupabase = v)
                      : null,
                  activeColor: LvsColors.pink,
                  contentPadding: EdgeInsets.zero,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LvsColors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LvsColors.amber.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: LvsColors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tu privacidad es importante. Puedes desactivar el guardado en cualquier momento.',
                          style: TextStyle(color: LvsColors.text2, fontSize: 9, height: 1.4),
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
              style: ElevatedButton.styleFrom(backgroundColor: LvsColors.violet),
              onPressed: () async {
                final newSettings = CompanionSettings(
                  name: nameController.text.trim().isEmpty ? 'Velvet' : nameController.text.trim(),
                  gender: selectedGender,
                  personality: selectedPersonality,
                  saveConversations: saveConversations,
                  syncWithSupabase: syncWithSupabase,
                );
                await _companionService.saveSettings(newSettings);
                Navigator.pop(ctx);
                setState(() => _settings = newSettings);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Companion configurado como "${newSettings.name}" (${newSettings.gender.displayName})'),
                    backgroundColor: LvsColors.teal,
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

  @override
  Widget build(BuildContext context) {
    // Calculadora de Shake (Vibración Visual Reactiva)
    // El máximo nivel teórico es 510 (255+255)
    final double shakeMultiplier = 15.0; 
    final double intensityRatio = (_currentM1 + _currentM2) / 510.0;
    final double currentPixels = intensityRatio * shakeMultiplier;

    return Scaffold(
      appBar: AppBar(
        title: Text(_settings.name.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: LvsColors.violet),
            tooltip: 'Configurar Companion',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: Icon(Icons.power_settings_new_rounded, color: LvsColors.red),
            tooltip: 'Parada de Emergencia',
            onPressed: () {
              _stopHardware();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardware silenciado.')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustar Avatar',
            onPressed: _pickAvatar,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ZONA DEL AVATAR (Shake/Glow)
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                // Desplazamiento reactivo de los motores físicos
                double dx = math.sin(_shakeController.value * 2 * math.pi * 5) * currentPixels;
                double dy = math.cos(_shakeController.value * 2 * math.pi * 7) * currentPixels;
  
                // Si los motores están fuertes, resplandece en rojo rosado (Glow)
                final shadowRadius = intensityRatio * 30.0;
  
                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: intensityRatio > 0.1 ? [
                        BoxShadow(
                          color: Colors.pinkAccent.withValues(alpha: intensityRatio * 0.8),
                          blurRadius: shadowRadius,
                          spreadRadius: intensityRatio * 10,
                        ),
                      ] : [],
                    ),
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.grey[850],
                      backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                      child: _avatarPath == null 
                        ? Padding(
                            padding: const EdgeInsets.all(25.0),
                            child: Image.asset('assets/icons/icon_ai_assistant.png'),
                          )
                        : null,
                    ),
                  ),
                );
              },
            ),
            
            if (_currentM1 > 0 || _currentM2 > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Nivel Físico Actual: C1:$_currentM1 | C2:$_currentM2',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ),
              
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white24),
  
            // ZONA DEL CHAT (Minimalista / Mensajería genérica)
            Expanded(
              child: ListView.builder(
                reverse: true, // Listado inverso
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildChatBubble(msg);
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
  
            // ZONA DEL TECLADO
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Envía un mensaje...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8) : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: message.isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: message.isUser ? Radius.zero : const Radius.circular(20),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.black87 : Colors.white,
            fontSize: 15,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
