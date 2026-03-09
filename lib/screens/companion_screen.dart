import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../services/gemini_service.dart';

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
  
  // Variables sensoriales
  int _currentM1 = 0;
  int _currentM2 = 0;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    
    // Controlador de Shake que fluye continuamente 
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avatarPath = prefs.getString('companion_avatar');
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('companion_avatar', pickedFile.path);
      setState(() {
        _avatarPath = pickedFile.path;
      });
    }
  }

  void _sendMessage() async {
    final geminiService = ref.read(geminiServiceProvider);
    if (_textController.text.trim().isEmpty) return;

    final userText = _textController.text.trim();
    _textController.clear();

    setState(() {
      _messages.insert(0, ChatMessage(userText, isUser: true));
      _isLoading = true;
    });

    final response = await geminiService.sendMessage(userText);

    if (mounted) {
      setState(() {
        _messages.insert(0, ChatMessage(response.text, isUser: false));
        _currentM1 = response.motor1;
        _currentM2 = response.motor2;
        _isLoading = false;
      });
      _scrollToBottom();

      // ✨ ACTIVAR HARDWARE REAL
      final ble = ref.read(bleProvider);
      if (ble.isConnected) {
        // Enviar ambos canales sincronizados (Knight 8154)
        ble.sendMultimediaSync(_currentM1, _currentM2);
      }

      // AUTO-STOP VISUAL Y HARDWARE: Apagar después de 5-8 seg
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            _currentM1 = 0;
            _currentM2 = 0;
          });
          // Detener hardware real
          final bleNow = ref.read(bleProvider);
          if (bleNow.isConnected) bleNow.emergencyStop(); 
        }
      });
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
  void dispose() {
    _shakeController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    // Hardware Kill al salir
    ref.read(geminiServiceProvider).shutdownHardwareEmergency();
    super.dispose();
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
        title: const Text('Compañía Digital'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.orangeAccent),
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
                      child: _avatarPath == null ? const Icon(Icons.person, size: 70, color: Colors.white54) : null,
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
