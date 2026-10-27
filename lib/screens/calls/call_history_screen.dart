// ═══════════════════════════════════════════════════════════════
// Velvet Sync · lib/screens/calls/call_history_screen.dart
// Historial de videollamadas
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:velvet_sync/theme.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final response = await Supabase.instance.client
        .from('calls')
        .select()
        .or('caller_id.eq.${user.id},callee_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(100);

    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LvsColors.bg,
      appBar: AppBar(
        title: const Text('HISTORIAL DE LLAMADAS'),
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
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Text('No hay llamadas aún.',
                  style: TextStyle(color: LvsColors.text3)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = rows[i];
              final isOutgoing = r['caller_id'] == Supabase.instance.client.auth.currentUser?.id;
              final otherName = isOutgoing ? r['callee_name'] : r['caller_name'];
              final otherAvatar = isOutgoing ? r['callee_avatar'] : r['caller_avatar'];
              final type = r['call_type'] as String? ?? 'video';
              final state = r['state'] as String? ?? 'unknown';
              final started = r['started_at'] != null ? DateTime.parse(r['started_at']).toLocal() : null;
              final ended = r['ended_at'] != null ? DateTime.parse(r['ended_at']).toLocal() : null;
              final duration = ended != null && started != null ? ended.difference(started).inSeconds : 0;

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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: LvsColors.pink.withValues(alpha: 0.15),
                          backgroundImage: otherAvatar != null && otherAvatar.isNotEmpty
                              ? NetworkImage(otherAvatar)
                              : null,
                          child: otherAvatar == null || otherAvatar.isEmpty
                              ? const Icon(Icons.person, color: LvsColors.pink, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherName ?? 'Desconocido',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                      type == 'video' 
                                          ? Icons.videocam_rounded 
                                          : Icons.call_rounded,
                                      color: isOutgoing ? LvsColors.teal : LvsColors.pink,
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                      isOutgoing ? 'Saliente' : 'Entrante',
                                      style: TextStyle(color: LvsColors.text3, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStateColor(state).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStateText(state),
                            style: TextStyle(
                                color: _getStateColor(state),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_fmt(started)}  ·  ${_dur(duration)}',
                      style: const TextStyle(color: LvsColors.text3, fontSize: 11),
                    ),
                    if (duration > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _dur(duration),
                        style: const TextStyle(color: LvsColors.teal, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'active':
        return LvsColors.teal;
      case 'ended':
        return LvsColors.text3;
      case 'rejected':
        return LvsColors.red;
      case 'missed':
        return LvsColors.amber;
      case 'failed':
        return LvsColors.red;
      default:
        return LvsColors.text3;
    }
  }

  String _getStateText(String state) {
    switch (state) {
      case 'active':
        return 'Contestada';
      case 'ended':
        return 'Finalizada';
      case 'rejected':
        return 'Rechazada';
      case 'missed':
        return 'Perdida';
      case 'failed':
        return 'Fallida';
      default:
        return state;
    }
  }

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dur(int s) {
    if (s <= 0) return '—';
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }
}