// Relatorios: resumo do periodo, sessoes, eventos, navegacao e exportacao.

import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, test } from 'node:test';

import { api, dayBody, event, HOUR, hourly, MINUTE, pairDevice, registerGuardian, startServer, sync, TIMEZONE, TODAY } from './helpers.ts';
import type { GuardianAccount, PairedDevice, TestServer } from './helpers.ts';

let server: TestServer;
let guardian: GuardianAccount;
let device: PairedDevice;

beforeEach(async () => {
  server = await startServer();
  guardian = await registerGuardian(server);
  device = await pairDevice(server, guardian);
  await api(server, 'PUT', '/v1/device/apps', {
    token: device.deviceToken,
    body: {
      full: true,
      apps: [
        { package: 'com.whatsapp', label: 'WhatsApp', category: 'communication', system: false, launchable: true },
        { package: 'com.jogo.a', label: 'Jogo A', category: 'games', system: false, launchable: true },
        { package: 'com.jogo.b', label: 'Jogo B', category: 'games', system: false, launchable: true },
        { package: 'com.google.android.youtube', label: 'YouTube', category: 'video', system: true, launchable: true },
      ],
    },
  });
});

afterEach(async () => {
  await server.close();
});

const base = () => `/v1/guardian/devices/${device.deviceId}`;

function at(day: string, hour: number, minute = 0): number {
  // Horario local de Fortaleza (UTC-3) convertido para UTC.
  return Date.parse(`${day}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00-03:00`);
}

async function seed(): Promise<void> {
  const blocked = (pkg: string, ts: number) => ({ ...event(server, 'blocked_attempt', { reason: 'app_blocked' }, pkg), ts });
  const response = await sync(server, device, {
    days: [
      dayBody({
        day: '2026-11-14',
        quotaUsedMs: 60 * MINUTE,
        totalUsedMs: 90 * MINUTE,
        limitMs: 120 * MINUTE,
        firstUseAt: at('2026-11-14', 9),
        lastUseAt: at('2026-11-14', 20),
        apps: [
          { package: 'com.jogo.a', ms: 50 * MINUTE, opens: 4 },
          { package: 'com.whatsapp', ms: 40 * MINUTE, opens: 10 },
        ],
        hourly: hourly({ 9: 50 * MINUTE, 20: 40 * MINUTE }),
      }),
      dayBody({
        day: '2026-11-16',
        quotaUsedMs: 120 * MINUTE,
        totalUsedMs: 150 * MINUTE,
        limitMs: 120 * MINUTE,
        limitReachedAt: at('2026-11-16', 18, 30),
        firstUseAt: at('2026-11-16', 8),
        lastUseAt: at('2026-11-16', 21),
        apps: [
          { package: 'com.jogo.a', ms: 70 * MINUTE, opens: 6 },
          { package: 'com.google.android.youtube', ms: 60 * MINUTE, opens: 3 },
          { package: 'com.whatsapp', ms: 20 * MINUTE, opens: 5 },
          { package: 'com.sem.inventario', ms: 0, opens: 1 },
        ],
        hourly: hourly({ 8: 30 * MINUTE, 9: 60 * MINUTE, 21: 60 * MINUTE }),
      }),
      dayBody({
        day: TODAY,
        quotaUsedMs: 10 * MINUTE,
        totalUsedMs: 10 * MINUTE,
        limitMs: 120 * MINUTE,
        firstUseAt: at(TODAY, 11),
        lastUseAt: at(TODAY, 11, 10),
        apps: [{ package: 'com.jogo.b', ms: 10 * MINUTE, opens: 1 }],
        hourly: hourly({ 11: 10 * MINUTE }),
      }),
    ],
    sessions: [
      { id: randomUUID(), package: 'com.whatsapp', start: at('2026-11-16', 8), end: at('2026-11-16', 8, 20), day: '2026-11-16', tzOffsetMin: -180 },
      { id: randomUUID(), package: 'com.jogo.a', start: at('2026-11-16', 9), end: at('2026-11-16', 10, 10), day: '2026-11-16', tzOffsetMin: -180 },
      { id: randomUUID(), package: 'com.app.desconhecido', start: at('2026-11-16', 7), end: at('2026-11-16', 7, 5), day: '2026-11-16', tzOffsetMin: -180 },
      { id: randomUUID(), package: 'com.jogo.b', start: at(TODAY, 11), end: at(TODAY, 11, 10), day: TODAY, tzOffsetMin: -180 },
    ],
    events: [
      blocked('com.jogo.a', at('2026-11-16', 19)),
      blocked('com.jogo.a', at('2026-11-16', 19, 5)),
      blocked('com.jogo.b', at('2026-11-16', 19, 10)),
      blocked('com.jogo.a', at('2026-11-14', 22)),
      { ...event(server, 'limit_reached', { day: '2026-11-16', limitMs: 2 * HOUR, quotaUsedMs: 2 * HOUR }), ts: at('2026-11-16', 18, 30) },
    ],
    browsing: [
      { id: randomUUID(), ts: at('2026-11-16', 15), url: 'https://pt.wikipedia.org/wiki/Lince', domain: 'pt.wikipedia.org', title: 'Lince', blocked: false, reason: null },
      { id: randomUUID(), ts: at('2026-11-16', 15, 5), url: 'https://apostas.exemplo.com/', domain: 'apostas.exemplo.com', title: null, blocked: true, reason: 'category' },
      { id: randomUUID(), ts: at(TODAY, 11, 5), url: 'https://exemplo.com/hoje', domain: 'exemplo.com', title: 'Hoje', blocked: false, reason: null },
    ],
  });
  assert.equal(response.status, 200, JSON.stringify(response.body));
}

describe('resumo do periodo', () => {
  test('preenche com zeros os dias sem uso e ordena apps, categorias e bloqueios', async () => {
    await seed();
    const response = await api(server, 'GET', `${base()}/reports/summary?from=2026-11-11&to=2026-11-17`, { token: guardian.token });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    const report = response.body;
    assert.equal(report.from, '2026-11-11');
    assert.equal(report.to, TODAY);
    assert.equal(report.timezone, TIMEZONE);

    assert.deepEqual(
      report.daily.map((day: { day: string; totalMs: number }) => [day.day, day.totalMs / MINUTE]),
      [
        ['2026-11-11', 0],
        ['2026-11-12', 0],
        ['2026-11-13', 0],
        ['2026-11-14', 90],
        ['2026-11-15', 0],
        ['2026-11-16', 150],
        ['2026-11-17', 10],
      ],
    );
    assert.deepEqual(report.daily[0], {
      day: '2026-11-11',
      totalMs: 0,
      quotaMs: 0,
      limitMs: null,
      limitReachedAt: null,
      blockedAttempts: 0,
      firstUseAt: null,
      lastUseAt: null,
    });
    assert.deepEqual(report.daily[5], {
      day: '2026-11-16',
      totalMs: 150 * MINUTE,
      quotaMs: 120 * MINUTE,
      limitMs: 120 * MINUTE,
      limitReachedAt: at('2026-11-16', 18, 30),
      blockedAttempts: 3,
      firstUseAt: at('2026-11-16', 8),
      lastUseAt: at('2026-11-16', 21),
    });
    assert.equal(report.daily[3].blockedAttempts, 1);

    assert.deepEqual(report.totals, {
      totalMs: 250 * MINUTE,
      quotaMs: 190 * MINUTE,
      daysWithUse: 3,
      avgPerDayMs: Math.round((250 * MINUTE) / 3),
      blockedAttempts: 4,
      sessions: 4,
      opens: 30,
    });

    assert.deepEqual(report.apps, [
      { package: 'com.jogo.a', label: 'Jogo A', category: 'games', totalMs: 120 * MINUTE, opens: 10, days: 2, blockedAttempts: 3 },
      { package: 'com.google.android.youtube', label: 'YouTube', category: 'video', totalMs: 60 * MINUTE, opens: 3, days: 1, blockedAttempts: 0 },
      { package: 'com.whatsapp', label: 'WhatsApp', category: 'communication', totalMs: 60 * MINUTE, opens: 15, days: 2, blockedAttempts: 0 },
      { package: 'com.jogo.b', label: 'Jogo B', category: 'games', totalMs: 10 * MINUTE, opens: 1, days: 1, blockedAttempts: 1 },
      // App fora do inventario aparece com o nome do pacote e categoria other.
      { package: 'com.sem.inventario', label: 'com.sem.inventario', category: 'other', totalMs: 0, opens: 1, days: 0, blockedAttempts: 0 },
    ]);
    assert.deepEqual(report.categories, [
      { category: 'games', totalMs: 130 * MINUTE },
      { category: 'communication', totalMs: 60 * MINUTE },
      { category: 'video', totalMs: 60 * MINUTE },
    ]);
    assert.equal(report.hourly.length, 24);
    assert.equal(report.hourly[9], 110 * MINUTE);
    assert.equal(report.hourly[8], 30 * MINUTE);
    assert.equal(report.hourly[11], 10 * MINUTE);
    assert.equal(report.hourly[20], 40 * MINUTE);
    assert.equal(report.hourly[21], 60 * MINUTE);
    assert.equal(report.hourly[0], 0);
    assert.deepEqual(report.blockedByApp, [
      { package: 'com.jogo.a', label: 'Jogo A', count: 3 },
      { package: 'com.jogo.b', label: 'Jogo B', count: 1 },
    ]);
  });

  test('periodo sem nenhum uso devolve tudo zerado', async () => {
    const response = await api(server, 'GET', `${base()}/reports/summary?from=2026-10-01&to=2026-10-03`, { token: guardian.token });
    assert.equal(response.body.daily.length, 3);
    assert.deepEqual(response.body.totals, { totalMs: 0, quotaMs: 0, daysWithUse: 0, avgPerDayMs: 0, blockedAttempts: 0, sessions: 0, opens: 0 });
    assert.deepEqual(response.body.apps, []);
    assert.deepEqual(response.body.categories, []);
    assert.deepEqual(response.body.blockedByApp, []);
    assert.ok(response.body.hourly.every((value: number) => value === 0));
  });

  test('sem parametros o periodo e o dia corrente do aparelho', async () => {
    await seed();
    const response = await api(server, 'GET', `${base()}/reports/summary`, { token: guardian.token });
    assert.equal(response.body.from, TODAY);
    assert.equal(response.body.to, TODAY);
    assert.equal(response.body.totals.totalMs, 10 * MINUTE);
  });

  test('valida o intervalo: formato, ordem e maximo de 92 dias', async () => {
    const check = async (query: string) => api(server, 'GET', `${base()}/reports/summary?${query}`, { token: guardian.token });
    assert.equal((await check('from=17/11/2026&to=2026-11-17')).status, 400);
    assert.equal((await check('from=2026-11-18&to=2026-11-17')).status, 400);
    assert.equal((await check('from=2026-02-30&to=2026-03-01')).status, 400);
    const tooLong = await check('from=2026-08-17&to=2026-11-17');
    assert.equal(tooLong.status, 400);
    assert.deepEqual(tooLong.body.error.details.fields, ['to']);
    const maximum = await check('from=2026-08-18&to=2026-11-17');
    assert.equal(maximum.status, 200);
    assert.equal(maximum.body.daily.length, 92);
  });
});

describe('sessoes, eventos e navegacao', () => {
  test('sessoes de um dia em ordem cronologica, com nome e categoria do app', async () => {
    await seed();
    const response = await api(server, 'GET', `${base()}/sessions?day=2026-11-16`, { token: guardian.token });
    assert.equal(response.body.day, '2026-11-16');
    assert.deepEqual(response.body.sessions, [
      { package: 'com.app.desconhecido', label: 'com.app.desconhecido', category: 'other', start: at('2026-11-16', 7), end: at('2026-11-16', 7, 5), durationMs: 5 * MINUTE, tzOffsetMin: -180 },
      { package: 'com.whatsapp', label: 'WhatsApp', category: 'communication', start: at('2026-11-16', 8), end: at('2026-11-16', 8, 20), durationMs: 20 * MINUTE, tzOffsetMin: -180 },
      { package: 'com.jogo.a', label: 'Jogo A', category: 'games', start: at('2026-11-16', 9), end: at('2026-11-16', 10, 10), durationMs: 70 * MINUTE, tzOffsetMin: -180 },
    ]);
    const today = await api(server, 'GET', `${base()}/sessions`, { token: guardian.token });
    assert.equal(today.body.day, TODAY);
    assert.equal(today.body.sessions.length, 1);
    assert.equal((await api(server, 'GET', `${base()}/sessions?day=ontem`, { token: guardian.token })).status, 400);
  });

  test('eventos com filtro por tipo, por periodo e paginacao', async () => {
    await seed();
    const all = await api(server, 'GET', `${base()}/events`, { token: guardian.token });
    assert.equal(all.body.events.length, 5);
    assert.equal(all.body.nextBefore, null);
    const first = all.body.events[0];
    assert.equal(first.type, 'limit_reached', 'do mais recente para o mais antigo, pela ordem de chegada');
    assert.deepEqual(first.data, { day: '2026-11-16', limitMs: 2 * HOUR, quotaUsedMs: 2 * HOUR });
    assert.equal(first.package, null);
    assert.equal(first.label, null);

    const blocked = await api(server, 'GET', `${base()}/events?types=blocked_attempt&from=2026-11-16&to=2026-11-16`, { token: guardian.token });
    assert.equal(blocked.body.events.length, 3);
    assert.ok(blocked.body.events.every((item: { type: string; label: string }) => item.type === 'blocked_attempt'));
    assert.deepEqual(blocked.body.events.map((item: { label: string }) => item.label), ['Jogo B', 'Jogo A', 'Jogo A']);

    const page = await api(server, 'GET', `${base()}/events?limit=2`, { token: guardian.token });
    assert.equal(page.body.events.length, 2);
    assert.equal(page.body.nextBefore, page.body.events[1].id);
    const rest = await api(server, 'GET', `${base()}/events?limit=10&before=${page.body.nextBefore}`, { token: guardian.token });
    assert.equal(rest.body.events.length, 3);
    assert.equal(rest.body.nextBefore, null);

    assert.equal((await api(server, 'GET', `${base()}/events?types=Tipo Invalido`, { token: guardian.token })).status, 400);
  });

  test('eventos usam o dia da cota calculado pelo servidor', async () => {
    await api(server, 'PUT', `${base()}/policy`, {
      token: guardian.token,
      body: { baseVersion: 1, policy: { dailyLimit: { enabled: true, minutes: 120, resetTime: '04:00' } } },
    });
    // 02:00 do dia 17 ainda pertence ao dia da cota 16 quando o reinicio e as 04:00.
    await sync(server, device, {
      policyVersion: 2,
      events: [{ ...event(server, 'blocked_attempt', { reason: 'schedule' }, 'com.jogo.a'), ts: at(TODAY, 2) }],
    });
    const previous = await api(server, 'GET', `${base()}/events?from=2026-11-16&to=2026-11-16`, { token: guardian.token });
    assert.equal(previous.body.events.length, 1);
    const today = await api(server, 'GET', `${base()}/events?from=${TODAY}&to=${TODAY}`, { token: guardian.token });
    assert.equal(today.body.events.length, 0);
  });

  test('historico do navegador gerenciado, com enderecos decifrados', async () => {
    await seed();
    const response = await api(server, 'GET', `${base()}/browsing?from=2026-11-16&to=2026-11-16`, { token: guardian.token });
    assert.equal(response.status, 200);
    assert.deepEqual(
      response.body.entries.map((entry: Record<string, unknown>) => ({ ...entry, id: 0 })),
      [
        { id: 0, ts: at('2026-11-16', 15, 5), url: 'https://apostas.exemplo.com/', domain: 'apostas.exemplo.com', title: null, blocked: true, reason: 'category' },
        { id: 0, ts: at('2026-11-16', 15), url: 'https://pt.wikipedia.org/wiki/Lince', domain: 'pt.wikipedia.org', title: 'Lince', blocked: false, reason: null },
      ],
    );
    const all = await api(server, 'GET', `${base()}/browsing?limit=2`, { token: guardian.token });
    assert.equal(all.body.entries.length, 2);
    assert.equal(all.body.entries[0].url, 'https://exemplo.com/hoje');
    assert.equal(typeof all.body.nextBefore, 'number');
    const rest = await api(server, 'GET', `${base()}/browsing?before=${all.body.nextBefore}`, { token: guardian.token });
    assert.equal(rest.body.entries.length, 1);
    assert.equal(rest.body.nextBefore, null);
  });
});

describe('exportacao', () => {
  test('exporta todos os dados do aparelho, sem os icones nem credenciais', async () => {
    await seed();
    await sync(server, device, { events: [event(server, 'time_request', { minutes: 30, message: 'por favor' })] });
    const response = await api(server, 'GET', `${base()}/export`, { token: guardian.token });
    assert.equal(response.status, 200);
    const data = response.body;
    assert.equal(data.exportedAt, server.now());
    assert.equal(data.device.id, device.deviceId);
    assert.equal(data.device.childName, 'João');
    assert.equal(data.policyVersion, 1);
    assert.equal(data.policy.schema, 1);
    assert.equal(data.apps.length, 4);
    assert.equal(data.days.length, 3);
    assert.equal(data.days[1].apps.length, 4);
    assert.equal(data.sessions.length, 4);
    assert.equal(data.events.length, 6);
    assert.equal(data.browsing.length, 3);
    assert.equal(data.browsing[0].url, 'https://pt.wikipedia.org/wiki/Lince');
    assert.equal(data.timeRequests.length, 1);
    assert.equal(data.timeRequests[0].message, 'por favor');
    const text = JSON.stringify(data);
    assert.ok(!text.includes(device.deviceToken));
    assert.ok(!text.includes(device.offlineSecret));
    assert.ok(!text.includes('enc:v1:'));

    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    assert.ok(audit.body.entries.some((entry: { action: string }) => entry.action === 'device.export'));
  });
});
