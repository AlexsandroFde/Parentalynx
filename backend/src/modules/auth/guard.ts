// Autenticacao por token e verificacao de elevacao (protocolo 1 e 2.2).

import type { FastifyRequest } from 'fastify';

import type { AppContext } from '../../context.ts';
import { sha256Hex } from '../../core/crypto.ts';
import { errors } from '../../core/errors.ts';
import { DAY_MS, MINUTE_MS } from '../../core/time.ts';
import type { DeviceRow, GuardianRow, LinkRow, SessionRow } from '../../db/rows.ts';

export interface GuardianAuth {
  guardian: GuardianRow;
  session: SessionRow;
}

/** Extrai o token do cabecalho `Authorization: Bearer`. */
export function bearerToken(header: string | string[] | undefined): string | null {
  const value = Array.isArray(header) ? header[0] : header;
  if (!value) return null;
  const match = /^Bearer\s+(\S+)$/i.exec(value.trim());
  return match?.[1] ?? null;
}

export function clientIp(request: FastifyRequest): string {
  return request.ip || 'desconhecido';
}

/** Valida um token de sessao do responsavel. Usado por HTTP e por WebSocket. */
export function authGuardianToken(ctx: AppContext, token: string | null, ip?: string): GuardianAuth {
  if (!token || !token.startsWith('gs_')) throw errors.unauthorized();
  const session = ctx.db.get<SessionRow>('SELECT * FROM sessions WHERE token_hash = ?', sha256Hex(token));
  if (!session) throw errors.unauthorized();
  const now = ctx.now();
  if (session.revoked_at !== null || session.expires_at <= now) throw errors.sessionExpired();
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', session.guardian_id);
  if (!guardian) throw errors.unauthorized();

  // Validade deslizante: cada uso renova o prazo. A gravacao e limitada a uma por minuto.
  if (now - session.last_seen_at >= MINUTE_MS) {
    const expiresAt = now + ctx.config.sessionTtlDays * DAY_MS;
    ctx.db.run(
      'UPDATE sessions SET last_seen_at = ?, expires_at = ?, ip = COALESCE(?, ip) WHERE id = ?',
      now,
      expiresAt,
      ip ?? null,
      session.id,
    );
    session.last_seen_at = now;
    session.expires_at = expiresAt;
  }
  return { guardian, session };
}

export function authGuardian(ctx: AppContext, request: FastifyRequest): GuardianAuth {
  return authGuardianToken(ctx, bearerToken(request.headers.authorization), clientIp(request));
}

/** Rotas marcadas com (E): exigem senha confirmada recentemente. */
export function requireElevated(ctx: AppContext, auth: GuardianAuth): void {
  if (auth.session.elevated_until <= ctx.now()) throw errors.elevationRequired();
}

/** Valida um token de aparelho. Token revogado responde `device_revoked`. */
export function authDeviceToken(ctx: AppContext, token: string | null): DeviceRow {
  if (!token || !token.startsWith('dv_')) throw errors.unauthorized();
  const hash = sha256Hex(token);
  const device = ctx.db.get<DeviceRow>('SELECT * FROM devices WHERE token_hash = ?', hash);
  if (device) {
    if (device.status !== 'active') throw errors.deviceRevoked();
    return device;
  }
  const revoked = ctx.db.get<{ token_hash: string }>('SELECT token_hash FROM revoked_tokens WHERE token_hash = ?', hash);
  if (revoked) throw errors.deviceRevoked();
  throw errors.unauthorized();
}

export function authDevice(ctx: AppContext, request: FastifyRequest): DeviceRow {
  return authDeviceToken(ctx, bearerToken(request.headers.authorization));
}

/** Valida um token de consulta de vinculacao. */
export function authPollToken(ctx: AppContext, request: FastifyRequest): LinkRow {
  const token = bearerToken(request.headers.authorization);
  if (!token || !token.startsWith('pp_')) throw errors.unauthorized();
  const link = ctx.db.get<LinkRow>('SELECT * FROM links WHERE poll_token_hash = ?', sha256Hex(token));
  if (!link || link.status === 'delivered') throw errors.unauthorized();
  return link;
}

/**
 * Busca um aparelho e confere a posse. Um responsavel so enxerga os aparelhos da propria conta:
 * aparelho de outra conta responde `forbidden`, sem devolver nenhum dado dele.
 */
export function ownedDevice(ctx: AppContext, auth: GuardianAuth, deviceId: string): DeviceRow {
  const device = ctx.db.get<DeviceRow>('SELECT * FROM devices WHERE id = ?', deviceId);
  if (!device) throw errors.notFound('Aparelho não encontrado.');
  if (device.guardian_id !== auth.guardian.id) throw errors.forbidden();
  return device;
}
