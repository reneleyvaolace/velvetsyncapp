// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/models/funscript.dart
// Modelo de Datos para Funscript (Video Sync)
// 
// Formato Funscript: Estándar de la industria para sincronización
// de videos con juguetes hápticos.
//
// Especificación: https://buttplug.io/stpihkal/video-encoding-formats/funscript/
// Inspirado en: ScriptPlayer (https://github.com/FredTungsten/ScriptPlayer)
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

// ═══════════════════════════════════════════════════════════════
// Funscript Model
// ═══════════════════════════════════════════════════════════════

/// Script interactivo para sincronización de video con juguetes
///
/// Formato JSON con timestamps y posiciones para controlar
/// dispositivos hápticos durante reproducción de video.
class Funscript {
  /// Versión del formato (ej: "1.0")
  final String version;

  /// ¿Invertir dirección del movimiento?
  final bool inverted;

  /// Rango de movimiento (0-90 grados típico)
  final int range;

  /// Lista de acciones temporizadas
  final List<FunscriptAction> actions;

  /// Metadata opcional del script
  final FunscriptMetadata? metadata;

  const Funscript({
    required this.version,
    this.inverted = false,
    this.range = 90,
    required this.actions,
    this.metadata,
  });

  /// Cargar desde archivo
  static Future<Funscript> fromFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    return Funscript.fromString(content);
  }

  /// Cargar desde string JSON
  factory Funscript.fromString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return Funscript.fromJson(json);
  }

  /// Cargar desde JSON
  factory Funscript.fromJson(Map<String, dynamic> json) {
    final actionsJson = json['actions'] as List? ?? [];
    
    return Funscript(
      version: json['version'] ?? '1.0',
      inverted: json['inverted'] ?? false,
      range: json['range'] ?? 90,
      actions: actionsJson
          .whereType<Map<String, dynamic>>()
          .map((a) => FunscriptAction.fromJson(a))
          .toList(),
      metadata: json['metadata'] != null
          ? FunscriptMetadata.fromJson(json['metadata'])
          : null,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'inverted': inverted,
      'range': range,
      'actions': actions.map((a) => a.toJson()).toList(),
      if (metadata != null) 'metadata': metadata!.toJson(),
    };
  }

  /// Guardar a archivo
  Future<void> toFile(String path) async {
    final file = File(path);
    await file.writeAsString(jsonEncode(toJson()));
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Búsqueda
  // ═══════════════════════════════════════════════════════════════

  /// Obtener posición en timestamp específico
  ///
  /// [timestamp] - Timestamp desde inicio del video
  /// Retorna: Intensidad normalizada (0.0-1.0)
  double getPositionAt(Duration timestamp) {
    if (actions.isEmpty) return 0.0;

    final ms = timestamp.inMilliseconds;

    // Caso especial: antes del primer action
    if (ms <= actions.first.at) {
      return _normalizePosition(actions.first.pos);
    }

    // Caso especial: después del último action
    if (ms >= actions.last.at) {
      return _normalizePosition(actions.last.pos);
    }

    // Encontrar actions para interpolar
    FunscriptAction? before;
    FunscriptAction? after;

    for (var i = 0; i < actions.length - 1; i++) {
      if (actions[i].at <= ms && actions[i + 1].at > ms) {
        before = actions[i];
        after = actions[i + 1];
        break;
      }
    }

    // Si no hay interpolación, retornar valor exacto
    if (before == null || after == null) {
      return _normalizePosition(before?.pos ?? 0);
    }

    // Interpolar linealmente
    final progress = (ms - before.at) / (after.at - before.at);
    final pos = before.pos + (after.pos - before.pos) * progress;

    return _normalizePosition(pos.round());
  }

  /// Normalizar posición a 0.0-1.0
  double _normalizePosition(int pos) {
    final normalized = pos / 99.0;
    final value = inverted ? 1.0 - normalized : normalized;
    return value.clamp(0.0, 1.0);
  }

  /// Obtener acción más cercana a timestamp
  FunscriptAction? getActionAt(Duration timestamp) {
    final ms = timestamp.inMilliseconds;
    
    // Búsqueda binaria para eficiencia
    var left = 0;
    var right = actions.length - 1;
    
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final action = actions[mid];
      
      if ((action.at - ms).abs() < 50) { // Tolerancia de 50ms
        return action;
      }
      
      if (action.at < ms) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // Métodos de Estadísticas
  // ═══════════════════════════════════════════════════════════════

  /// Duración total del script (ms del último action)
  int get durationMs => actions.isEmpty ? 0 : actions.last.at;

  /// Duración como Duration
  Duration get duration => Duration(milliseconds: durationMs);

  /// Cantidad de acciones
  int get actionCount => actions.length;

  /// Posición mínima
  int get minPosition => actions.isEmpty ? 0 : actions.map((a) => a.pos).reduce((a, b) => a < b ? a : b);

  /// Posición máxima
  int get maxPosition => actions.isEmpty ? 0 : actions.map((a) => a.pos).reduce((a, b) => a > b ? a : b);

  /// Posición promedio
  double get averagePosition {
    if (actions.isEmpty) return 0.0;
    final sum = actions.fold<int>(0, (sum, a) => sum + a.pos);
    return sum / actions.length;
  }

  /// Velocidad promedio (acciones por segundo)
  double get averageSpeed {
    if (durationMs == 0) return 0.0;
    return actions.length / (durationMs / 1000);
  }

  @override
  String toString() {
    return 'Funscript(version: $version, actions: ${actions.length}, duration: ${duration.inSeconds}s)';
  }
}

// ═══════════════════════════════════════════════════════════════
// Funscript Action
// ═══════════════════════════════════════════════════════════════

/// Acción individual en script Funscript
class FunscriptAction {
  /// Posición del dispositivo (0-99)
  /// 0 = completamente retraído
  /// 99 = completamente extendido
  final int pos;

  /// Timestamp en milisegundos desde inicio del video
  final int at;

  const FunscriptAction({
    required this.pos,
    required this.at,
  });

  /// Validar acción
  bool get isValid => pos >= 0 && pos <= 99 && at >= 0;

  /// Posición normalizada (0.0-1.0)
  double get normalizedPos => pos / 99.0;

  /// Timestamp como Duration
  Duration get asDuration => Duration(milliseconds: at);

  /// Cargar desde JSON
  factory FunscriptAction.fromJson(Map<String, dynamic> json) {
    return FunscriptAction(
      pos: json['pos'] as int? ?? 0,
      at: json['at'] as int? ?? 0,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'pos': pos,
      'at': at,
    };
  }

  @override
  String toString() {
    return 'FunscriptAction(pos: $pos, at: ${asDuration.inSeconds}.${(at % 1000).toString().padLeft(3, '0')}s)';
  }
}

// ═══════════════════════════════════════════════════════════════
// Funscript Metadata
// ═══════════════════════════════════════════════════════════════

/// Metadata opcional de script Funscript
class FunscriptMetadata {
  /// Título del script
  final String? title;

  /// Autor/director
  final String? director;

  /// Actores/performers
  final List<String> performers;

  /// Tags/categorías
  final List<String> tags;

  /// URL de origen
  final String? sourceUrl;

  /// Fecha de creación
  final DateTime? createdAt;

  const FunscriptMetadata({
    this.title,
    this.director,
    this.performers = const [],
    this.tags = const [],
    this.sourceUrl,
    this.createdAt,
  });

  /// Cargar desde JSON
  factory FunscriptMetadata.fromJson(Map<String, dynamic> json) {
    return FunscriptMetadata(
      title: json['title'],
      director: json['director'],
      performers: List<String>.from(json['performers'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      sourceUrl: json['source_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (director != null) 'director': director,
      if (performers.isNotEmpty) 'performers': performers,
      if (tags.isNotEmpty) 'tags': tags,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// Extensiones
// ═══════════════════════════════════════════════════════════════

extension FunscriptDurationExtension on Duration {
  /// Formatear como MM:SS.mmm
  String toFunscriptTimestamp() {
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }
}

// ═══════════════════════════════════════════════════════════════
// Ejemplos de Uso
// ═══════════════════════════════════════════════════════════════

/*
// Ejemplo 1: Cargar script
final funscript = await Funscript.fromFile('my-video.funscript');
lvsLog('Duración: ${funscript.duration.inSeconds}s');
lvsLog('Acciones: ${funscript.actionCount}');

// Ejemplo 2: Obtener posición durante reproducción
videoPlayer.addListener(() {
  final position = videoPlayer.value.position;
  final intensity = funscript.getPositionAt(position);
  
  // Enviar a juguete (0.0-1.0)
  toy.vibrate(intensity);
});

// Ejemplo 3: Crear script manualmente
final script = Funscript(
  version: '1.0',
  actions: [
    FunscriptAction(pos: 0, at: 0),
    FunscriptAction(pos: 99, at: 1000),
    FunscriptAction(pos: 50, at: 2000),
    FunscriptAction(pos: 0, at: 3000),
  ],
);
await script.toFile('custom-script.funscript');

// Ejemplo 4: Estadísticas
lvsLog('Velocidad promedio: ${funscript.averageSpeed.toStringAsFixed(2)} acciones/segundo');
lvsLog('Posición promedio: ${(funscript.averagePosition * 100).round()}%');
lvsLog('Rango: ${funscript.minPosition}-${funscript.maxPosition}');
*/
