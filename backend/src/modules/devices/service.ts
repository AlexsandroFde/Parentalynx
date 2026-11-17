// Aparelhos vinculados: leitura para o painel, politica versionada, comandos e exclusoes.

import { randomUUID } from 'node:crypto';

import type { AppContext } from '../../context.ts';
import { errors } from '../../core/errors.ts';
import { formatMinutes } from '../../core/format.ts';
import { addDays, isValidTimeZone, MINUTE_MS, quotaDayOf } from '../../core/time.ts';
import { isPlainObject } from '../../core/validate.ts';
import type { AppRow, DeviceRow, LinkRow, SessionRow, TimeRequestRow } from '../../db/rows.ts';
import { createAlert } from '../alerts/service.ts';
import type { GuardianAuth } from '../auth/guard.ts';
import { audit } from '../guardian/audit.ts';
import { parseStoredPolicy, pruneExtraTime, resolveRule } from '../policy/schema.ts';
import type { Overrides, Policy, SuspensionScope } from '../policy/schema.ts';

const ONLINE_WINDOW_MS = 2 * MINUTE_MS;
const POLICY_ALERT_WINDOW_MS = 10 * MINUTE_MS;

export interface DeviceJson {
  id: string;
  status: 'pending' | 'active' | 'revoked';
  childName: string | null;
  deviceName: string;
  model: string;
  manufacturer: string;
  androidRelease: string;
  sdkInt: number;
  appVersion: string;
  timezone: string;
  confirmCode?: string;
  relink?: boolean;
  createdAt: number;
  approvedAt: number | null;
  revokedAt: number | null;
  lastSyncAt: number | null;
  online: boolean;
  today: string;
  managementMode: string;
  policyVersion: number;
  appliedPolicyVersion: number;
  policyAppliedAt: number | null;
  pendingTimeRequests: number;
  state: Record<string, unknown> | null;
}

export function readPolicy(device: DeviceRow): Policy {
  return parseStoredPolicy(device.policy);
}

/** Dia da cota corrente do aparelho, no fuso e no horario de reinicio da politica. */
export function deviceToday(ctx: AppContext, policy: Policy): string {
  return quotaDayOf(ctx.now(), policy.timezone, policy.dailyLimit.resetTime);
}

function parseState(json: string | null): Record<string, unknown> | null {
  if (json === null) return null;
  const parsed: unknown = JSON.parse(json);
  return isPlainObject(parsed) ? parsed : null;
}

export function deviceJson(ctx: AppContext, device: DeviceRow): DeviceJson {
  const now = ctx.now();
  const policy = readPolicy(device);
  const pending = ctx.db.get<{ total: number }>(
    `SELECT COUNT(*) AS total FROM time_requests WHERE device_id = ? AND status = 'pending'`,
    device.id,
  );
  const recentlySynced = device.last_sync_at !== null && now - device.last_sync_at < ONLINE_WINDOW_MS;
  return {
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
    online: device.status === 'active' && (ctx.hub.isDeviceOnline(device.id) || recentlySynced),
    today: deviceToday(ctx, policy),
    managementMode: device.management_mode,
    policyVersion: device.policy_version,
    appliedPolicyVersion: device.applied_policy_version,
    policyAppliedAt: device.policy_applied_at,
    pendingTimeRequests: pending?.total ?? 0,
    state: parseState(device.state),
  };
}

/** Pedido de vinculo aguardando aprovacao, no formato de aparelho pendente. */
export function pendingDeviceJson(ctx: AppContext, link: LinkRow): DeviceJson {
  const timezone = isValidTimeZone(link.timezone) ? link.timezone : 'UTC';
  return {
    id: link.id,
    status: 'pending',
    childName: null,
    deviceName: link.device_name,
    model: link.model,
    manufacturer: link.manufacturer,
    androidRelease: link.android_release,
    sdkInt: link.sdk_int,
    appVersion: link.app_version,
    timezone: link.timezone,
    confirmCode: link.confirm_code,
    relink: link.relink_device_id !== null,
    createdAt: link.created_at,
    approvedAt: null,
    revokedAt: null,
    lastSyncAt: null,
    online: false,
    today: quotaDayOf(ctx.now(), timezone, '00:00'),
    managementMode: 'standard',
    policyVersion: 0,
    appliedPolicyVersion: 0,
    policyAppliedAt: null,
    pendingTimeRequests: 0,
    state: null,
  };
}

/** Marca como vencidos os pedidos de vinculo que passaram do prazo. */
export function expireLinks(ctx: AppContext): number {
  const now = ctx.now();
  return ctx.db.run(
    `UPDATE links SET status = 'expired', resolved_at = ? WHERE status = 'pending' AND expires_at <= ?`,
    now,
    now,
  ).changes;
}

export function pendingLinks(ctx: AppContext, guardianId: string): LinkRow[] {
  expireLinks(ctx);
  return ctx.db.all<LinkRow>(
    `SELECT * FROM links WHERE guardian_id = ? AND status = 'pending' ORDER BY created_at DESC`,
    guardianId,
  );
}

/** Pendentes primeiro, depois ativos por nome da crianca, depois revogados. */
export function listDevices(ctx: AppContext, guardianId: string): DeviceJson[] {
  const pending = pendingLinks(ctx, guardianId).map((link) => pendingDeviceJson(ctx, link));
  const devices = ctx.db
    .all<DeviceRow>(
      `SELECT * FROM devices WHERE guardian_id = ?
       ORDER BY CASE status WHEN 'active' THEN 0 ELSE 1 END, child_name COLLATE NOCASE, created_at`,
      guardianId,
    )
    .map((device) => deviceJson(ctx, device));
  return [...pending, ...devices];
}

export function requireActive(device: DeviceRow): void {
  if (device.status !== 'active') {
    throw errors.conflict('Este aparelho não está mais vinculado.');
  }
}

/** Grava uma nova versao da politica e atualiza a linha em memoria. */
export function writePolicy(ctx: AppContext, device: DeviceRow, policy: Policy): number {
  const version = device.policy_version + 1;
  const json = JSON.stringify(policy);
  const now = ctx.now();
  ctx.db.run(
    'UPDATE devices SET policy = ?, policy_version = ?, policy_updated_at = ? WHERE id = ?',
    json,
    version,
    now,
    device.id,
  );
  device.policy = json;
  device.policy_version = version;
  device.policy_updated_at = now;
  return version;
}

export interface PolicyChangeNotice {
  action: string;
  summary: string;
  /** Sessao que fez a mudanca, ou nulo quando veio do proprio servidor. */
  session: SessionRow | null;
  ip?: string | null;
  /** Motivo enviado ao aparelho em `sync_now`. */
  reason?: string;
}

/**
 * Efeitos de uma nova versao da politica: auditoria, aviso ao aparelho para sincronizar, aviso
 * aos outros paineis e alerta `policy_changed` para as outras sessoes da conta.
 */
export function announcePolicyChange(ctx: AppContext, device: DeviceRow, notice: PolicyChangeNotice): void {
  audit(ctx, {
    guardianId: device.guardian_id,
    action: notice.action,
    summary: notice.summary,
    session: notice.session,
    targetType: 'device',
    targetId: device.id,
    ip: notice.ip ?? null,
  });
  ctx.hub.toDevice(device.id, { type: 'sync_now', reason: notice.reason ?? 'policy' });
  ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id }, notice.session?.id ?? null);

  if (!notice.session) return;
  const others = ctx.db.get<{ total: number }>(
    `SELECT COUNT(*) AS total FROM sessions WHERE guardian_id = ? AND id <> ? AND revoked_at IS NULL AND expires_at > ?`,
    device.guardian_id,
    notice.session.id,
    ctx.now(),
  );
  if ((others?.total ?? 0) === 0) return;
  createAlert(ctx, {
    guardianId: device.guardian_id,
    type: 'policy_changed',
    deviceId: device.id,
    childName: device.child_name,
    title: 'Regras alteradas',
    body: `As regras de ${device.child_name} foram alteradas em ${notice.session.device_name}.`,
    data: { action: notice.action, summary: notice.summary, sessionId: notice.session.id },
    originSessionId: notice.session.id,
    dedupeKey: notice.session.id,
    dedupeWindowMs: POLICY_ALERT_WINDOW_MS,
  });
}

/** Aplica uma mudanca em `overrides`, cria nova versao e devolve a politica resultante. */
export function updateOverrides(
  ctx: AppContext,
  device: DeviceRow,
  mutate: (overrides: Overrides, today: string) => Overrides,
): Policy {
  const policy = readPolicy(device);
  const today = deviceToday(ctx, policy);
  const next: Policy = { ...policy, overrides: pruneExtraTime(mutate(policy.overrides, today), today) };
  writePolicy(ctx, device, next);
  return next;
}

export function addExtraTime(ctx: AppContext, device: DeviceRow, minutes: number): Policy {
  return updateOverrides(ctx, device, (overrides, today) => ({
    ...overrides,
    extraTime: [...overrides.extraTime, { id: randomUUID(), day: today, minutes, grantedAt: ctx.now() }],
  }));
}

export function setManualLock(ctx: AppContext, device: DeviceRow, active: boolean, until: number | null): Policy {
  return updateOverrides(ctx, device, (overrides) => ({
    ...overrides,
    manualLock: active ? { active: true, until, setAt: ctx.now() } : { active: false, until: null, setAt: null },
  }));
}

export function setSuspension(
  ctx: AppContext,
  device: DeviceRow,
  minutes: number | null,
  scopes: SuspensionScope[],
): Policy {
  return updateOverrides(ctx, device, (overrides) => ({
    ...overrides,
    suspension:
      minutes === null
        ? { until: 0, scopes: [], setAt: null }
        : { until: ctx.now() + minutes * MINUTE_MS, scopes, setAt: ctx.now() },
  }));
}

/** Guarda o token revogado para continuar respondendo `device_revoked`. */
function tombstoneToken(ctx: AppContext, tokenHash: string | null): void {
  if (tokenHash === null) return;
  ctx.db.run('INSERT OR IGNORE INTO revoked_tokens (token_hash, revoked_at) VALUES (?, ?)', tokenHash, ctx.now());
}

/** Revoga o vinculo. O aparelho passa a receber `device_revoked` e desativa o controle. */
export function revokeDevice(ctx: AppContext, device: DeviceRow): void {
  ctx.db.transaction(() => {
    tombstoneToken(ctx, device.token_hash);
    ctx.db.run(
      `UPDATE devices SET status = 'revoked', revoked_at = ?, token_hash = NULL WHERE id = ?`,
      ctx.now(),
      device.id,
    );
    ctx.db.run(
      `UPDATE time_requests SET status = 'expired', resolved_at = ? WHERE device_id = ? AND status = 'pending'`,
      ctx.now(),
      device.id,
    );
  });
  device.status = 'revoked';
  device.token_hash = null;
  ctx.hub.revokeDevice(device.id);
  ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id });
}

const HISTORY_TABLES = ['usage_day', 'usage_app', 'usage_sessions', 'events', 'browsing', 'time_requests'] as const;

/** Apaga o historico de uso do aparelho, mantendo o vinculo, a politica e o inventario. */
export function deleteDeviceData(ctx: AppContext, device: DeviceRow): void {
  ctx.db.transaction(() => {
    for (const table of HISTORY_TABLES) {
      ctx.db.run(`DELETE FROM ${table} WHERE device_id = ?`, device.id);
    }
    ctx.db.run('DELETE FROM alerts WHERE guardian_id = ? AND device_id = ?', device.guardian_id, device.id);
    ctx.db.run('UPDATE devices SET state = NULL WHERE id = ?', device.id);
  });
  ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id });
}

/** Apaga o aparelho e tudo o que pertence a ele. */
export function deleteDevice(ctx: AppContext, device: DeviceRow): void {
  ctx.db.transaction(() => {
    tombstoneToken(ctx, device.token_hash);
    ctx.db.run('DELETE FROM alerts WHERE guardian_id = ? AND device_id = ?', device.guardian_id, device.id);
    // Um pedido pendente que reaproveitaria este cadastro passa a criar um aparelho novo.
    ctx.db.run('UPDATE links SET relink_device_id = NULL WHERE relink_device_id = ?', device.id);
    ctx.db.run('DELETE FROM links WHERE device_id = ?', device.id);
    ctx.db.run('DELETE FROM devices WHERE id = ?', device.id);
  });
  ctx.hub.revokeDevice(device.id);
  ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id });
}

export interface AppEntryJson {
  package: string;
  label: string;
  category: string;
  system: boolean;
  launchable: boolean;
  essential: boolean;
  versionName: string | null;
  installedAt: number | null;
  updatedAt: number | null;
  iconHash: string | null;
  iconUrl: string | null;
  state: string;
  countsTowardLimit: boolean;
  dailyLimitMinutes: number | null;
  todayMs: number;
  weekMs: number;
  removed: boolean;
}

const APP_COLUMNS =
  'device_id, package, label, category, is_system, launchable, essential, version_name, installed_at, updated_at, icon_hash, icon_stored_hash, removed_at, seen_at';

export function listAppRows(ctx: AppContext, deviceId: string): AppRow[] {
  return ctx.db.all<AppRow>(
    `SELECT ${APP_COLUMNS} FROM apps WHERE device_id = ? ORDER BY label COLLATE NOCASE, package`,
    deviceId,
  );
}

/** Inventario do aparelho com o estado da regra e o uso de hoje e dos ultimos 7 dias. */
export function listApps(ctx: AppContext, device: DeviceRow): { day: string; apps: AppEntryJson[] } {
  const policy = readPolicy(device);
  const day = deviceToday(ctx, policy);
  const today = new Map(
    ctx.db
      .all<{ package: string; ms: number }>('SELECT package, ms FROM usage_app WHERE device_id = ? AND day = ?', device.id, day)
      .map((row) => [row.package, row.ms]),
  );
  const week = new Map(
    ctx.db
      .all<{ package: string; ms: number }>(
        'SELECT package, SUM(ms) AS ms FROM usage_app WHERE device_id = ? AND day BETWEEN ? AND ? GROUP BY package',
        device.id,
        addDays(day, -6),
        day,
      )
      .map((row) => [row.package, row.ms]),
  );
  const apps = listAppRows(ctx, device.id).map((row): AppEntryJson => {
    const rule = resolveRule(policy, row.package, row.is_system === 1);
    const hasIcon = row.icon_stored_hash !== null;
    return {
      package: row.package,
      label: row.label,
      category: row.category,
      system: row.is_system === 1,
      launchable: row.launchable === 1,
      essential: row.essential === 1,
      versionName: row.version_name,
      installedAt: row.installed_at,
      updatedAt: row.updated_at,
      iconHash: row.icon_stored_hash,
      iconUrl: hasIcon
        ? `/v1/guardian/devices/${device.id}/apps/icon?package=${encodeURIComponent(row.package)}&v=${encodeURIComponent(row.icon_stored_hash ?? '')}`
        : null,
      // Pacote essencial nunca e bloqueado pelo aparelho, qualquer que seja a regra.
      state: row.essential === 1 ? 'allowed' : rule.state,
      countsTowardLimit: row.essential === 1 ? false : rule.countsTowardLimit,
      dailyLimitMinutes: row.essential === 1 ? null : rule.dailyLimitMinutes,
      todayMs: today.get(row.package) ?? 0,
      weekMs: week.get(row.package) ?? 0,
      removed: row.removed_at !== null,
    };
  });
  return { day, apps };
}

/** Nome do app no inventario, ou o proprio nome do pacote. */
export function appLabel(ctx: AppContext, deviceId: string, packageName: string): string {
  const row = ctx.db.get<{ label: string }>(
    'SELECT label FROM apps WHERE device_id = ? AND package = ?',
    deviceId,
    packageName,
  );
  return row?.label ?? packageName;
}

export interface TimeRequestJson {
  id: string;
  deviceId: string;
  childName: string;
  createdAt: number;
  minutes: number | null;
  message: string | null;
  status: string;
  grantedMinutes: number | null;
  resolvedAt: number | null;
}

export function timeRequestJson(ctx: AppContext, row: TimeRequestRow, childName: string): TimeRequestJson {
  return {
    id: row.id,
    deviceId: row.device_id,
    childName,
    createdAt: row.created_at,
    minutes: row.minutes,
    message: ctx.cipher.decryptNullable(row.message_enc, 'time_requests.message'),
    status: row.status,
    grantedMinutes: row.granted_minutes,
    resolvedAt: row.resolved_at,
  };
}

/** Pedidos pendentes ha mais de 24 horas passam a `expired`. */
export function expireTimeRequests(ctx: AppContext): number {
  const now = ctx.now();
  return ctx.db.run(
    `UPDATE time_requests SET status = 'expired', resolved_at = ? WHERE status = 'pending' AND created_at <= ?`,
    now,
    now - 24 * 60 * MINUTE_MS,
  ).changes;
}

export function listTimeRequests(ctx: AppContext, device: DeviceRow, status: string | undefined): TimeRequestJson[] {
  expireTimeRequests(ctx);
  const rows =
    status === undefined
      ? ctx.db.all<TimeRequestRow>(
          'SELECT * FROM time_requests WHERE device_id = ? ORDER BY created_at DESC LIMIT 200',
          device.id,
        )
      : ctx.db.all<TimeRequestRow>(
          'SELECT * FROM time_requests WHERE device_id = ? AND status = ? ORDER BY created_at DESC LIMIT 200',
          device.id,
          status,
        );
  return rows.map((row) => timeRequestJson(ctx, row, device.child_name));
}

/**
 * Resolve um pedido de tempo. Aprovar soma os minutos ao tempo extra do dia corrente e cria
 * nova versao da politica. Negar nao altera a politica, mas avisa o aparelho para sincronizar.
 */
export function resolveTimeRequest(
  ctx: AppContext,
  auth: GuardianAuth,
  requestId: string,
  action: 'approve' | 'deny',
  minutes: number | undefined,
  ip: string,
): { request: TimeRequestJson; policyVersion: number } {
  expireTimeRequests(ctx);
  const row = ctx.db.get<TimeRequestRow>('SELECT * FROM time_requests WHERE id = ?', requestId);
  if (!row) throw errors.notFound('Pedido não encontrado.');
  const device = ctx.db.get<DeviceRow>('SELECT * FROM devices WHERE id = ?', row.device_id);
  if (!device) throw errors.notFound('Pedido não encontrado.');
  if (device.guardian_id !== auth.guardian.id) throw errors.forbidden();
  if (row.status !== 'pending') throw errors.conflict('Este pedido já foi resolvido ou expirou.', { status: row.status });
  requireActive(device);

  const now = ctx.now();
  const granted = action === 'approve' ? (minutes ?? row.minutes ?? 15) : null;
  ctx.db.transaction(() => {
    ctx.db.run(
      'UPDATE time_requests SET status = ?, granted_minutes = ?, resolved_at = ?, resolved_by_session = ? WHERE id = ?',
      action === 'approve' ? 'approved' : 'denied',
      granted,
      now,
      auth.session.id,
      row.id,
    );
    if (granted !== null) addExtraTime(ctx, device, granted);
  });

  const summary =
    granted !== null
      ? `Pedido de tempo de ${device.child_name} aprovado: mais ${formatMinutes(granted)}`
      : `Pedido de tempo de ${device.child_name} negado`;
  if (granted !== null) {
    announcePolicyChange(ctx, device, {
      action: 'time_request.approve',
      summary,
      session: auth.session,
      ip,
      reason: 'time_request',
    });
  } else {
    audit(ctx, {
      guardianId: device.guardian_id,
      action: 'time_request.deny',
      summary,
      session: auth.session,
      targetType: 'device',
      targetId: device.id,
      ip,
    });
    ctx.hub.toDevice(device.id, { type: 'sync_now', reason: 'time_request' });
    ctx.hub.toGuardian(device.guardian_id, { type: 'device_updated', deviceId: device.id }, auth.session.id);
  }

  const updated = ctx.db.get<TimeRequestRow>('SELECT * FROM time_requests WHERE id = ?', row.id);
  return {
    request: timeRequestJson(ctx, updated ?? row, device.child_name),
    policyVersion: device.policy_version,
  };
}
