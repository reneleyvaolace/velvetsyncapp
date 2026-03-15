// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/catalog_service.dart · v3.1.0
// Catálogo con Fallback + Persistencia Cifrada (Secure Storage)
// Los dispositivos pre-registrados se guardan y sobreviven reinicios
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/toy_model.dart';
import 'supabase_service.dart';
import '../ble/ble_service.dart';
import '../utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Clave de almacenamiento ─────────────────────────────────────
const _kPreregisteredKey = 'lvs_preregistered_devices';

/// URL del Catálogo Web de Velvet Sync (Planeado: subdominio de Vercel)
const kWebCatalogUrl = 'https://velvetsync.com/catalog';

// Provider solo para los pre-registrados (donde vive la persistencia reactiva)
final preregisteredProvider = StateProvider<List<ToyModel>>((ref) => []);

// Provider para TODOS los dispositivos del catálogo servidor (para CompatibleDevicesRow)
final serverCatalogProvider = StateNotifierProvider<ServerCatalogNotifier, List<ToyModel>>((ref) {
  return ServerCatalogNotifier();
});

class ServerCatalogNotifier extends StateNotifier<List<ToyModel>> {
  ServerCatalogNotifier() : super(lvsLocalFallback.take(5).toList());
  
  void updateCatalog(List<ToyModel> toys) {
    state = toys;
  }
}

// ✨ Provider para indicar si se está cargando el catálogo desde Supabase
final catalogLoadingProvider = StateProvider<bool>((ref) => true);

final catalogProvider = StateNotifierProvider<CatalogNotifier, AsyncValue<List<ToyModel>>>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CatalogNotifier(supabase, ref);
});

class CatalogNotifier extends StateNotifier<AsyncValue<List<ToyModel>>> {
  final SupabaseService _supabase;
  final Ref _ref;
  final _storage = const FlutterSecureStorage();
  List<ToyModel> _serverCatalog = [];
  List<ToyModel> _preregisteredList = []; // Persisten Cifrados

  CatalogNotifier(this._supabase, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Cargar pre-registrados del almacenamiento local (rápido)
    await _loadPreregistered();
    
    // 2. Cargar catálogo del servidor en segundo plano (NO bloquear la UI)
    // Usamos Future.delayed para que la UI se renderice primero con el fallback
    Future.delayed(Duration.zero, () => fetchCatalog());
  }

  // ─── PERSISTENCIA ─────────────────────────────────────────────

  Future<void> _loadPreregistered() async {
    try {
      final jsonStr = await _storage.read(key: _kPreregisteredKey);
      if (jsonStr == null) return;
      
      final List<dynamic> decoded = jsonDecode(jsonStr);
      _preregisteredList = decoded
          .map((s) {
            try { return ToyModel.fromJson(s); }
            catch (e) { return null; }
          })
          .whereType<ToyModel>()
          .toList();
      
      _ref.read(preregisteredProvider.notifier).state = _preregisteredList;
      
      // Auto-activar el último dispositivo usado si no hay nada conectado
      if (_preregisteredList.isNotEmpty) {
        final ble = _ref.read(bleProvider);
        if (!ble.isConnected) {
          ble.setActiveToy(_preregisteredList.last);
        }
      }
    } catch (e) {
      lvsLog('Error cargando almacenamiento seguro: $e', tag: 'CATALOG');
    }
  }

  Future<void> _savePreregistered() async {
    try {
      _ref.read(preregisteredProvider.notifier).state = _preregisteredList;
      final raw = _preregisteredList.map((t) => t.toJson()).toList();
      await _storage.write(key: _kPreregisteredKey, value: jsonEncode(raw));
    } catch (e) {
      lvsLog('Error guardando en almacenamiento seguro: $e', tag: 'CATALOG');
    }
  }

  // Combina catálogo del servidor + pre-registrados (sin duplicados)
  // v3.2.0: Ahora el estado del proveedor SOLO muestra los pre-registrados
  // para cumplir con la petición de "no cargar ninguno hasta que se dé de alta".
  List<ToyModel> _merged() {
    return _preregisteredList;
  }

  // ─── CATÁLOGO SERVIDOR ─────────────────────────────────────────

  Future<void> fetchCatalog() async {
    // FASE 1: Usar catálogo local inmediato
    final fallback = List<ToyModel>.from(lvsLocalFallback)..shuffle();
    final sample = fallback.take(5).toList();
    
    _serverCatalog = fallback;
    // Usamos microtask para no interferir con el ciclo de construcción de Riverpod
    Future.microtask(() => _ref.read(serverCatalogProvider.notifier).updateCatalog(sample));
    
    state = AsyncValue.data(_merged());

    // FASE 2: Cargar desde Supabase en segundo plano
    _loadFromSupabaseInBackground();
  }

  /// Carga dispositivos desde Supabase en segundo plano sin bloquear la UI
  Future<void> _loadFromSupabaseInBackground() async {
    // Solo mostramos 'loading' en el indicador pequeño si no tenemos datos de Supabase previos
    if (_serverCatalog.length <= _localFallbackCatalog().length) {
      _ref.read(catalogLoadingProvider.notifier).state = true;
    }

    try {
      lvsLog('🔄 Sincronizando catálogo con Supabase...', tag: 'CATALOG');

      final toys = await _supabase.fetchDeviceCatalog(limit: 500).timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );

      if (toys.isNotEmpty) {
        _serverCatalog = toys;

        // Actualizar con 5 aleatorios del catálogo completo
        final shuffled = List<ToyModel>.from(toys)..shuffle();
        final sample = shuffled.take(5).toList();
        _ref.read(serverCatalogProvider.notifier).updateCatalog(sample);

        // Sincronizar pre-registrados con datos frescos
        bool changed = false;
        for (int i = 0; i < _preregisteredList.length; i++) {
          final localToy = _preregisteredList[i];
          try {
            final freshToy = toys.firstWhere((t) => t.id == localToy.id);
            if (localToy.name != freshToy.name || localToy.imageUrl != freshToy.imageUrl) {
              _preregisteredList[i] = freshToy;
              changed = true;
            }
          } catch (_) {}
        }
        if (changed) await _savePreregistered();
        
        lvsLog('✅ Catálogo actualizado: ${toys.length} dispositivos, mostrando 5 aleatorios', tag: 'CATALOG');
      } else {
        lvsLog('⚠️ Supabase devolvió vacío, manteniendo fallback local', tag: 'CATALOG');
      }
      
      // Carga completada
      _ref.read(catalogLoadingProvider.notifier).state = false;
    } catch (e) {
      lvsLog('❌ Error cargando catálogo: $e', tag: 'CATALOG');
      _ref.read(catalogLoadingProvider.notifier).state = false;
    }
  }

  /// Limpieza profunda y recarga desde Supabase (NUKE)
  Future<void> nukeAndReload() async {
    try {
      lvsLog('Iniciando limpieza profunda del catálogo...', tag: 'CATALOG');
      // 1. Borrar persistencia local
      await _storage.delete(key: _kPreregisteredKey);
      
      // 2. Limpiar listas en memoria
      _preregisteredList.clear();
      _serverCatalog.clear();
      _ref.read(preregisteredProvider.notifier).state = [];
      _ref.read(serverCatalogProvider.notifier).updateCatalog([]);
      
      // 3. Recargar todo desde Supabase
      await fetchCatalog();
      lvsLog('Limpieza profunda completada.', tag: 'CATALOG');
    } catch (e) {
      lvsLog('Error durante nuke: $e', tag: 'CATALOG');
    }
  }

  // ─── PRE-REGISTRO / AGREGAR ────────────────────────────────────

  Future<ToyModel?> addByKey(String key) async {
    final String rawInput = key.trim();
    if (rawInput.isEmpty) return null;

    String cleanId = rawInput.toLowerCase();
    
    // ✨ Mejora Artificer: Extraer ID de URLs (ej: .../3778.png o barcode=3778)
    if (cleanId.contains('http') || cleanId.contains('zlmicro.com')) {
      try {
        final uri = Uri.parse(cleanId.contains('http') ? cleanId : 'https://$cleanId');
        if (uri.queryParameters.containsKey('barcode')) {
          cleanId = uri.queryParameters['barcode']!;
        } else if (uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last;
          cleanId = lastSegment.split('.').first; // Quita extensiones como .png
        }
      } catch (e) {
        // Si falla el parseo, intentamos un regex simple para el barcode
        final reg = RegExp(r'barcode=(\d+)');
        final match = reg.firstMatch(cleanId);
        if (match != null) cleanId = match.group(1)!;
      }
    }
    
    // Buscar en servidor o fallback
    ToyModel? found;
    
    // 1. Bypass Knight No. 3
    if (cleanId == '8154' || cleanId.contains('knight')) {
      found = _localFallbackCatalog().first;
    } else {
      // 2. Supabase
      try {
        found = await _supabase.fetchDeviceById(cleanId);
      } catch (_) {}
    }

    // 3. Fallback Local
    if (found == null) {
      try {
        found = _localFallbackCatalog().firstWhere((t) => t.id == cleanId);
      } catch (_) {}
    }

    // 4. ✨ NUEVO: Fallback Dinámico para IDs desconocidos
    if (found == null && cleanId.length >= 3) {
      lvsLog('ID desconocido "$cleanId". Generando perfil genérico...', tag: 'CATALOG');
      found = ToyModel(
        id: cleanId,
        name: 'LVS Genérico $cleanId',
        usageType: 'Universal',
        targetAnatomy: 'Universal',
        stimulationType: 'Vibración',
        motorLogic: 'Single Channel',
        imageUrl: '',
        qrCodeUrl: '',
        supportedFuncs: 'speed,vibration,pattern',
        isPrecise: false,
        broadcastPrefix: '77 62 4d 53 45',
      );
    }

    if (found != null) {
      final index = _preregisteredList.indexWhere((t) => t.id == found!.id);
      if (index == -1) {
        // Nuevo registro
        _preregisteredList = [..._preregisteredList, found];
        lvsLog('Nuevo dispositivo registrado: ${found.name}', tag: 'CATALOG');
      } else {
        // Actualización de datos frescos (ej: si era genérico)
        _preregisteredList[index] = found;
        lvsLog('Datos actualizados para dispositivo existente: ${found.name}', tag: 'CATALOG');
      }
      
      await _savePreregistered();
      state = AsyncValue.data(_merged());
      _ref.read(bleProvider).setActiveToy(found);
      return found;
    }
    return null;
  }

  /// Abre el catálogo web externo
  static Future<void> openWebCatalog() async {
    final uri = Uri.parse(kWebCatalogUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Registra un ToyModel directamente (para cuando se crea manualmente)
    Future<void> addManual(ToyModel toy) async {
    if (_preregisteredList.any((t) => t.id == toy.id)) return;
    _preregisteredList = [..._preregisteredList, toy];
    await _savePreregistered();
    state = AsyncValue.data(_merged());
    _ref.read(bleProvider).setActiveToy(toy);
    debugPrint('✅ Agregado y activado: ${toy.name}');
  }

  /// Lista de todos los dispositivos pre-registrados (para mostrar en home)
  List<ToyModel> get preregistered => List.unmodifiable(_preregisteredList);

  /// Busca un modelo por nombre exacto o parcial (para sesiones compartidas)
  ToyModel? findModelByName(String name) {
    if (name.isEmpty) return null;
    final all = _preregisteredList; // Solo buscamos en lo que el usuario tiene
    
    try {
      return all.firstWhere((t) => t.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      try {
        return all.firstWhere((t) => t.name.toLowerCase().contains(name.toLowerCase()));
      } catch (_) {
        return null;
      }
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────

  void updateDevice(String oldId, String newName, String newId) async {
    // Si el ID cambia, borramos el viejo y creamos el nuevo en pre-registrados
    // Si no estaba en pre-registrados (venía del catálogo general), lo añadimos ahora con su personalización
    
    ToyModel? baseToy;
    try {
      baseToy = _merged().firstWhere((t) => t.id == oldId);
    } catch (_) {
      try {
        baseToy = _serverCatalog.firstWhere((t) => t.id == oldId);
      } catch (_) {
        baseToy = _localFallbackCatalog().firstWhere((t) => t.id == oldId, orElse: () => _localFallbackCatalog().first);
      }
    }

    final updatedToy = ToyModel(
      id: newId.isNotEmpty ? newId : baseToy.id,
      name: newName.isNotEmpty ? newName : baseToy.name,
      usageType: baseToy.usageType,
      targetAnatomy: baseToy.targetAnatomy,
      stimulationType: baseToy.stimulationType,
      motorLogic: baseToy.motorLogic,
      imageUrl: baseToy.imageUrl,
      qrCodeUrl: baseToy.qrCodeUrl, 
      supportedFuncs: baseToy.supportedFuncs,
      isPrecise: baseToy.isPrecise,
      broadcastPrefix: baseToy.broadcastPrefix,
    );

    // Actualizar lista persistente
    final exists = _preregisteredList.any((t) => t.id == oldId);
    if (exists) {
      _preregisteredList = _preregisteredList.map((t) => t.id == oldId ? updatedToy : t).toList();
    } else {
      _preregisteredList = [..._preregisteredList, updatedToy];
    }

    await _savePreregistered();
    lvsLog('Dispositivo personalizado guardado: ${updatedToy.name} (${updatedToy.id})', tag: 'CATALOG');
    
    state = AsyncValue.data(_merged());

    final ble = _ref.read(bleProvider);
    if (ble.activeToy?.id == oldId) {
      ble.setActiveToy(updatedToy);
    }
  }

  void removeDevice(String id) {
    final all = state.valueOrNull ?? [];
    _preregisteredList = _preregisteredList.where((t) => t.id != id).toList();
    _savePreregistered();
    state = AsyncValue.data(all.where((t) => t.id != id).toList());
  }

  // ─── CATÁLOGO LOCAL DE EMERGENCIA ─────────────────────────────
  // (Mantenemos el método por compatibilidad interna de la clase)
  List<ToyModel> _localFallbackCatalog() => lvsLocalFallback;
}

/// Catálogo estático garantizado disponible desde el arranque
final List<ToyModel> lvsLocalFallback = [
  ToyModel(
    id: '8154', name: 'Knight No. 3',
    usageType: 'Wearable', targetAnatomy: 'Universal',
    stimulationType: 'Vibración + Empuje', motorLogic: 'Dual Channel',
    imageUrl: 'https://image.zlmicro.com/images/product/20240920/20240920102355033.png',
    qrCodeUrl: 'https://image.zlmicro.com/images/product/qrcode/8154.png',
    supportedFuncs: 'speed,vibration,thrust,pattern',
    isPrecise: true, broadcastPrefix: '77 62 4d 53 45',
  ),
  ToyModel(
    id: '9001', name: 'LVS Aria Pro',
    usageType: 'Wearable', targetAnatomy: 'Universal',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
  ),
  ToyModel(
    id: '7721', name: 'LVS Luna Mini',
    usageType: 'Wearable', targetAnatomy: 'Clitoral',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
  ),
  ToyModel(
    id: '5543', name: 'LVS Storm Plus',
    usageType: 'Insertable', targetAnatomy: 'Vaginal',
    stimulationType: 'Vibración', motorLogic: 'Dual Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
  ),
  ToyModel(
    id: '3398', name: 'LVS Wave',
    usageType: 'Wearable', targetAnatomy: 'Universal',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
  ),
  ToyModel(
    id: '6672', name: 'LVS Pulse',
    usageType: 'Wearable', targetAnatomy: 'Peniano',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
  ),
  ToyModel(
    id: '4429', name: 'LVS Zen',
    usageType: 'Insertable', targetAnatomy: 'Anal',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
  ),
];
