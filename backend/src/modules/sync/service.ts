// Rotas do aparelho: sincronizacao, inventario, icones e autenticacao do responsavel no aparelho
// (protocolo, secao 5).

import type { AppContext } from '../../context.ts';
import { ApiError, errors, fieldError } from '../../core/errors.ts';
import type { FieldIssue } from '../../core/errors.ts';
import { formatDurationMs, formatMinutes } from '../../core/format.ts';
import { verifyPassword } from '../../core/passwords.ts';
import { DAY_MS, diffDays, HOUR_MS, isDay, MINUTE_MS, quotaDayOf } from '../../core/time.ts';
import { isPlainObject, v } from '../../core/validate.ts';
import type { Parser } from '../../core/validate.ts';
import type { DeviceRow, GuardianRow, TimeRequestRow, UsageDayRow } from '../../db/rows.ts';
import { createAlert } from '../alerts/service.ts';
import { readSettings } from '../auth/service.ts';
import { appLabel, deviceToday, expireTimeRequests, readPolicy, revokeDevice } from '../devices/service.ts';
import { audit } from '../guardian/audit.ts';
import type { Policy } from '../policy/schema.ts';

export const MAX_SESSIONS = 500;
export const MAX_EVENTS = 500;
export const MAX_BROWSING = 500;
export const MAX_DAYS = 8;
export const MAX_INVENTORY = 3000;
export const MAX_ICON_BYTES = 64 * 1024;

const BLOCKED_ALERT_WINDOW_MS = 10 * MINUTE_MS;
/** Evento que chega com mais atraso que isto e registrado, mas nao gera notificacao. */
const STALE_EVENT_MS = 12 * HOUR_MS;
const INVENTORY_MAX_AGE_MS = 24 * HOUR_MS;

const MANAGEMENT_MODES = ['standard', 'device_admin', 'device_owner'] as const;
const LOCK_STATES = ['none', 'daily_limit', 'schedule', 'manual_lock', 'tamper_lock'] as const;
const BROWSING_REASONS = ['domain_blocked', 'category', 'safe_dns', 'not_in_allowlist'] as const;
export const APP_CATEGORIES = [
  'games',
  'social',
  'video',
  'audio',
  'image',
  'news',
  'maps',
  'productivity',
  'communication',
  'browser',
  'system',
  'other',
] as const;

// Nome de pacote como o sistema informa. So se exige que nao tenha espacos nem caracteres de
// controle: os valores vao para o banco por parametro, entao nao ha risco de injecao.
const packageName = v.string({ min: 1, max: 255, pattern: /^[^\s\p{Cc}]+$/u });
const clientId = v.string({ min: 1, max: 64, pattern: /^[A-Za-z0-9_.:-]+$/ });
const instant = v.int({ min: 0, max: 9_999_999_999_999 });
const dayMs = v.int({ min: 0, max: 2 * DAY_MS });

const dayString: Parser<string> = (value, path, issues) => {
  if (!isDay(value)) {
    issues.push({ field: path, message: 'Use uma data no formato AAAA-MM-DD.' });
    return '';
  }
  return value;
};

const statusParser = v.object({
  managementMode: v.oneOf(MANAGEMENT_MODES),
  permissions: v.record(v.bool(), { maxKeys: 32, key: /^[A-Za-z0-9_]{1,40}$/ }),
  enforcement: v.object({
    active: v.bool(),
    issues: v.array(v.string({ min: 1, max: 60 }), { max: 32 }),
  }),
  lock: v.object({ state: v.oneOf(LOCK_STATES), releaseAt: v.nullable(instant) }),
  foregroundApp: v.nullable(v.string({ max: 255 })),
  screenOn: v.bool(),
  batteryPercent: v.nullable(v.int({ min: 0, max: 100 })),
  appVersion: v.string({ max: 40 }),
  sdkInt: v.int({ min: 1, max: 1000 }),
  timezone: v.string({ max: 64 }),
  tzOffsetMin: v.int({ min: -1000, max: 1000 }),
  clockTrusted: v.bool(),
});

const dayParser = v.object({
  day: dayString,
  quotaUsedMs: dayMs,
  totalUsedMs: dayMs,
  limitMs: v.nullable(v.int({ min: 0, max: 3 * DAY_MS })),
  extraMs: v.withDefault(v.int({ min: 0, max: 3 * DAY_MS }), 0),
  limitReachedAt: v.nullable(instant),
  firstUseAt: v.nullable(instant),
  lastUseAt: v.nullable(instant),
  apps: v.array(v.object({ package: packageName, ms: dayMs, opens: v.int({ min: 0, max: 1_000_000 }) }), { max: 3000 }),
  hourly: v.array(v.int({ min: 0, max: 2 * HOUR_MS }), { min: 24, max: 24 }),
});

const sessionParser = v.object({
  id: clientId,
  package: packageName,
  start: instant,
  end: instant,
  day: dayString,
  tzOffsetMin: v.withDefault(v.int({ min: -1000, max: 1000 }), 0),
});

const eventParser = v.object({
  id: clientId,
  type: v.string({ min: 1, max: 40, pattern: /^[a-z0-9_]+$/ }),
  ts: instant,
  package: v.nullable(packageName),
  data: v.withDefault(v.anyObject(), {}),
});

// Os limites de texto aqui sao folgados de proposito: o que passar do tamanho gravado e cortado
// em `syncDevice`. Recusar o lote inteiro por causa de um endereco longo travaria a fila do
// aparelho, que reenviaria o mesmo lote para sempre.
const MAX_URL_CHARS = 4096;
const MAX_TITLE_CHARS = 500;
const MAX_DOMAIN_CHARS = 255;

const browsingParser = v.object({
  id: clientId,
  ts: instant,
  url: v.string({ min: 1, max: 200_000 }),
  domain: v.string({ max: 2000, lower: true }),
  title: v.nullable(v.string({ max: 200_000 })),
  blocked: v.bool(),
  reason: v.nullable(v.oneOf(BROWSING_REASONS)),
});

const syncParser = v.object({
  sentAt: instant,
  policyVersion: v.int({ min: 0, max: 1_000_000_000 }),
  policyAppliedAt: v.nullable(instant),
  status: statusParser,
  days: v.withDefault(v.array(dayParser, { max: MAX_DAYS }), []),
  sessions: v.withDefault(v.array(sessionParser, { max: MAX_SESSIONS }), []),
  events: v.withDefault(v.array(eventParser, { max: MAX_EVENTS }), []),
  browsing: v.withDefault(v.array(browsingParser, { max: MAX_BROWSING }), []),
});

type SyncBody = ReturnType<typeof syncParser>;
type SyncEvent = SyncBody['events'][number];
type SyncDay = SyncBody['days'][number];

/** Lotes acima do limite respondem `payload_too_large` antes de qualquer validacao de conteudo. */
function assertBatchLimits(body: unknown): void {
  if (!isPlainObject(body)) return;
  const limits: [string, number][] = [
    ['sessions', MAX_SESSIONS],
    ['events', MAX_EVENTS],
    ['browsing', MAX_BROWSING],
    ['days', MAX_DAYS],
  ];
  for (const [field, max] of limits) {
    const list = body[field];
    if (Array.isArray(list) && list.length > max) {
      throw errors.payloadTooLarge(`O campo ${field} aceita no máximo ${max} itens por sincronização.`);
    }
  }
}

export function parseSyncBody(body: unknown): SyncBody {
  assertBatchLimits(body);
  const issues: FieldIssue[] = [];
  const parsed = syncParser(body, '', issues);
  if (issues.length > 0) {
    throw new ApiError('validation_error', 'Dados de sincronização inválidos.', {
      fields: issues.map((issue) => issue.field),
      issues,
    });
  }
  return parsed;
}

export interface SyncResponse {
  serverTime: number;
  policyVersion: number;
  policy: Policy | null;
  ack: { sessions: string[]; events: string[]; browsing: string[]; days: string[] };
  reconcile: { day: string; quotaUsedMs: number; totalUsedMs: number } | null;
  timeRequests: { id: string; status: string; grantedMinutes: number | null; resolvedAt: number | null }[];
  childName: string;
  guardianName: string;
  lowTimeMinutes: number;
  needAppInventory: boolean;
}

function minOf(left: number | null, right: number | null): number | null {
  if (left === null) return right;
  if (right === null) return left;
  return Math.min(left, right);
}

function maxOf(left: number | null, right: number | null): number | null {
  if (left === null) return right;
  if (right === null) return left;
  return Math.max(left, right);
}

/**
 * Grava o agregado de um dia guardando sempre o MAIOR valor de cada contador (protocolo 5.2):
 * o aparelho nunca "recupera" tempo reenviando um valor menor.
 */
function upsertDay(ctx: AppContext, deviceId: string, day: SyncDay): UsageDayRow {
  const now = ctx.now();
  const existing = ctx.db.get<UsageDayRow>('SELECT * FROM usage_day WHERE device_id = ? AND day = ?', deviceId, day.day);
  let hourly = day.hourly;
  if (existing) {
    const stored = JSON.parse(existing.hourly) as number[];
    hourly = day.hourly.map((value, index) => Math.max(value, stored[index] ?? 0));
  }
  const merged: UsageDayRow = {
    device_id: deviceId,
    day: day.day,
    quota_ms: Math.max(existing?.quota_ms ?? 0, day.quotaUsedMs),
    total_ms: Math.max(existing?.total_ms ?? 0, day.totalUsedMs),
    limit_ms: day.limitMs,
    extra_ms: day.extraMs,
    limit_reached_at: day.limitReachedAt ?? existing?.limit_reached_at ?? null,
    first_use_at: minOf(existing?.first_use_at ?? null, day.firstUseAt),
    last_use_at: maxOf(existing?.last_use_at ?? null, day.lastUseAt),
    hourly: JSON.stringify(hourly),
    updated_at: now,
  };
  ctx.db.run(
    `INSERT INTO usage_day (device_id, day, quota_ms, total_ms, limit_ms, extra_ms, limit_reached_at, first_use_at, last_use_at, hourly, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(device_id, day) DO UPDATE SET
       quota_ms = excluded.quota_ms, total_ms = excluded.total_ms, limit_ms = excluded.limit_ms,
       extra_ms = excluded.extra_ms, limit_reached_at = excluded.limit_reached_at,
       first_use_at = excluded.first_use_at, last_use_at = excluded.last_use_at,
       hourly = excluded.hourly, updated_at = excluded.updated_at`,
    merged.device_id,
    merged.day,
    merged.quota_ms,
    merged.total_ms,
    merged.limit_ms,
    merged.extra_ms,
    merged.limit_reached_at,
    merged.first_use_at,
    merged.last_use_at,
    merged.hourly,
    merged.updated_at,
  );
  for (const app of day.apps) {
    ctx.db.run(
      `INSERT INTO usage_app (device_id, day, package, ms, opens) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(device_id, day, package) DO UPDATE SET ms = MAX(ms, excluded.ms), opens = MAX(opens, excluded.opens)`,
      deviceId,
      day.day,
      app.package,
      app.ms,
      app.opens,
    );
  }
  return merged;
}

const BLOCK_REASON_TEXT: Record<string, string> = {
  app_blocked: 'o app está bloqueado',
  daily_limit: 'o limite diário foi atingido',
  schedule: 'está fora do horário permitido',
  manual_lock: 'o aparelho está bloqueado',
  app_limit: 'o limite deste app foi atingido',
  new_app: 'o app aguarda aprovação',
  tamper_lock: 'a proteção do aparelho foi alterada',
};

const ISSUE_TEXT: Record<string, string> = {
  accessibility_disabled: 'O serviço de acessibilidade foi desativado. O bloqueio de apps pode não funcionar.',
  usage_access_missing: 'O acesso ao uso foi revogado. A contagem de tempo pode ficar imprecisa.',
  overlay_missing: 'A permissão de sobreposição não está concedida.',
  notifications_disabled: 'As notificações do app foram desativadas.',
  battery_optimized: 'O app está sujeito à otimização de bateria e pode ser encerrado em segundo plano.',
  suspend_failed: 'O sistema recusou a suspensão de um ou mais apps.',
  policy_invalid: 'O aparelho não conseguiu interpretar as regras recebidas.',
  clock_untrusted: 'O relógio do aparelho não pôde ser confirmado com o servidor.',
};

const PERMISSION_TEXT: Record<string, string> = {
  usageAccess: 'Acesso ao uso',
  accessibility: 'Serviço de acessibilidade',
  overlay: 'Sobreposição a outros apps',
  notifications: 'Notificações',
  batteryOptimizationIgnored: 'Isenção de otimização de bateria',
  deviceAdmin: 'Administrador do dispositivo',
  deviceOwner: 'Modo Device Owner',
  exactAlarms: 'Alarmes exatos',
};

const MODE_TEXT: Record<string, string> = {
  standard: 'padrão',
  device_admin: 'administrador do dispositivo',
  device_owner: 'Device Owner',
};

function text(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function integer(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? Math.round(value) : null;
}

/** Efeitos de um evento recem-gravado: alertas e pedidos de tempo (protocolo 5.3). */
function handleNewEvent(ctx: AppContext, device: DeviceRow, policy: Policy, event: SyncEvent): void {
  const now = ctx.now();
  const child = device.child_name;
  const fresh = now - event.ts <= STALE_EVENT_MS;
  const base = {
    guardianId: device.guardian_id,
    deviceId: device.id,
    childName: child,
    notify: fresh,
  };
  const data = event.data;

  switch (event.type) {
    case 'blocked_attempt': {
      if (!event.package) return;
      const label = appLabel(ctx, device.id, event.package);
      const reason = text(data.reason, 'app_blocked');
      createAlert(ctx, {
        ...base,
        type: 'blocked_app_attempt',
        title: 'Tentativa de abrir app bloqueado',
        body: `${child} tentou abrir ${label}: ${BLOCK_REASON_TEXT[reason] ?? 'o app não está liberado'}.`,
        data: { package: event.package, label, reason, eventAt: event.ts },
        dedupeKey: event.package,
        dedupeWindowMs: BLOCKED_ALERT_WINDOW_MS,
      });
      return;
    }
    case 'limit_reached': {
      const limitMs = integer(data.limitMs);
      createAlert(ctx, {
        ...base,
        type: 'limit_reached',
        title: 'Limite diário atingido',
        body:
          limitMs === null
            ? `${child} usou todo o tempo de hoje.`
            : `${child} usou todo o tempo de hoje (${formatDurationMs(limitMs)}).`,
        data: { day: text(data.day), limitMs, quotaUsedMs: integer(data.quotaUsedMs), eventAt: event.ts },
      });
      return;
    }
    case 'low_time': {
      const remainingMs = integer(data.remainingMs) ?? 0;
      createAlert(ctx, {
        ...base,
        type: 'low_time',
        title: 'Pouco tempo restante',
        body: `${child} tem ${formatDurationMs(remainingMs)} restantes hoje.`,
        data: { remainingMs, thresholdMinutes: integer(data.thresholdMinutes), eventAt: event.ts },
      });
      return;
    }
    case 'policy_apply_failed': {
      const version = integer(data.version);
      createAlert(ctx, {
        ...base,
        type: 'enforcement_failure',
        title: 'Falha ao aplicar as regras',
        body: `O aparelho de ${child} não conseguiu aplicar ${version === null ? 'as regras' : `a versão ${version} das regras`}.`,
        data: { event: event.type, version, error: text(data.error).slice(0, 300), eventAt: event.ts },
      });
      return;
    }
    case 'enforcement_issue': {
      const issue = text(data.issue, 'desconhecido');
      createAlert(ctx, {
        ...base,
        type: 'enforcement_failure',
        title: 'Controle parental com problema',
        body: `Aparelho de ${child}: ${ISSUE_TEXT[issue] ?? 'o controle parental relatou um problema.'}`,
        data: { event: event.type, issue, detail: text(data.detail).slice(0, 300), eventAt: event.ts },
        dedupeKey: `issue:${issue}`,
        dedupeWindowMs: HOUR_MS,
      });
      return;
    }
    case 'permission_changed': {
      const permission = text(data.permission, 'desconhecida');
      const granted = data.granted === true;
      createAlert(ctx, {
        ...base,
        type: 'permission_changed',
        title: granted ? 'Permissão concedida' : 'Permissão revogada',
        body: `${PERMISSION_TEXT[permission] ?? permission} foi ${granted ? 'concedida' : 'revogada'} no aparelho de ${child}.`,
        data: { permission, granted, eventAt: event.ts },
        // Concessao e boa noticia e vem em rajada na configuracao inicial: fica na central, sem
        // notificacao. Revogacao notifica.
        notify: !granted,
      });
      return;
    }
    case 'time_request': {
      const rawMinutes = integer(data.minutes);
      const minutes = rawMinutes !== null && rawMinutes >= 1 && rawMinutes <= 720 ? rawMinutes : null;
      const message = text(data.message).trim().slice(0, 300) || null;
      // Relogio do aparelho muito fora: usa a hora do servidor para o prazo de 24 horas valer.
      const createdAt = event.ts > now || now - event.ts > DAY_MS ? now : event.ts;
      const inserted = ctx.db.run(
        `INSERT OR IGNORE INTO time_requests (id, device_id, created_at, minutes, message_enc, status) VALUES (?, ?, ?, ?, ?, 'pending')`,
        event.id,
        device.id,
        createdAt,
        minutes,
        ctx.cipher.encryptNullable(message, 'time_requests.message'),
      );
      if (inserted.changes === 0) return;
      const asked = minutes === null ? 'mais tempo' : `mais ${formatMinutes(minutes)}`;
      createAlert(ctx, {
        ...base,
        notify: true,
        type: 'time_request',
        title: 'Pedido de mais tempo',
        body: message === null ? `${child} pediu ${asked}.` : `${child} pediu ${asked}: "${message}"`,
        data: { requestId: event.id, minutes, message },
      });
      ctx.hub.toGuardian(device.guardian_id, { type: 'time_request', deviceId: device.id, requestId: event.id });
      return;
    }
    case 'local_override': {
      const minutes = integer(data.minutes) ?? 0;
      const method = text(data.method) === 'offline_code' ? 'código de acesso offline' : 'senha administrativa';
      createAlert(ctx, {
        ...base,
        type: 'security_event',
        title: 'Uso liberado no próprio aparelho',
        body: `O uso foi liberado por ${formatMinutes(minutes)} no aparelho de ${child}, com ${method}.`,
        data: { event: event.type, minutes, method: text(data.method), eventAt: event.ts },
      });
      return;
    }
    case 'admin_auth_failed': {
      const attempts = integer(data.attempts) ?? 1;
      createAlert(ctx, {
        ...base,
        type: 'security_event',
        title: 'Tentativa de acesso à área do responsável',
        body: `Autenticação do responsável falhou no aparelho de ${child} (${attempts} tentativa${attempts === 1 ? '' : 's'}).`,
        data: { event: event.type, method: text(data.method), attempts, eventAt: event.ts },
        dedupeKey: 'admin_auth_failed',
        dedupeWindowMs: 5 * MINUTE_MS,
      });
      return;
    }
    case 'clock_changed': {
      const kind = text(data.kind) === 'timezone' ? 'O fuso horário' : 'A data ou a hora';
      createAlert(ctx, {
        ...base,
        type: 'security_event',
        title: 'Relógio do aparelho alterado',
        body: `${kind} do aparelho de ${child} foi alterado.`,
        data: { event: event.type, kind: text(data.kind), deltaMs: integer(data.deltaMs), timezone: text(data.timezone), eventAt: event.ts },
        dedupeKey: 'clock_changed',
        dedupeWindowMs: 5 * MINUTE_MS,
      });
      return;
    }
    case 'unlinked_locally': {
      createAlert(ctx, {
        ...base,
        type: 'security_event',
        title: 'Aparelho desvinculado localmente',
        body: `O controle parental foi desativado no próprio aparelho de ${child}.`,
        data: { event: event.type, method: text(data.method), eventAt: event.ts },
      });
      return;
    }
    case 'management_mode_changed': {
      const from = text(data.from);
      const to = text(data.to);
      createAlert(ctx, {
        ...base,
        type: 'security_event',
        title: 'Modo de gerenciamento alterado',
        body: `O aparelho de ${child} passou do modo ${MODE_TEXT[from] ?? from} para ${MODE_TEXT[to] ?? to}.`,
        data: { event: event.type, from, to, eventAt: event.ts },
      });
      return;
    }
    case 'app_installed': {
      if (!event.package) return;
      const label = text(data.label) || appLabel(ctx, device.id, event.package);
      const waiting = policy.apps.defaultForNewApps === 'blocked';
      createAlert(ctx, {
        ...base,
        type: 'new_app_installed',
        title: 'Novo app instalado',
        body: `${label} foi instalado no aparelho de ${child}.${waiting ? ' Ele fica bloqueado até você decidir.' : ''}`,
        data: { package: event.package, label, awaitingApproval: waiting, eventAt: event.ts },
      });
      return;
    }
    default:
      return;
  }
}

/** Sincronizacao do aparelho. Tudo e gravado em uma unica transacao. */
export function syncDevice(ctx: AppContext, device: DeviceRow, body: SyncBody, ip: string): SyncResponse {
  const now = ctx.now();
  const policy = readPolicy(device);
  const today = deviceToday(ctx, policy);
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', device.guardian_id);
  if (!guardian) throw errors.deviceRevoked();

  const ack = { sessions: [] as string[], events: [] as string[], browsing: [] as string[], days: [] as string[] };
  let currentDay: UsageDayRow | null = null;
  let unlinkedLocally: SyncBody['events'][number] | null = null;
  const appliedVersion = body.policyVersion <= device.policy_version ? body.policyVersion : device.applied_policy_version;
  const appliedChanged = appliedVersion !== device.applied_policy_version;

  ctx.db.transaction(() => {
    body.days.forEach((day, index) => {
      const isCurrent = index === body.days.length - 1;
      // Dia absurdo (relogio do aparelho errado) e descartado, mas confirmado para nao ser reenviado.
      const plausible = diffDays(today, day.day) <= 2 && diffDays(day.day, today) <= 400;
      if (plausible) {
        const stored = upsertDay(ctx, device.id, day);
        if (isCurrent) currentDay = stored;
      }
      if (!isCurrent) ack.days.push(day.day);
    });

    for (const session of body.sessions) {
      ack.sessions.push(session.id);
      const duration = session.end - session.start;
      if (duration < 0 || duration > DAY_MS) continue;
      ctx.db.run(
        `INSERT OR IGNORE INTO usage_sessions (device_id, client_id, package, start_ms, end_ms, duration_ms, day, tz_offset_min, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        device.id,
        session.id,
        session.package,
        session.start,
        session.end,
        duration,
        session.day,
        session.tzOffsetMin,
        now,
      );
    }

    for (const event of body.events) {
      ack.events.push(event.id);
      const json = JSON.stringify(event.data);
      if (json.length > 8000) continue;
      const inserted = ctx.db.run(
        `INSERT OR IGNORE INTO events (device_id, client_id, type, ts, day, package, data_enc, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        device.id,
        event.id,
        event.type,
        event.ts,
        quotaDayOf(event.ts, policy.timezone, policy.dailyLimit.resetTime),
        event.package,
        ctx.cipher.encrypt(json, 'events.data'),
        now,
      );
      // Reenvio do mesmo evento nao repete alertas nem pedidos.
      if (inserted.changes > 0) {
        handleNewEvent(ctx, device, policy, event);
        if (event.type === 'unlinked_locally') unlinkedLocally = event;
      }
    }

    for (const entry of body.browsing) {
      ack.browsing.push(entry.id);
      ctx.db.run(
        `INSERT OR IGNORE INTO browsing (device_id, client_id, ts, day, url_enc, domain, title_enc, blocked, reason, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        device.id,
        entry.id,
        entry.ts,
        quotaDayOf(entry.ts, policy.timezone, policy.dailyLimit.resetTime),
        ctx.cipher.encrypt(entry.url.slice(0, MAX_URL_CHARS), 'browsing.url'),
        entry.domain.slice(0, MAX_DOMAIN_CHARS),
        ctx.cipher.encryptNullable(entry.title === null ? null : entry.title.slice(0, MAX_TITLE_CHARS), 'browsing.title'),
        entry.blocked ? 1 : 0,
        entry.reason,
        now,
      );
    }

    const day = currentDay as UsageDayRow | null;
    const state: Record<string, unknown> = { ...body.status, reportedAt: now };
    if (day) {
      state.day = day.day;
      state.quotaUsedMs = day.quota_ms;
      state.totalUsedMs = day.total_ms;
      state.limitMs = day.limit_ms;
      state.extraMs = day.extra_ms;
      state.remainingMs = day.limit_ms === null ? null : Math.max(0, day.limit_ms - day.quota_ms);
      state.limitReachedAt = day.limit_reached_at;
    } else {
      state.day = null;
      state.quotaUsedMs = 0;
      state.totalUsedMs = 0;
      state.limitMs = null;
      state.extraMs = 0;
      state.remainingMs = null;
      state.limitReachedAt = null;
    }

    ctx.db.run(
      `UPDATE devices SET last_sync_at = ?, last_ip = ?, management_mode = ?, app_version = ?, sdk_int = ?, timezone = ?,
         applied_policy_version = ?, policy_applied_at = ?, state = ? WHERE id = ?`,
      now,
      ip,
      body.status.managementMode,
      body.status.appVersion,
      body.status.sdkInt,
      body.status.timezone,
      appliedVersion,
      body.policyAppliedAt ?? device.policy_applied_at,
      JSON.stringify(state),
      device.id,
    );
  });

  expireTimeRequests(ctx);
  const requests = ctx.db.all<TimeRequestRow>(
    'SELECT * FROM time_requests WHERE device_id = ? AND created_at > ? ORDER BY created_at DESC LIMIT 50',
    device.id,
    now - DAY_MS,
  );

  ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id });
  if (appliedChanged && appliedVersion === device.policy_version) {
    ctx.hub.toGuardian(device.guardian_id, { type: 'policy_applied', deviceId: device.id, version: appliedVersion });
  }

  // O aparelho avisou, na ultima sincronizacao dele, que o responsavel o desvinculou no proprio
  // aparelho sem conexao com o servidor (codigo de acesso offline). O controle ja nao vale la,
  // entao o cadastro passa a revogado: o painel nao deve mostrar como ativo um aparelho que
  // deixou de aplicar as regras. O historico e a politica ficam, para uma nova vinculacao.
  const unlinkEvent = unlinkedLocally as SyncBody['events'][number] | null;
  if (unlinkEvent && device.status === 'active') {
    revokeDevice(ctx, device);
    audit(ctx, {
      guardianId: device.guardian_id,
      action: 'device.unlink',
      summary: `${device.child_name} (${device.device_name}) desvinculado no próprio aparelho, com o código de acesso offline`,
      targetType: 'device',
      targetId: device.id,
      ip,
      origin: device.device_name,
    });
  }

  const reconcileDay = currentDay as UsageDayRow | null;
  return {
    serverTime: now,
    policyVersion: device.policy_version,
    policy: body.policyVersion === device.policy_version ? null : policy,
    ack,
    reconcile: reconcileDay
      ? { day: reconcileDay.day, quotaUsedMs: reconcileDay.quota_ms, totalUsedMs: reconcileDay.total_ms }
      : null,
    timeRequests: requests.map((row) => ({
      id: row.id,
      status: row.status,
      grantedMinutes: row.granted_minutes,
      resolvedAt: row.resolved_at,
    })),
    childName: device.child_name,
    guardianName: guardian.display_name,
    lowTimeMinutes: readSettings(guardian).lowTimeMinutes,
    needAppInventory: device.inventory_at === null || now - device.inventory_at > INVENTORY_MAX_AGE_MS,
  };
}

const inventoryApp = v.object({
  package: packageName,
  // Nome vazio e aceito e trocado pelo nome do pacote em `putInventory`.
  label: v.string({ max: 2000 }),
  category: v.string({ max: 200 }),
  system: v.bool(),
  launchable: v.bool(),
  essential: v.withDefault(v.bool(), false),
  versionName: v.nullable(v.string({ max: 80 })),
  installedAt: v.nullable(instant),
  updatedAt: v.nullable(instant),
  iconHash: v.nullable(v.string({ min: 8, max: 64, pattern: /^[0-9a-fA-F]+$/, lower: true })),
});

const inventoryParser = v.object({
  full: v.withDefault(v.bool(), false),
  apps: v.array(inventoryApp, { max: MAX_INVENTORY }),
});

export function parseInventoryBody(body: unknown): ReturnType<typeof inventoryParser> {
  if (isPlainObject(body) && Array.isArray(body.apps) && body.apps.length > MAX_INVENTORY) {
    throw errors.payloadTooLarge(`O inventário aceita no máximo ${MAX_INVENTORY} apps por envio.`);
  }
  const issues: FieldIssue[] = [];
  const parsed = inventoryParser(body, '', issues);
  if (issues.length > 0) {
    throw new ApiError('validation_error', 'Inventário inválido.', { fields: issues.map((issue) => issue.field), issues });
  }
  return parsed;
}

/** Grava o inventario. Com `full`, o que nao veio na lista e marcado como removido. */
export function putInventory(
  ctx: AppContext,
  device: DeviceRow,
  body: ReturnType<typeof inventoryParser>,
): { needIcons: string[] } {
  const now = ctx.now();
  const categories: readonly string[] = APP_CATEGORIES;
  ctx.db.transaction(() => {
    const received = new Set<string>();
    for (const app of body.apps) {
      received.add(app.package);
      ctx.db.run(
        `INSERT INTO apps (device_id, package, label, category, is_system, launchable, essential, version_name, installed_at, updated_at, icon_hash, removed_at, seen_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
         ON CONFLICT(device_id, package) DO UPDATE SET
           label = excluded.label, category = excluded.category, is_system = excluded.is_system,
           launchable = excluded.launchable, essential = excluded.essential, version_name = excluded.version_name,
           installed_at = excluded.installed_at, updated_at = excluded.updated_at, icon_hash = excluded.icon_hash,
           removed_at = NULL, seen_at = excluded.seen_at`,
        device.id,
        app.package,
        app.label === '' ? app.package : app.label.slice(0, 200),
        categories.includes(app.category) ? app.category : 'other',
        app.system ? 1 : 0,
        app.launchable ? 1 : 0,
        app.essential ? 1 : 0,
        app.versionName,
        app.installedAt,
        app.updatedAt,
        app.iconHash,
        now,
      );
    }
    if (body.full) {
      const known = ctx.db.all<{ package: string }>(
        'SELECT package FROM apps WHERE device_id = ? AND removed_at IS NULL',
        device.id,
      );
      for (const row of known) {
        if (received.has(row.package)) continue;
        ctx.db.run('UPDATE apps SET removed_at = ? WHERE device_id = ? AND package = ?', now, device.id, row.package);
      }
    }
    ctx.db.run('UPDATE devices SET inventory_at = ? WHERE id = ?', now, device.id);
  });
  const need = ctx.db.all<{ package: string }>(
    `SELECT package FROM apps WHERE device_id = ? AND removed_at IS NULL AND icon_hash IS NOT NULL
       AND (icon_stored_hash IS NULL OR icon_stored_hash <> icon_hash) ORDER BY package`,
    device.id,
  );
  ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id });
  return { needIcons: need.map((row) => row.package) };
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

export function putIcon(ctx: AppContext, device: DeviceRow, pkg: string, hash: string | undefined, image: Buffer): void {
  if (image.length > MAX_ICON_BYTES) throw errors.payloadTooLarge('O ícone aceita no máximo 64 KiB.');
  if (image.length < PNG_SIGNATURE.length || !image.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)) {
    throw fieldError('body', 'O ícone precisa ser uma imagem PNG.');
  }
  if (hash !== undefined && !/^[0-9a-fA-F]{8,64}$/.test(hash)) throw fieldError('hash', 'Hash inválido.');
  const row = ctx.db.get<{ icon_hash: string | null }>(
    'SELECT icon_hash FROM apps WHERE device_id = ? AND package = ?',
    device.id,
    pkg,
  );
  if (!row) throw errors.notFound('App não encontrado no inventário deste aparelho.');
  const stored = (hash ?? row.icon_hash)?.toLowerCase();
  if (!stored) throw fieldError('hash', 'Informe o hash do ícone.');
  ctx.db.run(
    'UPDATE apps SET icon = ?, icon_stored_hash = ? WHERE device_id = ? AND package = ?',
    image,
    stored,
    device.id,
    pkg,
  );
}

function adminLockMinutes(failures: number): number {
  return Math.min(60, 5 * 2 ** Math.min(failures - 5, 4));
}

/**
 * Confere a senha administrativa a pedido do aparelho da crianca. O contador e do aparelho e
 * nao afeta a conta: 5 falhas bloqueiam por 5 minutos, dobrando ate 60 (protocolo 2.3).
 */
export async function verifyAdminOnDevice(ctx: AppContext, device: DeviceRow, password: string, ip: string): Promise<void> {
  const now = ctx.now();
  if (device.admin_locked_until > now) {
    throw errors.accountLocked(Math.max(1, Math.ceil((device.admin_locked_until - now) / 1000)));
  }
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', device.guardian_id);
  if (!guardian) throw errors.deviceRevoked();

  if (await verifyPassword(password, guardian.password_hash)) {
    if (device.admin_failures !== 0 || device.admin_locked_until !== 0) {
      ctx.db.run('UPDATE devices SET admin_failures = 0, admin_locked_until = 0 WHERE id = ?', device.id);
    }
    return;
  }

  const row = ctx.db.get<{ admin_failures: number }>(
    'UPDATE devices SET admin_failures = admin_failures + 1 WHERE id = ? RETURNING admin_failures',
    device.id,
  );
  const failures = row?.admin_failures ?? 1;
  audit(ctx, {
    guardianId: device.guardian_id,
    action: 'device.admin_verify_failed',
    summary: `Senha administrativa incorreta no aparelho de ${device.child_name} (${failures} tentativa${failures === 1 ? '' : 's'})`,
    targetType: 'device',
    targetId: device.id,
    ip,
    origin: device.device_name,
  });
  if (failures >= 5) {
    const minutes = adminLockMinutes(failures);
    ctx.db.run('UPDATE devices SET admin_locked_until = ? WHERE id = ?', now + minutes * MINUTE_MS, device.id);
    createAlert(ctx, {
      guardianId: device.guardian_id,
      type: 'security_event',
      deviceId: device.id,
      childName: device.child_name,
      title: 'Tentativas de senha no aparelho',
      body: `A senha administrativa foi digitada errada ${failures} vezes no aparelho de ${device.child_name}. Novas tentativas ficam bloqueadas por ${formatMinutes(minutes)}.`,
      data: { event: 'admin_verify_locked', attempts: failures, lockMinutes: minutes },
    });
  }
  throw errors.invalidCredentials('Senha incorreta.', { attemptsLeft: Math.max(0, 5 - failures) });
}

/** Desvinculo pedido no proprio aparelho, com a senha administrativa. */
export async function unlinkFromDevice(ctx: AppContext, device: DeviceRow, password: string, ip: string): Promise<void> {
  await verifyAdminOnDevice(ctx, device, password, ip);
  revokeDevice(ctx, device);
  audit(ctx, {
    guardianId: device.guardian_id,
    action: 'device.unlink',
    summary: `${device.child_name} (${device.device_name}) desvinculado no próprio aparelho, com a senha administrativa`,
    targetType: 'device',
    targetId: device.id,
    ip,
    origin: device.device_name,
  });
  createAlert(ctx, {
    guardianId: device.guardian_id,
    type: 'device_linked',
    deviceId: device.id,
    childName: device.child_name,
    title: 'Vínculo removido',
    body: `${device.child_name} (${device.device_name}) foi desvinculado no próprio aparelho, com a senha administrativa.`,
    data: { status: 'revoked', origin: 'device' },
  });
}
