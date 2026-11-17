// Rotas do responsavel sobre a propria conta: perfil, sessoes, preferencias, auditoria,
// alertas e exclusao da conta (protocolo 2.5).

import type { FastifyInstance } from 'fastify';

import type { AppContext } from '../../context.ts';
import { errors, validationError } from '../../core/errors.ts';
import type { FieldIssue } from '../../core/errors.ts';
import { isPlainObject, parse, queryBool, queryInt, v } from '../../core/validate.ts';
import type { SessionRow } from '../../db/rows.ts';
import { listAlerts, markAlertsRead } from '../alerts/service.ts';
import { authGuardian, clientIp, requireElevated } from '../auth/guard.ts';
import { passwordParser } from '../auth/routes.ts';
import {
  ALERT_TYPES,
  assertPassword,
  changePassword,
  elevate,
  getGuardian,
  guardianJson,
  readNotificationPrefs,
  readSettings,
  revokeSession,
  rotateRecoveryKey,
  sessionJson,
  SETTINGS_LIMITS,
} from '../auth/service.ts';
import type { AlertType, GuardianSettings } from '../auth/service.ts';
import { audit, listAudit } from './audit.ts';

const passwordBody = v.object({ password: passwordParser });
const changePasswordBody = v.object({ currentPassword: passwordParser, newPassword: passwordParser });
const readBody = v.object({
  ids: v.optional(v.array(v.int({ min: 1 }), { max: 500 })),
  all: v.optional(v.bool()),
});

function parseSettingsPatch(input: unknown, current: GuardianSettings): GuardianSettings {
  if (!isPlainObject(input)) throw validationError([{ field: 'settings', message: 'Deve ser um objeto.' }]);
  const issues: FieldIssue[] = [];
  const next = { ...current };
  for (const key of Object.keys(input)) {
    if (!Object.hasOwn(SETTINGS_LIMITS, key)) {
      issues.push({ field: `settings.${key}`, message: 'Configuração desconhecida.' });
      continue;
    }
    const name = key as keyof GuardianSettings;
    const [min, max] = SETTINGS_LIMITS[name];
    const value = input[key];
    if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) {
      issues.push({ field: `settings.${key}`, message: `Deve ser um inteiro entre ${min} e ${max}.` });
      continue;
    }
    next[name] = value;
  }
  if (issues.length > 0) throw validationError(issues);
  return next;
}

export function registerGuardianRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get('/v1/guardian/me', async (request) => {
    const auth = authGuardian(ctx, request);
    return { guardian: guardianJson(auth.guardian), session: sessionJson(auth.session, auth.session.id) };
  });

  app.patch('/v1/guardian/me', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    if (!isPlainObject(request.body)) throw validationError([{ field: '(corpo)', message: 'Deve ser um objeto.' }]);
    const changes: string[] = [];
    let displayName = auth.guardian.display_name;
    if (request.body.displayName !== undefined) {
      const issues: FieldIssue[] = [];
      displayName = v.string({ min: 1, max: 60 })(request.body.displayName, 'displayName', issues);
      if (issues.length > 0) throw validationError(issues);
      if (displayName !== auth.guardian.display_name) changes.push(`Nome alterado para ${displayName}`);
    }
    let settings = readSettings(auth.guardian);
    if (request.body.settings !== undefined) {
      const next = parseSettingsPatch(request.body.settings, settings);
      if (JSON.stringify(next) !== JSON.stringify(settings)) changes.push('Configurações da conta alteradas');
      settings = next;
    }
    if (changes.length > 0) {
      ctx.db.run(
        'UPDATE guardians SET display_name = ?, settings = ? WHERE id = ?',
        displayName,
        JSON.stringify(settings),
        auth.guardian.id,
      );
      audit(ctx, {
        guardianId: auth.guardian.id,
        action: 'guardian.update',
        summary: changes.join('; '),
        session: auth.session,
        targetType: 'guardian',
        targetId: auth.guardian.id,
        ip: clientIp(request),
      });
    }
    return { guardian: guardianJson(getGuardian(ctx, auth.guardian.id)) };
  });

  app.post('/v1/guardian/session/elevate', async (request) => {
    const auth = authGuardian(ctx, request);
    const body = parse(passwordBody, request.body);
    const elevatedUntil = await elevate(ctx, auth.guardian, auth.session, body.password, clientIp(request));
    return { elevatedUntil };
  });

  app.post('/v1/guardian/password', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    const body = parse(changePasswordBody, request.body);
    await changePassword(ctx, auth.guardian, auth.session, body.currentPassword, body.newPassword, clientIp(request));
    return reply.code(204).send();
  });

  app.post('/v1/guardian/recovery-key', async (request) => {
    const auth = authGuardian(ctx, request);
    const body = parse(passwordBody, request.body);
    const recoveryKey = await rotateRecoveryKey(ctx, auth.guardian, auth.session, body.password, clientIp(request));
    return { recoveryKey };
  });

  app.get('/v1/guardian/sessions', async (request) => {
    const auth = authGuardian(ctx, request);
    const rows = ctx.db.all<SessionRow>(
      `SELECT * FROM sessions WHERE guardian_id = ? AND revoked_at IS NULL AND expires_at > ? ORDER BY last_seen_at DESC`,
      auth.guardian.id,
      ctx.now(),
    );
    return { sessions: rows.map((row) => sessionJson(row, auth.session.id)) };
  });

  app.delete<{ Params: { id: string } }>('/v1/guardian/sessions/:id', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const target = ctx.db.get<SessionRow>('SELECT * FROM sessions WHERE id = ?', request.params.id);
    if (!target) throw errors.notFound('Sessão não encontrada.');
    if (target.guardian_id !== auth.guardian.id) throw errors.forbidden();
    if (revokeSession(ctx, auth.guardian.id, target.id)) {
      audit(ctx, {
        guardianId: auth.guardian.id,
        action: 'session.revoke',
        summary: `Sessão de ${target.device_name} revogada`,
        session: auth.session,
        targetType: 'session',
        targetId: target.id,
        ip: clientIp(request),
      });
    }
    return reply.code(204).send();
  });

  app.put('/v1/guardian/notification-prefs', async (request) => {
    const auth = authGuardian(ctx, request);
    if (!isPlainObject(request.body)) throw validationError([{ field: '(corpo)', message: 'Deve ser um objeto.' }]);
    const prefs = readNotificationPrefs(auth.guardian);
    const issues: FieldIssue[] = [];
    const known: readonly string[] = ALERT_TYPES;
    for (const key of Object.keys(request.body)) {
      const value = request.body[key];
      if (!known.includes(key)) issues.push({ field: key, message: 'Tipo de alerta desconhecido.' });
      else if (typeof value !== 'boolean') issues.push({ field: key, message: 'Deve ser verdadeiro ou falso.' });
      else prefs[key as AlertType] = value;
    }
    if (issues.length > 0) throw validationError(issues);
    ctx.db.run('UPDATE guardians SET notification_prefs = ? WHERE id = ?', JSON.stringify(prefs), auth.guardian.id);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'prefs.update',
      summary: 'Preferências de notificação alteradas',
      session: auth.session,
      targetType: 'guardian',
      targetId: auth.guardian.id,
      ip: clientIp(request),
    });
    return { notificationPrefs: prefs };
  });

  app.delete('/v1/guardian/account', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    const body = parse(passwordBody, request.body);
    await assertPassword(ctx, auth.guardian, body.password, {
      action: 'guardian.delete_failed',
      session: auth.session,
      ip: clientIp(request),
    });
    const devices = ctx.db.all<{ id: string; token_hash: string | null }>(
      'SELECT id, token_hash FROM devices WHERE guardian_id = ?',
      auth.guardian.id,
    );
    ctx.db.transaction(() => {
      // Os tokens dos aparelhos ficam marcados como revogados para que os agentes se desativem.
      for (const device of devices) {
        if (device.token_hash === null) continue;
        ctx.db.run(
          'INSERT OR IGNORE INTO revoked_tokens (token_hash, revoked_at) VALUES (?, ?)',
          device.token_hash,
          ctx.now(),
        );
      }
      ctx.db.run('DELETE FROM guardians WHERE id = ?', auth.guardian.id);
    });
    for (const device of devices) ctx.hub.revokeDevice(device.id);
    ctx.hub.closeGuardian(auth.guardian.id);
    ctx.log.info({ guardianId: auth.guardian.id, devices: devices.length }, 'conta excluída a pedido do responsável');
    return reply.code(204).send();
  });

  app.get('/v1/guardian/audit', async (request) => {
    const auth = authGuardian(ctx, request);
    const before = queryInt(request.query, 'before', { min: 1 });
    const limit = queryInt(request.query, 'limit', { min: 1, max: 200 }) ?? 50;
    return listAudit(ctx, auth.guardian.id, before, limit);
  });

  app.get('/v1/guardian/alerts', async (request) => {
    const auth = authGuardian(ctx, request);
    return listAlerts(ctx, auth.guardian.id, auth.session.id, {
      after: queryInt(request.query, 'after', { min: 0 }),
      before: queryInt(request.query, 'before', { min: 1 }),
      limit: queryInt(request.query, 'limit', { min: 1, max: 200 }) ?? 50,
      notifyOnly: queryBool(request.query, 'notifyOnly'),
    });
  });

  app.post('/v1/guardian/alerts/read', async (request) => {
    const auth = authGuardian(ctx, request);
    const body = parse(readBody, request.body);
    return { unread: markAlertsRead(ctx, auth.guardian.id, auth.session.id, body) };
  });
}
