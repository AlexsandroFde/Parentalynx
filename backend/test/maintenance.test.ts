// Tarefas periodicas: monitor de falta de sincronizacao, retencao e prazos.

import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, test } from 'node:test';

import { runStalenessCheck } from '../src/modules/alerts/monitor.ts';
import { runFrequentTasks, runRetention } from '../src/modules/retention/service.ts';
import {
  api,
  count,
  DAY,
  dayBody,
  deviceInfo,
  event,
  HOUR,
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

let server: TestServer;
let guardian: GuardianAccount;
let device: PairedDevice;

beforeEach(async () => {
  server = await startServer();
  guardian = await registerGuardian(server);
  device = await pairDevice(server, guardian);
});

afterEach(async () => {
  await server.close();
});

interface Alert {
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
}

async function alertsOf(...types: string[]): Promise<Alert[]> {
  const response = await api(server, 'GET', '/v1/guardian/alerts?limit=200', { token: guardian.token });
  return (response.body.alerts as Alert[]).filter((alert) => types.includes(alert.type)).reverse();
}

describe('monitor de falta de sincronizacao', () => {
  test('alerta uma vez quando passa de syncStaleMinutes e outra quando passa de offlineHours', async () => {
    await sync(server, device);
    const lastSync = server.now();

    server.advance(180 * MINUTE);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 0 }, 'no limite exato ainda nao alerta');
    server.advance(MINUTE);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 1, offline: 0 });
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 0 }, 'nao repete para o mesmo periodo');
    server.advance(5 * HOUR);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 0 });

    let alerts = await alertsOf('sync_stale', 'device_offline');
    assert.equal(alerts.length, 1);
    assert.equal(alerts[0]?.type, 'sync_stale');
    assert.equal(alerts[0]?.title, 'Sem sincronização');
    assert.equal(alerts[0]?.body, 'O aparelho de João não sincroniza há 3 horas. As regras continuam valendo no aparelho.');
    assert.equal(alerts[0]?.data.lastSyncAt, lastSync);

    server.advance(16 * HOUR);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 1 });
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 0 });
    alerts = await alertsOf('sync_stale', 'device_offline');
    assert.deepEqual(alerts.map((alert) => alert.type), ['sync_stale', 'device_offline']);
    assert.equal(alerts[1]?.title, 'Aparelho offline');
    assert.match(alerts[1]?.body ?? '', /^O aparelho de João está sem conexão há 24 horas\./);
  });

  test('voltar a sincronizar rearma o monitor para o proximo periodo', async () => {
    await sync(server, device);
    server.advance(4 * HOUR);
    assert.equal(runStalenessCheck(server.ctx).stale, 1);
    await sync(server, device);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 0 });
    server.advance(4 * HOUR);
    assert.equal(runStalenessCheck(server.ctx).stale, 1);
    assert.equal((await alertsOf('sync_stale')).length, 2);
  });

  test('usa os limites configurados na conta', async () => {
    await api(server, 'PATCH', '/v1/guardian/me', { token: guardian.token, body: { settings: { syncStaleMinutes: 30, offlineHours: 6 } } });
    await sync(server, device);
    server.advance(31 * MINUTE);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 1, offline: 0 });
    server.advance(6 * HOUR);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 1 });
  });

  test('aparelho que pula direto para offline recebe so o alerta de offline', async () => {
    await sync(server, device);
    server.advance(30 * HOUR);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 1 });
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 0 });
    assert.deepEqual((await alertsOf('sync_stale', 'device_offline')).map((alert) => alert.type), ['device_offline']);
  });

  test('aparelho que nunca sincronizou conta a partir da aprovacao, e revogado nao gera alerta', async () => {
    const silent = await pairDevice(server, guardian, { childName: 'Ana' });
    await sync(server, device);
    server.advance(4 * HOUR);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 2, offline: 0 });
    const bodies = (await alertsOf('sync_stale')).map((alert) => alert.body);
    assert.ok(bodies.some((body) => body.includes('Ana')));

    await api(server, 'POST', '/v1/guardian/session/elevate', { token: guardian.token, body: { password: PASSWORD } });
    await api(server, 'POST', `/v1/guardian/devices/${silent.deviceId}/revoke`, { token: guardian.token });
    server.advance(30 * HOUR);
    assert.deepEqual(runStalenessCheck(server.ctx), { stale: 0, offline: 1 }, 'so o aparelho ainda vinculado');
  });

  test('o alerta respeita a preferencia de notificacao', async () => {
    await api(server, 'PUT', '/v1/guardian/notification-prefs', { token: guardian.token, body: { sync_stale: false } });
    await sync(server, device);
    server.advance(4 * HOUR);
    runStalenessCheck(server.ctx);
    const response = await api(server, 'GET', '/v1/guardian/alerts?notifyOnly=1&limit=200', { token: guardian.token });
    assert.ok(!response.body.alerts.some((alert: Alert) => alert.type === 'sync_stale'));
    assert.equal((await alertsOf('sync_stale')).length, 1);
  });
});

describe('retencao de dados', () => {
  async function seed(): Promise<void> {
    const response = await sync(server, device, {
      days: [dayBody({ quotaUsedMs: 10 * MINUTE, totalUsedMs: 10 * MINUTE, apps: [{ package: 'com.jogo.a', ms: 10 * MINUTE, opens: 1 }] })],
      sessions: [{ id: randomUUID(), package: 'com.jogo.a', start: server.now() - 10 * MINUTE, end: server.now(), day: TODAY, tzOffsetMin: -180 }],
      events: [event(server, 'blocked_attempt', { reason: 'app_blocked' }, 'com.jogo.b'), event(server, 'time_request', { minutes: 10 })],
      browsing: [{ id: randomUUID(), ts: server.now(), url: 'https://exemplo.com/', domain: 'exemplo.com', title: null, blocked: false, reason: null }],
    });
    assert.equal(response.status, 200);
  }

  const detailTables = ['usage_sessions', 'events', 'browsing', 'time_requests'];

  test('detalhes saem apos retentionDays, agregados apos 400 dias e auditoria apos 365', async () => {
    await seed();
    const alertsBefore = count(server, 'alerts');
    const auditBefore = count(server, 'audit_log');
    assert.ok(alertsBefore > 0 && auditBefore > 0);

    server.advance(89 * DAY);
    let result = runRetention(server.ctx);
    assert.equal(result.sessions + result.events + result.browsing + result.timeRequests + result.alerts, 0, 'dentro do prazo nada sai');
    for (const table of detailTables) assert.ok(count(server, table) > 0, table);

    server.advance(2 * DAY);
    result = runRetention(server.ctx);
    assert.equal(result.sessions, 1);
    assert.equal(result.events, 2);
    assert.equal(result.browsing, 1);
    assert.equal(result.timeRequests, 1);
    assert.equal(result.alerts, alertsBefore);
    for (const table of [...detailTables, 'alerts']) assert.equal(count(server, table), 0, table);
    // Agregados diarios e auditoria continuam.
    assert.equal(count(server, 'usage_day'), 1);
    assert.equal(count(server, 'usage_app'), 1);
    assert.equal(count(server, 'audit_log'), auditBefore);
    const report = await server.app.inject({
      method: 'GET',
      url: `/v1/guardian/devices/${device.deviceId}/reports/summary?from=${TODAY}&to=${TODAY}`,
      headers: { authorization: `Bearer ${(await relogin()).token}` },
    });
    assert.equal(JSON.parse(report.body).totals.totalMs, 10 * MINUTE, 'o relatorio agregado continua disponivel');

    server.advance(275 * DAY);
    result = runRetention(server.ctx);
    assert.equal(result.audit, auditBefore, 'a auditoria antiga sai com 365 dias');
    assert.equal(count(server, 'usage_day'), 1);

    server.advance(35 * DAY);
    result = runRetention(server.ctx);
    assert.equal(result.usageDays, 1);
    assert.equal(result.usageApps, 1);
    assert.equal(count(server, 'usage_day'), 0);
  });

  async function relogin(): Promise<{ token: string }> {
    const response = await api(server, 'POST', '/v1/auth/login', {
      body: { email: guardian.email, password: PASSWORD, deviceName: 'Novo' },
    });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    return { token: response.body.session.token };
  }

  test('cada conta segue a sua propria retencao', async () => {
    await seed();
    const other = await registerGuardian(server);
    const otherDevice = await pairDevice(server, other);
    await api(server, 'PATCH', '/v1/guardian/me', { token: other.token, body: { settings: { retentionDays: 30 } } });
    await sync(server, otherDevice, { events: [event(server, 'device_boot')] });

    server.advance(31 * DAY);
    const result = runRetention(server.ctx);
    assert.equal(result.events, 1);
    assert.equal(count(server, 'events', 'device_id = ?', otherDevice.deviceId), 0);
    assert.equal(count(server, 'events', 'device_id = ?', device.deviceId), 2, 'a conta com 90 dias mantem os dela');
  });

  test('limpa sessoes vencidas, codigos e pedidos de vinculo antigos', async () => {
    await newPairingCode(server, guardian);
    const expiredSession = await api(server, 'POST', '/v1/auth/login', { body: { email: guardian.email, password: PASSWORD, deviceName: 'Velho' } });
    await api(server, 'DELETE', `/v1/guardian/sessions/${expiredSession.body.session.id}`, { token: guardian.token });
    assert.equal(count(server, 'pairing_codes'), 2);
    assert.equal(count(server, 'links'), 1);
    assert.equal(count(server, 'sessions'), 2);

    server.advance(6 * DAY);
    assert.equal(runRetention(server.ctx).housekeeping, 0);
    server.advance(2 * DAY);
    const result = runRetention(server.ctx);
    assert.equal(result.housekeeping, 4, 'dois codigos, um pedido entregue e uma sessao revogada');
    assert.equal(count(server, 'pairing_codes'), 0);
    assert.equal(count(server, 'links'), 0);
    assert.equal(count(server, 'sessions'), 1, 'a sessao em uso continua');
    assert.equal((await sync(server, device)).status, 200, 'o aparelho vinculado nao e afetado');
  });
});

describe('prazos', () => {
  test('tarefas frequentes expiram pedidos de vinculo e de tempo', async () => {
    const code = await newPairingCode(server, guardian);
    const claim = await api(server, 'POST', '/v1/pairing/claim', { body: { code, device: deviceInfo() } });
    await sync(server, device, { events: [event(server, 'time_request', { minutes: 10 })] });

    server.advance(29 * MINUTE);
    runFrequentTasks(server.ctx);
    assert.equal(count(server, 'links', "status = 'pending'"), 1);
    server.advance(MINUTE);
    runFrequentTasks(server.ctx);
    assert.equal(count(server, 'links', "status = 'expired' AND id = ?", claim.body.linkId), 1);
    assert.equal(count(server, 'time_requests', "status = 'pending'"), 1);

    server.advance(24 * HOUR);
    runFrequentTasks(server.ctx);
    assert.equal(count(server, 'time_requests', "status = 'expired'"), 1);
  });

  test('a limpeza do limitador de taxa descarta janelas vencidas', async () => {
    await api(server, 'POST', '/v1/auth/login', { body: { email: 'x@exemplo.com', password: PASSWORD, deviceName: 'x' } });
    assert.ok(server.ctx.rate.size > 0);
    server.advance(2 * HOUR);
    runFrequentTasks(server.ctx);
    assert.equal(server.ctx.rate.size, 0);
  });
});
