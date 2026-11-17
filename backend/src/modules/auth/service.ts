// Contas, sessoes, protecao contra tentativas e recuperacao (protocolo, secao 2).

import { randomUUID } from 'node:crypto';

import type { AppContext } from '../../context.ts';
import { generateRecoveryKey, normalizeRecoveryKey } from '../../core/codes.ts';
import { newToken, safeEqual, sha256Hex } from '../../core/crypto.ts';
import { ApiError, errors } from '../../core/errors.ts';
import { assertStrongPassword } from '../../core/password-policy.ts';
import { burnPasswordTime, hashPassword, needsRehash, verifyPassword } from '../../core/passwords.ts';
import { DAY_MS, MINUTE_MS } from '../../core/time.ts';
import type { GuardianRow, SessionRow } from '../../db/rows.ts';
import { audit } from '../guardian/audit.ts';

export interface GuardianSettings {
  retentionDays: number;
  syncStaleMinutes: number;
  offlineHours: number;
  lowTimeMinutes: number;
}

export const DEFAULT_SETTINGS: GuardianSettings = {
  retentionDays: 90,
  syncStaleMinutes: 180,
  offlineHours: 24,
  lowTimeMinutes: 10,
};

export const SETTINGS_LIMITS: Record<keyof GuardianSettings, [number, number]> = {
  retentionDays: [30, 365],
  syncStaleMinutes: [30, 1440],
  offlineHours: [6, 168],
  lowTimeMinutes: [1, 60],
};

export const ALERT_TYPES = [
  'limit_reached',
  'low_time',
  'blocked_app_attempt',
  'sync_stale',
  'device_offline',
  'policy_changed',
  'enforcement_failure',
  'time_request',
  'permission_changed',
  'new_app_installed',
  'security_event',
  'device_linked',
] as const;

export type AlertType = (typeof ALERT_TYPES)[number];
export type NotificationPrefs = Record<AlertType, boolean>;

export function defaultNotificationPrefs(): NotificationPrefs {
  const prefs = {} as NotificationPrefs;
  for (const type of ALERT_TYPES) prefs[type] = true;
  return prefs;
}

export function readSettings(row: GuardianRow): GuardianSettings {
  const stored = JSON.parse(row.settings) as Partial<GuardianSettings>;
  return { ...DEFAULT_SETTINGS, ...stored };
}

export function readNotificationPrefs(row: GuardianRow): NotificationPrefs {
  const stored = JSON.parse(row.notification_prefs) as Partial<NotificationPrefs>;
  const prefs = defaultNotificationPrefs();
  for (const type of ALERT_TYPES) {
    if (typeof stored[type] === 'boolean') prefs[type] = stored[type];
  }
  return prefs;
}

export interface GuardianJson {
  id: string;
  email: string;
  displayName: string;
  createdAt: number;
  settings: GuardianSettings;
  notificationPrefs: NotificationPrefs;
}

export function guardianJson(row: GuardianRow): GuardianJson {
  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    createdAt: row.created_at,
    settings: readSettings(row),
    notificationPrefs: readNotificationPrefs(row),
  };
}

export interface SessionJson {
  id: string;
  deviceName: string;
  createdAt: number;
  lastSeenAt: number;
  expiresAt: number;
  elevatedUntil: number;
  current: boolean;
  token?: string;
}

export function sessionJson(row: SessionRow, currentSessionId: string | null, token?: string): SessionJson {
  const json: SessionJson = {
    id: row.id,
    deviceName: row.device_name,
    createdAt: row.created_at,
    lastSeenAt: row.last_seen_at,
    expiresAt: row.expires_at,
    elevatedUntil: row.elevated_until,
    current: row.id === currentSessionId,
  };
  if (token !== undefined) json.token = token;
  return json;
}

export function getGuardian(ctx: AppContext, guardianId: string): GuardianRow {
  const row = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', guardianId);
  if (!row) throw errors.unauthorized();
  return row;
}

/** Cria uma sessao ja elevada (registro, login e recuperacao provam a senha). */
export function createSession(
  ctx: AppContext,
  guardianId: string,
  deviceName: string,
  ip: string | null,
): { row: SessionRow; token: string } {
  const now = ctx.now();
  const token = newToken('gs_');
  const row: SessionRow = {
    id: randomUUID(),
    guardian_id: guardianId,
    token_hash: sha256Hex(token),
    device_name: deviceName,
    created_at: now,
    last_seen_at: now,
    expires_at: now + ctx.config.sessionTtlDays * DAY_MS,
    elevated_until: now + ctx.config.elevationMinutes * MINUTE_MS,
    revoked_at: null,
    ip,
  };
  ctx.db.run(
    `INSERT INTO sessions (id, guardian_id, token_hash, device_name, created_at, last_seen_at, expires_at, elevated_until, ip)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    row.id,
    row.guardian_id,
    row.token_hash,
    row.device_name,
    row.created_at,
    row.last_seen_at,
    row.expires_at,
    row.elevated_until,
    row.ip,
  );
  return { row, token };
}

/** Revoga sessoes da conta e fecha os WebSockets delas. Devolve quantas foram revogadas. */
export function revokeSessions(ctx: AppContext, guardianId: string, exceptSessionId: string | null): number {
  const result = ctx.db.run(
    'UPDATE sessions SET revoked_at = ? WHERE guardian_id = ? AND revoked_at IS NULL AND id <> ?',
    ctx.now(),
    guardianId,
    exceptSessionId ?? '',
  );
  ctx.hub.closeGuardian(guardianId, exceptSessionId);
  return result.changes;
}

export function revokeSession(ctx: AppContext, guardianId: string, sessionId: string): boolean {
  const result = ctx.db.run(
    'UPDATE sessions SET revoked_at = ? WHERE id = ? AND guardian_id = ? AND revoked_at IS NULL',
    ctx.now(),
    sessionId,
    guardianId,
  );
  ctx.hub.closeSession(guardianId, sessionId);
  return result.changes > 0;
}

function lockRemainingSec(lockedUntil: number, now: number): number {
  return Math.max(1, Math.ceil((lockedUntil - now) / 1000));
}

/** Registra uma senha errada. A partir de 5 seguidas: 1 minuto, dobrando ate 60. */
function recordPasswordFailure(ctx: AppContext, guardianId: string): void {
  const row = ctx.db.get<{ failed_logins: number }>(
    'UPDATE guardians SET failed_logins = failed_logins + 1 WHERE id = ? RETURNING failed_logins',
    guardianId,
  );
  const failures = row?.failed_logins ?? 0;
  if (failures < 5) return;
  const lockMinutes = Math.min(60, 2 ** Math.min(failures - 5, 6));
  ctx.db.run('UPDATE guardians SET locked_until = ? WHERE id = ?', ctx.now() + lockMinutes * MINUTE_MS, guardianId);
}

export interface PasswordCheckOrigin {
  /** Acao registrada na auditoria em caso de falha. */
  action: string;
  session?: SessionRow | null;
  ip?: string | null;
}

/**
 * Confere a senha administrativa com o contador por conta (login, elevacao e troca de senha).
 * Lanca `account_locked` durante o bloqueio e `invalid_credentials` em caso de erro.
 */
export async function assertPassword(
  ctx: AppContext,
  guardian: GuardianRow,
  password: string,
  origin: PasswordCheckOrigin,
): Promise<void> {
  const now = ctx.now();
  const fresh = getGuardian(ctx, guardian.id);
  if (fresh.locked_until > now) throw errors.accountLocked(lockRemainingSec(fresh.locked_until, now));

  const ok = await verifyPassword(password, fresh.password_hash);
  if (!ok) {
    recordPasswordFailure(ctx, guardian.id);
    audit(ctx, {
      guardianId: guardian.id,
      action: origin.action,
      summary: 'Senha administrativa incorreta',
      session: origin.session ?? null,
      targetType: 'guardian',
      targetId: guardian.id,
      ip: origin.ip ?? null,
    });
    throw errors.invalidCredentials('Senha incorreta.');
  }
  if (fresh.failed_logins !== 0 || fresh.locked_until !== 0) {
    ctx.db.run('UPDATE guardians SET failed_logins = 0, locked_until = 0 WHERE id = ?', guardian.id);
  }
  if (needsRehash(fresh.password_hash)) {
    const upgraded = await hashPassword(password);
    ctx.db.run('UPDATE guardians SET password_hash = ? WHERE id = ?', upgraded, guardian.id);
  }
}

export interface RegisterInput {
  email: string;
  displayName: string;
  password: string;
  deviceName: string;
}

export interface AuthResult {
  guardian: GuardianJson;
  session: SessionJson;
  recoveryKey?: string;
}

function hashRecoveryKey(key: string): string {
  const normalized = normalizeRecoveryKey(key);
  if (!normalized) throw new Error('Chave de recuperação gerada em formato inesperado.');
  return sha256Hex(normalized);
}

export async function register(ctx: AppContext, input: RegisterInput, ip: string): Promise<AuthResult> {
  assertStrongPassword(input.password, input.email, input.displayName);
  const existing = ctx.db.get<{ id: string }>('SELECT id FROM guardians WHERE email = ?', input.email);
  if (existing) throw new ApiError('email_in_use', 'Já existe uma conta com este e-mail.');

  const passwordHash = await hashPassword(input.password);
  const recoveryKey = generateRecoveryKey();
  const guardianId = randomUUID();
  const now = ctx.now();

  const created = ctx.db.transaction(() => {
    try {
      ctx.db.run(
        `INSERT INTO guardians (id, email, display_name, password_hash, recovery_key_hash, created_at, settings, notification_prefs)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        guardianId,
        input.email,
        input.displayName,
        passwordHash,
        hashRecoveryKey(recoveryKey),
        now,
        JSON.stringify(DEFAULT_SETTINGS),
        JSON.stringify(defaultNotificationPrefs()),
      );
    } catch (error) {
      // Corrida entre dois registros com o mesmo e-mail.
      if (error instanceof Error && /UNIQUE/i.test(error.message)) {
        throw new ApiError('email_in_use', 'Já existe uma conta com este e-mail.');
      }
      throw error;
    }
    const session = createSession(ctx, guardianId, input.deviceName, ip);
    audit(ctx, {
      guardianId,
      action: 'auth.register',
      summary: 'Conta criada',
      session: session.row,
      targetType: 'guardian',
      targetId: guardianId,
      ip,
    });
    return session;
  });

  return {
    guardian: guardianJson(getGuardian(ctx, guardianId)),
    session: sessionJson(created.row, created.row.id, created.token),
    recoveryKey,
  };
}

export async function login(
  ctx: AppContext,
  input: { email: string; password: string; deviceName: string },
  ip: string,
): Promise<AuthResult> {
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE email = ?', input.email);
  if (!guardian) {
    await burnPasswordTime(input.password);
    throw errors.invalidCredentials('E-mail ou senha incorretos.');
  }
  try {
    await assertPassword(ctx, guardian, input.password, { action: 'auth.login_failed', ip });
  } catch (error) {
    // A mesma mensagem para e-mail e senha errados, para nao revelar qual deles falhou.
    if (error instanceof ApiError && error.code === 'invalid_credentials') {
      throw errors.invalidCredentials('E-mail ou senha incorretos.');
    }
    throw error;
  }
  const session = ctx.db.transaction(() => {
    const created = createSession(ctx, guardian.id, input.deviceName, ip);
    audit(ctx, {
      guardianId: guardian.id,
      action: 'auth.login',
      summary: `Entrada em ${input.deviceName}`,
      session: created.row,
      targetType: 'session',
      targetId: created.row.id,
      ip,
    });
    return created;
  });
  return {
    guardian: guardianJson(getGuardian(ctx, guardian.id)),
    session: sessionJson(session.row, session.row.id, session.token),
  };
}

export async function recover(
  ctx: AppContext,
  input: { email: string; recoveryKey: string; newPassword: string; deviceName: string },
  ip: string,
): Promise<AuthResult> {
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE email = ?', input.email);
  if (!guardian) {
    await burnPasswordTime(input.newPassword);
    throw errors.invalidCredentials('E-mail ou chave de recuperação incorretos.');
  }
  const now = ctx.now();
  if (guardian.recovery_locked_until > now) {
    throw errors.accountLocked(lockRemainingSec(guardian.recovery_locked_until, now));
  }

  // A politica de senha e conferida antes da chave, para o erro nao indicar se a chave confere.
  assertStrongPassword(input.newPassword, guardian.email, guardian.display_name);

  const normalized = normalizeRecoveryKey(input.recoveryKey);
  const matches = normalized !== null && safeEqual(sha256Hex(normalized), guardian.recovery_key_hash);
  if (!matches) {
    const row = ctx.db.get<{ failed_recoveries: number }>(
      'UPDATE guardians SET failed_recoveries = failed_recoveries + 1 WHERE id = ? RETURNING failed_recoveries',
      guardian.id,
    );
    if ((row?.failed_recoveries ?? 0) >= 5) {
      ctx.db.run(
        'UPDATE guardians SET failed_recoveries = 0, recovery_locked_until = ? WHERE id = ?',
        now + 60 * MINUTE_MS,
        guardian.id,
      );
    }
    audit(ctx, {
      guardianId: guardian.id,
      action: 'auth.recover_failed',
      summary: 'Chave de recuperação incorreta',
      targetType: 'guardian',
      targetId: guardian.id,
      ip,
    });
    throw errors.invalidCredentials('E-mail ou chave de recuperação incorretos.');
  }

  const passwordHash = await hashPassword(input.newPassword);
  const recoveryKey = generateRecoveryKey();
  const session = ctx.db.transaction(() => {
    ctx.db.run(
      `UPDATE guardians SET password_hash = ?, recovery_key_hash = ?, failed_logins = 0, locked_until = 0,
         failed_recoveries = 0, recovery_locked_until = 0 WHERE id = ?`,
      passwordHash,
      hashRecoveryKey(recoveryKey),
      guardian.id,
    );
    const revoked = revokeSessions(ctx, guardian.id, null);
    const created = createSession(ctx, guardian.id, input.deviceName, ip);
    audit(ctx, {
      guardianId: guardian.id,
      action: 'auth.recover',
      summary: `Senha redefinida pela chave de recuperação. ${revoked} sessão(ões) revogada(s) e nova chave gerada`,
      session: created.row,
      targetType: 'guardian',
      targetId: guardian.id,
      ip,
    });
    return created;
  });

  return {
    guardian: guardianJson(getGuardian(ctx, guardian.id)),
    session: sessionJson(session.row, session.row.id, session.token),
    recoveryKey,
  };
}

export async function changePassword(
  ctx: AppContext,
  guardian: GuardianRow,
  session: SessionRow,
  currentPassword: string,
  newPassword: string,
  ip: string,
): Promise<void> {
  await assertPassword(ctx, guardian, currentPassword, { action: 'guardian.password_change_failed', session, ip });
  assertStrongPassword(newPassword, guardian.email, guardian.display_name);
  const passwordHash = await hashPassword(newPassword);
  ctx.db.transaction(() => {
    ctx.db.run('UPDATE guardians SET password_hash = ? WHERE id = ?', passwordHash, guardian.id);
    const revoked = revokeSessions(ctx, guardian.id, session.id);
    ctx.db.run(
      'UPDATE sessions SET elevated_until = ? WHERE id = ?',
      ctx.now() + ctx.config.elevationMinutes * MINUTE_MS,
      session.id,
    );
    audit(ctx, {
      guardianId: guardian.id,
      action: 'guardian.password_change',
      summary: `Senha administrativa alterada. ${revoked} outra(s) sessão(ões) revogada(s)`,
      session,
      targetType: 'guardian',
      targetId: guardian.id,
      ip,
    });
  });
}

export async function rotateRecoveryKey(
  ctx: AppContext,
  guardian: GuardianRow,
  session: SessionRow,
  password: string,
  ip: string,
): Promise<string> {
  await assertPassword(ctx, guardian, password, { action: 'guardian.recovery_key_failed', session, ip });
  const recoveryKey = generateRecoveryKey();
  ctx.db.run(
    'UPDATE guardians SET recovery_key_hash = ?, failed_recoveries = 0, recovery_locked_until = 0 WHERE id = ?',
    hashRecoveryKey(recoveryKey),
    guardian.id,
  );
  audit(ctx, {
    guardianId: guardian.id,
    action: 'guardian.recovery_key_rotate',
    summary: 'Nova chave de recuperação gerada',
    session,
    targetType: 'guardian',
    targetId: guardian.id,
    ip,
  });
  return recoveryKey;
}

export async function elevate(
  ctx: AppContext,
  guardian: GuardianRow,
  session: SessionRow,
  password: string,
  ip: string,
): Promise<number> {
  await assertPassword(ctx, guardian, password, { action: 'auth.elevate_failed', session, ip });
  const elevatedUntil = ctx.now() + ctx.config.elevationMinutes * MINUTE_MS;
  ctx.db.run('UPDATE sessions SET elevated_until = ? WHERE id = ?', elevatedUntil, session.id);
  return elevatedUntil;
}
