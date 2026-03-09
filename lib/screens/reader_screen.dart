// ═══════════════════════════════════════════════════════════════
// LVS Control · lib/screens/reader_screen.dart · v2.0.0
// Lector Háptico: Diccionario ampliado + detección robusta
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_service.dart';
import '../ble/lvs_commands.dart';
import '../theme.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final TextEditingController _textController = TextEditingController(
    text: "Toca las palabras resaltadas para sentir la historia...\n\n"
          "De repente, el ritmo se volvió FUERTE y persistente. "
          "Sentía como todo VIBRA en sintonía con su respiración. "
          "El PULSO se aceleraba, RAPIDO e imparable. "
          "Buscaba un contacto DURO, algo que la sacudiera por completo. "
          "Luego, todo se volvió SUAVE, un susurro en la piel, un movimiento LENTO y rítmico. "
          "Con cada LATIDO sentía más. Finalmente decidió un ALTO total."
  );

  Timer? _autoStopTimer;

  // ──────────────────────────────────────────────────────────────
  // Diccionario: mapa de raíces → comando BLE
  // Clave = palabra en MAYÚSCULAS sin acentos (normalizado)
  // ──────────────────────────────────────────────────────────────
  static final Map<String, List<int>> _keywords = {
    // ── Intensidad alta / Canal 1 ──────────────────────────────
    'FUERTE'   : LvsCommands.preciseChannel1(200),
    'FUERZA'   : LvsCommands.preciseChannel1(200),
    'DURO'     : LvsCommands.preciseChannel1(255),
    'DURA'     : LvsCommands.preciseChannel1(255),
    'MAXIMO'   : LvsCommands.preciseChannel1(255),
    'MAXIMA'   : LvsCommands.preciseChannel1(255),
    'INTENSO'  : LvsCommands.preciseChannel1(220),
    'INTENSA'  : LvsCommands.preciseChannel1(220),
    'FUEGO'    : LvsCommands.preciseChannel1(230),
    'PROFUNDO' : LvsCommands.preciseChannel1(210),
    'PROFUNDA' : LvsCommands.preciseChannel1(210),
    // ── Vibración / Canal 2 ────────────────────────────────────
    'VIBRA'    : LvsCommands.preciseChannel2(200),
    'VIBRABA'  : LvsCommands.preciseChannel2(200),
    'VIBRACION': LvsCommands.preciseChannel2(200),
    'VIBRAR'   : LvsCommands.preciseChannel2(200),
    'RAPIDO'   : LvsCommands.preciseChannel2(255),
    'RAPIDA'   : LvsCommands.preciseChannel2(255),
    'VELOZ'    : LvsCommands.preciseChannel2(240),
    'PULSO'    : LvsCommands.preciseChannel2(180),
    'LATIDO'   : LvsCommands.preciseChannel2(160),
    'TEMBLOR'  : LvsCommands.preciseChannel2(200),
    'TIEMBLA'  : LvsCommands.preciseChannel2(200),
    // ── Baja intensidad ────────────────────────────────────────
    'SUAVE'    : LvsCommands.preciseChannel1(50),
    'SUAVEMENTE': LvsCommands.preciseChannel1(50),
    'LENTO'    : LvsCommands.preciseChannel1(40),
    'LENTA'    : LvsCommands.preciseChannel1(40),
    'DESPACIO' : LvsCommands.preciseChannel1(35),
    'LIGERO'   : LvsCommands.preciseChannel1(60),
    'LIGERA'   : LvsCommands.preciseChannel1(60),
    // ── Stop ───────────────────────────────────────────────────
    'ALTO'     : LvsCommands.cmdStop,
    'PARA'     : LvsCommands.cmdStop,
    'DETENTE'  : LvsCommands.cmdStop,
    'PAUSA'    : LvsCommands.cmdStop,
    'STOP'     : LvsCommands.cmdStop,
    'QUIETO'   : LvsCommands.cmdStop,
    'QUIETA'   : LvsCommands.cmdStop,
  };

  // Normaliza: quita acentos, pasa a mayúsculas, elimina signos de puntuación
  static String _normalize(String word) {
    // Tabla de reemplazo de caracteres extendidos
    final Map<String, String> subs = {
      '\u00e1': 'A', '\u00e9': 'E', '\u00ed': 'I', '\u00f3': 'O', '\u00fa': 'U',
      '\u00c1': 'A', '\u00c9': 'E', '\u00cd': 'I', '\u00d3': 'O', '\u00da': 'U',
      '\u00e0': 'A', '\u00e8': 'E', '\u00ec': 'I', '\u00f2': 'O', '\u00f9': 'U',
      '\u00e2': 'A', '\u00ea': 'E', '\u00ee': 'I', '\u00f4': 'O', '\u00fb': 'U',
      '\u00e4': 'A', '\u00eb': 'E', '\u00ef': 'I', '\u00f6': 'O', '\u00fc': 'U',
      '\u00f1': 'N', '\u00d1': 'N',
    };
    var result = word.toUpperCase();
    for (final e in subs.entries) {
      result = result.replaceAll(e.key.toUpperCase(), e.value);
    }
    // Quitar todo lo que no sea A-Z
    return result.replaceAll(RegExp(r'[^A-Z]'), '');
  }

  // Determina el canal de un comando para asignar el color en UI
  // Retorna: 1=CH1(rosa), 2=CH2(teal), 0=STOP(rojo)
  static int _cmdChannel(List<int> cmd) {
    if (cmd.isEmpty) return 0;
    if (cmd[0] == LvsCommands.cmdStop[0]) return 0; // Stop
    if (cmd[0] == 0xD6 || cmd[0] == 0xD5 || cmd[0] == 0xD4 || cmd[0] == 0xD7) return 1; // CH1
    if (cmd[0] == 0xA6 || cmd[0] == 0xA5) return 2; // CH2
    return 1; // default
  }

  // Devuelve el comando si la palabra (o su raíz) está en el diccionario
  List<int>? _matchKeyword(String raw) {
    final norm = _normalize(raw);
    if (norm.isEmpty) return null;

    // Búsqueda exacta
    if (_keywords.containsKey(norm)) return _keywords[norm];

    // Búsqueda por prefijo (mínimo 4 letras): ej. "VIBRAN" → "VIBRA"
    if (norm.length >= 4) {
      for (final k in _keywords.keys) {
        if (norm.startsWith(k) || k.startsWith(norm)) {
          return _keywords[k];
        }
      }
    }
    return null;
  }

  void _triggerHaptic(String word) {
    final ble = ref.read(bleProvider);
    if (!ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conecta el dispositivo primero'), duration: Duration(seconds: 1)),
      );
      return;
    }

    final cmd = _matchKeyword(word);
    if (cmd == null) return;

    HapticFeedback.mediumImpact();
    _autoStopTimer?.cancel();

    ble.writeCommand(cmd, label: 'READER:${_normalize(word)}');

    final isStop = cmd == LvsCommands.cmdStop;
    if (!isStop) {
      // Auto-stop después de 3 segundos
      _autoStopTimer = Timer(const Duration(seconds: 3), () {
        ble.writeCommand(LvsCommands.cmdStop, label: 'READER_AUTO_STOP');
      });
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: LvsColors.bg,
        appBar: AppBar(
          title: const Text('LECTOR HÁPTICO'),
          backgroundColor: Colors.transparent,
          actions: [
            // Botón de parada de emergencia
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: LvsColors.red),
              tooltip: 'Parada de Emergencia',
              onPressed: () {
                _autoStopTimer?.cancel();
                ref.read(bleProvider).emergencyStop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Área de lectura ──────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: CardGlass(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.touch_app, color: LvsColors.pink, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Toca las palabras en rosa para activar',
                            style: TextStyle(color: LvsColors.text3, fontSize: 10, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildInteractiveText(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Leyenda de palabras clave ────────────────────
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chipLabel('ALTA INTENSIDAD', LvsColors.pink),
                  _chipLabel('VIBRACIÓN', LvsColors.teal),
                  _chipLabel('SUAVE/LENTO', LvsColors.violet),
                  _chipLabel('STOP', LvsColors.red),
                ],
              ),
            ),

            // ── Editor de texto ──────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: LvsColors.pink.withValues(alpha: 0.15)),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(color: LvsColors.text2, fontSize: 13, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu historia aquí...\nLas palabras hápticas se resaltarán automáticamente.',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 12),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveText() {
    final rawText = _textController.text;
    // IMPORTANTE: split SIN grupo capturante, luego reconstruir con espacio
    // Separar por líneas primero, luego por palabras
    final lines = rawText.split('\n');
    List<InlineSpan> spans = [];

    for (int li = 0; li < lines.length; li++) {
      final words = lines[li].split(' ');
      for (int wi = 0; wi < words.length; wi++) {
        final token = words[wi];
        if (token.isEmpty) {
          spans.add(const TextSpan(text: ' '));
          continue;
        }

        final cmd = _matchKeyword(token);
        if (cmd != null) {
          final channel = _cmdChannel(cmd);
          final Color color = channel == 0
              ? LvsColors.red
              : channel == 2
                  ? LvsColors.teal
                  : LvsColors.pink;

          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => _triggerHaptic(token),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.7)),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6)],
                  ),
                  child: Text(
                    token,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          spans.add(TextSpan(
            text: token,
            style: const TextStyle(color: LvsColors.text1, fontSize: 16, height: 1.6),
          ));
        }
        // Espacio entre palabras (menos al final de línea)
        if (wi < words.length - 1) {
          spans.add(const TextSpan(text: ' '));
        }
      }
      // Salto de línea entre líneas (menos la última)
      if (li < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _chipLabel(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}
