import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/devices/models/session_models.dart';

void main() {
  group('ParticipantStatus', () {
    test('has all required values', () {
      expect(ParticipantStatus.values, hasLength(4));
      expect(ParticipantStatus.active, isA<ParticipantStatus>());
      expect(ParticipantStatus.away, isA<ParticipantStatus>());
      expect(ParticipantStatus.disconnected, isA<ParticipantStatus>());
      expect(ParticipantStatus.spectating, isA<ParticipantStatus>());
    });
  });

  group('SessionParticipant', () {
    test('creates instance with required fields', () {
      final p = SessionParticipant(userId: 'user-1');
      expect(p.userId, 'user-1');
      expect(p.displayName, 'Anonymous');
      expect(p.isHost, false);
      expect(p.canControl, true);
      expect(p.status, ParticipantStatus.active);
      expect(p.joinedAt, isA<DateTime>());
    });

    test('creates instance with host role', () {
      final p = SessionParticipant(userId: 'host-1', isHost: true);
      expect(p.isHost, true);
      expect(p.canControl, true);
    });

    test('creates instance with custom display name', () {
      final p = SessionParticipant(userId: 'u1', displayName: 'Alice');
      expect(p.displayName, 'Alice');
    });

    test('fromJson parses correctly', () {
      final json = {
        'userId': 'u1',
        'displayName': 'Bob',
        'isHost': true,
        'canControl': true,
        'joinedAt': '2026-06-26T12:00:00.000',
        'status': 'active',
      };
      final p = SessionParticipant.fromJson(json);
      expect(p.userId, 'u1');
      expect(p.displayName, 'Bob');
      expect(p.isHost, true);
      expect(p.canControl, true);
      expect(p.status, ParticipantStatus.active);
    });

    test('fromJson handles missing fields with defaults', () {
      final p = SessionParticipant.fromJson({});
      expect(p.userId, '');
      expect(p.displayName, 'Anonymous');
      expect(p.isHost, false);
      expect(p.canControl, true);
      expect(p.status, ParticipantStatus.active);
    });

    test('fromJson parses unknown status as active', () {
      final json = {'userId': 'u1', 'status': 'unknown_status'};
      final p = SessionParticipant.fromJson(json);
      expect(p.status, ParticipantStatus.active);
    });

    test('toJson serializes correctly', () {
      final p = SessionParticipant(
        userId: 'u1',
        displayName: 'Charlie',
        isHost: false,
        canControl: true,
        joinedAt: DateTime(2026, 6, 26),
        status: ParticipantStatus.away,
      );
      final json = p.toJson();
      expect(json['userId'], 'u1');
      expect(json['displayName'], 'Charlie');
      expect(json['isHost'], false);
      expect(json['status'], 'away');
    });

    test('toString formats correctly', () {
      final p = SessionParticipant(userId: 'u1', displayName: 'Admin', isHost: true);
      final str = p.toString();
      expect(str, contains('Admin'));
      expect(str, contains('host'));
    });
  });

  group('SessionDevice', () {
    test('creates instance with required fields', () {
      final d = SessionDevice(
        id: 'dev-1',
        deviceId: 'phys-1',
        name: 'Test Device',
        isActive: true,
        currentIntensity: 0.5,
        addedAt: DateTime(2026, 6, 26),
      );
      expect(d.id, 'dev-1');
      expect(d.name, 'Test Device');
      expect(d.isActive, true);
      expect(d.currentIntensity, 0.5);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'dev-1',
        'deviceId': 'phys-1',
        'name': 'Nora',
        'ownerId': 'u1',
        'controlledBy': 'u2',
        'isActive': true,
        'currentIntensity': 0.75,
        'addedAt': '2026-06-26T12:00:00.000',
      };
      final d = SessionDevice.fromJson(json);
      expect(d.id, 'dev-1');
      expect(d.ownerId, 'u1');
      expect(d.controlledBy, 'u2');
      expect(d.currentIntensity, 0.75);
    });

    test('fromJson handles missing fields', () {
      final d = SessionDevice.fromJson({});
      expect(d.id, '');
      expect(d.isActive, false);
      expect(d.currentIntensity, 0.0);
    });

    test('toJson serializes correctly', () {
      final d = SessionDevice(
        id: 'dev-1',
        deviceId: 'phys-1',
        name: 'Nora',
        ownerId: 'u1',
        controlledBy: 'u2',
        isActive: true,
        currentIntensity: 1.0,
        addedAt: DateTime(2026, 6, 26),
      );
      final json = d.toJson();
      expect(json['id'], 'dev-1');
      expect(json['ownerId'], 'u1');
      expect(json['currentIntensity'], 1.0);
    });

    test('isControllableBy returns true when no controller assigned', () {
      final d = SessionDevice(
        id: 'dev-1', deviceId: 'phys-1', name: 'Test',
        isActive: true, currentIntensity: 0.0, addedAt: DateTime(2026, 6, 26),
      );
      expect(d.isControllableBy('any-user'), true);
    });

    test('isControllableBy returns true for assigned controller', () {
      final d = SessionDevice(
        id: 'dev-1', deviceId: 'phys-1', name: 'Test',
        controlledBy: 'controller-1', isActive: true,
        currentIntensity: 0.0, addedAt: DateTime(2026, 6, 26),
      );
      expect(d.isControllableBy('controller-1'), true);
      expect(d.isControllableBy('other-user'), false);
    });

    test('toString formats correctly', () {
      final d = SessionDevice(
        id: 'dev-1', deviceId: 'phys-1', name: 'Nora',
        ownerId: 'u1', isActive: true, currentIntensity: 0.0,
        addedAt: DateTime(2026, 6, 26),
      );
      expect(d.toString(), contains('Nora'));
    });
  });

  group('SessionConfig', () {
    test('creates with default values', () {
      const config = SessionConfig();
      expect(config.collaborativeMode, true);
      expect(config.exclusiveMode, false);
      expect(config.allowSpectators, true);
      expect(config.requireApproval, false);
      expect(config.showOthersIntensity, true);
      expect(config.allowChat, true);
    });

    test('creates with custom values', () {
      const config = SessionConfig(
        collaborativeMode: false,
        exclusiveMode: true,
        maxDurationMinutes: 60,
        maxParticipants: 10,
      );
      expect(config.collaborativeMode, false);
      expect(config.maxDurationMinutes, 60);
      expect(config.maxParticipants, 10);
    });

    test('fromJson parses correctly', () {
      final json = {
        'collaborativeMode': false,
        'exclusiveMode': true,
        'maxDurationMinutes': 30,
        'maxParticipants': 5,
      };
      final config = SessionConfig.fromJson(json);
      expect(config.collaborativeMode, false);
      expect(config.exclusiveMode, true);
      expect(config.maxDurationMinutes, 30);
      expect(config.maxParticipants, 5);
    });

    test('fromJson handles missing fields with defaults', () {
      final config = SessionConfig.fromJson({});
      expect(config.collaborativeMode, true);
      expect(config.maxParticipants, null);
    });

    test('toJson serializes correctly', () {
      const config = SessionConfig(
        collaborativeMode: false,
        maxDurationMinutes: 45,
      );
      final json = config.toJson();
      expect(json['collaborativeMode'], false);
      expect(json['maxDurationMinutes'], 45);
      expect(json.containsKey('maxParticipants'), false);
    });

    test('defaultConfig is collaborative', () {
      expect(SessionConfig.defaultConfig.collaborativeMode, true);
    });

    test('exclusiveConfig allows only host control', () {
      expect(SessionConfig.exclusiveConfig.collaborativeMode, false);
      expect(SessionConfig.exclusiveConfig.exclusiveMode, true);
      expect(SessionConfig.exclusiveConfig.allowSpectators, false);
    });

    test('publicConfig allows anyone to join', () {
      expect(SessionConfig.publicConfig.collaborativeMode, true);
      expect(SessionConfig.publicConfig.requireApproval, false);
    });

    test('privateConfig requires approval', () {
      expect(SessionConfig.privateConfig.requireApproval, true);
      expect(SessionConfig.privateConfig.allowSpectators, false);
    });
  });

  group('SharedSession', () {
    test('create builds session with defaults', () {
      final session = SharedSession.create(
        name: 'Test Session',
        hostUserId: 'host-1',
      );
      expect(session.name, 'Test Session');
      expect(session.hostUserId, 'host-1');
      expect(session.isActive, true);
      expect(session.participants.length, 1);
      expect(session.participants.first.isHost, true);
      expect(session.devices, isEmpty);
      expect(session.id, startsWith('session_'));
      expect(session.accessToken, isNotEmpty);
    });

    test('create accepts custom config', () {
      final session = SharedSession.create(
        name: 'Exclusive',
        hostUserId: 'host-1',
        config: SessionConfig.exclusiveConfig,
      );
      expect(session.config.exclusiveMode, true);
    });

    test('fromJson parses full session', () {
      final json = {
        'id': 'session-1',
        'accessToken': 'abc123',
        'name': 'Test',
        'hostUserId': 'host-1',
        'participants': [
          {'userId': 'host-1', 'isHost': true},
          {'userId': 'user-2', 'displayName': 'Alice'},
        ],
        'devices': [
          {
            'id': 'dev-1', 'deviceId': 'phys-1', 'name': 'Nora',
            'isActive': true, 'currentIntensity': 0.0,
            'addedAt': '2026-06-26T12:00:00.000',
          },
        ],
        'isActive': true,
        'createdAt': '2026-06-26T12:00:00.000',
        'expiresAt': '2026-06-26T13:00:00.000',
        'config': {'collaborativeMode': false},
      };
      final session = SharedSession.fromJson(json);
      expect(session.id, 'session-1');
      expect(session.name, 'Test');
      expect(session.participants.length, 2);
      expect(session.devices.length, 1);
      expect(session.config.collaborativeMode, false);
      expect(session.expiresAt, isNotNull);
    });

    test('fromJson handles missing fields', () {
      final session = SharedSession.fromJson({});
      expect(session.id, '');
      expect(session.participants, isEmpty);
      expect(session.devices, isEmpty);
      expect(session.isActive, true);
      expect(session.expiresAt, null);
    });

    test('toJson serializes correctly', () {
      final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
      final json = session.toJson();
      expect(json['name'], 'Test');
      expect(json['hostUserId'], 'host-1');
      expect(json['isActive'], true);
      expect(json['participants'], isA<List>());
      expect(json['config'], isA<Map>());
    });

    test('toJson omits expiresAt when null', () {
      final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
      final json = session.toJson();
      expect(json.containsKey('expiresAt'), true);
      expect(json['expiresAt'], null);
    });

    test('isHost returns true for host user', () {
      final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
      expect(session.isHost('host-1'), true);
      expect(session.isHost('other'), false);
    });

    test('isParticipant returns true for participants', () {
      final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
      expect(session.isParticipant('host-1'), true);
      expect(session.isParticipant('other'), false);
    });

    group('canControl', () {
      test('host can always control', () {
        final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
        expect(session.canControl('host-1', 'dev-1'), true);
      });

      test('participant can control when collaborative mode', () {
        final session = SharedSession.create(
          name: 'Test',
          hostUserId: 'host-1',
          config: const SessionConfig(collaborativeMode: true),
        );
        expect(session.canControl('participant-1', 'dev-1'), true);
      });

      test('participant cannot control in exclusive mode', () {
        final session = SharedSession.create(
          name: 'Test',
          hostUserId: 'host-1',
          config: const SessionConfig(
            collaborativeMode: false,
            exclusiveMode: true,
          ),
        );
        expect(session.canControl('participant-1', 'dev-1'), false);
      });

      test('participant can control if assigned as controller', () {
        final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
        expect(
          session.canControl('assigned-user', 'dev-1', controlledBy: 'assigned-user'),
          true,
        );
        expect(
          session.canControl('other-user', 'dev-1', controlledBy: 'assigned-user'),
          false,
        );
      });
    });

    test('remainingDuration returns null when no expiry', () {
      final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
      expect(session.remainingDuration, null);
    });

    test('isExpired returns false for non-expiring session', () {
      final session = SharedSession.create(name: 'Test', hostUserId: 'host-1');
      expect(session.isExpired, false);
    });

    test('toString formats correctly', () {
      final session = SharedSession.create(name: 'My Session', hostUserId: 'host-1');
      expect(session.toString(), contains('My Session'));
    });
  });

  group('SessionEvent', () {
    const sessionId = 'session-1';
    final device = SessionDevice(
      id: 'dev-1', deviceId: 'phys-1', name: 'Test',
      isActive: true, currentIntensity: 0.0,
      addedAt: DateTime(2026, 6, 26),
    );
    final participant = SessionParticipant(userId: 'user-1');

    test('UserJoinedEvent toJson', () {
      final event = UserJoinedEvent(sessionId: sessionId, participant: participant);
      final json = event.toJson();
      expect(json['type'], 'user_joined');
      expect(json['sessionId'], sessionId);
      expect(json['participant'], isA<Map>());
    });

    test('UserLeftEvent toJson', () {
      final event = UserLeftEvent(sessionId: sessionId, userId: 'user-1');
      final json = event.toJson();
      expect(json['type'], 'user_left');
      expect(json['userId'], 'user-1');
    });

    test('DeviceAddedEvent toJson', () {
      final event = DeviceAddedEvent(sessionId: sessionId, device: device);
      final json = event.toJson();
      expect(json['type'], 'device_added');
      expect(json['device'], isA<Map>());
    });

    test('DeviceRemovedEvent toJson', () {
      final event = DeviceRemovedEvent(sessionId: sessionId, deviceId: 'dev-1');
      final json = event.toJson();
      expect(json['type'], 'device_removed');
      expect(json['deviceId'], 'dev-1');
    });

    test('ControlCommandEvent toJson', () {
      final event = ControlCommandEvent(
        sessionId: sessionId,
        userId: 'user-1',
        deviceId: 'dev-1',
        intensity: 0.8,
        commandType: 'vibrate',
      );
      final json = event.toJson();
      expect(json['type'], 'control_command');
      expect(json['intensity'], 0.8);
      expect(json['commandType'], 'vibrate');
    });

    test('ControlCommandEvent omits commandType when null', () {
      final event = ControlCommandEvent(
        sessionId: sessionId,
        userId: 'user-1',
        deviceId: 'dev-1',
        intensity: 0.5,
      );
      final json = event.toJson();
      expect(json['commandType'], null);
    });

    test('ChatMessageEvent toJson', () {
      final event = ChatMessageEvent(
        sessionId: sessionId,
        userId: 'user-1',
        message: 'Hello!',
      );
      final json = event.toJson();
      expect(json['type'], 'chat_message');
      expect(json['message'], 'Hello!');
    });

    test('all events have timestamp', () {
      final event = UserJoinedEvent(sessionId: sessionId, participant: participant);
      expect(event.timestamp, isA<DateTime>());
      expect(event.sessionId, sessionId);
    });
  });
}
