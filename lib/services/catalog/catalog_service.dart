// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/services/catalog_service.dart · v3.1.0
// Catálogo con Fallback + Persistencia Cifrada (Secure Storage)
// Los dispositivos pre-registrados se guardan y sobreviven reinicios
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/devices/models/lovespouse_device.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/ble/ble_service.dart';
import 'package:velvet_sync/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:velvet_sync/devices/parsers/lovespouse_parser_service.dart';

// ── LoveSpouse API directa ──────────────────────────────────────
const _kLoveSpouseApiBase = 'https://lovespouse.zlmicro.com/index.php';
const _kLoveSpouseUserIds = [
  '745540175', '749000390', '771002891', '781986154',
  '781053646', '772488032', '782514043', '7815577341',
];

// ── Clave de almacenamiento ─────────────────────────────────────
const _kPreregisteredKey = 'lvs_preregistered_devices';

/// URL del Catálogo Web de Velvet Sync (Planeado: subdominio de Vercel)
const kWebCatalogUrl = 'https://velvetsynccatalog.vercel.app/';

// Provider solo para los pre-registrados (donde vive la persistencia reactiva)
final preregisteredProvider = StateProvider<List<ToyModel>>((ref) => []);

// Provider para catálogo LoveSpouse (dispositivos técnicos - 2,753 dispositivos precargados)
final lovespouseCatalogProvider = StateNotifierProvider<LovespouseCatalogNotifier, AsyncValue<List<ToyModel>>>((ref) {
  return LovespouseCatalogNotifier();
});

class LovespouseCatalogNotifier extends StateNotifier<AsyncValue<List<ToyModel>>> {
  final _parserService = LovespouseParserService();
  List<LovespouseDevice> _rawDevices = [];
  bool _isLoading = false;
  bool _hasLoaded = false;  // Nueva bandera para carga perezosa

  LovespouseCatalogNotifier() : super(const AsyncValue.data([])) {
    // NO cargar en el constructor - carga perezosa en primer acceso
  }

  /// Carga dispositivos bajo demanda (lazy loading)
  Future<void> _ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;
    _isLoading = true;
    
    try {
      lvsLog('🔄 Cargando catálogo LoveSpouse bajo demanda...', tag: 'CATALOG');
      final stopwatch = Stopwatch()..start();
      
      _rawDevices = await _parserService.getAllDevices();
      final toyModels = _rawDevices.map((d) => d.toToyModel()).toList();
      
      state = AsyncValue.data(toyModels);
      _hasLoaded = true;
      
      stopwatch.stop();
      lvsLog('✅ LoveSpouse: ${toyModels.length} dispositivos cargados en ${stopwatch.elapsedMilliseconds}ms', tag: 'CATALOG');
    } catch (e, stack) {
      lvsLog('❌ Error cargando LoveSpouse: $e', tag: 'CATALOG');
      lvsLog('Stack: $stack', tag: 'CATALOG');
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoading = false;
    }
  }

  /// Fuerza recarga completa
  Future<void> reload() async {
    _hasLoaded = false;
    _rawDevices.clear();
    state = const AsyncValue.loading();
    await _ensureLoaded();
  }

  /// Asegura que los datos estén cargados antes de buscar
  Future<void> _ensureLoadedBeforeSearch() async {
    if (!_hasLoaded) {
      await _ensureLoaded();
    }
  }

  /// Busca un dispositivo por barcode (O(1) usando índice del parser)
  Future<ToyModel?> findByBarcode(String barcode) async {
    await _ensureLoadedBeforeSearch();
    // Si ya está cargado, buscar en memoria
    if (state is AsyncData<List<ToyModel>>) {
      try {
        return (state as AsyncData<List<ToyModel>>).value.firstWhere((t) => t.id == barcode);
      } catch (_) {}
    }
    
    // Si no, usar el parser con índice optimizado
    final device = await _parserService.findByBarcode(barcode);
    return device?.toToyModel();
  }

  /// Busca un dispositivo por nombre BLE
  Future<ToyModel?> findByBleName(String bleName) async {
    await _ensureLoadedBeforeSearch();
    if (state is AsyncData<List<ToyModel>>) {
      try {
        return (state as AsyncData<List<ToyModel>>).value.firstWhere((t) => t.name.toLowerCase().contains(bleName.toLowerCase()));
      } catch (_) {}
    }
    
    final device = await _parserService.findByBleName(bleName);
    return device?.toToyModel();
  }

  /// Busca por título (parcial)
  Future<List<ToyModel>> findByTitle(String title) async {
    await _ensureLoadedBeforeSearch();
    if (state is AsyncData<List<ToyModel>>) {
      final all = (state as AsyncData<List<ToyModel>>).value;
      return all.where((t) => t.name.toLowerCase().contains(title.toLowerCase())).toList();
    }
    final devices = await _parserService.findByTitle(title);
    return devices.map((d) => d.toToyModel()).toList();
  }

  /// Filtra por función
  Future<List<ToyModel>> filterByFunction(String funcCode) async {
    await _ensureLoadedBeforeSearch();
    if (state is AsyncData<List<ToyModel>>) {
      final all = (state as AsyncData<List<ToyModel>>).value;
      return all.where((t) => t.supports(funcCode)).toList();
    }
    final devices = await _parserService.filterByFunction(funcCode);
    return devices.map((d) => d.toToyModel()).toList();
  }

  /// Obtiene dispositivos con canal dual
  Future<List<ToyModel>> getDualChannelDevices() async {
    await _ensureLoadedBeforeSearch();
    if (state is AsyncData<List<ToyModel>>) {
      final all = (state as AsyncData<List<ToyModel>>).value;
      return all.where((t) => t.hasDualChannel).toList();
    }
    final devices = await _parserService.getDualChannelDevices();
    return devices.map((d) => d.toToyModel()).toList();
  }

  /// Obtiene todos los códigos de función únicos
  Future<Set<String>> getAllFunctionCodes() async {
    await _ensureLoadedBeforeSearch();
    if (state is AsyncData<List<ToyModel>>) {
      final all = (state as AsyncData<List<ToyModel>>).value;
      final codes = <String>{};
      for (var d in all) {
        codes.addAll(d.supportedFuncs.split(RegExp(r'[,|]')).map((e) => e.trim()));
      }
      return codes;
    }
    return _parserService.getAllFunctionCodes();
  }

/// Verifica si el catálogo está cargado
bool get isLoaded => _hasLoaded;
  
  /// Número de dispositivos cargados
  int get count => state is AsyncData<List<ToyModel>> ? (state as AsyncData<List<ToyModel>>).value.length : 0;
}

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
    // Si no hay pre-registrados, retornar al menos el fallback local
    if (_preregisteredList.isEmpty) {
      return lvsLocalFallback;
    }
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

    // Asegurar que el loading se resetee antes de cargar desde Supabase
    _ref.read(catalogLoadingProvider.notifier).state = false;

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
        var changed = false;
        for (var i = 0; i < _preregisteredList.length; i++) {
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

      // Carga completada - siempre asegurar que loading sea false
      _ref.read(catalogLoadingProvider.notifier).state = false;
    } catch (e) {
      lvsLog('❌ Error cargando catálogo: $e', tag: 'CATALOG');
      // En caso de error, también asegurar que loading sea false
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

  // ─── LOVE SPOUSE API DIRECTA (FALLBACK) ─────────────────────────

  /// Fetches device details directly from the LoveSpouse API as a last resort.
  /// Uses rotating user IDs and the `custom=inter` parameter for full FuncObj.
  Future<ToyModel?> _fetchFromLoveSpouseApi(String barcode) async {
    final rng = math.Random();
    for (var attempt = 0; attempt < 3; attempt++) {
      final userId = _kLoveSpouseUserIds[rng.nextInt(_kLoveSpouseUserIds.length)];
      final uri = Uri.parse(_kLoveSpouseApiBase).replace(queryParameters: {
        'g': 'App',
        'm': 'Diyapp',
        'a': 'getproductdetail',
        'barcode': barcode,
        'userid': userId,
        'custom': 'inter',
      });
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data['code'] != 1 || data['data'] == null) continue;
        final device = LovespouseDevice.fromJson(data['data']);
        if (device.status != 1) continue;
        lvsLog('✅ API directa: encontrado ${device.displayName} ($barcode)', tag: 'CATALOG');
        return device.toToyModel();
      } catch (_) {
        continue;
      }
    }
    lvsLog('⚠️ API directa: no encontrado $barcode', tag: 'CATALOG');
    return null;
  }

  // ─── PRE-REGISTRO / AGREGAR ────────────────────────────────────

  Future<ToyModel?> addByKey(String key) async {
    final rawInput = key.trim();
    if (rawInput.isEmpty) return null;

    var cleanId = rawInput.toLowerCase();

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

    // 1. Supabase
    try {
      found = await _supabase.fetchDeviceById(cleanId);
    } catch (_) {}

    // 3. Catálogo LoveSpouse JSON local (2,753 dispositivos) - Precargado en memoria
    if (found == null) {
      // Primero intentar desde el estado del provider (si ya está cargado)
      final lovespouseCatalogState = _ref.read(lovespouseCatalogProvider);
      if (lovespouseCatalogState is AsyncData<List<ToyModel>>) {
        final lovespouseCatalog = lovespouseCatalogState.value;
        try {
          found = lovespouseCatalog.firstWhere((t) => t.id == cleanId);
          lvsLog('Match en catálogo LoveSpouse: ${found.name} ($cleanId)', tag: 'CATALOG');
        } catch (_) {}
        // Si no encontró por ID exacto, buscar por nombre/alias
        if (found == null) {
          try {
            found = lovespouseCatalog.firstWhere((t) =>
                t.name.toLowerCase().contains(cleanId) ||
                cleanId.contains(t.id));
          } catch (_) {}
        }
      }
      // Si el catálogo no está listo aún, usar el parser directamente
      if (found == null) {
        final parser = LovespouseParserService();
        final device = await parser.findByBarcode(cleanId);
        found = device?.toToyModel();
        if (found != null) {
          lvsLog('Match en catálogo LoveSpouse (parser): ${found.name} ($cleanId)', tag: 'CATALOG');
        }
      }
      // Si aún no encontró, buscar por nombre/alias
      if (found == null) {
        final parser = LovespouseParserService();
        final devicesByTitle = await parser.findByTitle(cleanId);
        if (devicesByTitle.isNotEmpty) {
          found = devicesByTitle.first.toToyModel();
          lvsLog('Match por título LoveSpouse: ${found.name} ($cleanId)', tag: 'CATALOG');
        }
      }
    }

    // 4. LoveSpouse API directa (último recurso antes del fallback local)
    found ??= await _fetchFromLoveSpouseApi(cleanId);

    if (found == null) {
      try {
        found = _localFallbackCatalog().firstWhere((t) => t.id == cleanId);
      } catch (_) {}
    }

    // 6. ✨ Fallback Dinámico para IDs desconocidos
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
        bleProtocol: BleProtocolType.classic,
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

  Future<void> updateDevice(String oldId, String newName, String newId) async {
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
      bleProtocol: baseToy.bleProtocol,
      isPrivateProtocol: baseToy.isPrivateProtocol,
      encryptCommand: baseToy.encryptCommand,
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

  Future<void> removeDevice(String id) async {
    _preregisteredList = _preregisteredList.where((t) => t.id != id).toList();
    await _savePreregistered();
    state = AsyncValue.data(_merged());
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
    bleProtocol: BleProtocolType.classic,
  ),
  ToyModel(
    id: '9001', name: 'LVS Aria Pro',
    usageType: 'Wearable', targetAnatomy: 'Universal',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
    bleProtocol: BleProtocolType.classic,
  ),
  ToyModel(
    id: '7721', name: 'LVS Luna Mini',
    usageType: 'Wearable', targetAnatomy: 'Clitoral',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
    bleProtocol: BleProtocolType.classic,
  ),
  ToyModel(
    id: '5543', name: 'LVS Storm Plus',
    usageType: 'Insertable', targetAnatomy: 'Vaginal',
    stimulationType: 'Vibración', motorLogic: 'Dual Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
    bleProtocol: BleProtocolType.classic,
  ),
  ToyModel(
    id: '3398', name: 'LVS Wave',
    usageType: 'Wearable', targetAnatomy: 'Universal',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
    bleProtocol: BleProtocolType.classic,
  ),
  ToyModel(
    id: '6672', name: 'LVS Pulse',
    usageType: 'Wearable', targetAnatomy: 'Peniano',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
    bleProtocol: BleProtocolType.classic,
  ),
  ToyModel(
    id: '4429', name: 'LVS Zen',
    usageType: 'Insertable', targetAnatomy: 'Anal',
    stimulationType: 'Vibración', motorLogic: 'Single Channel',
    imageUrl: '', qrCodeUrl: '',
    supportedFuncs: 'speed,vibration,pattern',
    isPrecise: false, broadcastPrefix: '77 62 4d 53 45',
    bleProtocol: BleProtocolType.classic,
  ),
];
