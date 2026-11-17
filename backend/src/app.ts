// Montagem do servidor Fastify. Separado de `server.ts` para ser usado pelos testes.

import websocket from '@fastify/websocket';
import Fastify from 'fastify';
import type { FastifyError, FastifyInstance } from 'fastify';

import type { AppConfig } from './config.ts';
import { createContext } from './context.ts';
import type { AppContext } from './context.ts';
import { ApiError, errors, validationError } from './core/errors.ts';
import { openDatabase } from './db/database.ts';
import type { Db } from './db/database.ts';
import { registerAuthRoutes } from './modules/auth/routes.ts';
import { registerDeviceRoutes } from './modules/devices/routes.ts';
import { registerGuardianRoutes } from './modules/guardian/routes.ts';
import { registerPairingRoutes } from './modules/pairing/routes.ts';
import { registerRealtimeRoutes } from './modules/realtime/routes.ts';
import { registerReportRoutes } from './modules/reports/routes.ts';
import { registerSyncRoutes } from './modules/sync/routes.ts';

export interface BuiltApp {
  app: FastifyInstance;
  ctx: AppContext;
}

/** Destino alternativo do log, usado pelos testes para conferir que nada sensivel e registrado. */
export interface LogStream {
  write(message: string): void;
}

function toApiError(error: FastifyError | Error): ApiError | null {
  if (error instanceof ApiError) return error;
  const code = 'code' in error ? error.code : undefined;
  const status = 'statusCode' in error ? error.statusCode : undefined;
  if (code === 'FST_ERR_CTP_BODY_TOO_LARGE' || status === 413) return errors.payloadTooLarge();
  if (code === 'FST_ERR_CTP_INVALID_MEDIA_TYPE' || status === 415) {
    return validationError([{ field: '(corpo)', message: 'Tipo de conteúdo não suportado.' }], 'Tipo de conteúdo não suportado.');
  }
  if (typeof status === 'number' && status >= 400 && status < 500) {
    return validationError([{ field: '(corpo)', message: 'Requisição malformada.' }], 'Requisição malformada.');
  }
  return null;
}

/**
 * Cria o servidor. Se `db` nao for informado, abre o banco do caminho configurado e aplica as
 * migracoes. Quem chama e responsavel por `app.close()`, que tambem fecha o banco.
 */
export async function buildApp(
  config: AppConfig,
  db: Db = openDatabase(config.databasePath),
  logStream?: LogStream,
): Promise<BuiltApp> {
  const app = Fastify({
    logger:
      config.logLevel === 'silent'
        ? false
        : {
            level: config.logLevel,
            // Nunca registrar credenciais: o cabecalho de autorizacao e mascarado.
            redact: ['req.headers.authorization', 'req.headers.cookie'],
            ...(logStream ? { stream: logStream } : {}),
          },
    trustProxy: config.trustProxy,
    bodyLimit: 1024 * 1024,
    // Parametros de caminho muito longos sao recusados antes de chegar as rotas.
    routerOptions: { maxParamLength: 200 },
  });
  const ctx = createContext(config, db, app.log);

  // Corpo JSON vazio vale como objeto vazio, para rotas de comando sem parametros.
  const parseJson = app.getDefaultJsonParser('error', 'error');
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (request, body, done) => {
    if (typeof body === 'string' && body.trim() === '') {
      done(null, {});
      return;
    }
    parseJson(request, body as string, done);
  });
  app.addContentTypeParser(['image/png', 'application/octet-stream'], { parseAs: 'buffer' }, (_request, body, done) => {
    done(null, body);
  });

  app.addHook('onSend', async (_request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff');
    reply.header('X-Frame-Options', 'DENY');
    reply.header('Referrer-Policy', 'no-referrer');
    if (!reply.hasHeader('Cache-Control')) reply.header('Cache-Control', 'no-store');
  });

  app.setErrorHandler((error: FastifyError | Error, request, reply) => {
    const apiError = toApiError(error);
    if (apiError) {
      if (apiError.code === 'rate_limited' || apiError.code === 'account_locked') {
        const retry = apiError.details.retryAfterSec;
        if (typeof retry === 'number') reply.header('Retry-After', String(retry));
      }
      return reply.code(apiError.status).send(apiError.toBody());
    }
    request.log.error({ err: error }, 'erro inesperado');
    const internal = errors.internal();
    return reply.code(internal.status).send(internal.toBody());
  });

  app.setNotFoundHandler((_request, reply) => {
    const notFound = errors.notFound('Rota não encontrada.');
    return reply.code(notFound.status).send(notFound.toBody());
  });

  app.addHook('onClose', async () => {
    ctx.hub.closeAll();
    db.close();
  });

  await app.register(websocket, { options: { maxPayload: 4096 } });

  registerAuthRoutes(app, ctx);
  registerGuardianRoutes(app, ctx);
  registerPairingRoutes(app, ctx);
  registerDeviceRoutes(app, ctx);
  registerReportRoutes(app, ctx);
  registerSyncRoutes(app, ctx);
  registerRealtimeRoutes(app, ctx);

  return { app, ctx };
}
