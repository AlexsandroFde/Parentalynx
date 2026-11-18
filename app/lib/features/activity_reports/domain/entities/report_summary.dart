import 'package:equatable/equatable.dart';

import '../../../app_management/domain/entities/app_entry.dart';

/// Totais de um relatorio (protocolo, secao 6).
final class ReportTotals extends Equatable {
  const ReportTotals({
    required this.totalMs,
    required this.quotaMs,
    required this.daysWithUse,
    required this.avgPerDayMs,
    required this.blockedAttempts,
    required this.sessions,
    required this.opens,
  });

  static const ReportTotals zero = ReportTotals(
    totalMs: 0,
    quotaMs: 0,
    daysWithUse: 0,
    avgPerDayMs: 0,
    blockedAttempts: 0,
    sessions: 0,
    opens: 0,
  );

  final int totalMs;
  final int quotaMs;
  final int daysWithUse;
  final int avgPerDayMs;
  final int blockedAttempts;
  final int sessions;
  final int opens;

  @override
  List<Object?> get props => <Object?>[
    totalMs,
    quotaMs,
    daysWithUse,
    avgPerDayMs,
    blockedAttempts,
    sessions,
    opens,
  ];
}

/// Uso de um dia da cota.
final class DailyUsage extends Equatable {
  const DailyUsage({
    required this.day,
    required this.totalMs,
    required this.quotaMs,
    required this.blockedAttempts,
    this.limitMs,
    this.limitReachedAt,
    this.firstUseAt,
    this.lastUseAt,
  });

  final String day;

  /// Todo o tempo em apps rastreados.
  final int totalMs;

  /// A parte que consumiu a cota do dia.
  final int quotaMs;
  final int? limitMs;
  final int? limitReachedAt;
  final int blockedAttempts;
  final int? firstUseAt;
  final int? lastUseAt;

  /// Tempo que nao consumiu a cota (excecoes ou regras suspensas).
  int get outsideQuotaMs => totalMs > quotaMs ? totalMs - quotaMs : 0;

  @override
  List<Object?> get props => <Object?>[
    day,
    totalMs,
    quotaMs,
    limitMs,
    limitReachedAt,
    blockedAttempts,
    firstUseAt,
    lastUseAt,
  ];
}

/// Uso de um app no periodo.
final class AppUsage extends Equatable {
  const AppUsage({
    required this.package,
    required this.label,
    required this.category,
    required this.totalMs,
    required this.opens,
    required this.days,
    required this.blockedAttempts,
  });

  final String package;
  final String label;
  final AppCategory category;
  final int totalMs;
  final int opens;
  final int days;
  final int blockedAttempts;

  @override
  List<Object?> get props => <Object?>[
    package,
    label,
    category,
    totalMs,
    opens,
    days,
    blockedAttempts,
  ];
}

/// Tempo de uso de uma categoria de apps no periodo.
final class CategoryUsage extends Equatable {
  const CategoryUsage({required this.category, required this.totalMs});

  final AppCategory category;
  final int totalMs;

  @override
  List<Object?> get props => <Object?>[category, totalMs];
}

/// Tentativas de abrir um app bloqueado no periodo.
final class BlockedApp extends Equatable {
  const BlockedApp({required this.package, required this.label, required this.count});

  final String package;
  final String label;
  final int count;

  @override
  List<Object?> get props => <Object?>[package, label, count];
}

/// Relatorio de uso de um aparelho em um intervalo de dias da cota.
final class ReportSummary extends Equatable {
  const ReportSummary({
    required this.from,
    required this.to,
    required this.timezone,
    required this.totals,
    required this.daily,
    required this.apps,
    required this.categories,
    required this.hourly,
    required this.blockedByApp,
  });

  /// Quantidade de posicoes de [hourly]: uma por hora do dia.
  static const int hoursPerDay = 24;

  final String from;
  final String to;
  final String timezone;
  final ReportTotals totals;
  final List<DailyUsage> daily;
  final List<AppUsage> apps;
  final List<CategoryUsage> categories;

  /// Tempo total por hora local do dia, somado no periodo. Sempre 24 posicoes.
  final List<int> hourly;
  final List<BlockedApp> blockedByApp;

  bool get hasUsage => totals.totalMs > 0;

  /// O periodo tem mais de um dia (graficos por dia fazem sentido).
  bool get isMultiDay => daily.length > 1;

  /// Hora do dia com mais uso, ou nulo se nao houve uso.
  int? get peakHour {
    int best = -1;
    int bestMs = 0;
    for (int hour = 0; hour < hourly.length; hour++) {
      if (hourly[hour] > bestMs) {
        bestMs = hourly[hour];
        best = hour;
      }
    }
    return best < 0 ? null : best;
  }

  /// Os [limit] apps mais usados (o servidor ja manda do mais usado para o menos usado).
  List<AppUsage> topApps({int limit = 8}) => apps.take(limit).toList();

  /// Categorias com algum uso no periodo.
  List<CategoryUsage> get usedCategories {
    return categories.where((CategoryUsage category) => category.totalMs > 0).toList();
  }

  /// Fracao do tempo total do periodo, de 0 a 100, arredondada. Nulo sem uso.
  int? percentOfTotal(int ms) {
    final int total = totals.totalMs;
    return total <= 0 ? null : (ms * 100 / total).round();
  }

  @override
  List<Object?> get props => <Object?>[
    from,
    to,
    timezone,
    totals,
    daily,
    apps,
    categories,
    hourly,
    blockedByApp,
  ];
}
