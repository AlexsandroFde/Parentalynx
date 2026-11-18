import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../child_device/domain/entities/child_device.dart';

/// Nivel de consumo da cota, para a cor do anel de tempo.
enum QuotaLevel {
  normal,

  /// A partir de 80% da cota.
  attention,

  /// Cota esgotada.
  exhausted;

  static QuotaLevel of(double usedFraction) {
    if (usedFraction >= 1) {
      return QuotaLevel.exhausted;
    }
    return usedFraction >= 0.8 ? QuotaLevel.attention : QuotaLevel.normal;
  }
}

/// Tempo de hoje de um aparelho, como o painel mostra: usado, limite, restante e o quanto da
/// cota ja foi consumido.
///
/// O retrato pode ser de um dia anterior, se o aparelho ainda nao sincronizou hoje: nesse
/// caso os tempos de hoje valem zero e o limite inteiro fica disponivel.
final class TodayUsage extends Equatable {
  const TodayUsage({
    required this.stale,
    required this.usedMs,
    required this.totalMs,
    required this.fraction,
    required this.level,
    required this.extraMs,
    required this.reportedAt,
    this.limitMs,
    this.remainingMs,
  });

  /// Tempo de hoje do aparelho, ou nulo enquanto ele nao sincronizou pela primeira vez.
  static TodayUsage? of(ChildDevice device) {
    final DeviceSnapshot? snapshot = device.snapshot;
    if (snapshot == null) {
      return null;
    }
    final bool stale = device.today.isNotEmpty && snapshot.day != device.today;
    final int used = stale ? 0 : snapshot.quotaUsedMs;
    final int total = stale ? 0 : snapshot.totalUsedMs;
    final int? limit = snapshot.limitMs;
    final int? remaining = limit == null
        ? null
        : math.max(0, stale ? limit : (snapshot.remainingMs ?? limit - used));
    final double fraction = limit == null ? 0 : (limit <= 0 ? 1 : (used / limit).clamp(0.0, 1.0));
    return TodayUsage(
      stale: stale,
      usedMs: used,
      totalMs: total,
      limitMs: limit,
      remainingMs: remaining,
      fraction: fraction,
      level: QuotaLevel.of(fraction),
      extraMs: snapshot.extraMs,
      reportedAt: snapshot.reportedAt,
    );
  }

  /// O retrato e de um dia anterior.
  final bool stale;

  /// Tempo que descontou da cota hoje.
  final int usedMs;

  /// Tempo total de uso hoje, inclusive o que nao desconta da cota.
  final int totalMs;

  /// Limite efetivo de hoje, ou nulo sem limite diario.
  final int? limitMs;

  /// Tempo restante da cota, ou nulo sem limite diario.
  final int? remainingMs;

  /// Fracao da cota ja usada, de 0 a 1.
  final double fraction;
  final QuotaLevel level;

  /// Tempo extra incluido no limite de hoje.
  final int extraMs;

  /// Quando o aparelho enviou o retrato.
  final int reportedAt;

  bool get hasLimit => limitMs != null;

  /// O limite de hoje inclui tempo extra (e o retrato e de hoje).
  bool get includesExtra => extraMs > 0 && !stale;

  @override
  List<Object?> get props => <Object?>[
    stale,
    usedMs,
    totalMs,
    limitMs,
    remainingMs,
    fraction,
    level,
    extraMs,
    reportedAt,
  ];
}
