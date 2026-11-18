import '../../../../core/json/json_reader.dart';

// Objetos de transferencia dos relatorios no formato do protocolo (secoes 4 e 6). Espelham o
// JSON: campos ausentes ficam nulos. Os padroes sao aplicados pelo `ReportMapper`.

final class ReportTotalsDto {
  const ReportTotalsDto({
    this.totalMs,
    this.quotaMs,
    this.daysWithUse,
    this.avgPerDayMs,
    this.blockedAttempts,
    this.sessions,
    this.opens,
  });

  factory ReportTotalsDto.fromJson(JsonMap json) {
    return ReportTotalsDto(
      totalMs: json.intOrNull('totalMs'),
      quotaMs: json.intOrNull('quotaMs'),
      daysWithUse: json.intOrNull('daysWithUse'),
      avgPerDayMs: json.intOrNull('avgPerDayMs'),
      blockedAttempts: json.intOrNull('blockedAttempts'),
      sessions: json.intOrNull('sessions'),
      opens: json.intOrNull('opens'),
    );
  }

  final int? totalMs;
  final int? quotaMs;
  final int? daysWithUse;
  final int? avgPerDayMs;
  final int? blockedAttempts;
  final int? sessions;
  final int? opens;
}

final class DailyUsageDto {
  const DailyUsageDto({
    required this.day,
    this.totalMs,
    this.quotaMs,
    this.limitMs,
    this.limitReachedAt,
    this.blockedAttempts,
    this.firstUseAt,
    this.lastUseAt,
  });

  factory DailyUsageDto.fromJson(JsonMap json) {
    return DailyUsageDto(
      day: json.str('day'),
      totalMs: json.intOrNull('totalMs'),
      quotaMs: json.intOrNull('quotaMs'),
      limitMs: json.intOrNull('limitMs'),
      limitReachedAt: json.intOrNull('limitReachedAt'),
      blockedAttempts: json.intOrNull('blockedAttempts'),
      firstUseAt: json.intOrNull('firstUseAt'),
      lastUseAt: json.intOrNull('lastUseAt'),
    );
  }

  final String day;
  final int? totalMs;
  final int? quotaMs;
  final int? limitMs;
  final int? limitReachedAt;
  final int? blockedAttempts;
  final int? firstUseAt;
  final int? lastUseAt;
}

final class AppUsageDto {
  const AppUsageDto({
    required this.package,
    this.label,
    this.category,
    this.totalMs,
    this.opens,
    this.days,
    this.blockedAttempts,
  });

  factory AppUsageDto.fromJson(JsonMap json) {
    return AppUsageDto(
      package: json.str('package'),
      label: json.strOrNull('label'),
      category: json.strOrNull('category'),
      totalMs: json.intOrNull('totalMs'),
      opens: json.intOrNull('opens'),
      days: json.intOrNull('days'),
      blockedAttempts: json.intOrNull('blockedAttempts'),
    );
  }

  final String package;
  final String? label;
  final String? category;
  final int? totalMs;
  final int? opens;
  final int? days;
  final int? blockedAttempts;
}

final class CategoryUsageDto {
  const CategoryUsageDto({this.category, this.totalMs});

  factory CategoryUsageDto.fromJson(JsonMap json) {
    return CategoryUsageDto(
      category: json.strOrNull('category'),
      totalMs: json.intOrNull('totalMs'),
    );
  }

  final String? category;
  final int? totalMs;
}

final class BlockedAppDto {
  const BlockedAppDto({required this.package, this.label, this.count});

  factory BlockedAppDto.fromJson(JsonMap json) {
    return BlockedAppDto(
      package: json.str('package'),
      label: json.strOrNull('label'),
      count: json.intOrNull('count'),
    );
  }

  final String package;
  final String? label;
  final int? count;
}

final class ReportSummaryDto {
  const ReportSummaryDto({
    required this.from,
    required this.to,
    this.timezone,
    this.totals,
    this.daily = const <DailyUsageDto>[],
    this.apps = const <AppUsageDto>[],
    this.categories = const <CategoryUsageDto>[],
    this.hourly = const <int>[],
    this.blockedByApp = const <BlockedAppDto>[],
  });

  factory ReportSummaryDto.fromJson(JsonMap json) {
    final JsonMap? totals = json.objOrNull('totals');
    return ReportSummaryDto(
      from: json.str('from'),
      to: json.str('to'),
      timezone: json.strOrNull('timezone'),
      totals: totals == null ? null : ReportTotalsDto.fromJson(totals),
      daily: json.objList('daily').map(DailyUsageDto.fromJson).toList(),
      apps: json.objList('apps').map(AppUsageDto.fromJson).toList(),
      categories: json.objList('categories').map(CategoryUsageDto.fromJson).toList(),
      hourly: json.has('hourly') ? json.intList('hourly') : const <int>[],
      blockedByApp: json.objList('blockedByApp').map(BlockedAppDto.fromJson).toList(),
    );
  }

  final String from;
  final String to;
  final String? timezone;
  final ReportTotalsDto? totals;
  final List<DailyUsageDto> daily;
  final List<AppUsageDto> apps;
  final List<CategoryUsageDto> categories;

  /// Milissegundos por hora local. Pode vir com menos de 24 posicoes.
  final List<int> hourly;
  final List<BlockedAppDto> blockedByApp;
}

final class UsageSessionDto {
  const UsageSessionDto({
    required this.package,
    this.label,
    this.category,
    this.start,
    this.end,
    this.durationMs,
    this.tzOffsetMin,
  });

  factory UsageSessionDto.fromJson(JsonMap json) {
    return UsageSessionDto(
      package: json.str('package'),
      label: json.strOrNull('label'),
      category: json.strOrNull('category'),
      start: json.intOrNull('start'),
      end: json.intOrNull('end'),
      durationMs: json.intOrNull('durationMs'),
      tzOffsetMin: json.intOrNull('tzOffsetMin'),
    );
  }

  final String package;
  final String? label;
  final String? category;
  final int? start;
  final int? end;
  final int? durationMs;
  final int? tzOffsetMin;
}

/// Campo `data` de um evento. Cada tipo usa alguns campos; valores de tipo inesperado sao
/// ignorados, para um evento de uma versao mais nova nao derrubar a lista.
final class EventDataDto {
  const EventDataDto({
    this.reason,
    this.quotaUsedMs,
    this.remainingMs,
    this.releaseAt,
    this.version,
    this.error,
    this.issue,
    this.permission,
    this.granted,
    this.minutes,
    this.message,
    this.kind,
  });

  factory EventDataDto.fromJson(JsonMap json) {
    return EventDataDto(
      reason: _string(json, 'reason'),
      quotaUsedMs: _integer(json, 'quotaUsedMs'),
      remainingMs: _integer(json, 'remainingMs'),
      releaseAt: _integer(json, 'releaseAt'),
      version: _integer(json, 'version'),
      error: _string(json, 'error'),
      issue: _string(json, 'issue'),
      permission: _string(json, 'permission'),
      granted: _boolean(json, 'granted'),
      minutes: _integer(json, 'minutes'),
      message: _string(json, 'message'),
      kind: _string(json, 'kind'),
    );
  }

  final String? reason;
  final int? quotaUsedMs;
  final int? remainingMs;
  final int? releaseAt;
  final int? version;
  final String? error;
  final String? issue;
  final String? permission;
  final bool? granted;
  final int? minutes;
  final String? message;
  final String? kind;

  static String? _string(JsonMap json, String key) {
    final Object? value = json.raw[key];
    return value is String ? value : null;
  }

  static int? _integer(JsonMap json, String key) {
    final Object? value = json.raw[key];
    if (value is int) {
      return value;
    }
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    return null;
  }

  static bool? _boolean(JsonMap json, String key) {
    final Object? value = json.raw[key];
    return value is bool ? value : null;
  }
}

final class DeviceEventDto {
  const DeviceEventDto({this.id, this.type, this.ts, this.package, this.label, this.data});

  factory DeviceEventDto.fromJson(JsonMap json) {
    final JsonMap? data = json.objOrNull('data');
    return DeviceEventDto(
      id: json.intOrNull('id'),
      type: json.strOrNull('type'),
      ts: json.intOrNull('ts'),
      package: json.strOrNull('package'),
      label: json.strOrNull('label'),
      data: data == null ? null : EventDataDto.fromJson(data),
    );
  }

  final int? id;
  final String? type;
  final int? ts;
  final String? package;
  final String? label;
  final EventDataDto? data;
}

final class BrowsingEntryDto {
  const BrowsingEntryDto({
    required this.id,
    this.ts,
    this.url,
    this.domain,
    this.title,
    this.blocked,
    this.reason,
  });

  factory BrowsingEntryDto.fromJson(JsonMap json) {
    return BrowsingEntryDto(
      // O identificador pode vir como numero ou texto.
      id: '${json.raw['id'] ?? ''}',
      ts: json.intOrNull('ts'),
      url: json.strOrNull('url'),
      domain: json.strOrNull('domain'),
      title: json.strOrNull('title'),
      blocked: json.has('blocked') ? json.boolean('blocked') : null,
      reason: json.strOrNull('reason'),
    );
  }

  final String id;
  final int? ts;
  final String? url;
  final String? domain;
  final String? title;
  final bool? blocked;
  final String? reason;
}

/// Pagina de uma lista paginada pelo cursor `before`.
final class CursorPageDto<T> {
  const CursorPageDto({required this.items, this.nextBefore});

  /// Le a lista em [key] e o cursor `nextBefore`, que e opaco: numero ou texto.
  factory CursorPageDto.fromJson(JsonMap json, String key, T Function(JsonMap json) item) {
    final Object? cursor = json.raw['nextBefore'];
    return CursorPageDto<T>(
      items: json.objList(key).map(item).toList(),
      nextBefore: cursor == null ? null : '$cursor',
    );
  }

  final List<T> items;
  final String? nextBefore;
}
