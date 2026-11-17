// Rotas de WebSocket (protocolo, secao 7).
//
// A autenticacao acontece dentro do manipulador, e nao em um gancho anterior, porque o protocolo
// pede que token invalido feche a conexao com o codigo 4401 (e nao que a troca de protocolo
// falhe com 401). Os ouvintes sao registrados de forma sincrona para nao perder mensagens.

import type { FastifyInstance } from 'fastify';
import type { RawData, WebSocket } from 'ws';

import type { AppContext } from '../../context.ts';
import { authDeviceToken, authGuardianToken, bearerToken } from '../auth/guard.ts';
import { CLOSE_UNAUTHORIZED, closeSocket } from './hub.ts';
import type { Connection } from './hub.ts';

function send(socket: WebSocket, message: object): void {
  try {
    socket.send(JSON.stringify(message));
  } catch {
    // A conexao caiu entre a abertura e o envio.
  }
}

function attach(ctx: AppContext, socket: WebSocket, connection: Connection): void {
  send(socket, { type: 'hello', serverTime: ctx.now() });
  socket.on('message', (raw: RawData) => {
    connection.lastSeen = ctx.now();
    let type: unknown;
    try {
      const parsed: unknown = JSON.parse(raw.toString());
      type = typeof parsed === 'object' && parsed !== null ? (parsed as { type?: unknown }).type : undefined;
    } catch {
      return;
    }
    if (type === 'ping') send(socket, { type: 'pong' });
  });
  socket.on('close', () => ctx.hub.remove(connection));
  socket.on('error', () => ctx.hub.remove(connection));
}

export function registerRealtimeRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get('/v1/guardian/stream', { websocket: true }, (socket, request) => {
    try {
      const auth = authGuardianToken(ctx, bearerToken(request.headers.authorization), request.ip);
      attach(ctx, socket, ctx.hub.addGuardian(auth.guardian.id, auth.session.id, socket, ctx.now()));
    } catch {
      closeSocket(socket, CLOSE_UNAUTHORIZED, 'unauthorized');
    }
  });

  app.get('/v1/device/stream', { websocket: true }, (socket, request) => {
    try {
      const device = authDeviceToken(ctx, bearerToken(request.headers.authorization));
      attach(ctx, socket, ctx.hub.addDevice(device.id, socket, ctx.now()));
    } catch {
      closeSocket(socket, CLOSE_UNAUTHORIZED, 'unauthorized');
    }
  });
}
