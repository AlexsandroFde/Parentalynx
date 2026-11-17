import '../../../../core/json/json_reader.dart';
import '../../apps/domain/app_entry.dart';

/// Modelos dos relatorios (protocolo, secao 6).

class ReportTotals {
  const ReportTotals({
    required this.totalMs,
    required this.quotaMs,
    required this.daysWithUse,
    required this.avgPerDayMs,
    required this.blockedAttempts,
    required this.sessions,
    required this.opens,
  });

  factory ReportTotals.fromJson(JsonMap json) {
    return ReportTotals(
      totalMs: json.intOr('totalMs', fallback: 0),
      quotaMs: json.intOr('quotaMs', fallback: 0),
      daysWithUse: json.intOr('daysWithUse', fallback: 0),
      avgPerDayMs: json.intOr('avgPerDayMs', fallback: 0),
      blockedAttempts: json.intOr('blockedAttempts', fallback: 0),
      sessions: json.intOr('sessions', fallback: 0),
      opens: json.intOr('opens', fallback: 0),
    );
  }

  final int totalMs;
  final int quotaMs;
  final int daysWithUse;
  final int avgPerDayMs;
  final int blockedAttempts;
  final int sessions;
  final int opens;
}

class DailyUsage {
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

  factory DailyUsage.fromJson(JsonMap json) {
    return DailyUsage(
      day: json.str('day'),
      totalMs: json.intOr('totalMs', fallback: 0),
      quotaMs: json.intOr('quotaMs', fallback: 0),
      limitMs: json.intOrNull('limitMs'),
      limitReachedAt: json.intOrNull('limitReachedAt'),
      blockedAttempts: json.intOr('blockedAttempts', fallback: 0),
      firstUseAt: json.intOrNull('firstUseAt'),
      lastUseAt: json.intOrNull('lastUseAt'),
    );
  }

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
}

class AppUsage {
  const AppUsage({
    required this.package,
    required this.label,
    required this.category,
    required this.totalMs,
    required this.opens,
    required this.days,
    required this.blockedAttempts,
  });

  factory AppUsage.fromJson(JsonMap json) {
    final String package = json.str('package');
    return AppUsage(
      package: package,
      label: json.strOrNull('label') ?? package,
      category: AppCategory.parse(json.strOrNull('category')),
      totalMs: json.intOr('totalMs', fallback: 0),
      opens: json.intOr('opens', fallback: 0),
      days: json.intOr('days', fallback: 0),
      blockedAttempts: json.intOr('blockedAttempts', fallback: 0),
    );
  }

  final String package;
  final String label;
  final AppCategory category;
  final int totalMs;
  final int opens;
  final int days;
  final int blockedAttempts;
}

class CategoryUsage {
  const CategoryUsage({required this.category, required this.totalMs});

  factory CategoryUsage.fromJson(JsonMap json) {
    return CategoryUsage(
      category: AppCategory.parse(json.strOrNull('category')),
      totalMs: json.intOr('totalMs', fallback: 0),
    );
  }

  final AppCategory category;
  final int totalMs;
}

class BlockedApp {
  const BlockedApp({required this.package, required this.label, required this.count});

  factory BlockedApp.fromJson(JsonMap json) {
    final String package = json.str('package');
    return BlockedApp(
      package: package,
      label: json.strOrNull('label') ?? package,
      count: json.intOr('count', fallback: 0),
    );
  }

  final String package;
  final String label;
  final int count;
}

class ReportSummary {
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

  factory ReportSummary.fromJson(JsonMap json) {
    final List<int> hourly = json.has('hourly') ? json.intList('hourly') : const <int>[];
    return ReportSummary(
      from: json.str('from'),
      to: json.str('to'),
      timezone: json.strOrNull('timezone') ?? 'UTC',
      totals: ReportTotals.fromJson(json.objOrNull('totals') ?? const JsonMap.empty()),
      daily: json.objList('daily').map(DailyUsage.fromJson).toList(),
      apps: json.objList('apps').map(AppUsage.fromJson).toList(),
      categories: json.objList('categories').map(CategoryUsage.fromJson).toList(),
      // Sempre 24 posicoes, mesmo se o servidor mandar menos.
      hourly: <int>[for (int hour = 0; hour < 24; hour++) hour < hourly.length ? hourly[hour] : 0],
      blockedByApp: json.objList('blockedByApp').map(BlockedApp.fromJson).toList(),
    );
  }

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
}

class UsageSession {
  const UsageSession({
    required this.package,
    required this.label,
    required this.category,
    required this.start,
    required this.end,
    required this.durationMs,
    required this.tzOffsetMin,
  });

  factory UsageSession.fromJson(JsonMap json) {
    final String package = json.str('package');
    final int start = json.intOr('start', fallback: 0);
    final int end = json.intOr('end', fallback: start);
    return UsageSession(
      package: package,
      label: json.strOrNull('label') ?? package,
      category: AppCategory.parse(json.strOrNull('category')),
      start: start,
      end: end,
      durationMs: json.intOr('durationMs', fallback: end - start),
      tzOffsetMin: json.intOr('tzOffsetMin', fallback: 0),
    );
  }

  final String package;
  final String label;
  final AppCategory category;
  final int start;
  final int end;
  final int durationMs;

  /// Diferenca do fuso do aparelho para UTC no momento da sessao, em minutos.
  final int tzOffsetMin;

  /// Inicio no relogio local do aparelho da crianca (como instante UTC deslocado).
  DateTime get localStart {
    return DateTime.fromMillisecondsSinceEpoch(start + tzOffsetMin * 60000, isUtc: true);
  }

  DateTime get localEnd {
    return DateTime.fromMillisecondsSinceEpoch(end + tzOffsetMin * 60000, isUtc: true);
  }
}

class DeviceEvent {
  const DeviceEvent({
    required this.id,
    required this.type,
    required this.ts,
    required this.data,
    this.package,
    this.label,
  });

  factory DeviceEvent.fromJson(JsonMap json) {
    return DeviceEvent(
      id: json.intOr('id', fallback: 0),
      type: json.strOrNull('type') ?? '',
      ts: json.intOr('ts', fallback: 0),
      package: json.strOrNull('package'),
      label: json.strOrNull('label'),
      data: json.objOrNull('data') ?? const JsonMap.empty(),
    );
  }

  final int id;
  final String type;
  final int ts;
  final String? package;
  final String? label;
  final JsonMap data;

  /// Nome do app do evento, ou o pacote quando o servidor nao conhece o nome.
  String get appName => label ?? package ?? 'app';
}

class BrowsingEntry {
  const BrowsingEntry({
    required this.id,
    required this.ts,
    required this.url,
    required this.domain,
    required this.title,
    required this.blocked,
    this.reason,
  });

  factory BrowsingEntry.fromJson(JsonMap json) {
    return BrowsingEntry(
      id: '${json.raw['id'] ?? ''}',
      ts: json.intOr('ts', fallback: 0),
      url: json.strOrNull('url') ?? '',
      domain: json.strOrNull('domain') ?? '',
      title: json.strOrNull('title') ?? '',
      blocked: json.boolOr('blocked', fallback: false),
      reason: json.strOrNull('reason'),
    );
  }

  final String id;
  final int ts;
  final String url;
  final String domain;
  final String title;
  final bool blocked;
  final String? reason;
}

/// Pagina de uma lista paginada pelo cursor `before`.
class ResultPage<T> {
  const ResultPage({required this.items, this.nextBefore});

  final List<T> items;

  /// Cursor da proxima pagina, ou nulo quando nao ha mais itens.
  final String? nextBefore;
}
