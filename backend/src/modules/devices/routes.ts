// Rotas do responsavel sobre os aparelhos: leitura, politica, comandos, inventario e pedidos de
// tempo (protocolo, secao 4).

import type { FastifyInstance } from 'fastify';

import type { AppContext } from '../../context.ts';
import { ApiError, errors, fieldError } from '../../core/errors.ts';
import { formatMinutes } from '../../core/format.ts';
import { localParts } from '../../core/time.ts';
import { parse, queryString, v } from '../../core/validate.ts';
import type { LinkRow } from '../../db/rows.ts';
import { createAlert } from '../alerts/service.ts';
import { authGuardian, clientIp, ownedDevice, requireElevated } from '../auth/guard.ts';
import { audit } from '../guardian/audit.ts';
import { sameEditablePolicy, summarizePolicyChange } from '../policy/diff.ts';
import { normalizePolicyInput, SUSPENSION_SCOPES } from '../policy/schema.ts';
import type { SuspensionScope } from '../policy/schema.ts';
import {
  addExtraTime,
  announcePolicyChange,
  deleteDevice,
  deleteDeviceData,
  deviceJson,
  expireLinks,
  listAppRows,
  listApps,
  listDevices,
  listTimeRequests,
  pendingDeviceJson,
  readPolicy,
  requireActive,
  resolveTimeRequest,
  revokeDevice,
  setManualLock,
  setSuspension,
  writePolicy,
} from './service.ts';

type IdParams = { Params: { id: string } };

const renameBody = v.object({ childName: v.string({ min: 1, max: 60 }) });
const policyBody = v.object({ baseVersion: v.int({ min: 0 }), policy: v.anyObject() });
const extraTimeBody = v.object({ minutes: v.int({ min: 1, max: 720 }) });
const lockBody = v.object({ until: v.nullable(v.int({ min: 0 })) });
const suspensionBody = v.object({
  minutes: v.int({ min: 1, max: 1440 }),
  scopes: v.array(v.oneOf(SUSPENSION_SCOPES), { min: 1, max: 3 }),
});
const resolveBody = v.object({
  action: v.oneOf(['approve', 'deny'] as const),
  minutes: v.optional(v.int({ min: 1, max: 720 })),
});

const SCOPE_TEXT: Record<SuspensionScope, string> = {
  dailyLimit: 'limite diário',
  schedules: 'horários',
  appBlocks: 'bloqueio de apps',
};

const REQUEST_STATUSES = ['pending', 'approved', 'denied', 'expired'];

function hourMinute(instantMs: number, timeZone: string): string {
  const { minuteOfDay } = localParts(instantMs, timeZone);
  return `${String(Math.floor(minuteOfDay / 60)).padStart(2, '0')}:${String(minuteOfDay % 60).padStart(2, '0')}`;
}

export function registerDeviceRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get('/v1/guardian/devices', async (request) => {
    const auth = authGuardian(ctx, request);
    return { devices: listDevices(ctx, auth.guardian.id) };
  });

  app.get<IdParams>('/v1/guardian/devices/:id', async (request) => {
    const auth = authGuardian(ctx, request);
    try {
      const device = ownedDevice(ctx, auth, request.params.id);
      return { device: deviceJson(ctx, device), policyVersion: device.policy_version, policy: readPolicy(device) };
    } catch (error) {
      if (!(error instanceof ApiError) || error.code !== 'not_found') throw error;
      // Um pedido de vinculo ainda pendente e visto pelo painel como aparelho pendente.
      expireLinks(ctx);
      const link = ctx.db.get<LinkRow>(`SELECT * FROM links WHERE id = ? AND status = 'pending'`, request.params.id);
      if (!link) throw error;
      if (link.guardian_id !== auth.guardian.id) throw errors.forbidden();
      return { device: pendingDeviceJson(ctx, link), policyVersion: 0, policy: null };
    }
  });

  app.patch<IdParams>('/v1/guardian/devices/:id', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    const body = parse(renameBody, request.body);
    if (body.childName !== device.child_name) {
      ctx.db.run('UPDATE devices SET child_name = ? WHERE id = ?', body.childName, device.id);
      audit(ctx, {
        guardianId: auth.guardian.id,
        action: 'device.rename',
        summary: `Nome da criança alterado de ${device.child_name} para ${body.childName}`,
        session: auth.session,
        targetType: 'device',
        targetId: device.id,
        ip: clientIp(request),
      });
      device.child_name = body.childName;
      // O aparelho recebe o novo nome na proxima sincronizacao.
      ctx.hub.toDevice(device.id, { type: 'sync_now', reason: 'command' });
      ctx.hub.toGuardian(auth.guardian.id, { type: 'device_updated', deviceId: device.id }, auth.session.id);
    }
    return { device: deviceJson(ctx, device) };
  });

  app.post<IdParams>('/v1/guardian/devices/:id/revoke', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    if (device.status === 'active') {
      revokeDevice(ctx, device);
      audit(ctx, {
        guardianId: auth.guardian.id,
        action: 'device.revoke',
        summary: `Vínculo de ${device.child_name} (${device.device_name}) revogado`,
        session: auth.session,
        targetType: 'device',
        targetId: device.id,
        ip: clientIp(request),
      });
      createAlert(ctx, {
        guardianId: auth.guardian.id,
        type: 'device_linked',
        deviceId: device.id,
        childName: device.child_name,
        title: 'Vínculo removido',
        body: `${device.child_name} (${device.device_name}) foi desvinculado em ${auth.session.device_name}.`,
        data: { status: 'revoked', origin: 'guardian' },
        originSessionId: auth.session.id,
      });
    }
    return reply.code(204).send();
  });

  app.delete<IdParams>('/v1/guardian/devices/:id', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    deleteDevice(ctx, device);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'device.delete',
      summary: `Aparelho de ${device.child_name} (${device.device_name}) e todo o histórico apagados`,
      session: auth.session,
      targetType: 'device',
      targetId: device.id,
      ip: clientIp(request),
    });
    return reply.code(204).send();
  });

  app.delete<IdParams>('/v1/guardian/devices/:id/data', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    deleteDeviceData(ctx, device);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'device.data_delete',
      summary: `Histórico de ${device.child_name} apagado`,
      session: auth.session,
      targetType: 'device',
      targetId: device.id,
      ip: clientIp(request),
    });
    return reply.code(204).send();
  });

  app.get<IdParams>('/v1/guardian/devices/:id/offline-secret', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'device.offline_secret_view',
      summary: `Código de acesso offline de ${device.child_name} consultado`,
      session: auth.session,
      targetType: 'device',
      targetId: device.id,
      ip: clientIp(request),
    });
    return { secret: ctx.cipher.decrypt(device.offline_secret_enc, 'devices.offline_secret') };
  });

  app.put<IdParams>('/v1/guardian/devices/:id/policy', { bodyLimit: 2 * 1024 * 1024 }, async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    const body = parse(policyBody, request.body);
    if (body.baseVersion !== device.policy_version) {
      throw new ApiError('version_conflict', 'As regras foram alteradas em outro lugar. Recarregue antes de salvar.', {
        currentVersion: device.policy_version,
      });
    }
    const current = readPolicy(device);
    const next = normalizePolicyInput(body.policy, current);
    if (sameEditablePolicy(current, next)) {
      return { policyVersion: device.policy_version, policy: current };
    }
    const labels = new Map(listAppRows(ctx, device.id).map((row) => [row.package, row.label]));
    const summary = summarizePolicyChange(current, next, (pkg) => labels.get(pkg) ?? pkg);
    writePolicy(ctx, device, next);
    announcePolicyChange(ctx, device, { action: 'policy.update', summary, session: auth.session, ip: clientIp(request) });
    return { policyVersion: device.policy_version, policy: next };
  });

  app.post<IdParams>('/v1/guardian/devices/:id/extra-time', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    const body = parse(extraTimeBody, request.body);
    const policy = addExtraTime(ctx, device, body.minutes);
    announcePolicyChange(ctx, device, {
      action: 'policy.extra_time',
      summary: `Tempo extra concedido a ${device.child_name}: ${formatMinutes(body.minutes)}`,
      session: auth.session,
      ip: clientIp(request),
      reason: 'command',
    });
    return { policyVersion: device.policy_version, policy };
  });

  app.post<IdParams>('/v1/guardian/devices/:id/lock', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    const body = parse(lockBody, request.body ?? {});
    if (body.until !== null && body.until <= ctx.now()) {
      throw fieldError('until', 'O fim do bloqueio precisa estar no futuro.');
    }
    const policy = setManualLock(ctx, device, true, body.until);
    const until = body.until === null ? '' : ` até ${hourMinute(body.until, policy.timezone)}`;
    announcePolicyChange(ctx, device, {
      action: 'policy.lock',
      summary: `Aparelho de ${device.child_name} bloqueado${until}`,
      session: auth.session,
      ip: clientIp(request),
      reason: 'command',
    });
    return { policyVersion: device.policy_version, policy };
  });

  app.post<IdParams>('/v1/guardian/devices/:id/unlock', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    const policy = setManualLock(ctx, device, false, null);
    announcePolicyChange(ctx, device, {
      action: 'policy.unlock',
      summary: `Aparelho de ${device.child_name} desbloqueado`,
      session: auth.session,
      ip: clientIp(request),
      reason: 'command',
    });
    return { policyVersion: device.policy_version, policy };
  });

  app.post<IdParams>('/v1/guardian/devices/:id/suspension', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    const body = parse(suspensionBody, request.body);
    const scopes = SUSPENSION_SCOPES.filter((scope) => body.scopes.includes(scope));
    const policy = setSuspension(ctx, device, body.minutes, scopes);
    announcePolicyChange(ctx, device, {
      action: 'policy.suspend',
      summary: `Regras de ${device.child_name} suspensas por ${formatMinutes(body.minutes)} (${scopes.map((scope) => SCOPE_TEXT[scope]).join(', ')})`,
      session: auth.session,
      ip: clientIp(request),
      reason: 'command',
    });
    return { policyVersion: device.policy_version, policy };
  });

  app.delete<IdParams>('/v1/guardian/devices/:id/suspension', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    requireActive(device);
    const policy = setSuspension(ctx, device, null, []);
    announcePolicyChange(ctx, device, {
      action: 'policy.resume',
      summary: `Suspensão de regras de ${device.child_name} encerrada`,
      session: auth.session,
      ip: clientIp(request),
      reason: 'command',
    });
    return { policyVersion: device.policy_version, policy };
  });

  app.get<IdParams>('/v1/guardian/devices/:id/apps', async (request) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    return listApps(ctx, device);
  });

  app.get<IdParams>('/v1/guardian/devices/:id/apps/icon', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    const pkg = queryString(request.query, 'package');
    if (!pkg) throw fieldError('package', 'Informe o pacote.');
    const row = ctx.db.get<{ icon: Uint8Array | null; icon_stored_hash: string | null }>(
      'SELECT icon, icon_stored_hash FROM apps WHERE device_id = ? AND package = ?',
      device.id,
      pkg,
    );
    if (!row || row.icon === null || row.icon_stored_hash === null) throw errors.notFound('Ícone não encontrado.');
    const etag = `"${row.icon_stored_hash}"`;
    reply.header('ETag', etag);
    reply.header('Cache-Control', 'private, max-age=31536000, immutable');
    if (request.headers['if-none-match'] === etag) return reply.code(304).send();
    return reply.type('image/png').send(Buffer.from(row.icon));
  });

  app.get<IdParams>('/v1/guardian/devices/:id/time-requests', async (request) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    const status = queryString(request.query, 'status');
    if (status !== undefined && !REQUEST_STATUSES.includes(status)) {
      throw fieldError('status', `Deve ser um de: ${REQUEST_STATUSES.join(', ')}.`);
    }
    return { requests: listTimeRequests(ctx, device, status) };
  });

  app.post<IdParams>('/v1/guardian/time-requests/:id/resolve', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const body = parse(resolveBody, request.body);
    return resolveTimeRequest(ctx, auth, request.params.id, body.action, body.minutes, clientIp(request));
  });
}
