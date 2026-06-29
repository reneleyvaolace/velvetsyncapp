import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/devices/models/funscript.dart';

void main() {
  group('FunscriptAction', () {
    test('creates instance with required fields', () {
      const action = FunscriptAction(pos: 50, at: 1000);
      expect(action.pos, 50);
      expect(action.at, 1000);
    });

    test('isValid returns true for valid action', () {
      expect(const FunscriptAction(pos: 0, at: 0).isValid, true);
      expect(const FunscriptAction(pos: 99, at: 1000).isValid, true);
      expect(const FunscriptAction(pos: 50, at: 500).isValid, true);
    });

    test('isValid returns false for out of range pos', () {
      expect(const FunscriptAction(pos: -1, at: 100).isValid, false);
      expect(const FunscriptAction(pos: 100, at: 100).isValid, false);
    });

    test('normalizedPos returns 0.0-1.0 range', () {
      expect(const FunscriptAction(pos: 0, at: 0).normalizedPos, 0.0);
      expect(const FunscriptAction(pos: 99, at: 0).normalizedPos, 1.0);
      expect(const FunscriptAction(pos: 50, at: 0).normalizedPos, closeTo(0.505, 0.01));
    });

    test('asDuration converts ms to Duration', () {
      const action = FunscriptAction(pos: 50, at: 1500);
      expect(action.asDuration, const Duration(milliseconds: 1500));
    });

    test('fromJson parses correctly', () {
      final action = FunscriptAction.fromJson({'pos': 75, 'at': 2000});
      expect(action.pos, 75);
      expect(action.at, 2000);
    });

    test('fromJson handles missing fields', () {
      final action = FunscriptAction.fromJson({});
      expect(action.pos, 0);
      expect(action.at, 0);
    });

    test('toJson serializes correctly', () {
      const action = FunscriptAction(pos: 30, at: 500);
      final json = action.toJson();
      expect(json['pos'], 30);
      expect(json['at'], 500);
    });

    test('toString formats correctly', () {
      const action = FunscriptAction(pos: 99, at: 1000);
      expect(action.toString(), contains('99'));
      expect(action.toString(), contains('1.000'));
    });
  });

  group('FunscriptMetadata', () {
    test('creates with default values', () {
      const meta = FunscriptMetadata();
      expect(meta.title, null);
      expect(meta.performers, isEmpty);
      expect(meta.tags, isEmpty);
    });

    test('fromJson parses correctly', () {
      final json = {
        'title': 'Test Script',
        'director': 'Director',
        'performers': ['Performer A'],
        'tags': ['tag1', 'tag2'],
        'source_url': 'https://example.com',
        'created_at': '2026-06-26T12:00:00.000',
      };
      final meta = FunscriptMetadata.fromJson(json);
      expect(meta.title, 'Test Script');
      expect(meta.performers, ['Performer A']);
      expect(meta.tags, ['tag1', 'tag2']);
      expect(meta.createdAt, DateTime(2026, 6, 26, 12, 0, 0));
    });

    test('fromJson handles missing fields', () {
      final meta = FunscriptMetadata.fromJson({});
      expect(meta.title, null);
      expect(meta.performers, isEmpty);
    });

    test('toJson serializes correctly', () {
      const meta = FunscriptMetadata(
        title: 'Script',
        performers: ['Actor'],
        tags: ['fun'],
      );
      final json = meta.toJson();
      expect(json['title'], 'Script');
      expect(json['performers'], ['Actor']);
      expect(json.containsKey('director'), false);
    });
  });

  group('Funscript', () {
    final sampleActions = [
      const FunscriptAction(pos: 0, at: 0),
      const FunscriptAction(pos: 50, at: 1000),
      const FunscriptAction(pos: 99, at: 2000),
      const FunscriptAction(pos: 30, at: 3000),
      const FunscriptAction(pos: 0, at: 4000),
    ];

    test('creates instance with required fields', () {
      final script = Funscript(version: '1.0', actions: sampleActions);
      expect(script.version, '1.0');
      expect(script.actions.length, 5);
      expect(script.inverted, false);
      expect(script.range, 90);
    });

    test('fromString parses JSON string', () {
      const jsonStr = '{"version":"1.0","actions":[{"pos":0,"at":0},{"pos":99,"at":1000}]}';
      final script = Funscript.fromString(jsonStr);
      expect(script.version, '1.0');
      expect(script.actions.length, 2);
      expect(script.actions.first.pos, 0);
    });

    test('fromJson parses correctly', () {
      final json = {
        'version': '2.0',
        'inverted': true,
        'range': 100,
        'actions': [
          {'pos': 50, 'at': 500},
        ],
        'metadata': {'title': 'My Script'},
      };
      final script = Funscript.fromJson(json);
      expect(script.version, '2.0');
      expect(script.inverted, true);
      expect(script.range, 100);
      expect(script.actions.length, 1);
      expect(script.metadata, isNotNull);
      expect(script.metadata!.title, 'My Script');
    });

    test('fromJson handles missing fields', () {
      final script = Funscript.fromJson({});
      expect(script.version, '1.0');
      expect(script.actions, isEmpty);
      expect(script.metadata, null);
    });

    test('toJson serializes correctly', () {
      final script = Funscript(version: '1.0', actions: sampleActions);
      final json = script.toJson();
      expect(json['version'], '1.0');
      expect(json['actions'], isA<List>());
      expect(json['actions'].length, 5);
    });

    test('toJson omits metadata when null', () {
      const script = Funscript(version: '1.0', actions: []);
      final json = script.toJson();
      expect(json.containsKey('metadata'), false);
    });

    group('getPositionAt', () {
      test('returns first action position for timestamp before start', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        final pos = script.getPositionAt(Duration.zero);
        expect(pos, 0.0);
      });

      test('returns last action position for timestamp after end', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        final pos = script.getPositionAt(const Duration(milliseconds: 5000));
        expect(pos, 0.0);
      });

      test('returns interpolated position between actions', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        // at 500ms: between pos 0 (0ms) and pos 50 (1000ms)
        final pos = script.getPositionAt(const Duration(milliseconds: 500));
        expect(pos, closeTo(0.2525, 0.01));
      });

      test('returns 0.0 for empty actions', () {
        const script = Funscript(version: '1.0', actions: []);
        expect(script.getPositionAt(const Duration(milliseconds: 500)), 0.0);
      });

      test('returns inverted position when inverted', () {
        const script = Funscript(version: '1.0', inverted: true, actions: [
          FunscriptAction(pos: 0, at: 0),
          FunscriptAction(pos: 99, at: 1000),
        ]);
        final pos = script.getPositionAt(Duration.zero);
        expect(pos, closeTo(1.0, 0.01));
      });
    });

    group('getActionAt', () {
      test('returns action within 50ms tolerance', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        final action = script.getActionAt(const Duration(milliseconds: 1002));
        expect(action, isNotNull);
        expect(action!.at, 1000);
      });

      test('returns null when no action within tolerance', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        final action = script.getActionAt(const Duration(milliseconds: 1100));
        expect(action, null);
      });

      test('returns null for empty actions', () {
        const script = Funscript(version: '1.0', actions: []);
        expect(script.getActionAt(Duration.zero), null);
      });
    });

    group('statistics', () {
      test('durationMs returns last action timestamp', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        expect(script.durationMs, 4000);
      });

      test('durationMs returns 0 for empty actions', () {
        const script = Funscript(version: '1.0', actions: []);
        expect(script.durationMs, 0);
      });

      test('duration returns as Duration', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        expect(script.duration, const Duration(seconds: 4));
      });

      test('actionCount returns correct count', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        expect(script.actionCount, 5);
      });

      test('minPosition returns minimum position', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        expect(script.minPosition, 0);
      });

      test('maxPosition returns maximum position', () {
        final script = Funscript(version: '1.0', actions: sampleActions);
        expect(script.maxPosition, 99);
      });

      test('averagePosition calculates correctly', () {
        const script = Funscript(version: '1.0', actions: [
          FunscriptAction(pos: 0, at: 0),
          FunscriptAction(pos: 50, at: 1000),
          FunscriptAction(pos: 100, at: 2000),
        ]);
        expect(script.averagePosition, closeTo(50.0, 0.1));
      });

      test('averagePosition returns 0 for empty actions', () {
        const script = Funscript(version: '1.0', actions: []);
        expect(script.averagePosition, 0.0);
      });

      test('averageSpeed calculates actions per second', () {
        const script = Funscript(version: '1.0', actions: [
          FunscriptAction(pos: 0, at: 0),
          FunscriptAction(pos: 50, at: 500),
          FunscriptAction(pos: 99, at: 1000),
        ]);
        expect(script.averageSpeed, closeTo(3.0, 0.1));
      });

      test('averageSpeed returns 0 for empty actions', () {
        const script = Funscript(version: '1.0', actions: []);
        expect(script.averageSpeed, 0.0);
      });
    });

    test('toString formats correctly', () {
      final script = Funscript(version: '1.0', actions: sampleActions);
      expect(script.toString(), contains('1.0'));
      expect(script.toString(), contains('5'));
    });
  });

  group('FunscriptDurationExtension', () {
    test('toFunscriptTimestamp formats correctly', () {
      const dur = Duration(hours: 1, minutes: 5, seconds: 30, milliseconds: 500);
      expect(dur.toFunscriptTimestamp(), '05:30.500');
    });

    test('toFunscriptTimestamp handles zero', () {
      expect(Duration.zero.toFunscriptTimestamp(), '00:00.000');
    });

    test('toFunscriptTimestamp pads correctly', () {
      const dur = Duration(seconds: 3, milliseconds: 50);
      expect(dur.toFunscriptTimestamp(), '00:03.050');
    });
  });
}
