import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'usage_session.dart';

/// Intervalo sem uso entre duas sessoes, para a linha do tempo.
final class InactivityGap extends Equatable {
  const InactivityGap({required this.start, required this.end});

  final int start;
  final int end;

  int get durationMs => end - start;

  @override
  List<Object?> get props => <Object?>[start, end];
}

/// Item da linha do tempo de um dia: uma sessao ou uma pausa longa.
sealed class TimelineItem extends Equatable {
  const TimelineItem();
}

final class TimelineSession extends TimelineItem {
  const TimelineSession(this.session);

  final UsageSession session;

  @override
  List<Object?> get props => <Object?>[session];
}

final class TimelineGap extends TimelineItem {
  const TimelineGap(this.gap);

  final InactivityGap gap;

  @override
  List<Object?> get props => <Object?>[gap];
}

/// Linha do tempo das sessoes de um dia, com o resumo do dia.
final class DayTimeline extends Equatable {
  const DayTimeline({
    required this.sessions,
    required this.items,
    required this.totalMs,
    required this.longestGapMs,
  });

  /// Monta a linha do tempo: sessoes em ordem e os intervalos sem uso de pelo menos
  /// [minGapMs] entre elas.
  factory DayTimeline.fromSessions(List<UsageSession> sessions, {int minGapMs = defaultMinGapMs}) {
    final List<UsageSession> sorted = <UsageSession>[...sessions]
      ..sort((UsageSession a, UsageSession b) => a.start.compareTo(b.start));
    final List<TimelineItem> items = <TimelineItem>[];
    int? lastEnd;
    int longestGap = 0;
    for (final UsageSession session in sorted) {
      final int? previousEnd = lastEnd;
      if (previousEnd != null && session.start - previousEnd >= minGapMs) {
        final InactivityGap gap = InactivityGap(start: previousEnd, end: session.start);
        longestGap = math.max(longestGap, gap.durationMs);
        items.add(TimelineGap(gap));
      }
      items.add(TimelineSession(session));
      lastEnd = previousEnd == null || session.end > previousEnd ? session.end : previousEnd;
    }
    return DayTimeline(
      sessions: sessions,
      items: items,
      totalMs: sessions.fold<int>(0, (int sum, UsageSession s) => sum + s.durationMs),
      longestGapMs: longestGap,
    );
  }

  /// Pausa minima para aparecer na linha do tempo: 15 minutos.
  static const int defaultMinGapMs = 15 * 60000;

  /// Sessoes do dia, na ordem recebida.
  final List<UsageSession> sessions;
  final List<TimelineItem> items;

  /// Soma da duracao das sessoes.
  final int totalMs;

  /// Maior pausa entre sessoes. Zero quando nao ha pausa longa.
  final int longestGapMs;

  bool get isEmpty => sessions.isEmpty;

  @override
  List<Object?> get props => <Object?>[sessions, items, totalMs, longestGapMs];
}
