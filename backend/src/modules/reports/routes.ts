// Rotas de relatorios do responsavel (protocolo, secoes 4 e 6).

import type { FastifyInstance } from 'fastify';

import type { AppContext } from '../../context.ts';
import { fieldError } from '../../core/errors.ts';
import { isDay } from '../../core/time.ts';
import { queryInt, queryString } from '../../core/validate.ts';
import { authGuardian, clientIp, ownedDevice, requireElevated } from '../auth/guard.ts';
import { deviceToday, readPolicy } from '../devices/service.ts';
import { audit } from '../guardian/audit.ts';
import { exportDevice, listBrowsing, listEvents, listSessions, reportSummary, resolveRange } from './service.ts';

type IdParams = { Params: { id: string } };

/** Le um dia opcional da consulta, validando o formato. */
function queryDay(query: unknown, name: string): string | undefined {
  const value = queryString(query, name);
  if (value !== undefined && !isDay(value)) throw fieldError(name, 'Use uma data no formato AAAA-MM-DD.');
  return value;
}

export function registerReportRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get<IdParams>('/v1/guardian/devices/:id/reports/summary', async (request) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    const range = resolveRange(ctx, device, queryDay(request.query, 'from'), queryDay(request.query, 'to'));
    return reportSummary(ctx, device, range.from, range.to);
  });

  app.get<IdParams>('/v1/guardian/devices/:id/sessions', async (request) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    const day = queryDay(request.query, 'day') ?? deviceToday(ctx, readPolicy(device));
    return { day, sessions: listSessions(ctx, device, day) };
  });

  app.get<IdParams>('/v1/guardian/devices/:id/events', async (request) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    const types = queryString(request.query, 'types')
      ?.split(',')
      .map((type) => type.trim())
      .filter((type) => type !== '');
    if (types && (types.length > 20 || types.some((type) => !/^[a-z0-9_]{1,40}$/.test(type)))) {
      throw fieldError('types', 'Informe até 20 tipos de evento separados por vírgula.');
    }
    return listEvents(ctx, device, {
      from: queryDay(request.query, 'from'),
      to: queryDay(request.query, 'to'),
      types,
      before: queryInt(request.query, 'before', { min: 1 }),
      limit: queryInt(request.query, 'limit', { min: 1, max: 200 }) ?? 50,
    });
  });

  app.get<IdParams>('/v1/guardian/devices/:id/browsing', async (request) => {
    const auth = authGuardian(ctx, request);
    const device = ownedDevice(ctx, auth, request.params.id);
    return listBrowsing(ctx, device, {
      from: queryDay(request.query, 'from'),
      to: queryDay(request.query, 'to'),
      before: queryInt(request.query, 'before', { min: 1 }),
      limit: queryInt(request.query, 'limit', { min: 1, max: 200 }) ?? 50,
    });
  });

  app.get<IdParams>('/v1/guardian/devices/:id/export', async (request) => {
    const auth = authGuardian(ctx, request);
    requireElevated(ctx, auth);
    const device = ownedDevice(ctx, auth, request.params.id);
    audit(ctx, {
      guardianId: auth.guardian.id,
      action: 'device.export',
      summary: `Dados de ${device.child_name} exportados`,
      session: auth.session,
      targetType: 'device',
      targetId: device.id,
      ip: clientIp(request),
    });
    return exportDevice(ctx, device);
  });
}
