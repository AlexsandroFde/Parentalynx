// Rotas de vinculacao (protocolo 3.2).

import type { FastifyInstance } from 'fastify';

import type { AppContext } from '../../context.ts';
import { parse, v } from '../../core/validate.ts';
import { authGuardian, authPollToken, clientIp, requireElevated } from '../auth/guard.ts';
import { pendingDeviceJson, pendingLinks } from '../devices/service.ts';
import {
  activePairingCode,
  approveLink,
  cancelPairingCode,
  claimPairingCode,
  createPairingCode,
  pairingStatus,
  rejectLink,
} from './service.ts';

const claimBody = v.object({
  code: v.string({ min: 1, max: 40 }),
  device: v.object({
    name: v.string({ min: 1, max: 80 }),
    model: v.string({ max: 80 }),
    manufacturer: v.string({ max: 80 }),
    androidRelease: v.string({ max: 20 }),
    sdkInt: v.int({ min: 1, max: 1000 }),
    appVersion: v.string({ max: 40 }),
    timezone: v.string({ min: 1, max: 64 }),
    hardwareId: v.string({ min: 16, max: 128, lower: true, pattern: /^[0-9a-f]+$/ }),
  }),
});

const approveBody = v.object({ childName: v.string({ min: 1, max: 60 }) });

export function registerPairingRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post('/v1/guardian/pairing-codes', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    return reply.code(201).send(createPairingCode(ctx, auth, clientIp(request)));
  });

  app.get('/v1/guardian/pairing-codes/active', async (request) => {
    const auth = authGuardian(ctx, request);
    return {
      code: activePairingCode(ctx, auth.guardian.id),
      pending: pendingLinks(ctx, auth.guardian.id).map((link) => pendingDeviceJson(ctx, link)),
    };
  });

  app.delete<{ Params: { id: string } }>('/v1/guardian/pairing-codes/:id', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    cancelPairingCode(ctx, auth, request.params.id, clientIp(request));
    return reply.code(204).send();
  });

  app.post('/v1/pairing/claim', async (request, reply) => {
    const ip = clientIp(request);
    ctx.rate.consume(`claim:${ip}`, ctx.config.rateLimits.claim, ctx.now());
    const body = parse(claimBody, request.body);
    return reply.code(201).send(claimPairingCode(ctx, body.code, body.device, ip));
  });

  app.get('/v1/pairing/status', async (request) => {
    ctx.rate.consume(`pairing-status:${clientIp(request)}`, ctx.config.rateLimits.pairingStatus, ctx.now());
    return pairingStatus(ctx, authPollToken(ctx, request));
  });

  app.post<{ Params: { id: string } }>('/v1/guardian/devices/:id/approve', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const body = parse(approveBody, request.body);
    return { device: approveLink(ctx, auth, request.params.id, body.childName, clientIp(request)) };
  });

  app.post<{ Params: { id: string } }>('/v1/guardian/devices/:id/reject', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    rejectLink(ctx, auth, request.params.id, clientIp(request));
    return reply.code(204).send();
  });
}
