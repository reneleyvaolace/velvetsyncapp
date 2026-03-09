// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/catalog_service.dart · v3.0.0
// Catálogo con Fallback + Persistencia SharedPreferences
// Los dispositivos pre-registrados se guardan y sobreviven reinicios
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/toy_model.dart';
import 'supabase_service.dart';

// ── Clave de almacenamiento ─────────────────────────────────────
const _kPreregisteredKey = 'lvs_preregistered_devices';

// Provider solo para los pre-registrados (donde vive la persistencia reactiva)
final preregisteredProvider = StateProvider<List<ToyModel>>((ref) => []);

final catalogProvider = StateNotifierProvider<CatalogNotifier, AsyncValue<List<ToyModel>>>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CatalogNotifier(supabase, ref);
});

class CatalogNotifier extends StateNotifier<AsyncValue<List<ToyModel>>> {
  final SupabaseService _supabase;
  final Ref _ref;
  List<ToyModel> _serverCatalog = [];
  List<ToyModel> _preregisteredList = []; // Persisten en SharedPreferences

  CatalogNotifier(this._supabase, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Cargar pre-registrados del almacenamiento local primero (instantáneo)
    await _loadPreregistered();
    // 2. Luego cargar el catálogo del servidor
    await fetchCatalog();
  }

  // ─── PERSISTENCIA ─────────────────────────────────────────────

  Future<void> _loadPreregistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPreregisteredKey) ?? [];
      _preregisteredList = raw
          .map((s) {
            try { return ToyModel.fromJson(jsonDecode(s)); }
            catch (e) { 
              debugPrint('⚠️ Error decodificando: $e');
              return null; 
            }
          })
          .whereType<ToyModel>()
          .toList();
      
      // ✨ SINCRONIZACIÓN REACTIVA
      _ref.read(preregisteredProvider.notifier).state = _preregisteredList;
      debugPrint('💾 Pre-registrados cargados: ${_preregisteredList.length}');
    } catch (e) {
      debugPrint('⚠️ No se pudieron cargar pre-registrados: $e');
    }
  }

  Future<void> _savePreregistered() async {
    try {
      _ref.read(preregisteredProvider.notifier).state = _preregisteredList;
      final prefs = await SharedPreferences.getInstance();
      final raw = _preregisteredList.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_kPreregisteredKey, raw);
    } catch (e) {
      debugPrint('⚠️ Error guardando pre-registrados: $e');
    }
  }

  // Combina catálogo del servidor + pre-registrados (sin duplicados)
  List<ToyModel> _merged() {
    final all = List<ToyModel>.from(_serverCatalog);
    for (final pre in _preregisteredList) {
      if (!all.any((t) => t.id == pre.id)) {
        all.add(pre);
      }
    }
    return all;
  }

  // ─── CATÁLOGO SERVIDOR ─────────────────────────────────────────

  Future<void> fetchCatalog() async {
    try {
      // Mostrar pre-registrados inmediatamente mientras carga
      if (_preregisteredList.isNotEmpty) {
        state = AsyncValue.data(_merged());
      } else {
        state = const AsyncValue.loading();
      }

      // Intentar Supabase
      final toys = await _supabase.fetchDeviceCatalog();

      if (toys.isNotEmpty) {
        _serverCatalog = toys;
        debugPrint('📦 Catálogo Supabase: ${toys.length} dispositivos.');
      } else {
        // Fallback local
        _serverCatalog = _localFallbackCatalog();
        debugPrint('⚠️ Usando catálogo local (${_serverCatalog.length} items).');
      }

      state = AsyncValue.data(_merged());
    } catch (e, stack) {
      _serverCatalog = _localFallbackCatalog();
      if (_serverCatalog.isNotEmpty || _preregisteredList.isNotEmpty) {
        state = AsyncValue.data(_merged());
      } else {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  // ─── PRE-REGISTRO / AGREGAR ────────────────────────────────────

  Future<ToyModel?> addByKey(String key) async {
    final String rawInput = key.trim();
    if (rawInput.isEmpty) return null;

    // ── 1. Extracción de ID (URLs, códigos QR, etc.) ────────
    String cleanId = rawInput;
    if (rawInput.startsWith('http')) {
      final uri = Uri.tryParse(rawInput);
      if (uri != null) {
        cleanId = uri.queryParameters['id'] ?? uri.queryParameters['k'] ?? rawInput;
        if (cleanId == rawInput) {
          final regExp = RegExp(r'(\d{4,})');
          final match = regExp.firstMatch(rawInput);
          if (match != null) cleanId = match.group(0)!;
        }
      }
    }

    // Si es un ID corto, nos aseguramos de que sean solo números
    if (cleanId.length <= 6) {
      cleanId = cleanId.replaceAll(RegExp(r'[^0-9]'), '');
    }
    if (cleanId.isEmpty) cleanId = rawInput.toLowerCase();
    else cleanId = cleanId.toLowerCase();

    debugPrint('🔎 Catalog: Procesando búsqueda para "$cleanId"');

    // ── 2. BYPASS INMEDIATO (Knight 8154) ────────────────────
    if (cleanId == '8154' || cleanId.contains('knight')) {
      final knight = _localFallbackCatalog().first; 
      if (!_preregisteredList.any((t) => t.id == knight.id)) {
        _preregisteredList = [..._preregisteredList, knight];
        await _savePreregistered();
        state = AsyncValue.data(_merged());
      }
      return knight;
    }

    // ── 3. Búsqueda en Supabase (Base de Datos Real) ────────
    try {
      final toy = await _supabase.fetchDeviceById(cleanId);
      if (toy != null) {
        if (!_preregisteredList.any((t) => t.id == toy.id)) {
          _preregisteredList = [..._preregisteredList, toy];
          await _savePreregistered();
          state = AsyncValue.data(_merged());
        }
        return toy;
      }
    } catch (e) {
      debugPrint('⚠️ Supabase Error: $e');
    }

    // ── 4. Búsqueda en Fallback Local General ───────────────
    final locals = _localFallbackCatalog();
    final localMatch = locals.where((t) => 
      t.id.toLowerCase() == cleanId || 
      t.name.toLowerCase().contains(cleanId)
    ).toList();

    if (localMatch.isNotEmpty) {
      final found = localMatch.first;
      if (!_preregisteredList.any((t) => t.id == found.id)) {
        _preregisteredList = [..._preregisteredList, found];
        await _savePreregistered();
        state = AsyncValue.data(_merged());
      }
      return found;
    }

    debugPrint('❌ No se encontró dispositivo: $cleanId');
    return null;
  }

  /// Registra un ToyModel directamente (para cuando se crea manualmente)
  Future<void> addManual(ToyModel toy) async {
    if (_preregisteredList.any((t) => t.id == toy.id)) return;
    _preregisteredList = [..._preregisteredList, toy];
    await _savePreregistered();
    state = AsyncValue.data(_merged());
    debugPrint('✅ Agregado manualmente: ${toy.name}');
  }

  /// Lista de todos los dispositivos pre-registrados (para mostrar en home)
  List<ToyModel> get preregistered => List.unmodifiable(_preregisteredList);

  // ─── CRUD ─────────────────────────────────────────────────────

  void updateDevice(String oldId, String newName, String newId) {
    final all = state.valueOrNull ?? [];
    final updated = all.map((t) {
      if (t.id == oldId) {
        return ToyModel(
          id: newId.isNotEmpty ? newId : t.id,
          name: newName.isNotEmpty ? newName : t.name,
          usageType: t.usageType,
          targetAnatomy: t.targetAnatomy,
          stimulationType: t.stimulationType,
          motorLogic: t.motorLogic,
          imageUrl: t.imageUrl,
          supportedFuncs: t.supportedFuncs,
          isPrecise: t.isPrecise,
          broadcastPrefix: t.broadcastPrefix,
        );
      }
      return t;
    }).toList();

    // Actualizar también en pre-registrados
    _preregisteredList = _preregisteredList.map((t) {
      if (t.id == oldId) {
        return ToyModel(
          id: newId.isNotEmpty ? newId : t.id,
          name: newName.isNotEmpty ? newName : t.name,
          usageType: t.usageType, targetAnatomy: t.targetAnatomy,
          stimulationType: t.stimulationType, motorLogic: t.motorLogic,
          imageUrl: t.imageUrl, supportedFuncs: t.supportedFuncs,
          isPrecise: t.isPrecise, broadcastPrefix: t.broadcastPrefix,
        );
      }
      return t;
    }).toList();
    _savePreregistered();
    state = AsyncValue.data(updated);
  }

  void removeDevice(String id) {
    final all = state.valueOrNull ?? [];
    _preregisteredList = _preregisteredList.where((t) => t.id != id).toList();
    _savePreregistered();
    state = AsyncValue.data(all.where((t) => t.id != id).toList());
  }

  // ─── CATÁLOGO LOCAL DE EMERGENCIA ─────────────────────────────

  List<ToyModel> _localFallbackCatalog() {
    return [
      ToyModel(
        id: '8154', name: 'Knight No. 3',
        usageType: 'Wearable', targetAnatomy: 'Universal',
        stimulationType: 'Vibración + Empuje', motorLogic: 'Dual Channel',
        imageUrl: 'https://i.imgur.com/ZGqFl5R.png',
        supportedFuncs: 'speed,vibration,thrust,pattern',
        isPrecise: true, broadcastPrefix: '77 62 4d 53 45',
      ),
      ToyModel(
        id: '9001', name: 'LVS Aria Pro',
        usageType: 'Wearable', targetAnatomy: 'Universal',
        stimulationType: 'Vibración', motorLogic: 'Single Channel',
        imageUrl: '',
        supportedFuncs: 'speed,vibration,pattern',
        isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
      ),
    ];
  }
}
