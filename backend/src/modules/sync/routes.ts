// Rotas do aparelho da crianca, autenticadas por token `dv_` (protocolo, secao 5).

import type { FastifyInstance } from 'fastify';

import type { AppContext } from '../../context.ts';
import { fieldError } from '../../core/errors.ts';
import { parse, queryString, v } from '../../core/validate.ts';
import { authDevice, clientIp } from '../auth/guard.ts';
import { passwordParser } from '../auth/routes.ts';
import {
  MAX_ICON_BYTES,
  parseInventoryBody,
  parseSyncBody,
  putIcon,
  putInventory,
  syncDevice,
  unlinkFromDevice,
  verifyAdminOnDevice,
} from './service.ts';

const passwordBody = v.object({ password: passwordParser });

export function registerSyncRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post('/v1/device/sync', { bodyLimit: 8 * 1024 * 1024 }, async (request) => {
    const device = authDevice(ctx, request);
    const body = parseSyncBody(request.body);
    return syncDevice(ctx, device, body, clientIp(request));
  });

  app.put('/v1/device/apps', { bodyLimit: 4 * 1024 * 1024 }, async (request) => {
    const device = authDevice(ctx, request);
    return putInventory(ctx, device, parseInventoryBody(request.body));
  });

  // O limite do corpo fica um pouco acima de 64 KiB: o corte exato e feito em `putIcon`.
  app.put('/v1/device/apps/icon', { bodyLimit: MAX_ICON_BYTES + 1024 }, async (request, reply) => {
    const device = authDevice(ctx, request);
    const pkg = queryString(request.query, 'package');
    if (!pkg) throw fieldError('package', 'Informe o pacote.');
    if (!Buffer.isBuffer(request.body)) {
      throw fieldError('body', 'Envie o ícone como image/png.');
    }
    putIcon(ctx, device, pkg, queryString(request.query, 'hash'), request.body);
    return reply.code(204).send();
  });

  app.post('/v1/device/admin-verify', async (request) => {
    const device = authDevice(ctx, request);
    const body = parse(passwordBody, request.body);
    await verifyAdminOnDevice(ctx, device, body.password, clientIp(request));
    return { ok: true };
  });

  app.post('/v1/device/unlink', async (request, reply) => {
    const device = authDevice(ctx, request);
    const body = parse(passwordBody, request.body);
    await unlinkFromDevice(ctx, device, body.password, clientIp(request));
    return reply.code(204).send();
  });
}
