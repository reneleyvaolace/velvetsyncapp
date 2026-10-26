// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/session_history_screen.dart
// Historial de sesiones remotas (duración, motivo de cierre).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:velvet_sync/services/backend/supabase_service.dart';
import 'package:velvet_sync/theme.dart';

class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  ConsumerState<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(supabaseServiceProvider).fetchSessionHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('HISTORIAL DE SESIONES'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: LvsColors.red)),
            );
          }
          final rows = snap.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return const Center(
              child: Text('Aún no hay sesiones cerradas.',
                  style: TextStyle(color: LvsColors.text3)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = rows[i];
              final started = _parse(r['started_at']);
              final ended = _parse(r['ended_at']);
              final secs = (r['duration_seconds'] as num?)?.toInt() ?? 0;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['device_id']?.toString() ?? 'Dispositivo',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmt(started)} → ${_fmt(ended)}',
                      style: const TextStyle(color: LvsColors.text3, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duración: ${_dur(secs)} · ${r['ended_reason'] ?? '—'}',
                      style: const TextStyle(color: LvsColors.teal, fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  static String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _dur(int s) {
    if (s <= 0) return '—';
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }
}
