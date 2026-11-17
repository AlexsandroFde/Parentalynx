// Vinculacao entre responsavel e aparelho da crianca (protocolo, secao 3).

import { randomUUID } from 'node:crypto';

import type { AppContext } from '../../context.ts';
import { generateConfirmCode, generatePairingCode, normalizePairingCode } from '../../core/codes.ts';
import { newToken, sha256Hex } from '../../core/crypto.ts';
import { errors } from '../../core/errors.ts';
import { MINUTE_MS } from '../../core/time.ts';
import { generateOfflineSecret } from '../../core/totp.ts';
import type { DeviceRow, GuardianRow, LinkRow, PairingCodeRow } from '../../db/rows.ts';
import { createAlert } from '../alerts/service.ts';
import type { GuardianAuth } from '../auth/guard.ts';
import { deviceJson, expireLinks, readPolicy } from '../devices/service.ts';
import type { DeviceJson } from '../devices/service.ts';
import { audit } from '../guardian/audit.ts';
import { defaultPolicy } from '../policy/schema.ts';
import type { Policy } from '../policy/schema.ts';

export interface DeviceInfoInput {
  name: string;
  model: string;
  manufacturer: string;
  androidRelease: string;
  sdkInt: number;
  appVersion: string;
  timezone: string;
  hardwareId: string;
}

/** Gera um codigo novo. So existe um codigo ativo por conta: o anterior e invalidado. */
export function createPairingCode(
  ctx: AppContext,
  auth: GuardianAuth,
  ip: string,
): { id: string; code: string; expiresAt: number } {
  const now = ctx.now();
  const expiresAt = now + ctx.config.pairingCodeTtlMinutes * MINUTE_MS;
  const id = randomUUID();
  // Colisao de 40 bits entre codigos gravados e improvavel, mas o indice unico a detecta.
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = generatePairingCode();
    try {
      ctx.db.transaction(() => {
        ctx.db.run(
          `UPDATE pairing_codes SET invalidated_at = ? WHERE guardian_id = ? AND consumed_at IS NULL AND invalidated_at IS NULL`,
          now,
          auth.guardian.id,
        );
        ctx.db.run(
          'INSERT INTO pairing_codes (id, guardian_id, code_hash, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',
          id,
          auth.guardian.id,
          sha256Hex(code),
          now,
          expiresAt,
        );
        audit(ctx, {
          guardianId: auth.guardian.id,
          action: 'pairing.code_create',
          summary: 'Código de vinculação gerado',
          session: auth.session,
          targetType: 'pairing',
          targetId: id,
          ip,
        });
      });
      return { id, code, expiresAt };
    } catch (error) {
      if (!(error instanceof Error) || !/UNIQUE/i.test(error.message)) throw error;
    }
  }
  throw errors.internal();
}

export function activePairingCode(ctx: AppContext, guardianId: string): { id: string; expiresAt: number } | null {
  const row = ctx.db.get<PairingCodeRow>(
    `SELECT * FROM pairing_codes
     WHERE guardian_id = ? AND consumed_at IS NULL AND invalidated_at IS NULL AND expires_at > ?
     ORDER BY created_at DESC LIMIT 1`,
    guardianId,
    ctx.now(),
  );
  return row ? { id: row.id, expiresAt: row.expires_at } : null;
}

export function cancelPairingCode(ctx: AppContext, auth: GuardianAuth, codeId: string, ip: string): void {
  const row = ctx.db.get<PairingCodeRow>('SELECT * FROM pairing_codes WHERE id = ?', codeId);
  if (!row) throw errors.notFound('Código não encontrado.');
  if (row.guardian_id !== auth.guardian.id) throw errors.forbidden();
  if (row.consumed_at === null && row.invalidated_at === null) {
    ctx.db.run('UPDATE pairing_codes SET invalidated_at = ? WHERE id = ?', ctx.now(), codeId);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'pairing.code_cancel',
      summary: 'Código de vinculação cancelado',
      session: auth.session,
      targetType: 'pairing',
      targetId: codeId,
      ip,
    });
  }
}

export interface ClaimResult {
  linkId: string;
  pollToken: string;
  confirmCode: string;
  guardianName: string;
  expiresAt: number;
}

/**
 * Uso do codigo pelo aparelho da crianca. O codigo e consumido e nasce um pedido pendente, que
 * so vira vinculo quando o responsavel aprova.
 */
export function claimPairingCode(ctx: AppContext, rawCode: string, info: DeviceInfoInput, ip: string): ClaimResult {
  const now = ctx.now();
  const failureKey = `claim-fail:${ip}`;
  ctx.rate.assertBelow(failureKey, ctx.config.rateLimits.claimFailures, now);

  const code = normalizePairingCode(rawCode);
  const row = code ? ctx.db.get<PairingCodeRow>('SELECT * FROM pairing_codes WHERE code_hash = ?', sha256Hex(code)) : undefined;
  if (!row) {
    ctx.rate.record(failureKey, ctx.config.rateLimits.claimFailures, now);
    throw errors.invalidCredentials('Código de vinculação incorreto.');
  }
  if (row.consumed_at !== null || row.invalidated_at !== null || row.expires_at <= now) {
    throw errors.codeExpired();
  }
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', row.guardian_id);
  if (!guardian) throw errors.codeExpired();

  const existing = ctx.db.get<{ id: string }>(
    'SELECT id FROM devices WHERE guardian_id = ? AND hardware_id = ? ORDER BY approved_at DESC LIMIT 1',
    guardian.id,
    info.hardwareId,
  );
  const linkId = randomUUID();
  const pollToken = newToken('pp_');
  const confirmCode = generateConfirmCode();
  const expiresAt = now + ctx.config.linkTtlMinutes * MINUTE_MS;

  ctx.db.transaction(() => {
    const consumed = ctx.db.run(
      'UPDATE pairing_codes SET consumed_at = ? WHERE id = ? AND consumed_at IS NULL',
      now,
      row.id,
    );
    if (consumed.changes === 0) throw errors.codeExpired();
    ctx.db.run(
      `INSERT INTO links (id, guardian_id, code_id, status, poll_token_hash, confirm_code, device_name, model, manufacturer,
         android_release, sdk_int, app_version, timezone, hardware_id, relink_device_id, created_at, expires_at)
       VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      linkId,
      guardian.id,
      row.id,
      sha256Hex(pollToken),
      confirmCode,
      info.name,
      info.model,
      info.manufacturer,
      info.androidRelease,
      info.sdkInt,
      info.appVersion,
      info.timezone,
      info.hardwareId,
      existing?.id ?? null,
      now,
      expiresAt,
    );
    audit(ctx, {
      guardianId: guardian.id,
      action: 'pairing.claim',
      summary: `${info.name} usou o código de vinculação e aguarda aprovação`,
      targetType: 'pairing',
      targetId: linkId,
      ip,
      origin: info.name,
    });
  });

  createAlert(ctx, {
    guardianId: guardian.id,
    type: 'device_linked',
    deviceId: linkId,
    title: 'Novo aparelho aguardando aprovação',
    body: `${info.name} pediu vinculação. Confira o código ${confirmCode} nos dois aparelhos antes de aprovar.`,
    data: { status: 'pending', linkId, confirmCode, relink: existing !== undefined },
  });
  ctx.hub.toGuardian(guardian.id, { type: 'link_pending', deviceId: linkId });

  return { linkId, pollToken, confirmCode, guardianName: guardian.display_name, expiresAt };
}

function pendingLink(ctx: AppContext, auth: GuardianAuth, linkId: string): LinkRow {
  expireLinks(ctx);
  const link = ctx.db.get<LinkRow>('SELECT * FROM links WHERE id = ?', linkId);
  if (!link) {
    // Aparelho ja aprovado tem o mesmo identificador do pedido (quando nao e reaproveitamento).
    const device = ctx.db.get<DeviceRow>('SELECT * FROM devices WHERE id = ?', linkId);
    if (device && device.guardian_id === auth.guardian.id) {
      throw errors.conflict('Este pedido de vínculo já foi resolvido.');
    }
    throw errors.notFound('Pedido de vínculo não encontrado.');
  }
  if (link.guardian_id !== auth.guardian.id) throw errors.forbidden();
  if (link.status === 'expired') throw errors.conflict('Este pedido de vínculo expirou. Gere um novo código.');
  if (link.status !== 'pending') throw errors.conflict('Este pedido de vínculo já foi resolvido.');
  return link;
}

/**
 * Aprova o pedido. Se o mesmo aparelho (pelo `hardwareId`) ja pertence a conta, o cadastro e
 * reaproveitado: politica e historico ficam, o token antigo deixa de valer.
 */
export function approveLink(ctx: AppContext, auth: GuardianAuth, linkId: string, childName: string, ip: string): DeviceJson {
  const link = pendingLink(ctx, auth, linkId);
  const now = ctx.now();
  const existing = ctx.db.get<DeviceRow>(
    'SELECT * FROM devices WHERE guardian_id = ? AND hardware_id = ? ORDER BY approved_at DESC LIMIT 1',
    auth.guardian.id,
    link.hardware_id,
  );
  const secret = ctx.cipher.encrypt(generateOfflineSecret(), 'devices.offline_secret');
  const deviceId = existing?.id ?? link.id;

  ctx.db.transaction(() => {
    if (existing) {
      if (existing.token_hash !== null) {
        ctx.db.run(
          'INSERT OR IGNORE INTO revoked_tokens (token_hash, revoked_at) VALUES (?, ?)',
          existing.token_hash,
          now,
        );
      }
      ctx.db.run(
        `UPDATE devices SET status = 'active', child_name = ?, device_name = ?, model = ?, manufacturer = ?,
           android_release = ?, sdk_int = ?, app_version = ?, timezone = ?, token_hash = NULL, offline_secret_enc = ?,
           approved_at = ?, revoked_at = NULL, applied_policy_version = 0, policy_applied_at = NULL, state = NULL,
           stale_alert_for = NULL, offline_alert_for = NULL, admin_failures = 0, admin_locked_until = 0
         WHERE id = ?`,
        childName,
        link.device_name,
        link.model,
        link.manufacturer,
        link.android_release,
        link.sdk_int,
        link.app_version,
        link.timezone,
        secret,
        now,
        existing.id,
      );
    } else {
      ctx.db.run(
        `INSERT INTO devices (id, guardian_id, status, child_name, device_name, model, manufacturer, android_release, sdk_int,
           app_version, timezone, hardware_id, offline_secret_enc, created_at, approved_at, policy, policy_version, policy_updated_at)
         VALUES (?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)`,
        deviceId,
        auth.guardian.id,
        childName,
        link.device_name,
        link.model,
        link.manufacturer,
        link.android_release,
        link.sdk_int,
        link.app_version,
        link.timezone,
        link.hardware_id,
        secret,
        now,
        now,
        JSON.stringify(defaultPolicy(link.timezone)),
        now,
      );
    }
    ctx.db.run(
      `UPDATE links SET status = 'approved', device_id = ?, relink_device_id = ?, resolved_at = ? WHERE id = ?`,
      deviceId,
      existing?.id ?? null,
      now,
      link.id,
    );
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'device.approve',
      summary: existing
        ? `Vínculo de ${link.device_name} aprovado como ${childName}, reaproveitando o cadastro anterior`
        : `Vínculo de ${link.device_name} aprovado como ${childName}`,
      session: auth.session,
      targetType: 'device',
      targetId: deviceId,
      ip,
    });
  });

  const device = ctx.db.get<DeviceRow>('SELECT * FROM devices WHERE id = ?', deviceId);
  if (!device) throw errors.internal();
  createAlert(ctx, {
    guardianId: auth.guardian.id,
    type: 'device_linked',
    deviceId,
    childName,
    title: 'Aparelho vinculado',
    body: `${link.device_name} foi vinculado como ${childName}.`,
    data: { status: 'approved', linkId: link.id, relink: existing !== undefined },
    originSessionId: auth.session.id,
  });
  ctx.hub.toGuardian(auth.guardian.id, { type: 'link_resolved', deviceId, linkId: link.id, status: 'active' });
  return deviceJson(ctx, device);
}

export function rejectLink(ctx: AppContext, auth: GuardianAuth, linkId: string, ip: string): void {
  const link = pendingLink(ctx, auth, linkId);
  ctx.db.transaction(() => {
    ctx.db.run(`UPDATE links SET status = 'rejected', resolved_at = ? WHERE id = ?`, ctx.now(), link.id);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'device.reject',
      summary: `Pedido de vínculo de ${link.device_name} recusado`,
      session: auth.session,
      targetType: 'pairing',
      targetId: link.id,
      ip,
    });
  });
  ctx.hub.toGuardian(auth.guardian.id, {
    type: 'link_resolved',
    deviceId: link.id,
    linkId: link.id,
    status: 'rejected',
  });
}

export interface PairingStatusJson {
  status: 'pending' | 'approved' | 'rejected' | 'expired';
  credentials?: { deviceId: string; deviceToken: string; offlineSecret: string };
  childName?: string;
  guardianName?: string;
  policyVersion?: number;
  policy?: Policy;
}

/**
 * Consulta do aparelho da crianca. Em `approved` as credenciais sao geradas e entregues uma
 * unica vez: o token de consulta deixa de valer na mesma operacao.
 */
export function pairingStatus(ctx: AppContext, link: LinkRow): PairingStatusJson {
  const now = ctx.now();
  if (link.status === 'pending') {
    if (link.expires_at > now) return { status: 'pending' };
    ctx.db.run(`UPDATE links SET status = 'expired', resolved_at = ? WHERE id = ? AND status = 'pending'`, now, link.id);
    return { status: 'expired' };
  }
  if (link.status === 'rejected' || link.status === 'expired') return { status: link.status };
  if (link.status !== 'approved' || link.device_id === null) throw errors.unauthorized();

  const device = ctx.db.get<DeviceRow>('SELECT * FROM devices WHERE id = ?', link.device_id);
  if (!device || device.status !== 'active') return { status: 'rejected' };
  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', device.guardian_id);
  if (!guardian) return { status: 'rejected' };

  const deviceToken = newToken('dv_');
  ctx.db.transaction(() => {
    if (device.token_hash !== null) {
      ctx.db.run('INSERT OR IGNORE INTO revoked_tokens (token_hash, revoked_at) VALUES (?, ?)', device.token_hash, now);
    }
    ctx.db.run('UPDATE devices SET token_hash = ? WHERE id = ?', sha256Hex(deviceToken), device.id);
    ctx.db.run(`UPDATE links SET status = 'delivered', delivered_at = ? WHERE id = ?`, now, link.id);
  });

  return {
    status: 'approved',
    credentials: {
      deviceId: device.id,
      deviceToken,
      offlineSecret: ctx.cipher.decrypt(device.offline_secret_enc, 'devices.offline_secret'),
    },
    childName: device.child_name,
    guardianName: guardian.display_name,
    policyVersion: device.policy_version,
    policy: readPolicy(device),
  };
}
