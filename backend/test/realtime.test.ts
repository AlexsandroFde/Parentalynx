// WebSocket: saudacao, avisos em tempo real, token invalido e inatividade.

import assert from 'node:assert/strict';
import { once } from 'node:events';
import { afterEach, beforeEach, describe, test } from 'node:test';

import type { WebSocket } from 'ws';

import { CLOSE_IDLE, CLOSE_UNAUTHORIZED } from '../src/modules/realtime/hub.ts';
import {
  api,
  deviceInfo,
  event,
  login,
  MINUTE,
  newPairingCode,
  pairDevice,
  PASSWORD,
  registerGuardian,
  startServer,
  sync,
  TODAY,
} from './helpers.ts';
import type { GuardianAccount, PairedDevice, TestServer } from './helpers.ts';

type Message = { type: string } & Record<string, unknown>;

/** Cliente de teste que guarda as mensagens recebidas e permite esperar por um tipo. */
class Client {
  readonly messages: Message[] = [];
  closeCode: number | null = null;
  private socket: WebSocket | null = null;
  private waiters: (() => void)[] = [];

  attach(socket: WebSocket): void {
    this.socket = socket;
    socket.on('message', (raw) => {
      this.messages.push(JSON.parse(raw.toString()) as Message);
      this.wake();
    });
    socket.on('close', (code) => {
      this.closeCode = code;
      this.wake();
    });
  }

  private wake(): void {
    const waiting = this.waiters;
    this.waiters = [];
    for (const resolve of waiting) resolve();
  }

  private async until<T>(check: () => T | undefined, what: string): Promise<T> {
    const deadline = Date.now() + 3000;
    for (;;) {
      const found = check();
      if (found !== undefined) return found;
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new Error(`tempo esgotado esperando ${what}. Recebido: ${JSON.stringify(this.messages)}`);
      await new Promise<void>((resolve) => {
        const timer = setTimeout(resolve, remaining);
        this.waiters.push(() => {
          clearTimeout(timer);
          resolve();
        });
      });
    }
  }

  /** Espera a proxima mensagem do tipo, a partir da posicao `from`. */
  next(type: string, from = 0): Promise<Message> {
    return this.until(() => this.messages.slice(from).find((message) => message.type === type), `mensagem ${type}`);
  }

  closed(): Promise<number> {
    return this.until(() => this.closeCode ?? undefined, 'fechamento');
  }

  types(): string[] {
    return this.messages.map((message) => message.type);
  }

  send(message: object): void {
    this.socket?.send(JSON.stringify(message));
  }

  close(): void {
    this.socket?.terminate();
  }
}

let server: TestServer;
let guardian: GuardianAccount;
let device: PairedDevice;
let clients: Client[];

async function connect(path: string, token?: string): Promise<Client> {
  const client = new Client();
  clients.push(client);
  const headers = token ? { authorization: `Bearer ${token}` } : {};
  // `onInit` registra os ouvintes antes da abertura, para a saudacao nao se perder.
  await server.app.injectWS(path, { headers }, { onInit: (socket) => client.attach(socket) });
  return client;
}

/** Da tempo para mensagens indevidas chegarem antes de conferir que nao chegaram. */
async function settle(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 60));
}

beforeEach(async () => {
  server = await startServer();
  guardian = await registerGuardian(server);
  device = await pairDevice(server, guardian);
  clients = [];
});

afterEach(async () => {
  for (const client of clients) client.close();
  await server.close();
});

describe('conexao', () => {
  test('saudacao com a hora do servidor e resposta a ping', async () => {
    const panel = await connect('/v1/guardian/stream', guardian.token);
    assert.deepEqual(await panel.next('hello'), { type: 'hello', serverTime: server.now() });
    panel.send({ type: 'ping' });
    assert.deepEqual(await panel.next('pong'), { type: 'pong' });

    const agent = await connect('/v1/device/stream', device.deviceToken);
    assert.deepEqual(await agent.next('hello'), { type: 'hello', serverTime: server.now() });
    agent.send({ type: 'ping' });
    assert.deepEqual(await agent.next('pong'), { type: 'pong' });
    // Mensagens que nao sao JSON ou de tipo desconhecido sao ignoradas sem derrubar a conexao.
    agent.send({ type: 'qualquer' });
    agent.send({ type: 'ping' });
    await agent.next('pong', agent.messages.length);
    assert.equal(agent.closeCode, null);
  });

  test('token invalido, ausente ou do tipo errado fecha com 4401', async () => {
    const cases: [string, string | undefined][] = [
      ['/v1/guardian/stream', undefined],
      ['/v1/guardian/stream', 'gs_inexistente'],
      ['/v1/guardian/stream', device.deviceToken],
      ['/v1/device/stream', undefined],
      ['/v1/device/stream', 'dv_inexistente'],
      ['/v1/device/stream', guardian.token],
    ];
    for (const [path, token] of cases) {
      const client = await connect(path, token);
      assert.equal(await client.closed(), CLOSE_UNAUTHORIZED, `${path} com ${token ?? 'sem token'}`);
      assert.deepEqual(client.messages, [], 'nenhuma mensagem antes do fechamento');
    }
    assert.equal(CLOSE_UNAUTHORIZED, 4401);
    assert.equal(server.ctx.hub.connectionCount, 0);
  });

  test('sessao revogada tem o WebSocket fechado', async () => {
    const other = await login(server, guardian.email, PASSWORD);
    const panel = await connect('/v1/guardian/stream', other.body.session.token);
    await panel.next('hello');
    await api(server, 'DELETE', `/v1/guardian/sessions/${other.body.session.id}`, { token: guardian.token });
    assert.equal(await panel.closed(), CLOSE_UNAUTHORIZED);
    const late = await connect('/v1/guardian/stream', other.body.session.token);
    assert.equal(await late.closed(), CLOSE_UNAUTHORIZED);
  });

  test('conexao sem trafego por 90 segundos e encerrada, ping a mantem viva', async () => {
    const quiet = await connect('/v1/guardian/stream', guardian.token);
    const active = await connect('/v1/device/stream', device.deviceToken);
    await quiet.next('hello');
    await active.next('hello');

    server.advance(60_000);
    active.send({ type: 'ping' });
    await active.next('pong');
    assert.equal(server.ctx.hub.sweepIdle(server.now()), 0);

    server.advance(31_000);
    assert.equal(server.ctx.hub.sweepIdle(server.now()), 1);
    assert.equal(await quiet.closed(), CLOSE_IDLE);
    assert.equal(active.closeCode, null);
    assert.equal(server.ctx.hub.connectionCount, 1);
  });
});

describe('avisos ao painel do responsavel', () => {
  test('pedido de vinculo e sua resolucao chegam em tempo real', async () => {
    const panel = await connect('/v1/guardian/stream', guardian.token);
    await panel.next('hello');
    const code = await newPairingCode(server, guardian);
    const claim = await api(server, 'POST', '/v1/pairing/claim', { body: { code, device: deviceInfo({ name: 'Galaxy da Ana' }) } });
    assert.deepEqual(await panel.next('link_pending'), { type: 'link_pending', deviceId: claim.body.linkId });
    const alert = await panel.next('alert');
    assert.equal((alert.alert as { type: string }).type, 'device_linked');
    assert.equal((alert.alert as { deviceId: string }).deviceId, claim.body.linkId);

    await api(server, 'POST', `/v1/guardian/devices/${claim.body.linkId}/approve`, { token: guardian.token, body: { childName: 'Ana' } });
    assert.deepEqual(await panel.next('link_resolved'), {
      type: 'link_resolved',
      deviceId: claim.body.linkId,
      linkId: claim.body.linkId,
      status: 'active',
    });

    const second = await api(server, 'POST', '/v1/pairing/claim', {
      body: { code: await newPairingCode(server, guardian), device: deviceInfo() },
    });
    const mark = panel.messages.length;
    await api(server, 'POST', `/v1/guardian/devices/${second.body.linkId}/reject`, { token: guardian.token });
    assert.deepEqual(await panel.next('link_resolved', mark), {
      type: 'link_resolved',
      deviceId: second.body.linkId,
      linkId: second.body.linkId,
      status: 'rejected',
    });
  });

  test('sincronizacao do aparelho avisa o painel, com alertas e confirmacao da politica', async () => {
    const panel = await connect('/v1/guardian/stream', guardian.token);
    await panel.next('hello');
    const request = event(server, 'time_request', { minutes: 20 });
    await sync(server, device, {
      policyVersion: 1,
      events: [event(server, 'limit_reached', { day: TODAY, limitMs: 60 * MINUTE, quotaUsedMs: 60 * MINUTE }), request],
    });
    assert.deepEqual(await panel.next('device_updated'), { type: 'device_updated', deviceId: device.deviceId });
    assert.deepEqual(await panel.next('policy_applied'), { type: 'policy_applied', deviceId: device.deviceId, version: 1 });
    assert.deepEqual(await panel.next('time_request'), { type: 'time_request', deviceId: device.deviceId, requestId: request.id });
    const alerts = panel.messages.filter((message) => message.type === 'alert').map((message) => (message.alert as { type: string }).type);
    assert.deepEqual(alerts, ['limit_reached', 'time_request']);

    // Uma segunda sincronizacao com a mesma versao nao repete a confirmacao.
    const mark = panel.messages.length;
    await sync(server, device, { policyVersion: 1 });
    await panel.next('device_updated', mark);
    await settle();
    assert.ok(!panel.messages.slice(mark).some((message) => message.type === 'policy_applied'));
  });

  test('quem fez a alteracao nao recebe o proprio aviso, as outras sessoes recebem', async () => {
    const other = await login(server, guardian.email, PASSWORD, 'Moto do Pedro');
    const mine = await connect('/v1/guardian/stream', guardian.token);
    const theirs = await connect('/v1/guardian/stream', other.body.session.token);
    await mine.next('hello');
    await theirs.next('hello');

    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 15 } });
    assert.deepEqual(await theirs.next('device_updated'), { type: 'device_updated', deviceId: device.deviceId });
    const alert = await theirs.next('alert');
    assert.equal((alert.alert as { type: string }).type, 'policy_changed');
    await settle();
    assert.deepEqual(mine.types(), ['hello']);
  });

  test('avisos de uma conta nao chegam a outra', async () => {
    const stranger = await registerGuardian(server);
    const outsider = await connect('/v1/guardian/stream', stranger.token);
    await outsider.next('hello');
    await sync(server, device, { events: [event(server, 'limit_reached', { day: TODAY, limitMs: 1, quotaUsedMs: 1 })] });
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/lock`, { token: guardian.token });
    await settle();
    assert.deepEqual(outsider.types(), ['hello']);
  });
});

describe('avisos ao aparelho', () => {
  test('mudanca de politica, comando e resolucao de pedido pedem sincronizacao', async () => {
    const agent = await connect('/v1/device/stream', device.deviceToken);
    await agent.next('hello');
    assert.equal((await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token })).body.device.online, true);

    await api(server, 'PUT', `/v1/guardian/devices/${device.deviceId}/policy`, {
      token: guardian.token,
      body: { baseVersion: 1, policy: { dailyLimit: { enabled: true, minutes: 60 } } },
    });
    assert.deepEqual(await agent.next('sync_now'), { type: 'sync_now', reason: 'policy' });

    let mark = agent.messages.length;
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/lock`, { token: guardian.token });
    assert.deepEqual(await agent.next('sync_now', mark), { type: 'sync_now', reason: 'command' });

    const request = event(server, 'time_request', { minutes: 10 });
    await sync(server, device, { policyVersion: 3, events: [request] });
    mark = agent.messages.length;
    await api(server, 'POST', `/v1/guardian/time-requests/${request.id}/resolve`, { token: guardian.token, body: { action: 'deny' } });
    assert.deepEqual(await agent.next('sync_now', mark), { type: 'sync_now', reason: 'time_request' });

    // Salvar sem mudanca nao incomoda o aparelho.
    mark = agent.messages.length;
    const current = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token });
    await api(server, 'PUT', `/v1/guardian/devices/${device.deviceId}/policy`, {
      token: guardian.token,
      body: { baseVersion: current.body.policyVersion, policy: current.body.policy },
    });
    await settle();
    assert.equal(agent.messages.length, mark);
  });

  test('aviso so chega ao aparelho certo', async () => {
    const other = await pairDevice(server, guardian, { childName: 'Ana' });
    const agent = await connect('/v1/device/stream', device.deviceToken);
    const sibling = await connect('/v1/device/stream', other.deviceToken);
    await agent.next('hello');
    await sibling.next('hello');
    await api(server, 'POST', `/v1/guardian/devices/${other.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 5 } });
    await sibling.next('sync_now');
    await settle();
    assert.deepEqual(agent.types(), ['hello']);
  });

  test('revogar avisa o aparelho e fecha a conexao', async () => {
    const agent = await connect('/v1/device/stream', device.deviceToken);
    await agent.next('hello');
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/revoke`, { token: guardian.token });
    assert.deepEqual(await agent.next('revoked'), { type: 'revoked' });
    assert.equal(await agent.closed(), CLOSE_UNAUTHORIZED);
    assert.equal((await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token })).body.device.online, false);
    const again = await connect('/v1/device/stream', device.deviceToken);
    assert.equal(await again.closed(), CLOSE_UNAUTHORIZED);
  });

  test('funciona tambem por conexao real de rede', async () => {
    await server.app.listen({ port: 0, host: '127.0.0.1' });
    const address = server.app.server.address();
    assert.ok(address && typeof address === 'object');
    const { WebSocket: RealSocket } = await import('ws');
    const socket = new RealSocket(`ws://127.0.0.1:${address.port}/v1/device/stream`, {
      headers: { authorization: `Bearer ${device.deviceToken}` },
    });
    const client = new Client();
    clients.push(client);
    client.attach(socket);
    await once(socket, 'open');
    assert.equal((await client.next('hello')).serverTime, server.now());
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 5 } });
    assert.deepEqual(await client.next('sync_now'), { type: 'sync_now', reason: 'command' });

    const rejected = new RealSocket(`ws://127.0.0.1:${address.port}/v1/device/stream`);
    const [code] = (await once(rejected, 'close')) as [number];
    assert.equal(code, CLOSE_UNAUTHORIZED);
  });
});
