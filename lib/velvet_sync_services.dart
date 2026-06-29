// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/velvet_sync_services.dart
// Export de servicios de negocio (90% reutilizable)
// ═══════════════════════════════════════════════════════════════
//
// USO:
// ```dart
// import 'package:velvet_sync_platform/velvet_sync_services.dart';
//
// final ble = BleService();
// final catalog = CatalogService();
// final handy = HandyService(apiKey: 'tu-api-key');
// ```
// ═══════════════════════════════════════════════════════════════

// BLE Service
export 'services/ble/ble_service_platform.dart';
// export 'services/ble/ble_service_stub.dart'; // Removido para evitar ambigüedad con bleProvider
// export 'services/ble/ble_service_mobile.dart' hide getBleService; // Removido por el mismo motivo
export 'services/ble/lvs_commands.dart';
export 'services/ble/toy_profile.dart';

// Buttplug Service
export 'services/buttplug/buttplug_client_service.dart';
export 'services/buttplug/buttplug_device.dart';

// P2P Services
export 'services/p2p/p2p_connection_manager.dart';
export 'services/p2p/p2p_signaling_service.dart';
export 'services/p2p/direct_websocket_transport.dart';
export 'services/p2p/supabase_broadcast_transport.dart';

// Catalog Service
export 'services/catalog/catalog_service.dart';

// Handy Service (Dispositivos Handy)
// ⚠️ Requiere API Key y registro en handyfeeling.com

// Precision Control Service (NUEVO - Control preciso 0-255)

// Session Services
export 'services/session/session_manager.dart';
export 'services/session/session_chat_service.dart';
export 'services/session/session_timer_service.dart';

// Media Services
export 'services/media/video_call_service.dart';
export 'services/media/funscript_loader.dart';
export 'services/media/game_haptics_mapper.dart';
export 'services/media/haptic_video_sync_service.dart';
export 'services/media/haptic_recorder_service.dart';
export 'services/media/remote_haptic_receiver.dart';

// Backend Services
export 'services/backend/supabase_service.dart';
export 'services/backend/sync_service.dart';
export 'services/backend/link_service.dart';
export 'services/backend/cloud_backup_service.dart';
export 'services/backend/companion_settings.dart';
export 'services/backend/profile_service.dart';
export 'services/backend/contact_service.dart';
export 'services/backend/invitation_service.dart';

// AI Services
export 'services/ai/ai_service.dart';
export 'services/ai/ai_hardware_bridge_service.dart';
