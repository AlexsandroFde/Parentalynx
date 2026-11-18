import '../../../app_management/domain/entities/app_entry.dart';
import '../../domain/entities/browsing_entry.dart';
import '../../domain/entities/cursor_page.dart';
import '../../domain/entities/device_event.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/entities/usage_session.dart';
import '../dto/report_dtos.dart';

/// Converte os relatorios do protocolo nas entidades, aplicando os valores padrao.
abstract final class ReportMapper {
  static ReportSummary summary(ReportSummaryDto dto) {
    final ReportTotalsDto? totals = dto.totals;
    return ReportSummary(
      from: dto.from,
      to: dto.to,
      timezone: dto.timezone ?? 'UTC',
      totals: totals == null ? ReportTotals.zero : _totals(totals),
      daily: dto.daily.map(_daily).toList(),
      apps: dto.apps.map(_app).toList(),
      categories: dto.categories.map(_category).toList(),
      // Sempre 24 posicoes, mesmo se o servidor mandar menos.
      hourly: <int>[
        for (int hour = 0; hour < ReportSummary.hoursPerDay; hour++)
          hour < dto.hourly.length ? dto.hourly[hour] : 0,
      ],
      blockedByApp: dto.blockedByApp
          .map(
            (BlockedAppDto app) => BlockedApp(
              package: app.package,
              label: app.label ?? app.package,
              count: app.count ?? 0,
            ),
          )
          .toList(),
    );
  }

  static ReportTotals _totals(ReportTotalsDto dto) {
    return ReportTotals(
      totalMs: dto.totalMs ?? 0,
      quotaMs: dto.quotaMs ?? 0,
      daysWithUse: dto.daysWithUse ?? 0,
      avgPerDayMs: dto.avgPerDayMs ?? 0,
      blockedAttempts: dto.blockedAttempts ?? 0,
      sessions: dto.sessions ?? 0,
      opens: dto.opens ?? 0,
    );
  }

  static DailyUsage _daily(DailyUsageDto dto) {
    return DailyUsage(
      day: dto.day,
      totalMs: dto.totalMs ?? 0,
      quotaMs: dto.quotaMs ?? 0,
      limitMs: dto.limitMs,
      limitReachedAt: dto.limitReachedAt,
      blockedAttempts: dto.blockedAttempts ?? 0,
      firstUseAt: dto.firstUseAt,
      lastUseAt: dto.lastUseAt,
    );
  }

  static AppUsage _app(AppUsageDto dto) {
    return AppUsage(
      package: dto.package,
      label: dto.label ?? dto.package,
      category: AppCategory.parse(dto.category),
      totalMs: dto.totalMs ?? 0,
      opens: dto.opens ?? 0,
      days: dto.days ?? 0,
      blockedAttempts: dto.blockedAttempts ?? 0,
    );
  }

  static CategoryUsage _category(CategoryUsageDto dto) {
    return CategoryUsage(category: AppCategory.parse(dto.category), totalMs: dto.totalMs ?? 0);
  }

  static UsageSession session(UsageSessionDto dto) {
    final int start = dto.start ?? 0;
    final int end = dto.end ?? start;
    return UsageSession(
      package: dto.package,
      label: dto.label ?? dto.package,
      category: AppCategory.parse(dto.category),
      start: start,
      end: end,
      durationMs: dto.durationMs ?? end - start,
      tzOffsetMin: dto.tzOffsetMin ?? 0,
    );
  }

  static DeviceEvent event(DeviceEventDto dto) {
    final EventDataDto? data = dto.data;
    return DeviceEvent(
      id: dto.id ?? 0,
      type: dto.type ?? '',
      ts: dto.ts ?? 0,
      package: dto.package,
      label: dto.label,
      details: data == null
          ? EventDetails.none
          : EventDetails(
              reason: data.reason,
              quotaUsedMs: data.quotaUsedMs,
              remainingMs: data.remainingMs,
              releaseAt: data.releaseAt,
              version: data.version,
              error: data.error,
              issue: data.issue,
              permission: data.permission,
              granted: data.granted,
              minutes: data.minutes,
              message: data.message,
              kind: data.kind,
            ),
    );
  }

  static BrowsingEntry browsing(BrowsingEntryDto dto) {
    return BrowsingEntry(
      id: dto.id,
      ts: dto.ts ?? 0,
      url: dto.url ?? '',
      domain: dto.domain ?? '',
      title: dto.title ?? '',
      blocked: dto.blocked ?? false,
      reason: dto.reason,
    );
  }

  static CursorPage<E> page<D, E>(CursorPageDto<D> dto, E Function(D item) map) {
    return CursorPage<E>(items: dto.items.map(map).toList(), nextBefore: dto.nextBefore);
  }
}
