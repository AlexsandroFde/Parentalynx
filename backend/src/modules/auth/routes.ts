// Rotas publicas de conta: saude, metadados, registro, login e recuperacao (protocolo 2.4).

import type { FastifyInstance } from 'fastify';

import type { AppContext } from '../../context.ts';
import { parse, v } from '../../core/validate.ts';
import { audit } from '../guardian/audit.ts';
import { authGuardian, clientIp } from './guard.ts';
import { login, recover, register, revokeSession } from './service.ts';

export const emailParser = v.string({ min: 3, max: 254, lower: true, pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/ });
/** A senha nao e aparada: espacos nas pontas fazem parte dela. */
export const passwordParser = v.string({ min: 1, max: 1000, trim: false });
const deviceNameParser = v.withDefault(v.string({ min: 1, max: 80 }), 'Aparelho do responsável');

const registerBody = v.object({
  email: emailParser,
  displayName: v.string({ min: 1, max: 60 }),
  password: passwordParser,
  deviceName: deviceNameParser,
});

const loginBody = v.object({
  email: emailParser,
  password: passwordParser,
  deviceName: deviceNameParser,
});

const recoverBody = v.object({
  email: emailParser,
  recoveryKey: v.string({ min: 1, max: 100 }),
  newPassword: passwordParser,
  deviceName: deviceNameParser,
});

export function registerAuthRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get('/health', async () => ({ status: 'ok', time: ctx.now() }));

  app.get('/v1/meta', async (request) => {
    ctx.rate.consume(`meta:${clientIp(request)}`, ctx.config.rateLimits.meta, ctx.now());
    return { serverTime: ctx.now(), apiVersion: 1, name: 'ParentaLynx' };
  });

  app.post('/v1/auth/register', async (request, reply) => {
    const ip = clientIp(request);
    ctx.rate.consume(`register:${ip}`, ctx.config.rateLimits.register, ctx.now());
    const body = parse(registerBody, request.body);
    const result = await register(ctx, body, ip);
    return reply.code(201).send(result);
  });

  app.post('/v1/auth/login', async (request) => {
    const ip = clientIp(request);
    ctx.rate.consume(`login:${ip}`, ctx.config.rateLimits.login, ctx.now());
    const body = parse(loginBody, request.body);
    return login(ctx, body, ip);
  });

  app.post('/v1/auth/recover', async (request) => {
    const ip = clientIp(request);
    ctx.rate.consume(`recover:${ip}`, ctx.config.rateLimits.recover, ctx.now());
    const body = parse(recoverBody, request.body);
    return recover(ctx, body, ip);
  });

  app.post('/v1/auth/logout', async (request, reply) => {
    const auth = authGuardian(ctx, request);
    revokeSession(ctx, auth.guardian.id, auth.session.id);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'auth.logout',
      summary: `Saída de ${auth.session.device_name}`,
      session: auth.session,
      targetType: 'session',
      targetId: auth.session.id,
      ip: clientIp(request),
    });
    return reply.code(204).send();
  });
}
