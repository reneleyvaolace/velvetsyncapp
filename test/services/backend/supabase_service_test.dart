import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/services/backend/supabase_service.dart';

// ── Mocks ──────────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

class MockListBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockDynamicBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

class _ThenResponse {
  final Object? value;
  final bool isError;
  const _ThenResponse(this.value, {this.isError = false});
}

class MockMapBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap> {
  final List<_ThenResponse> _thenResponses = [];

  void thenReturns(PostgrestMap result) {
    _thenResponses.add(_ThenResponse(result));
  }

  void thenThrows(Object error) {
    _thenResponses.add(_ThenResponse(error, isError: true));
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestMap) onValue,
      {Function? onError}) {
    if (_thenResponses.isEmpty) return Future<R>.value(null as R);
    final response = _thenResponses.removeAt(0);
    if (response.isError) {
      return Future<R>.microtask(
        () => onError!(response.value as Object, StackTrace.empty) as R,
      );
    }
    return Future<R>.microtask(
      () => onValue(response.value as PostgrestMap) as R,
    );
  }
}

class MockNullableMapBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap?> {
  final List<_ThenResponse> _thenResponses = [];

  void thenReturns(PostgrestMap? result) {
    _thenResponses.add(_ThenResponse(result));
  }

  void thenThrows(Object error) {
    _thenResponses.add(_ThenResponse(error, isError: true));
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestMap?) onValue,
      {Function? onError}) {
    if (_thenResponses.isEmpty) return Future<R>.value(null as R);
    final response = _thenResponses.removeAt(0);
    if (response.isError) {
      return Future<R>.microtask(
        () => onError!(response.value as Object, StackTrace.empty) as R,
      );
    }
    return Future<R>.microtask(
      () => onValue(response.value as PostgrestMap?) as R,
    );
  }
}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {
  final MockListBuilder listBuilder;
  final MockDynamicBuilder dynamicBuilder;
  MockQueryBuilder(this.listBuilder, this.dynamicBuilder);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #select) return listBuilder;
    if (invocation.memberName == #insert) return dynamicBuilder;
    return super.noSuchMethod(invocation);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

const _testCatalogRow = {
  'id': 'dev-1',
  'factory_model': 'Knight No. 3',
  'model_name': 'Knight 3',
  'usage_type': 'insertable',
  'target_anatomy': 'vaginal',
  'stimulation_type': 'oscillating',
  'motor_logic': 'standard',
  'image_url': 'https://example.com/img.png',
  'qr_code_url': null,
  'supported_funcs': null,
  'is_precise_new': false,
  'broadcast_prefix': null,
};

PostgrestList _toList(List<Map<String, dynamic>> data) =>
    PostgrestList.from(data);

Map<String, dynamic> _sessionRow({
  String id = 'sess-1',
  String token = 'abc123xyz456def_',
}) {
  return {
    'id': id,
    'device_id': 'dev-1',
    'access_token': token,
    'is_active': true,
    'expires_at':
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  };
}

dynamic _anyCallback(dynamic _) => null;

void _registerFallbacks() {
  registerFallbackValue(const Duration(seconds: 1));
  registerFallbackValue(_anyCallback);
}

void _stubListChain(
  MockListBuilder mock,
  MockNullableMapBuilder nullableMap,
  MockMapBuilder map,
) {
  when(() => mock.select(any())).thenAnswer((_) => mock);
  when(() => mock.eq(any(), any())).thenAnswer((_) => mock);
  when(() => mock.or(any())).thenAnswer((_) => mock);
  when(() => mock.filter(any(), any(), any())).thenAnswer((_) => mock);
  when(() => mock.limit(any())).thenAnswer((_) => mock);
  when(() => mock.maybeSingle()).thenAnswer((_) => nullableMap);
  when(() => mock.single()).thenAnswer((_) => map);
}

void _stubDynamicChain(MockDynamicBuilder mock, MockListBuilder listBuilder) {
  when(() => mock.select(any())).thenAnswer((_) => listBuilder);
}

void main() {
  late SupabaseService service;
  late MockSupabaseClient mockClient;
  late MockListBuilder mockListBuilder;
  late MockDynamicBuilder mockDynamicBuilder;
  late MockMapBuilder mockMapBuilder;
  late MockNullableMapBuilder mockNullableMapBuilder;
  late MockQueryBuilder mockQuery;

  setUpAll(() {
    _registerFallbacks();
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockListBuilder = MockListBuilder();
    mockDynamicBuilder = MockDynamicBuilder();
    mockMapBuilder = MockMapBuilder();
    mockNullableMapBuilder = MockNullableMapBuilder();
    mockQuery = MockQueryBuilder(mockListBuilder, mockDynamicBuilder);

    when(() => mockClient.from(any())).thenAnswer((_) => mockQuery);

    _stubListChain(mockListBuilder, mockNullableMapBuilder, mockMapBuilder);
    _stubDynamicChain(mockDynamicBuilder, mockListBuilder);

    service = SupabaseService.testing(client: mockClient);
    service.resetInitialized();
    service.setInitialized();
  });

  group('construction', () {
    test('default constructor creates instance', () {
      expect(SupabaseService(), isA<SupabaseService>());
    });

    test('testing factory injects mock client', () {
      final s = SupabaseService.testing(client: mockClient);
      expect(s, isA<SupabaseService>());
    });
  });

  group('client getter', () {
    test('returns mock client when provided', () {
      expect(service.client, same(mockClient));
    });
  });

  group('initialize', () {
    test('setInitialized marks as initialized', () {
      service.resetInitialized();
      final s = SupabaseService.testing(client: mockClient);
      expect(s.isInitialized, false);
      s.setInitialized();
      expect(s.isInitialized, true);
    });

    test('resetInitialized resets state', () {
      expect(service.isInitialized, true);
      service.resetInitialized();
      expect(service.isInitialized, false);
    });
  });

  group('fetchDeviceCatalog', () {
    test('returns list of ToyModel on success', () async {
      when(() => mockListBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer((_) => Future.value(_toList([_testCatalogRow])));

      final result = await service.fetchDeviceCatalog();

      expect(result.length, 1);
      expect(result.first.id, 'dev-1');
      expect(result.first.name, 'Knight 3');
    });

    test('returns empty list when not initialized', () async {
      service.resetInitialized();
      final result = await service.fetchDeviceCatalog();
      expect(result, isEmpty);
    });

    test('returns empty list on error', () async {
      when(() => mockListBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenThrow(Exception('oops'));
      final result = await service.fetchDeviceCatalog();
      expect(result, isEmpty);
    });
  });

  group('fetchDeviceById', () {
    test('returns ToyModel on exact ID match', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer((_) => Future.value(PostgrestMap.from(_testCatalogRow)));

      final result = await service.fetchDeviceById('dev-1');
      expect(result, isNotNull);
      expect(result!.id, 'dev-1');
    });

    test('returns null when not found', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer((_) => Future.value(null));

      final result = await service.fetchDeviceById('nonexistent');
      expect(result, isNull);
    });

    test('returns null when not initialized', () async {
      service.resetInitialized();
      final result = await service.fetchDeviceById('dev-1');
      expect(result, isNull);
    });

    test('returns null on error', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenThrow(Exception('err'));
      final result = await service.fetchDeviceById('dev-1');
      expect(result, isNull);
    });
  });

  group('getTroubleshooting', () {
    test('returns steps string on success', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer(
          (_) => Future.value(PostgrestMap.from({'steps': 'Step 1: reboot'})));

      final result = await service.getTroubleshooting('E001');
      expect(result, 'Step 1: reboot');
    });

    test('returns null when data has no steps', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          ))
          .thenAnswer((_) => Future.value(PostgrestMap.from({'steps': null})));
      final result = await service.getTroubleshooting('E001');
      expect(result, isNull);
    });

    test('returns null when not initialized', () async {
      service.resetInitialized();
      final result = await service.getTroubleshooting('E001');
      expect(result, isNull);
    });

    test('returns null on error', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenThrow(Exception('err'));
      final result = await service.getTroubleshooting('E001');
      expect(result, isNull);
    });
  });

  group('isStealthActive', () {
    test('returns true when stealth policy exists', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer(
          (_) => Future.value(PostgrestMap.from({'max_intensity_cap': 50})));
      expect(await service.isStealthActive(), true);
    });

    test('returns false when no stealth policy', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer((_) => Future.value(null));
      expect(await service.isStealthActive(), false);
    });

    test('returns false when not initialized', () async {
      service.resetInitialized();
      expect(await service.isStealthActive(), false);
    });

    test('returns false on error', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenThrow(Exception('err'));
      expect(await service.isStealthActive(), false);
    });
  });

  group('getStealthIntensityCap', () {
    test('returns cap as fraction of 100', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer(
          (_) => Future.value(PostgrestMap.from({'max_intensity_cap': 75})));
      expect(await service.getStealthIntensityCap(), 0.75);
    });

    test('returns 1.0 when no stealth policy', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenAnswer((_) => Future.value(null));
      expect(await service.getStealthIntensityCap(), 1.0);
    });

    test('returns 1.0 when not initialized', () async {
      service.resetInitialized();
      expect(await service.getStealthIntensityCap(), 1.0);
    });

    test('returns 1.0 on error', () async {
      when(() => mockNullableMapBuilder.timeout(
            any(),
            onTimeout: any(named: 'onTimeout'),
          )).thenThrow(Exception('err'));
      expect(await service.getStealthIntensityCap(), 1.0);
    });
  });

  group('fetchSessionByToken', () {
    test('returns session on valid token', () async {
      final row = _sessionRow();
      mockNullableMapBuilder.thenReturns(PostgrestMap.from(row));

      final result = await service.fetchSessionByToken('abc123xyz456def_');
      expect(result, isNotNull);
      expect(result!['id'], 'sess-1');
    });

    test('returns null when session not found', () async {
      mockNullableMapBuilder.thenReturns(null);

      final result = await service.fetchSessionByToken('abc123xyz456def_');
      expect(result, isNull);
    });

    test('returns null for empty token', () async {
      expect(await service.fetchSessionByToken(''), isNull);
    });

    test('returns null for invalid token format (too short)', () async {
      expect(await service.fetchSessionByToken('short'), isNull);
    });

    test('returns null for invalid token format (special chars)', () async {
      expect(await service.fetchSessionByToken('abc 123 xyz 456 def ghi!!!'),
          isNull);
    });

    test('returns null when not initialized', () async {
      service.resetInitialized();
      expect(await service.fetchSessionByToken('abc123xyz456def_'), isNull);
    });

    test('returns null on error', () async {
      mockNullableMapBuilder.thenThrows(Exception('err'));
      final result = await service.fetchSessionByToken('abc123xyz456def_');
      expect(result, isNull);
    });
  });

  group('createSharedSession', () {
    setUp(() {
      service.resetInitialized();
      service.setInitialized();
    });

    test('creates session successfully', () async {
      final row = _sessionRow();
      mockMapBuilder.thenReturns(PostgrestMap.from(row));

      final result = await service.createSharedSession('dev-1');
      expect(result, isNotNull);
      expect(result!['id'], 'sess-1');
    });

    test('throws on FK failure (no more generic ID fallback)', () async {
      mockMapBuilder.thenThrows(Exception('foreign key violation'));

      expect(
        () => service.createSharedSession('dev-unknown'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws StateError on rate limit', () async {
      final row = _sessionRow();
      mockMapBuilder.thenReturns(PostgrestMap.from(row));

      await service.createSharedSession('dev-1');
      expect(() => service.createSharedSession('dev-1'),
          throwsA(isA<StateError>()));
    });

    test('returns null when not initialized', () async {
      service.resetInitialized();
      expect(await service.createSharedSession('dev-1'), isNull);
    });

    test('rethrows on unknown error', () async {
      mockMapBuilder.thenThrows(Exception('unknown'));
      expect(
        () => service.createSharedSession('dev-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('joinControlRoom', () {
    late MockRealtimeChannel channel;

    setUp(() {
      channel = MockRealtimeChannel();
      when(() => mockClient.channel(any())).thenReturn(channel);
      when(() => channel.onBroadcast(
            event: any(named: 'event'),
            callback: any(named: 'callback'),
          )).thenReturn(channel);
      when(() => channel.subscribe()).thenReturn(channel);
      when(() => channel.unsubscribe()).thenAnswer((_) => Future.value('ok'));
    });

    test('subscribes to channel with broadcast listener', () {
      service.joinControlRoom('session-1', (_, __) {});

      verify(() => mockClient.channel('session_session-1')).called(1);
      verify(() => channel.onBroadcast(
            event: 'control_command',
            callback: any(named: 'callback'),
          )).called(1);
      verify(() => channel.subscribe()).called(1);
    });

    test('unsubscribes previous channel before joining new', () {
      service.joinControlRoom('session-1', (_, __) {});
      service.joinControlRoom('session-2', (_, __) {});

      verify(() => channel.unsubscribe()).called(1);
    });
  });

  group('sendBroadcastCommand', () {
    test('sends broadcast message via channel', () async {
      final channel = MockRealtimeChannel();
      when(() => mockClient.channel(any())).thenReturn(channel);
      when(() => channel.subscribe()).thenReturn(channel);
      when(() => channel.sendBroadcastMessage(
            event: any(named: 'event'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) => Future.value(ChannelResponse.ok));

      await service.sendBroadcastCommand('session-1', 'intensity', 128);

      verify(() => mockClient.channel('session_session-1')).called(1);
      verify(() => channel.sendBroadcastMessage(
            event: 'control_command',
            payload: any(named: 'payload'),
          )).called(1);
    });
  });

  group('leaveControlRoom', () {
    test('unsubscribes and clears active channel', () {
      final channel = MockRealtimeChannel();
      when(() => mockClient.channel(any())).thenReturn(channel);
      when(() => channel.onBroadcast(
            event: any(named: 'event'),
            callback: any(named: 'callback'),
          )).thenReturn(channel);
      when(() => channel.subscribe()).thenReturn(channel);
      when(() => channel.unsubscribe()).thenAnswer((_) => Future.value('ok'));

      service.joinControlRoom('session-1', (_, __) {});
      service.leaveControlRoom();

      verify(() => channel.unsubscribe()).called(1);
    });
  });
}
