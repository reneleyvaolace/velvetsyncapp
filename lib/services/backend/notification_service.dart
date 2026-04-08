import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final notificationServiceProvider = ChangeNotifierProvider<NotificationService>((ref) => NotificationService());

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    // Solicitar permisos de notificaciones
    await _requestPermissions();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    // Android 13+ requiere permiso POST_NOTIFICATIONS
    final androidStatus = await Permission.notification.status;
    if (androidStatus.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<bool> requestPermissions() async {
    final androidStatus = await Permission.notification.status;
    if (androidStatus.isGranted) return true;
    
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  Future<bool> get hasPermission async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Manejar tap en notificación
  }

  Future<void> showForegroundNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'velvet_sync_foreground',
      'Velvet Sync Activo',
      channelDescription: 'Notificación de foreground service',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(0, title, body, details, payload: payload);
  }

  Future<void> showSessionInvite({
    required String partnerName,
    required String sessionToken,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'velvet_sync_session',
      'Invitación de Sesión',
      channelDescription: 'Notificaciones de invitación a sesiones remotas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Nueva Invitación',
      '$partnerName te ha invitado a una sesión',
      details,
      payload: 'session:$sessionToken',
    );
  }

  Future<void> showBatteryLow({required int level}) async {
    const androidDetails = AndroidNotificationDetails(
      'velvet_sync_alerts',
      'Alertas',
      channelDescription: 'Alertas de batería y conexión',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2,
      'Batería Baja',
      'El dispositivo tiene $level% de batería',
      details,
    );
  }

  Future<void> showConnectionLost() async {
    const androidDetails = AndroidNotificationDetails(
      'velvet_sync_alerts',
      'Alertas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      3,
      'Conexión Perdida',
      'Se perdió la conexión con el dispositivo',
      details,
    );
  }

  Future<void> cancelForeground() async {
    await _notifications.cancel(0);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}