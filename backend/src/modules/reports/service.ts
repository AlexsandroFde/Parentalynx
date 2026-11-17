// Relatorios para o painel dos responsaveis (protocolo, secao 6).

import type { AppContext } from '../../context.ts';
import { fieldError } from '../../core/errors.ts';
import { dayRange, diffDays, isDay } from '../../core/time.ts';
import { isPlainObject } from '../../core/validate.ts';
import type { DeviceRow, UsageDayRow } from '../../db/rows.ts';
import { deviceToday, listAppRows, readPolicy } from '../devices/service.ts';

export const MAX_REPORT_DAYS = 92;

interface AppMeta {
  label: string;
  category: string;
}

function appMeta(ctx: AppContext, deviceId: string): Map<string, AppMeta> {
  return new Map(listAppRows(ctx, deviceId).map((row) => [row.package, { label: row.label, category: row.category }]));
}

/** Valida o intervalo de dias de uma consulta. Sem parametros, usa o dia corrente do aparelho. */
export function resolveRange(
  ctx: AppContext,
  device: DeviceRow,
  from: string | undefined,
  to: string | undefined,
  maxDays = MAX_REPORT_DAYS,
): { from: string; to: string } {
  const today = deviceToday(ctx, readPolicy(device));
  const end = to ?? today;
  const start = from ?? end;
  if (!isDay(start)) throw fieldError('from', 'Use uma data no formato AAAA-MM-DD.');
  if (!isDay(end)) throw fieldError('to', 'Use uma data no formato AAAA-MM-DD.');
  const span = diffDays(start, end);
  if (span < 0) throw fieldError('from', 'O início do período precisa ser anterior ou igual ao fim.');
  if (span + 1 > maxDays) throw fieldError('to', `O período aceita no máximo ${maxDays} dias.`);
  return { from: start, to: end };
}

export interface ReportSummary {
  from: string;
  to: string;
  timezone: string;
  totals: {
    totalMs: number;
    quotaMs: number;
    daysWithUse: number;
    avgPerDayMs: number;
    blockedAttempts: number;
    sessions: number;
    opens: number;
  };
  daily: {
    day: string;
    totalMs: number;
    quotaMs: number;
    limitMs: number | null;
    limitReachedAt: number | null;
    blockedAttempts: number;
    firstUseAt: number | null;
    lastUseAt: number | null;
  }[];
  apps: {
    package: string;
    label: string;
    category: string;
    totalMs: number;
    opens: number;
    days: number;
    blockedAttempts: number;
  }[];
  categories: { category: string; totalMs: number }[];
  hourly: number[];
  blockedByApp: { package: string; label: string; count: number }[];
}

export function reportSummary(ctx: AppContext, device: DeviceRow, from: string, to: string): ReportSummary {
  const meta = appMeta(ctx, device.id);
  const labelOf = (pkg: string): string => meta.get(pkg)?.label ?? pkg;
  const categoryOf = (pkg: string): string => meta.get(pkg)?.category ?? 'other';

  const dayRows = new Map(
    ctx.db
      .all<UsageDayRow>('SELECT * FROM usage_day WHERE device_id = ? AND day BETWEEN ? AND ?', device.id, from, to)
      .map((row) => [row.day, row]),
  );
  const blockedPerDay = new Map(
    ctx.db
      .all<{ day: string; total: number }>(
        `SELECT day, COUNT(*) AS total FROM events
         WHERE device_id = ? AND type = 'blocked_attempt' AND day BETWEEN ? AND ? GROUP BY day`,
        device.id,
        from,
        to,
      )
      .map((row) => [row.day, row.total]),
  );
  const blockedPerApp = ctx.db.all<{ package: string; total: number }>(
    `SELECT package, COUNT(*) AS total FROM events
     WHERE device_id = ? AND type = 'blocked_attempt' AND package IS NOT NULL AND day BETWEEN ? AND ?
     GROUP BY package ORDER BY total DESC, package`,
    device.id,
    from,
    to,
  );
  const blockedOf = new Map(blockedPerApp.map((row) => [row.package, row.total]));

  const hourly = new Array<number>(24).fill(0);
  const daily = dayRange(from, to).map((day) => {
    const row = dayRows.get(day);
    if (row) {
      const values = JSON.parse(row.hourly) as number[];
      for (let hour = 0; hour < 24; hour += 1) hourly[hour] = (hourly[hour] ?? 0) + (values[hour] ?? 0);
    }
    return {
      day,
      totalMs: row?.total_ms ?? 0,
      quotaMs: row?.quota_ms ?? 0,
      limitMs: row?.limit_ms ?? null,
      limitReachedAt: row?.limit_reached_at ?? null,
      blockedAttempts: blockedPerDay.get(day) ?? 0,
      firstUseAt: row?.first_use_at ?? null,
      lastUseAt: row?.last_use_at ?? null,
    };
  });

  const appRows = ctx.db.all<{ package: string; total: number; opens: number; days: number }>(
    `SELECT package, SUM(ms) AS total, SUM(opens) AS opens, SUM(CASE WHEN ms > 0 THEN 1 ELSE 0 END) AS days
     FROM usage_app WHERE device_id = ? AND day BETWEEN ? AND ?
     GROUP BY package HAVING SUM(ms) > 0 OR SUM(opens) > 0
     ORDER BY total DESC, package`,
    device.id,
    from,
    to,
  );
  const apps = appRows.map((row) => ({
    package: row.package,
    label: labelOf(row.package),
    category: categoryOf(row.package),
    totalMs: row.total,
    opens: row.opens,
    days: row.days,
    blockedAttempts: blockedOf.get(row.package) ?? 0,
  }));

  const perCategory = new Map<string, number>();
  for (const app of apps) perCategory.set(app.category, (perCategory.get(app.category) ?? 0) + app.totalMs);
  const categories = [...perCategory.entries()]
    .filter(([, totalMs]) => totalMs > 0)
    .map(([category, totalMs]) => ({ category, totalMs }))
    .sort((left, right) => right.totalMs - left.totalMs || left.category.localeCompare(right.category));

  const sessions = ctx.db.get<{ total: number }>(
    'SELECT COUNT(*) AS total FROM usage_sessions WHERE device_id = ? AND day BETWEEN ? AND ?',
    device.id,
    from,
    to,
  );

  const totalMs = daily.reduce((sum, day) => sum + day.totalMs, 0);
  const daysWithUse = daily.filter((day) => day.totalMs > 0).length;
  return {
    from,
    to,
    timezone: readPolicy(device).timezone,
    totals: {
      totalMs,
      quotaMs: daily.reduce((sum, day) => sum + day.quotaMs, 0),
      daysWithUse,
      // Media nos dias em que houve uso, para um dia parado nao distorcer o habito.
      avgPerDayMs: daysWithUse === 0 ? 0 : Math.round(totalMs / daysWithUse),
      blockedAttempts: daily.reduce((sum, day) => sum + day.blockedAttempts, 0),
      sessions: sessions?.total ?? 0,
      opens: apps.reduce((sum, app) => sum + app.opens, 0),
    },
    daily,
    apps,
    categories,
    hourly,
    blockedByApp: blockedPerApp.map((row) => ({ package: row.package, label: labelOf(row.package), count: row.total })),
  };
}

export interface UsageSessionJson {
  package: string;
  label: string;
  category: string;
  start: number;
  end: number;
  durationMs: number;
  tzOffsetMin: number;
}

export function listSessions(ctx: AppContext, device: DeviceRow, day: string): UsageSessionJson[] {
  const meta = appMeta(ctx, device.id);
  return ctx.db
    .all<{ package: string; start_ms: number; end_ms: number; duration_ms: number; tz_offset_min: number }>(
      `SELECT package, start_ms, end_ms, duration_ms, tz_offset_min FROM usage_sessions
       WHERE device_id = ? AND day = ? ORDER BY start_ms, client_id LIMIT 5000`,
      device.id,
      day,
    )
    .map((row) => ({
      package: row.package,
      label: meta.get(row.package)?.label ?? row.package,
      category: meta.get(row.package)?.category ?? 'other',
      start: row.start_ms,
      end: row.end_ms,
      durationMs: row.duration_ms,
      tzOffsetMin: row.tz_offset_min,
    }));
}

export interface EventJson {
  id: number;
  type: string;
  ts: number;
  package: string | null;
  label: string | null;
  data: Record<string, unknown>;
}

export interface EventQuery {
  from?: string;
  to?: string;
  types?: string[];
  before?: number;
  limit: number;
}

function decodeEventData(ctx: AppContext, stored: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(ctx.cipher.decrypt(stored, 'events.data'));
  return isPlainObject(parsed) ? parsed : {};
}

/** Eventos do aparelho, do mais recente para o mais antigo (ordem de chegada ao servidor). */
export function listEvents(
  ctx: AppContext,
  device: DeviceRow,
  query: EventQuery,
): { events: EventJson[]; nextBefore: number | null } {
  const meta = appMeta(ctx, device.id);
  const conditions = ['device_id = ?', 'id < ?'];
  const params: (string | number)[] = [device.id, query.before ?? Number.MAX_SAFE_INTEGER];
  if (query.from !== undefined) {
    conditions.push('day >= ?');
    params.push(query.from);
  }
  if (query.to !== undefined) {
    conditions.push('day <= ?');
    params.push(query.to);
  }
  if (query.types && query.types.length > 0) {
    conditions.push(`type IN (${query.types.map(() => '?').join(', ')})`);
    params.push(...query.types);
  }
  const rows = ctx.db.all<{ id: number; type: string; ts: number; package: string | null; data_enc: string }>(
    `SELECT id, type, ts, package, data_enc FROM events WHERE ${conditions.join(' AND ')} ORDER BY id DESC LIMIT ?`,
    ...params,
    query.limit + 1,
  );
  const page = rows.slice(0, query.limit);
  const last = page[page.length - 1];
  return {
    events: page.map((row) => ({
      id: row.id,
      type: row.type,
      ts: row.ts,
      package: row.package,
      label: row.package === null ? null : (meta.get(row.package)?.label ?? row.package),
      data: decodeEventData(ctx, row.data_enc),
    })),
    nextBefore: rows.length > query.limit && last ? last.id : null,
  };
}

export interface BrowsingJson {
  id: number;
  ts: number;
  url: string;
  domain: string;
  title: string | null;
  blocked: boolean;
  reason: string | null;
}

export function listBrowsing(
  ctx: AppContext,
  device: DeviceRow,
  query: { from?: string; to?: string; before?: number; limit: number },
): { entries: BrowsingJson[]; nextBefore: number | null } {
  const conditions = ['device_id = ?', 'id < ?'];
  const params: (string | number)[] = [device.id, query.before ?? Number.MAX_SAFE_INTEGER];
  if (query.from !== undefined) {
    conditions.push('day >= ?');
    params.push(query.from);
  }
  if (query.to !== undefined) {
    conditions.push('day <= ?');
    params.push(query.to);
  }
  const rows = ctx.db.all<{
    id: number;
    ts: number;
    url_enc: string;
    domain: string;
    title_enc: string | null;
    blocked: number;
    reason: string | null;
  }>(
    `SELECT id, ts, url_enc, domain, title_enc, blocked, reason FROM browsing
     WHERE ${conditions.join(' AND ')} ORDER BY id DESC LIMIT ?`,
    ...params,
    query.limit + 1,
  );
  const page = rows.slice(0, query.limit);
  const last = page[page.length - 1];
  return {
    entries: page.map((row) => ({
      id: row.id,
      ts: row.ts,
      url: ctx.cipher.decrypt(row.url_enc, 'browsing.url'),
      domain: row.domain,
      title: ctx.cipher.decryptNullable(row.title_enc, 'browsing.title'),
      blocked: row.blocked === 1,
      reason: row.reason,
    })),
    nextBefore: rows.length > query.limit && last ? last.id : null,
  };
}

/** Todos os dados do aparelho, decifrados, para portabilidade (LGPD). */
export function exportDevice(ctx: AppContext, device: DeviceRow): Record<string, unknown> {
  const usageApps = ctx.db.all<{ day: string; package: string; ms: number; opens: number }>(
    'SELECT day, package, ms, opens FROM usage_app WHERE device_id = ? ORDER BY day, package',
    device.id,
  );
  const appsByDay = new Map<string, { package: string; ms: number; opens: number }[]>();
  for (const row of usageApps) {
    const list = appsByDay.get(row.day) ?? [];
    list.push({ package: row.package, ms: row.ms, opens: row.opens });
    appsByDay.set(row.day, list);
  }
  const days = ctx.db
    .all<UsageDayRow>('SELECT * FROM usage_day WHERE device_id = ? ORDER BY day', device.id)
    .map((row) => ({
      day: row.day,
      quotaUsedMs: row.quota_ms,
      totalUsedMs: row.total_ms,
      limitMs: row.limit_ms,
      extraMs: row.extra_ms,
      limitReachedAt: row.limit_reached_at,
      firstUseAt: row.first_use_at,
      lastUseAt: row.last_use_at,
      hourly: JSON.parse(row.hourly) as number[],
      apps: appsByDay.get(row.day) ?? [],
    }));
  const sessions = ctx.db
    .all<{ client_id: string; package: string; start_ms: number; end_ms: number; day: string; tz_offset_min: number }>(
      'SELECT client_id, package, start_ms, end_ms, day, tz_offset_min FROM usage_sessions WHERE device_id = ? ORDER BY start_ms',
      device.id,
    )
    .map((row) => ({
      id: row.client_id,
      package: row.package,
      start: row.start_ms,
      end: row.end_ms,
      day: row.day,
      tzOffsetMin: row.tz_offset_min,
    }));
  const events = ctx.db
    .all<{ client_id: string; type: string; ts: number; package: string | null; data_enc: string }>(
      'SELECT client_id, type, ts, package, data_enc FROM events WHERE device_id = ? ORDER BY id',
      device.id,
    )
    .map((row) => ({
      id: row.client_id,
      type: row.type,
      ts: row.ts,
      package: row.package,
      data: decodeEventData(ctx, row.data_enc),
    }));
  const browsing = ctx.db
    .all<{
      client_id: string;
      ts: number;
      url_enc: string;
      domain: string;
      title_enc: string | null;
      blocked: number;
      reason: string | null;
    }>('SELECT client_id, ts, url_enc, domain, title_enc, blocked, reason FROM browsing WHERE device_id = ? ORDER BY id', device.id)
    .map((row) => ({
      id: row.client_id,
      ts: row.ts,
      url: ctx.cipher.decrypt(row.url_enc, 'browsing.url'),
      domain: row.domain,
      title: ctx.cipher.decryptNullable(row.title_enc, 'browsing.title'),
      blocked: row.blocked === 1,
      reason: row.reason,
    }));
  const apps = listAppRows(ctx, device.id).map((row) => ({
    package: row.package,
    label: row.label,
    category: row.category,
    system: row.is_system === 1,
    launchable: row.launchable === 1,
    essential: row.essential === 1,
    versionName: row.version_name,
    installedAt: row.installed_at,
    updatedAt: row.updated_at,
    removed: row.removed_at !== null,
  }));
  const timeRequests = ctx.db
    .all<{
      id: string;
      created_at: number;
      minutes: number | null;
      message_enc: string | null;
      status: string;
      granted_minutes: number | null;
      resolved_at: number | null;
    }>(
      'SELECT id, created_at, minutes, message_enc, status, granted_minutes, resolved_at FROM time_requests WHERE device_id = ? ORDER BY created_at',
      device.id,
    )
    .map((row) => ({
      id: row.id,
      createdAt: row.created_at,
      minutes: row.minutes,
      message: ctx.cipher.decryptNullable(row.message_enc, 'time_requests.message'),
      status: row.status,
      grantedMinutes: row.granted_minutes,
      resolvedAt: row.resolved_at,
    }));

  return {
    exportedAt: ctx.now(),
    device: {
      id: device.id,
      status: device.status,
      childName: device.child_name,
      deviceName: device.device_name,
      model: device.model,
      manufacturer: device.manufacturer,
      androidRelease: device.android_release,
      sdkInt: device.sdk_int,
      appVersion: device.app_version,
      timezone: device.timezone,
      createdAt: device.created_at,
      approvedAt: device.approved_at,
      revokedAt: device.revoked_at,
      lastSyncAt: device.last_sync_at,
      managementMode: device.management_mode,
    },
    policyVersion: device.policy_version,
    policy: readPolicy(device),
    apps,
    days,
    sessions,
    events,
    browsing,
    timeRequests,
  };
}
