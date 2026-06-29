import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/devices/models/device_sync_model.dart';

void main() {
  group('DeviceSyncEvent - Constructor', () {
    test('creates event with required fields', () {
      final event = DeviceSyncEvent(
        id: 'evt_1',
        deviceId: '8154',
        command: 'APPLY_AI_PROFILE',
        payload: {'intensity': 75},
        timestamp: DateTime(2026, 6, 26),
      );
      expect(event.id, 'evt_1');
      expect(event.deviceId, '8154');
      expect(event.command, 'APPLY_AI_PROFILE');
      expect(event.payload, {'intensity': 75});
    });

    test('isAiProfile returns true for APPLY_AI_PROFILE command', () {
      final event = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'APPLY_AI_PROFILE',
        payload: {}, timestamp: DateTime.now(),
      );
      expect(event.isAiProfile, true);
      expect(event.isIntensity, false);
    });

    test('isIntensity returns true for SET_INTENSITY command', () {
      final event = DeviceSyncEvent(
        id: '2', deviceId: 'd1', command: 'SET_INTENSITY',
        payload: {'intensity': 50}, timestamp: DateTime.now(),
      );
      expect(event.isIntensity, true);
    });

    test('isPattern returns true for SET_PATTERN command', () {
      final event = DeviceSyncEvent(
        id: '3', deviceId: 'd1', command: 'SET_PATTERN',
        payload: {'pattern': 3}, timestamp: DateTime.now(),
      );
      expect(event.isPattern, true);
    });

    test('isStop returns true for STOP command', () {
      final event = DeviceSyncEvent(
        id: '4', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime.now(),
      );
      expect(event.isStop, true);
    });
  });

  group('DeviceSyncEvent - fromMap', () {
    test('parses map with all fields', () {
      final map = {
        'id': 'evt_5',
        'device_id': '8154',
        'command': 'APPLY_AI_PROFILE',
        'payload': '{"intensity": 80, "pattern": 2}',
        'created_at': '2026-06-26T12:00:00.000Z',
        'session_id': 'session_abc',
        'user_id': 'user_xyz',
      };

      final event = DeviceSyncEvent.fromMap(map);
      expect(event.id, 'evt_5');
      expect(event.deviceId, '8154');
      expect(event.command, 'APPLY_AI_PROFILE');
      expect(event.payload, {'intensity': 80, 'pattern': 2});
      expect(event.sessionId, 'session_abc');
      expect(event.userId, 'user_xyz');
    });

    test('parses payload as Map when already decoded', () {
      final map = {
        'id': 'evt_6',
        'device_id': 'd1',
        'command': 'SET_INTENSITY',
        'payload': {'intensity': 100},
        'created_at': DateTime(2026, 6, 26),
      };

      final event = DeviceSyncEvent.fromMap(map);
      expect(event.payload, {'intensity': 100});
    });

    test('handles missing payload gracefully', () {
      final event = DeviceSyncEvent.fromMap({
        'id': 'evt_7', 'device_id': 'd1', 'command': 'STOP',
      });
      expect(event.payload, {});
    });

    test('handles invalid JSON payload gracefully', () {
      final event = DeviceSyncEvent.fromMap({
        'id': 'evt_8', 'device_id': 'd1', 'command': 'TEST',
        'payload': '{invalid json}',
      });
      expect(event.payload, containsPair('raw', '{invalid json}'));
    });

    test('uses alternative field names', () {
      final event = DeviceSyncEvent.fromMap({
        'id': 'evt_9',
        'deviceId': 'd2',
        'command': 'STOP',
        'timestamp': '2026-06-26T12:00:00.000Z',
        'sessionId': 'sess_1',
        'userId': 'u1',
      });
      expect(event.deviceId, 'd2');
      expect(event.sessionId, 'sess_1');
      expect(event.userId, 'u1');
    });

    test('falls back to current time for invalid timestamp', () {
      final now = DateTime.now();
      final event = DeviceSyncEvent.fromMap({
        'id': 'evt_10', 'device_id': 'd1', 'command': 'STOP',
        'created_at': 'not-a-date',
      });
      expect(event.timestamp.difference(now).inSeconds, lessThan(2));
    });
  });

  group('DeviceSyncEvent - toMap', () {
    test('serializes correctly', () {
      final event = DeviceSyncEvent(
        id: 'evt_11',
        deviceId: '8154',
        command: 'SET_INTENSITY',
        payload: {'intensity': 50},
        timestamp: DateTime(2026, 6, 26),
        sessionId: 'sess_1',
        userId: 'u1',
      );

      final map = event.toMap();
      expect(map['id'], 'evt_11');
      expect(map['device_id'], '8154');
      expect(map['command'], 'SET_INTENSITY');
      expect(map['payload'], isA<String>());
      expect(map['session_id'], 'sess_1');
      expect(map['user_id'], 'u1');
    });
  });

  group('DeviceSyncEvent - intensity getter', () {
    test('returns null when payload has no intensity', () {
      final event = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime.now(),
      );
      expect(event.intensity, null);
    });

    test('returns int intensity from AI_PROFILE', () {
      final event = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'APPLY_AI_PROFILE',
        payload: {'intensity': 75}, timestamp: DateTime.now(),
      );
      expect(event.intensity, 75);
    });

    test('parses intensity from double', () {
      final event = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'SET_INTENSITY',
        payload: {'intensity': 50.0}, timestamp: DateTime.now(),
      );
      expect(event.intensity, 50);
    });

    test('parses intensity from string', () {
      final event = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'SET_INTENSITY',
        payload: {'intensity': '80'}, timestamp: DateTime.now(),
      );
      expect(event.intensity, 80);
    });

    test('returns intensity_ch1 as fallback', () {
      final event = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'APPLY_AI_PROFILE',
        payload: {'intensity_ch1': 90}, timestamp: DateTime.now(),
      );
      expect(event.intensity, 90);
    });
  });

  group('DeviceSyncEvent - copyWith', () {
    test('creates copy with modified fields', () {
      final original = DeviceSyncEvent(
        id: 'original', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime(2026, 1, 1),
      );

      final modified = original.copyWith(
        command: 'SET_INTENSITY',
        payload: {'intensity': 50},
      );

      expect(modified.id, 'original');
      expect(modified.deviceId, 'd1');
      expect(modified.command, 'SET_INTENSITY');
      expect(modified.payload, {'intensity': 50});
    });
  });

  group('DeviceSyncEvent - equality', () {
    test('identical events are equal', () {
      final a = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime(2026, 1, 1),
      );
      final b = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime(2026, 1, 1),
      );
      expect(a, equals(b));
    });

    test('different events are not equal', () {
      final a = DeviceSyncEvent(
        id: '1', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime(2026, 1, 1),
      );
      final b = DeviceSyncEvent(
        id: '2', deviceId: 'd1', command: 'STOP',
        payload: {}, timestamp: DateTime(2026, 1, 1),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
