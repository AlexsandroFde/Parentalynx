// Rotas do aparelho: sincronizacao, inventario, icones, pedidos de tempo e senha no aparelho.

import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, test } from 'node:test';

import {
  api,
  count,
  DAY,
  dayBody,
  event,
  HOUR,
  hourly,
  login,
  MINUTE,
  pairDevice,
  PASSWORD,
  PNG_1X1,
  registerGuardian,
  startServer,
  statusBody,
  sync,
  syncBody,
  TODAY,
} from './helpers.ts';
import type { ApiResponse, GuardianAccount, PairedDevice, TestServer } from './helpers.ts';

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

async function deviceView(): Promise<ApiResponse> {
  return api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token });
}

function session(pkg: string, start: number, end: number, id: string = randomUUID()): Record<string, unknown> {
  return { id, package: pkg, start, end, day: TODAY, tzOffsetMin: -180 };
}

function visit(url: string, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { id: randomUUID(), ts: server.now(), url, domain: new URL(url).hostname, title: 'Página', blocked: false, reason: null, ...overrides };
}

describe('sincronizacao de configuracoes', () => {
  test('a primeira sincronizacao entrega a politica e os dados da conta', async () => {
    const response = await sync(server, device, { policyVersion: 0, policyAppliedAt: null });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.serverTime, server.now());
    assert.equal(response.body.policyVersion, 1);
    assert.equal(response.body.policy.schema, 1);
    assert.deepEqual(response.body.ack, { sessions: [], events: [], browsing: [], days: [] });
    assert.deepEqual(response.body.reconcile, { day: TODAY, quotaUsedMs: 0, totalUsedMs: 0 });
    assert.deepEqual(response.body.timeRequests, []);
    assert.equal(response.body.childName, 'João');
    assert.equal(response.body.guardianName, 'Maria');
    assert.equal(response.body.lowTimeMinutes, 10);
    assert.equal(response.body.needAppInventory, true);
  });

  test('o aparelho confirma a versao aplicada e deixa de receber a politica', async () => {
    const appliedAt = server.now() - 5_000;
    const response = await sync(server, device, { policyVersion: 1, policyAppliedAt: appliedAt });
    assert.equal(response.body.policy, null);
    assert.equal(response.body.policyVersion, 1);
    const view = await deviceView();
    assert.equal(view.body.device.appliedPolicyVersion, 1);
    assert.equal(view.body.device.policyAppliedAt, appliedAt);
    assert.equal(view.body.device.lastSyncAt, server.now());
    assert.equal(view.body.device.online, true);
  });

  test('alteracao do responsavel chega na sincronizacao seguinte e fica pendente ate ser aplicada', async () => {
    await sync(server, device);
    const changed = await api(server, 'PUT', `/v1/guardian/devices/${device.deviceId}/policy`, {
      token: guardian.token,
      body: { baseVersion: 1, policy: { dailyLimit: { enabled: true, minutes: 90 } } },
    });
    assert.equal(changed.body.policyVersion, 2);
    let view = await deviceView();
    assert.equal(view.body.device.policyVersion, 2);
    assert.equal(view.body.device.appliedPolicyVersion, 1, 'ainda nao confirmada pelo aparelho');

    const delivered = await sync(server, device, { policyVersion: 1 });
    assert.equal(delivered.body.policyVersion, 2);
    assert.equal(delivered.body.policy.dailyLimit.minutes, 90);
    assert.equal(delivered.body.policy.dailyLimit.enabled, true);

    await sync(server, device, { policyVersion: 2, policyAppliedAt: server.now() });
    view = await deviceView();
    assert.equal(view.body.device.appliedPolicyVersion, 2);
  });

  test('a conta leva as preferencias ao aparelho (minutos de pouco tempo e nome da crianca)', async () => {
    await api(server, 'PATCH', '/v1/guardian/me', { token: guardian.token, body: { settings: { lowTimeMinutes: 20 } } });
    await api(server, 'PATCH', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token, body: { childName: 'João Pedro' } });
    const response = await sync(server, device);
    assert.equal(response.body.lowTimeMinutes, 20);
    assert.equal(response.body.childName, 'João Pedro');
  });

  test('o retrato do aparelho aparece no painel com o resumo do dia', async () => {
    await sync(server, device, {
      status: statusBody({
        managementMode: 'device_owner',
        lock: { state: 'daily_limit', releaseAt: server.now() + 12 * HOUR },
        enforcement: { active: true, issues: ['overlay_missing'] },
        foregroundApp: null,
        batteryPercent: 42,
      }),
      days: [dayBody({ quotaUsedMs: 90 * MINUTE, totalUsedMs: 100 * MINUTE, limitMs: 120 * MINUTE, extraMs: 30 * MINUTE, limitReachedAt: null })],
    });
    const view = await deviceView();
    assert.equal(view.body.device.managementMode, 'device_owner');
    const state = view.body.device.state;
    assert.equal(state.reportedAt, server.now());
    assert.equal(state.day, TODAY);
    assert.equal(state.quotaUsedMs, 90 * MINUTE);
    assert.equal(state.totalUsedMs, 100 * MINUTE);
    assert.equal(state.limitMs, 120 * MINUTE);
    assert.equal(state.extraMs, 30 * MINUTE);
    assert.equal(state.remainingMs, 30 * MINUTE);
    assert.deepEqual(state.lock, { state: 'daily_limit', releaseAt: server.now() + 12 * HOUR });
    assert.deepEqual(state.enforcement.issues, ['overlay_missing']);
    assert.equal(state.batteryPercent, 42);
    assert.equal(state.permissions.accessibility, true);
    assert.equal(state.clockTrusted, true);
  });

  test('aparelho fica offline 2 minutos depois da ultima sincronizacao', async () => {
    await sync(server, device);
    server.advance(2 * MINUTE - 1);
    assert.equal((await deviceView()).body.device.online, true);
    server.advance(2);
    assert.equal((await deviceView()).body.device.online, false);
  });
});

describe('contagem de tempo e reconciliacao', () => {
  test('o servidor guarda o maior valor de cada contador e o devolve', async () => {
    const first = await sync(server, device, {
      days: [
        dayBody({
          quotaUsedMs: 60 * MINUTE,
          totalUsedMs: 70 * MINUTE,
          firstUseAt: server.now() - 2 * HOUR,
          lastUseAt: server.now() - HOUR,
          apps: [
            { package: 'com.whatsapp', ms: 30 * MINUTE, opens: 5 },
            { package: 'com.jogo.a', ms: 40 * MINUTE, opens: 2 },
          ],
          hourly: hourly({ 10: 30 * MINUTE, 11: 40 * MINUTE }),
        }),
      ],
    });
    assert.deepEqual(first.body.reconcile, { day: TODAY, quotaUsedMs: 60 * MINUTE, totalUsedMs: 70 * MINUTE });

    // O aparelho reenvia valores MENORES (por exemplo depois de perder os dados locais).
    const lower = await sync(server, device, {
      days: [
        dayBody({
          quotaUsedMs: 10 * MINUTE,
          totalUsedMs: 15 * MINUTE,
          firstUseAt: server.now() - 30 * MINUTE,
          lastUseAt: server.now(),
          apps: [
            { package: 'com.whatsapp', ms: 5 * MINUTE, opens: 1 },
            { package: 'com.novo.app', ms: 10 * MINUTE, opens: 1 },
          ],
          hourly: hourly({ 11: 10 * MINUTE, 12: 5 * MINUTE }),
        }),
      ],
    });
    assert.deepEqual(lower.body.reconcile, { day: TODAY, quotaUsedMs: 60 * MINUTE, totalUsedMs: 70 * MINUTE }, 'o tempo nunca diminui');

    const row = server.ctx.db.get<{ hourly: string; first_use_at: number; last_use_at: number }>(
      'SELECT hourly, first_use_at, last_use_at FROM usage_day WHERE device_id = ? AND day = ?',
      device.deviceId,
      TODAY,
    );
    assert.ok(row);
    const stored = JSON.parse(row.hourly) as number[];
    assert.equal(stored[10], 30 * MINUTE);
    assert.equal(stored[11], 40 * MINUTE);
    assert.equal(stored[12], 5 * MINUTE);
    assert.equal(row.first_use_at, server.now() - 2 * HOUR);
    assert.equal(row.last_use_at, server.now());
    const apps = server.ctx.db.all<{ package: string; ms: number; opens: number }>(
      'SELECT package, ms, opens FROM usage_app WHERE device_id = ? ORDER BY package',
      device.deviceId,
    );
    assert.deepEqual(
      apps.map((app) => ({ ...app })),
      [
        { package: 'com.jogo.a', ms: 40 * MINUTE, opens: 2 },
        { package: 'com.novo.app', ms: 10 * MINUTE, opens: 1 },
        { package: 'com.whatsapp', ms: 30 * MINUTE, opens: 5 },
      ],
    );

    // Valor maior passa a valer.
    const higher = await sync(server, device, { days: [dayBody({ quotaUsedMs: 61 * MINUTE, totalUsedMs: 75 * MINUTE })] });
    assert.deepEqual(higher.body.reconcile, { day: TODAY, quotaUsedMs: 61 * MINUTE, totalUsedMs: 75 * MINUTE });
  });

  test('dias anteriores sao confirmados, o dia corrente e sempre o ultimo', async () => {
    const response = await sync(server, device, {
      days: [
        dayBody({ day: '2026-11-15', quotaUsedMs: 100, totalUsedMs: 100 }),
        dayBody({ day: '2026-11-16', quotaUsedMs: 200, totalUsedMs: 200 }),
        dayBody({ day: TODAY, quotaUsedMs: 300, totalUsedMs: 300 }),
      ],
    });
    assert.deepEqual(response.body.ack.days, ['2026-11-15', '2026-11-16']);
    assert.deepEqual(response.body.reconcile, { day: TODAY, quotaUsedMs: 300, totalUsedMs: 300 });
    assert.equal(count(server, 'usage_day', 'device_id = ?', device.deviceId), 3);
  });

  test('dia impossivel (relogio do aparelho errado) e descartado, mas confirmado', async () => {
    const response = await sync(server, device, {
      days: [dayBody({ day: '2031-01-01', quotaUsedMs: 999, totalUsedMs: 999 }), dayBody({ day: TODAY, quotaUsedMs: 5, totalUsedMs: 5 })],
    });
    assert.deepEqual(response.body.ack.days, ['2031-01-01']);
    assert.equal(count(server, 'usage_day', 'device_id = ?', device.deviceId), 1);
  });

  test('sem dia informado nao ha reconciliacao', async () => {
    const response = await sync(server, device, { days: [] });
    assert.equal(response.status, 200);
    assert.equal(response.body.reconcile, null);
    assert.equal((await deviceView()).body.device.state.remainingMs, null);
  });
});

describe('fila de saida e idempotencia', () => {
  test('reenvio do mesmo lote nao duplica sessoes, eventos, navegacao nem alertas', async () => {
    const batch = {
      sessions: [session('com.whatsapp', server.now() - 20 * MINUTE, server.now() - 10 * MINUTE), session('com.jogo.a', server.now() - 10 * MINUTE, server.now())],
      events: [
        event(server, 'blocked_attempt', { reason: 'app_blocked' }, 'com.jogo.a'),
        event(server, 'limit_reached', { day: TODAY, limitMs: 2 * HOUR, quotaUsedMs: 2 * HOUR }),
        event(server, 'device_boot'),
      ],
      browsing: [visit('https://exemplo.com/a'), visit('https://apostas.exemplo.com/', { blocked: true, reason: 'category' })],
    };
    const first = await sync(server, device, batch);
    assert.equal(first.status, 200, JSON.stringify(first.body));
    assert.deepEqual(first.body.ack.sessions, batch.sessions.map((item) => item.id));
    assert.deepEqual(first.body.ack.events, batch.events.map((item) => item.id));
    assert.deepEqual(first.body.ack.browsing, batch.browsing.map((item) => item.id));
    const fromEvents = "device_id = ? AND type IN ('blocked_app_attempt', 'limit_reached')";
    const alertsAfterFirst = count(server, 'alerts', fromEvents, device.deviceId);

    // A confirmacao se perdeu no caminho: o aparelho reenvia tudo.
    const second = await sync(server, device, batch);
    assert.deepEqual(second.body.ack, first.body.ack);
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', device.deviceId), 2);
    assert.equal(count(server, 'events', 'device_id = ?', device.deviceId), 3);
    assert.equal(count(server, 'browsing', 'device_id = ?', device.deviceId), 2);
    assert.equal(count(server, 'alerts', fromEvents, device.deviceId), alertsAfterFirst, 'alertas nao se repetem');
    assert.equal(alertsAfterFirst, 2);
  });

  test('itens sem sentido sao descartados mas confirmados, para nao travar a fila', async () => {
    const backwards = session('com.app.x', server.now(), server.now() - 1000);
    const tooLong = session('com.app.y', server.now() - 3 * DAY, server.now());
    const fine = session('com.app.z', server.now() - 1000, server.now());
    const response = await sync(server, device, { sessions: [backwards, tooLong, fine] });
    assert.deepEqual(response.body.ack.sessions, [backwards.id, tooLong.id, fine.id]);
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', device.deviceId), 1);
  });

  test('lotes acima do limite respondem payload_too_large', async () => {
    const sessions = Array.from({ length: 501 }, () => session('com.app.x', server.now() - 1000, server.now()));
    const tooManySessions = await sync(server, device, { sessions });
    assert.equal(tooManySessions.status, 413);
    assert.equal(tooManySessions.body.error.code, 'payload_too_large');
    const events = Array.from({ length: 501 }, () => event(server, 'device_boot'));
    assert.equal((await sync(server, device, { events })).status, 413);
    const browsing = Array.from({ length: 501 }, () => visit('https://exemplo.com/'));
    assert.equal((await sync(server, device, { browsing })).status, 413);
    const days = Array.from({ length: 9 }, (_, index) => dayBody({ day: `2026-11-0${index + 1}` }));
    assert.equal((await sync(server, device, { days })).status, 413);
    assert.equal(count(server, 'usage_sessions'), 0);

    // No limite exato passa.
    const exact = await sync(server, device, { sessions: sessions.slice(0, 500) });
    assert.equal(exact.status, 200);
    assert.equal(exact.body.ack.sessions.length, 500);
  });

  test('corpo invalido e recusado com os campos apontados', async () => {
    const response = await sync(server, device, {
      policyVersion: -1,
      status: statusBody({ managementMode: 'root', lock: { state: 'preso', releaseAt: null } }),
      days: [dayBody({ day: '17/11/2026', hourly: [1, 2, 3] })],
      sessions: [{ id: '', package: 'com.app', start: 1, end: 2, day: TODAY }],
      events: [{ id: 'e1', type: 'Tipo Invalido', ts: 1 }],
    });
    assert.equal(response.status, 400);
    assert.equal(response.body.error.code, 'validation_error');
    assert.deepEqual(response.body.error.details.fields, [
      'policyVersion',
      'status.managementMode',
      'status.lock.state',
      'days[0].day',
      'days[0].hourly',
      'sessions[0].id',
      'events[0].type',
    ]);
  });
});

describe('inventario de aplicativos', () => {
  const apps = [
    { package: 'com.whatsapp', label: 'WhatsApp', category: 'communication', system: false, launchable: true, essential: false, versionName: '2.24', installedAt: 1, updatedAt: 2, iconHash: 'aabbccdd00112233' },
    { package: 'com.jogo.a', label: 'Jogo A', category: 'games', system: false, launchable: true, essential: false, versionName: '1.0', installedAt: 1, updatedAt: 2, iconHash: '1122334455667788' },
    { package: 'com.android.settings', label: 'Configurações', category: 'system', system: true, launchable: true, essential: false, versionName: '14', installedAt: 1, updatedAt: 2, iconHash: null },
    { package: 'com.android.dialer', label: 'Telefone', category: 'categoria-nova', system: true, launchable: true, essential: true, versionName: null, installedAt: null, updatedAt: null, iconHash: null },
  ];

  async function putApps(list: unknown[] = apps, full = true): Promise<ApiResponse> {
    return api(server, 'PUT', '/v1/device/apps', { token: device.deviceToken, body: { full, apps: list } });
  }

  test('grava o inventario, pede os icones que faltam e os serve ao painel', async () => {
    const inventory = await putApps();
    assert.equal(inventory.status, 200, JSON.stringify(inventory.body));
    assert.deepEqual(inventory.body.needIcons, ['com.jogo.a', 'com.whatsapp']);
    assert.equal((await sync(server, device)).body.needAppInventory, false);

    const upload = await api(server, 'PUT', '/v1/device/apps/icon?package=com.whatsapp&hash=aabbccdd00112233', {
      token: device.deviceToken,
      body: PNG_1X1,
      headers: { 'content-type': 'image/png' },
    });
    assert.equal(upload.status, 204);
    assert.deepEqual((await putApps()).body.needIcons, ['com.jogo.a'], 'so falta o que ainda nao foi enviado');

    const list = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/apps`, { token: guardian.token });
    assert.equal(list.body.day, TODAY);
    const byPackage = new Map<string, Record<string, unknown>>(list.body.apps.map((app: { package: string }) => [app.package, app]));
    const whatsapp = byPackage.get('com.whatsapp');
    assert.ok(whatsapp);
    assert.equal(whatsapp.label, 'WhatsApp');
    assert.equal(whatsapp.category, 'communication');
    assert.equal(whatsapp.iconHash, 'aabbccdd00112233');
    assert.equal(whatsapp.iconUrl, `/v1/guardian/devices/${device.deviceId}/apps/icon?package=com.whatsapp&v=aabbccdd00112233`);
    assert.equal(byPackage.get('com.jogo.a')?.iconUrl, null);
    assert.equal(byPackage.get('com.android.dialer')?.category, 'other', 'categoria desconhecida vira other');
    assert.equal(byPackage.get('com.android.dialer')?.essential, true);

    const icon = await api(server, 'GET', String(whatsapp.iconUrl), { token: guardian.token });
    assert.equal(icon.status, 200);
    assert.equal(icon.headers['content-type'], 'image/png');
    assert.equal(icon.headers.etag, '"aabbccdd00112233"');
    assert.deepEqual(icon.raw, PNG_1X1);
    const cached = await api(server, 'GET', String(whatsapp.iconUrl), {
      token: guardian.token,
      headers: { 'if-none-match': '"aabbccdd00112233"' },
    });
    assert.equal(cached.status, 304);
    assert.equal((await api(server, 'GET', String(whatsapp.iconUrl))).status, 401, 'icone exige sessao do responsavel');
    const missing = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/apps/icon?package=com.jogo.a`, { token: guardian.token });
    assert.equal(missing.status, 404);
  });

  test('icone invalido ou grande demais e recusado', async () => {
    await putApps();
    const notPng = await api(server, 'PUT', '/v1/device/apps/icon?package=com.whatsapp&hash=aabbccdd00112233', {
      token: device.deviceToken,
      body: Buffer.from('isto nao e uma imagem'),
      headers: { 'content-type': 'image/png' },
    });
    assert.equal(notPng.status, 400);
    const big = await api(server, 'PUT', '/v1/device/apps/icon?package=com.whatsapp&hash=aabbccdd00112233', {
      token: device.deviceToken,
      body: Buffer.concat([PNG_1X1, Buffer.alloc(64 * 1024)]),
      headers: { 'content-type': 'image/png' },
    });
    assert.equal(big.status, 413);
    assert.equal(big.body.error.code, 'payload_too_large');
    const unknown = await api(server, 'PUT', '/v1/device/apps/icon?package=com.nao.existe&hash=aabbccdd00112233', {
      token: device.deviceToken,
      body: PNG_1X1,
      headers: { 'content-type': 'image/png' },
    });
    assert.equal(unknown.status, 404);
    const noPackage = await api(server, 'PUT', '/v1/device/apps/icon', {
      token: device.deviceToken,
      body: PNG_1X1,
      headers: { 'content-type': 'image/png' },
    });
    assert.equal(noPackage.status, 400);
  });

  test('inventario completo marca como removido o que nao veio, e o parcial so acrescenta', async () => {
    await putApps();
    await putApps(apps.slice(0, 2), true);
    let list = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/apps`, { token: guardian.token });
    const removed = (list.body.apps as { package: string; removed: boolean }[]).filter((app) => app.removed).map((app) => app.package);
    assert.deepEqual(removed.sort(), ['com.android.dialer', 'com.android.settings']);

    // Reinstalado: volta a aparecer como presente.
    await putApps([apps[2]], false);
    list = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/apps`, { token: guardian.token });
    const stillRemoved = (list.body.apps as { package: string; removed: boolean }[]).filter((app) => app.removed).map((app) => app.package);
    assert.deepEqual(stillRemoved, ['com.android.dialer']);
    assert.equal(list.body.apps.length, 4);
  });

  test('o painel ve o estado de cada app conforme a politica e o uso de hoje e da semana', async () => {
    await putApps([
      ...apps,
      { package: 'com.novo.app', label: 'App Novo', category: 'other', system: false, launchable: true, essential: false, versionName: '1', installedAt: 1, updatedAt: 1, iconHash: null },
    ]);
    await api(server, 'PUT', `/v1/guardian/devices/${device.deviceId}/policy`, {
      token: guardian.token,
      body: {
        baseVersion: 1,
        policy: {
          apps: {
            defaultForNewApps: 'blocked',
            rules: {
              'com.whatsapp': { state: 'exception', countsTowardLimit: false },
              'com.jogo.a': { state: 'allowed', dailyLimitMinutes: 45 },
              'com.android.dialer': { state: 'blocked' },
            },
          },
        },
      },
    });
    await sync(server, device, {
      policyVersion: 2,
      days: [
        dayBody({ day: '2026-11-12', apps: [{ package: 'com.jogo.a', ms: 20 * MINUTE, opens: 1 }] }),
        dayBody({ day: '2026-11-10', apps: [{ package: 'com.jogo.a', ms: 99 * MINUTE, opens: 1 }] }),
        dayBody({ apps: [{ package: 'com.jogo.a', ms: 30 * MINUTE, opens: 4 }, { package: 'com.whatsapp', ms: 5 * MINUTE, opens: 2 }] }),
      ],
    });
    const list = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/apps`, { token: guardian.token });
    const byPackage = new Map<string, Record<string, unknown>>(list.body.apps.map((app: { package: string }) => [app.package, app]));
    const pick = (pkg: string) => {
      const app = byPackage.get(pkg);
      assert.ok(app, pkg);
      return { state: app.state, countsTowardLimit: app.countsTowardLimit, dailyLimitMinutes: app.dailyLimitMinutes, todayMs: app.todayMs, weekMs: app.weekMs };
    };
    assert.deepEqual(pick('com.whatsapp'), { state: 'exception', countsTowardLimit: false, dailyLimitMinutes: null, todayMs: 5 * MINUTE, weekMs: 5 * MINUTE });
    // A semana cobre os ultimos 7 dias (11 a 17): o uso do dia 10 fica de fora.
    assert.deepEqual(pick('com.jogo.a'), { state: 'allowed', countsTowardLimit: true, dailyLimitMinutes: 45, todayMs: 30 * MINUTE, weekMs: 50 * MINUTE });
    assert.deepEqual(pick('com.novo.app'), { state: 'blocked', countsTowardLimit: false, dailyLimitMinutes: null, todayMs: 0, weekMs: 0 });
    assert.equal(pick('com.android.settings').state, 'allowed', 'app de sistema sem regra continua liberado');
    assert.equal(pick('com.android.dialer').state, 'allowed', 'pacote essencial nunca aparece como bloqueado');
  });

  test('inventario invalido ou grande demais e recusado', async () => {
    const invalid = await putApps([{ package: 'com.app', label: '', category: 'games', system: 'sim', launchable: true }]);
    assert.equal(invalid.status, 400);
    assert.deepEqual(invalid.body.error.details.fields, ['apps[0].system']);
    const many = Array.from({ length: 3001 }, (_, index) => ({ ...apps[0], package: `com.app.n${index}` }));
    assert.equal((await putApps(many)).status, 413);
  });
});

describe('pedido de tempo adicional', () => {
  test('o pedido chega ao responsavel, a aprovacao vira tempo extra e volta para o aparelho', async () => {
    const request = event(server, 'time_request', { minutes: 30, message: '  Falta pouco para terminar a fase  ' });
    const sent = await sync(server, device, { events: [request] });
    assert.deepEqual(sent.body.timeRequests, [{ id: request.id, status: 'pending', grantedMinutes: null, resolvedAt: null }]);

    const view = await deviceView();
    assert.equal(view.body.device.pendingTimeRequests, 1);
    const pending = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/time-requests?status=pending`, { token: guardian.token });
    assert.deepEqual(pending.body.requests, [
      {
        id: request.id,
        deviceId: device.deviceId,
        childName: 'João',
        createdAt: server.now(),
        minutes: 30,
        message: 'Falta pouco para terminar a fase',
        status: 'pending',
        grantedMinutes: null,
        resolvedAt: null,
      },
    ]);
    const alerts = await api(server, 'GET', '/v1/guardian/alerts', { token: guardian.token });
    const alert = alerts.body.alerts.find((item: { type: string }) => item.type === 'time_request');
    assert.equal(alert.title, 'Pedido de mais tempo');
    assert.equal(alert.body, 'João pediu mais 30 min: "Falta pouco para terminar a fase"');
    assert.equal(alert.data.requestId, request.id);

    server.advance(MINUTE);
    const approved = await api(server, 'POST', `/v1/guardian/time-requests/${request.id}/resolve`, {
      token: guardian.token,
      body: { action: 'approve', minutes: 20 },
    });
    assert.equal(approved.status, 200, JSON.stringify(approved.body));
    assert.equal(approved.body.request.status, 'approved');
    assert.equal(approved.body.request.grantedMinutes, 20);
    assert.equal(approved.body.request.resolvedAt, server.now());
    assert.equal(approved.body.policyVersion, 2);

    const delivered = await sync(server, device, { policyVersion: 1 });
    assert.equal(delivered.body.policyVersion, 2);
    assert.deepEqual(
      delivered.body.policy.overrides.extraTime.map((entry: { day: string; minutes: number }) => [entry.day, entry.minutes]),
      [[TODAY, 20]],
    );
    assert.deepEqual(delivered.body.timeRequests, [{ id: request.id, status: 'approved', grantedMinutes: 20, resolvedAt: server.now() }]);

    const again = await api(server, 'POST', `/v1/guardian/time-requests/${request.id}/resolve`, { token: guardian.token, body: { action: 'deny' } });
    assert.equal(again.status, 409);
    assert.equal((await deviceView()).body.device.pendingTimeRequests, 0);
  });

  test('aprovar sem informar minutos usa o que a crianca pediu, e negar nao altera a politica', async () => {
    const first = event(server, 'time_request', { minutes: 45 });
    const second = event(server, 'time_request', {});
    await sync(server, device, { events: [first, second] });

    const approved = await api(server, 'POST', `/v1/guardian/time-requests/${first.id}/resolve`, { token: guardian.token, body: { action: 'approve' } });
    assert.equal(approved.body.request.grantedMinutes, 45);
    const denied = await api(server, 'POST', `/v1/guardian/time-requests/${second.id}/resolve`, { token: guardian.token, body: { action: 'deny' } });
    assert.equal(denied.body.request.status, 'denied');
    assert.equal(denied.body.request.grantedMinutes, null);
    assert.equal(denied.body.policyVersion, 2, 'negar nao cria versao');

    const all = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/time-requests`, { token: guardian.token });
    assert.deepEqual(all.body.requests.map((item: { status: string }) => item.status).sort(), ['approved', 'denied']);
    const badStatus = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/time-requests?status=talvez`, { token: guardian.token });
    assert.equal(badStatus.status, 400);
  });

  test('pedido pendente expira em 24 horas', async () => {
    const request = event(server, 'time_request', { minutes: 15 });
    await sync(server, device, { events: [request] });
    server.advance(24 * HOUR);
    await api(server, 'POST', '/v1/guardian/session/elevate', { token: guardian.token, body: { password: PASSWORD } });
    const late = await api(server, 'POST', `/v1/guardian/time-requests/${request.id}/resolve`, { token: guardian.token, body: { action: 'approve' } });
    assert.equal(late.status, 409);
    assert.equal(late.body.error.details.status, 'expired');
    const list = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/time-requests`, { token: guardian.token });
    assert.equal(list.body.requests[0].status, 'expired');
  });

  test('pedido de outra conta nao pode ser resolvido', async () => {
    const request = event(server, 'time_request', { minutes: 15 });
    await sync(server, device, { events: [request] });
    const stranger = await registerGuardian(server);
    const response = await api(server, 'POST', `/v1/guardian/time-requests/${request.id}/resolve`, { token: stranger.token, body: { action: 'approve' } });
    assert.equal(response.status, 403);
    const missing = await api(server, 'POST', `/v1/guardian/time-requests/${randomUUID()}/resolve`, { token: guardian.token, body: { action: 'approve' } });
    assert.equal(missing.status, 404);
  });
});

describe('autenticacao do responsavel no aparelho da crianca', () => {
  const verify = (password: string) => api(server, 'POST', '/v1/device/admin-verify', { token: device.deviceToken, body: { password } });

  test('confere a senha administrativa sem expor nada alem do resultado', async () => {
    const ok = await verify(PASSWORD);
    assert.equal(ok.status, 200);
    assert.deepEqual(ok.body, { ok: true });
    const wrong = await verify('Senha#Errada99');
    assert.equal(wrong.status, 401);
    assert.equal(wrong.body.error.code, 'invalid_credentials');
    assert.equal(wrong.body.error.details.attemptsLeft, 4);
  });

  test('5 falhas bloqueiam o aparelho por 5 minutos, dobrando, sem afetar a conta', async () => {
    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const response = await verify('Senha#Errada99');
      assert.equal(response.status, 401);
      assert.equal(response.body.error.details.attemptsLeft, 5 - attempt);
    }
    const locked = await verify(PASSWORD);
    assert.equal(locked.status, 423);
    assert.equal(locked.body.error.code, 'account_locked');
    assert.equal(locked.body.error.details.retryAfterSec, 300);

    // A conta do responsavel continua livre: o contador e do aparelho.
    assert.equal((await login(server, guardian.email, PASSWORD)).status, 200);
    const alerts = await api(server, 'GET', '/v1/guardian/alerts', { token: guardian.token });
    const security = alerts.body.alerts.filter((alert: { type: string }) => alert.type === 'security_event');
    assert.equal(security.length, 1);
    assert.equal(security[0].title, 'Tentativas de senha no aparelho');
    assert.equal(security[0].data.attempts, 5);

    server.advance(5 * MINUTE + 1);
    assert.equal((await verify('Senha#Errada99')).status, 401);
    assert.equal((await verify(PASSWORD)).body.error.details.retryAfterSec, 600, 'dobra para 10 minutos');
    server.advance(10 * MINUTE + 1);
    assert.equal((await verify(PASSWORD)).status, 200);
    assert.equal((await verify('Senha#Errada99')).body.error.details.attemptsLeft, 4, 'o acerto zera o contador');
  });

  test('desvincular pelo aparelho exige a senha e revoga o token', async () => {
    const wrong = await api(server, 'POST', '/v1/device/unlink', { token: device.deviceToken, body: { password: 'Senha#Errada99' } });
    assert.equal(wrong.status, 401);
    assert.equal((await sync(server, device)).status, 200);

    const unlinked = await api(server, 'POST', '/v1/device/unlink', { token: device.deviceToken, body: { password: PASSWORD } });
    assert.equal(unlinked.status, 204);
    const after = await sync(server, device);
    assert.equal(after.status, 401);
    assert.equal(after.body.error.code, 'device_revoked');
    const view = await deviceView();
    assert.equal(view.body.device.status, 'revoked');
    assert.equal(view.body.device.revokedAt, server.now());
    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    assert.ok(audit.body.entries.some((entry: { action: string }) => entry.action === 'device.unlink'));
  });
});

describe('token do aparelho', () => {
  test('token ausente, desconhecido ou de sessao e recusado em todas as rotas do aparelho', async () => {
    for (const token of [undefined, 'dv_desconhecido', guardian.token]) {
      const options = token === undefined ? {} : { token };
      assert.equal((await api(server, 'POST', '/v1/device/sync', { ...options, body: syncBody(server) })).status, 401);
      assert.equal((await api(server, 'PUT', '/v1/device/apps', { ...options, body: { full: true, apps: [] } })).status, 401);
      assert.equal((await api(server, 'POST', '/v1/device/admin-verify', { ...options, body: { password: PASSWORD } })).status, 401);
      assert.equal((await api(server, 'POST', '/v1/device/unlink', { ...options, body: { password: PASSWORD } })).status, 401);
    }
  });

  test('token de aparelho nao da acesso as rotas do responsavel', async () => {
    assert.equal((await api(server, 'GET', '/v1/guardian/devices', { token: device.deviceToken })).status, 401);
    assert.equal((await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: device.deviceToken })).status, 401);
  });
});

describe('desvinculacao feita no proprio aparelho, sem conexao', () => {
  test('o aviso de desvinculacao local revoga o cadastro e fica na auditoria', async () => {
    // O responsavel se autenticou no aparelho com o codigo de acesso offline e desvinculou.
    // A ultima sincronizacao do aparelho leva o evento.
    const farewell = await sync(server, device, {
      events: [event(server, 'unlinked_locally', { method: 'offline_code' })],
    });
    assert.equal(farewell.status, 200, JSON.stringify(farewell.body));
    assert.equal(farewell.body.ack.events.length, 1);

    // O token deixa de valer: o aparelho ja nao aplica as regras.
    const after = await sync(server, device);
    assert.equal(after.status, 401);
    assert.equal(after.body.error.code, 'device_revoked');

    // O painel mostra o aparelho como revogado, com o historico preservado.
    const list = await api(server, 'GET', '/v1/guardian/devices', { token: guardian.token });
    const listed = list.body.devices.find((item: { id: string }) => item.id === device.deviceId);
    assert.equal(listed.status, 'revoked');
    assert.equal(count(server, 'events', 'device_id = ?', device.deviceId), 1);

    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    const entry = audit.body.entries.find((item: { action: string }) => item.action === 'device.unlink');
    assert.ok(entry, 'a desvinculacao deveria estar na auditoria');
    assert.match(entry.summary, /código de acesso offline/);
  });

  test('reenviar o mesmo aviso nao tem efeito adicional', async () => {
    const unlink = event(server, 'unlinked_locally', { method: 'offline_code' });
    assert.equal((await sync(server, device, { events: [unlink] })).status, 200);
    // O aparelho ja esta revogado: um reenvio e recusado como qualquer outra chamada.
    assert.equal((await sync(server, device, { events: [unlink] })).status, 401);
    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    const entries = audit.body.entries.filter((item: { action: string }) => item.action === 'device.unlink');
    assert.equal(entries.length, 1);
  });
});
