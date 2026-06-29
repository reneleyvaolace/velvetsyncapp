import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/devices/models/device_sync_model.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/services/backend/sync_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

class MockPostgresChangePayload extends Mock implements PostgresChangePayload {}

DeviceSyncEvent _makeEvent({
  String id = 'evt-1',
  String deviceId = 'dev-1',
  String command = 'SET_INTENSITY',
  Map<String, dynamic> payload = const {'intensity': 128},
}) {
  return DeviceSyncEvent(
    id: id,
    deviceId: deviceId,
    command: command,
    payload: payload,
    timestamp: DateTime(2026, 6, 26),
  );
}

void main() {
  late SyncService syncService;
  late MockSupabaseService mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseService();
    syncService = SyncService.testing(supabaseService: mockSupabase);
  });

  group('SyncService - State', () {
    test('starts in disconnected state', () {
      expect(syncService.state, SyncChannelState.disconnected);
    });

    test('isInitialized returns false by default', () {
      expect(syncService.isInitialized, false);
    });

    test('isReceiving returns false when disconnected', () {
      expect(syncService.isReceiving, false);
    });

    test('recentEvents is empty by default', () {
      expect(syncService.recentEvents, isEmpty);
    });

    test('lastEvent returns null when no events', () {
      expect(syncService.lastEvent, null);
    });
  });

  group('SyncService - Event Management', () {
    setUp(() {
      syncService.clearHistory();
    });

    test('addTestEvent adds event to recentEvents', () {
      syncService.addTestEvent(_makeEvent());
      expect(syncService.recentEvents.length, 1);
      expect(syncService.recentEvents.first.deviceId, 'dev-1');
    });

    test('onDatabaseChange processes valid event from payload', () {
      final payload = MockPostgresChangePayload();
      when(() => payload.newRecord).thenReturn({
        'device_id': 'dev-1',
        'command': 'SET_INTENSITY',
        'payload': '{"intensity": 128}',
        'created_at': '2026-06-26T12:00:00.000',
      });

      syncService.onDatabaseChange(payload);

      expect(syncService.recentEvents.length, 1);
      expect(syncService.recentEvents.first.deviceId, 'dev-1');
    });

    test('onDatabaseChange rejects event with empty deviceId', () {
      final payload = MockPostgresChangePayload();
      when(() => payload.newRecord).thenReturn({
        'device_id': '',
        'command': 'SET_INTENSITY',
        'payload': '{}',
        'created_at': '2026-06-26T12:00:00.000',
      });

      syncService.onDatabaseChange(payload);

      expect(syncService.recentEvents, isEmpty);
    });

    test('onDatabaseChange rejects event with empty command', () {
      final payload = MockPostgresChangePayload();
      when(() => payload.newRecord).thenReturn({
        'device_id': 'dev-1',
        'command': '',
        'payload': '{}',
        'created_at': '2026-06-26T12:00:00.000',
      });

      syncService.onDatabaseChange(payload);

      expect(syncService.recentEvents, isEmpty);
    });

    test('getEventsForDevice filters by device ID', () {
      syncService.addTestEvent(_makeEvent(deviceId: 'dev-1', command: 'START'));
      syncService.addTestEvent(_makeEvent(deviceId: 'dev-2', command: 'STOP'));
      syncService.addTestEvent(_makeEvent(deviceId: 'dev-1', command: 'STOP'));

      final devEvents = syncService.getEventsForDevice('dev-1');
      expect(devEvents.length, 2);
      expect(devEvents.every((e) => e.deviceId == 'dev-1'), true);
    });

    test('getEventsByCommand filters by command', () {
      syncService.addTestEvent(
          _makeEvent(deviceId: 'dev-1', command: 'SET_INTENSITY'));
      syncService.addTestEvent(_makeEvent(deviceId: 'dev-2', command: 'STOP'));
      syncService.addTestEvent(
          _makeEvent(deviceId: 'dev-3', command: 'SET_INTENSITY'));

      final intensityEvents = syncService.getEventsByCommand('SET_INTENSITY');
      expect(intensityEvents.length, 2);
    });

    test('clearHistory removes all events', () {
      syncService.addTestEvent(_makeEvent());
      expect(syncService.recentEvents, isNotEmpty);

      syncService.clearHistory();
      expect(syncService.recentEvents, isEmpty);
      expect(syncService.lastEvent, null);
    });

    test('recentEvents maxes at 50', () {
      for (var i = 0; i < 55; i++) {
        syncService.addTestEvent(_makeEvent(id: 'evt-$i', deviceId: 'dev-$i'));
      }
      expect(syncService.recentEvents.length, 50);
    });

    test('lastEvent returns most recent event', () {
      syncService.addTestEvent(_makeEvent(deviceId: 'dev-1', command: 'START'));
      syncService.addTestEvent(_makeEvent(deviceId: 'dev-2', command: 'STOP'));

      expect(syncService.lastEvent?.deviceId, 'dev-2');
    });

    test('pruneOldEvents removes events older than 5 minutes', () {
      syncService.addTestEvent(DeviceSyncEvent(
        id: 'old',
        deviceId: 'dev-1',
        command: 'OLD',
        payload: {},
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ));
      syncService.addTestEvent(DeviceSyncEvent(
        id: 'new',
        deviceId: 'dev-1',
        command: 'NEW',
        payload: {},
        timestamp: DateTime.now(),
      ));

      syncService.pruneOldEvents();

      expect(syncService.recentEvents.length, 1);
      expect(syncService.recentEvents.first.command, 'NEW');
    });
  });

  group('SyncService - AI Profile Listeners', () {
    setUp(() {
      syncService.clearHistory();
    });

    test('addAiProfileListener registers callback', () {
      final calls = <DeviceSyncEvent>[];
      void listener(DeviceSyncEvent event) => calls.add(event);

      syncService.addAiProfileListener(listener);
      syncService.notifyAiProfileListeners(
        _makeEvent(command: 'APPLY_AI_PROFILE'),
      );

      expect(calls.length, 1);
    });

    test('removeAiProfileListener unregisters callback', () {
      final calls = <DeviceSyncEvent>[];
      void listener(DeviceSyncEvent event) => calls.add(event);

      syncService.addAiProfileListener(listener);
      syncService.removeAiProfileListener(listener);
      syncService.notifyAiProfileListeners(
        _makeEvent(command: 'APPLY_AI_PROFILE'),
      );

      expect(calls, isEmpty);
    });

    test('does not add duplicate listener', () {
      final calls = <DeviceSyncEvent>[];
      void listener(DeviceSyncEvent event) => calls.add(event);

      syncService.addAiProfileListener(listener);
      syncService.addAiProfileListener(listener);
      syncService.notifyAiProfileListeners(
        _makeEvent(command: 'APPLY_AI_PROFILE'),
      );

      expect(calls.length, 1);
    });

    test('listener error does not affect other listeners', () {
      final calls = <DeviceSyncEvent>[];
      void badListener(DeviceSyncEvent event) => throw Exception('Boom!');
      void goodListener(DeviceSyncEvent event) => calls.add(event);

      syncService.addAiProfileListener(badListener);
      syncService.addAiProfileListener(goodListener);
      syncService.notifyAiProfileListeners(
        _makeEvent(command: 'APPLY_AI_PROFILE'),
      );

      expect(calls.length, 1);
    });
  });

  group('SyncService - Event Stream', () {
    test('eventsStream emits added events', () async {
      final emitted = <List<DeviceSyncEvent>>[];
      final sub = syncService.eventsStream.listen(emitted.add);

      syncService.addTestEvent(_makeEvent());

      await Future.delayed(Duration.zero);
      expect(emitted.length, 1);
      expect(emitted.first.length, 1);
      expect(emitted.first.first.deviceId, 'dev-1');

      await sub.cancel();
    });
  });
}
