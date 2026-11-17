// Politica versionada: validacao, conflito de versao, comandos e auditoria.

import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';

import { summarizePolicyChange } from '../src/modules/policy/diff.ts';
import {
  defaultPolicy,
  effectiveLimitMinutes,
  normalizeDomain,
  normalizePolicyInput,
  resolveRule,
} from '../src/modules/policy/schema.ts';
import { api, HOUR, login, MINUTE, pairDevice, PASSWORD, registerGuardian, startServer, TIMEZONE, TODAY } from './helpers.ts';
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

async function getPolicy(): Promise<ApiResponse> {
  return api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token });
}

async function putPolicy(baseVersion: number, policy: Record<string, unknown>, token = guardian.token): Promise<ApiResponse> {
  return api(server, 'PUT', `/v1/guardian/devices/${device.deviceId}/policy`, { token, body: { baseVersion, policy } });
}

describe('documento da politica', () => {
  test('aparelho novo recebe a politica padrao, sem nada bloqueado', async () => {
    const response = await getPolicy();
    assert.equal(response.body.policyVersion, 1);
    assert.deepEqual(response.body.policy, {
      schema: 1,
      timezone: TIMEZONE,
      dailyLimit: { enabled: false, minutes: 120, perWeekday: {}, resetTime: '00:00', warnAtMinutes: [15, 5] },
      allowedHours: { enabled: false, windows: [] },
      blockPeriods: [],
      apps: { defaultForNewApps: 'allowed', rules: {} },
      web: {
        managedBrowser: true,
        logHistory: true,
        safeDns: true,
        safeSearch: true,
        mode: 'blocklist',
        blockedDomains: [],
        allowedDomains: [],
        blockedCategories: ['adult', 'gambling'],
      },
      protection: {
        lockOnTamper: false,
        blockUninstall: true,
        blockSafeBoot: true,
        blockFactoryReset: true,
        blockDateTimeChange: true,
        blockAddUser: true,
        blockUnknownSources: false,
        blockUsbDebugging: false,
      },
      overrides: {
        extraTime: [],
        manualLock: { active: false, until: null, setAt: null },
        suspension: { until: 0, scopes: [], setAt: null },
      },
    });
  });

  test('salva o documento completo, normaliza e cria nova versao', async () => {
    const response = await putPolicy(1, {
      schema: 1,
      timezone: 'America/Sao_Paulo',
      dailyLimit: { enabled: true, minutes: 150, perWeekday: { '7': 240, '6': 240 }, resetTime: '04:00', warnAtMinutes: [5, 15, 5] },
      allowedHours: { enabled: true, windows: [{ days: [5, 1, 3, 3], start: '07:00', end: '20:30' }, { days: [6, 7], start: '08:00', end: '24:00' }] },
      blockPeriods: [
        { id: 'dormir', label: ' Hora de dormir ', enabled: true, kind: 'weekly', days: [1, 2, 3, 4, 5, 6, 7], start: '21:00', end: '07:00' },
        { label: 'Estudo para a prova', enabled: true, kind: 'once', startAt: 1_800_000_000_000, endAt: 1_800_003_600_000 },
      ],
      apps: {
        defaultForNewApps: 'blocked',
        rules: {
          'com.whatsapp': { state: 'exception', countsTowardLimit: false, dailyLimitMinutes: null },
          'com.example.jogo': { state: 'blocked', dailyLimitMinutes: 30 },
          'com.google.android.youtube': { state: 'allowed', dailyLimitMinutes: 45, countsTowardLimit: false },
          'com.escola.app': { state: 'exception' },
          'com.duolingo': { state: 'exception', countsTowardLimit: true, dailyLimitMinutes: 60 },
        },
      },
      web: {
        managedBrowser: true,
        logHistory: true,
        safeDns: true,
        safeSearch: false,
        mode: 'allowlist',
        blockedDomains: ['https://WWW.Apostas.com/pagina?x=1', 'apostas.com', '*.jogos.exemplo.org'],
        allowedDomains: ['Wikipedia.org'],
        blockedCategories: ['games', 'adult', 'games'],
      },
      protection: { lockOnTamper: true, blockUsbDebugging: true },
    });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.policyVersion, 2);
    const policy = response.body.policy;
    assert.equal(policy.timezone, 'America/Sao_Paulo');
    assert.deepEqual(policy.dailyLimit, {
      enabled: true,
      minutes: 150,
      perWeekday: { '6': 240, '7': 240 },
      resetTime: '04:00',
      warnAtMinutes: [15, 5],
    });
    assert.deepEqual(policy.allowedHours.windows, [
      { days: [1, 3, 5], start: '07:00', end: '20:30' },
      { days: [6, 7], start: '08:00', end: '24:00' },
    ]);
    assert.equal(policy.blockPeriods.length, 2);
    assert.deepEqual(policy.blockPeriods[0], {
      id: 'dormir',
      label: 'Hora de dormir',
      enabled: true,
      kind: 'weekly',
      days: [1, 2, 3, 4, 5, 6, 7],
      start: '21:00',
      end: '07:00',
    });
    assert.match(policy.blockPeriods[1].id, /^[0-9a-f-]{36}$/, 'identificador gerado quando ausente');
    assert.equal(policy.blockPeriods[1].kind, 'once');
    assert.deepEqual(policy.apps.rules, {
      'com.duolingo': { state: 'exception', countsTowardLimit: true, dailyLimitMinutes: 60 },
      'com.escola.app': { state: 'exception', countsTowardLimit: false, dailyLimitMinutes: null },
      'com.example.jogo': { state: 'blocked', countsTowardLimit: false, dailyLimitMinutes: null },
      'com.google.android.youtube': { state: 'allowed', countsTowardLimit: true, dailyLimitMinutes: 45 },
      'com.whatsapp': { state: 'exception', countsTowardLimit: false, dailyLimitMinutes: null },
    });
    assert.deepEqual(policy.web.blockedDomains, ['apostas.com', 'jogos.exemplo.org']);
    assert.deepEqual(policy.web.allowedDomains, ['wikipedia.org']);
    assert.deepEqual(policy.web.blockedCategories, ['adult', 'games']);
    assert.equal(policy.web.mode, 'allowlist');
    assert.equal(policy.protection.lockOnTamper, true);
    assert.equal(policy.protection.blockUsbDebugging, true);
    assert.equal(policy.protection.blockUninstall, true, 'campo ausente mantem o valor atual');

    const stored = await getPolicy();
    assert.deepEqual(stored.body.policy, policy);
    assert.equal(stored.body.device.policyVersion, 2);
    assert.equal(stored.body.device.appliedPolicyVersion, 0);
  });

  test('secao ausente mantem o valor atual e os overrides nunca sao alterados pelo PUT', async () => {
    const extra = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, {
      token: guardian.token,
      body: { minutes: 30 },
    });
    assert.equal(extra.body.policyVersion, 2);
    const response = await putPolicy(2, {
      dailyLimit: { enabled: true, minutes: 90 },
      overrides: { extraTime: [], manualLock: { active: true, until: null, setAt: 1 }, suspension: { until: 9e15, scopes: ['dailyLimit'] } },
    });
    assert.equal(response.status, 200);
    assert.equal(response.body.policyVersion, 3);
    assert.equal(response.body.policy.dailyLimit.minutes, 90);
    assert.equal(response.body.policy.dailyLimit.resetTime, '00:00');
    assert.deepEqual(response.body.policy.dailyLimit.warnAtMinutes, [15, 5]);
    assert.deepEqual(response.body.policy.web.blockedCategories, ['adult', 'gambling']);
    assert.equal(response.body.policy.overrides.extraTime.length, 1, 'tempo extra preservado');
    assert.equal(response.body.policy.overrides.extraTime[0].minutes, 30);
    assert.equal(response.body.policy.overrides.manualLock.active, false, 'override enviado e ignorado');
    assert.equal(response.body.policy.overrides.suspension.until, 0);
  });

  test('conflito de versao quando a base nao e a atual', async () => {
    assert.equal((await putPolicy(1, { dailyLimit: { enabled: true, minutes: 60 } })).body.policyVersion, 2);
    const stale = await putPolicy(1, { dailyLimit: { enabled: true, minutes: 30 } });
    assert.equal(stale.status, 409);
    assert.equal(stale.body.error.code, 'version_conflict');
    assert.equal(stale.body.error.details.currentVersion, 2);
    assert.equal((await getPolicy()).body.policy.dailyLimit.minutes, 60, 'nada foi gravado');
    assert.equal((await putPolicy(2, { dailyLimit: { enabled: true, minutes: 30 } })).body.policyVersion, 3);
  });

  test('salvar sem mudanca nao cria versao nova', async () => {
    const current = (await getPolicy()).body.policy;
    const same = await putPolicy(1, current);
    assert.equal(same.status, 200);
    assert.equal(same.body.policyVersion, 1);
  });

  test('recusa valores invalidos apontando cada campo', async () => {
    const response = await putPolicy(1, {
      schema: 2,
      timezone: 'Marte/Olimpo',
      dailyLimit: { enabled: 'sim', minutes: 2000, perWeekday: { '8': 60, '1': -1 }, resetTime: '24:00', warnAtMinutes: [1, 2, 3, 4, 5] },
      allowedHours: { enabled: true, windows: [{ days: [1], start: '20:00', end: '08:00' }, { days: [], start: '08:00', end: '09:00' }] },
      blockPeriods: [
        { label: 'x', kind: 'weekly', days: [1], start: '10:00', end: '10:00' },
        { label: 'y', kind: 'once', startAt: 10, endAt: 5 },
        { label: 'z', kind: 'mensal' },
        { label: 'n'.repeat(61), kind: 'weekly', days: [1], start: '10:00', end: '11:00' },
      ],
      apps: {
        defaultForNewApps: 'talvez',
        rules: {
          __proto__: { state: 'blocked' },
          'pacote invalido': { state: 'blocked' },
          semponto: { state: 'blocked' },
          'com.app.um': { state: 'liberado' },
          'com.app.dois': { state: 'allowed', dailyLimitMinutes: 0 },
        },
      },
      web: { mode: 'tudo', blockedDomains: ['nao e dominio', 'localhost'], blockedCategories: ['armas'] },
      protection: { blockUninstall: 'nao' },
    });
    assert.equal(response.status, 400);
    assert.equal(response.body.error.code, 'validation_error');
    const fields: string[] = response.body.error.details.fields;
    for (const expected of [
      'policy.schema',
      'policy.timezone',
      'policy.dailyLimit.enabled',
      'policy.dailyLimit.minutes',
      'policy.dailyLimit.perWeekday.8',
      'policy.dailyLimit.perWeekday.1',
      'policy.dailyLimit.resetTime',
      'policy.dailyLimit.warnAtMinutes',
      'policy.allowedHours.windows[0]',
      'policy.allowedHours.windows[1].days',
      'policy.blockPeriods[0]',
      'policy.blockPeriods[1]',
      'policy.blockPeriods[2].kind',
      'policy.blockPeriods[3].label',
      'policy.apps.defaultForNewApps',
      'policy.apps.rules.pacote invalido',
      'policy.apps.rules.semponto',
      'policy.apps.rules.com.app.um.state',
      'policy.apps.rules.com.app.dois.dailyLimitMinutes',
      'policy.web.mode',
      'policy.web.blockedDomains[0]',
      'policy.web.blockedDomains[1]',
      'policy.web.blockedCategories[0]',
      'policy.protection.blockUninstall',
    ]) {
      assert.ok(fields.includes(expected), `faltou ${expected} em ${JSON.stringify(fields)}`);
    }
    assert.equal((await getPolicy()).body.policyVersion, 1);
  });

  test('limites de quantidade', async () => {
    const periods = Array.from({ length: 51 }, (_, index) => ({ label: `p${index}`, kind: 'weekly', days: [1], start: '10:00', end: '11:00' }));
    assert.deepEqual((await putPolicy(1, { blockPeriods: periods })).body.error.details.fields, ['policy.blockPeriods']);
    const domains = Array.from({ length: 501 }, (_, index) => `site${index}.exemplo.com`);
    assert.deepEqual((await putPolicy(1, { web: { blockedDomains: domains } })).body.error.details.fields, ['policy.web.blockedDomains']);
    assert.equal((await putPolicy(1, { web: { blockedDomains: domains.slice(0, 500) } })).status, 200);
  });

  test('alterar a politica exige elevacao e aparelho ativo', async () => {
    server.advance(16 * MINUTE);
    const denied = await putPolicy(1, { dailyLimit: { enabled: true, minutes: 60 } });
    assert.equal(denied.status, 403);
    assert.equal(denied.body.error.code, 'elevation_required');
    await api(server, 'POST', '/v1/guardian/session/elevate', { token: guardian.token, body: { password: PASSWORD } });
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/revoke`, { token: guardian.token });
    const revoked = await putPolicy(1, { dailyLimit: { enabled: true, minutes: 60 } });
    assert.equal(revoked.status, 409);
    assert.equal(revoked.body.error.code, 'conflict');
  });
});

describe('comandos sobre os overrides', () => {
  test('tempo extra vale para o dia da cota corrente e sempre cria nova versao', async () => {
    const first = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 30 } });
    assert.equal(first.status, 200);
    assert.equal(first.body.policyVersion, 2);
    const [entry] = first.body.policy.overrides.extraTime;
    assert.equal(entry.day, TODAY);
    assert.equal(entry.minutes, 30);
    assert.equal(entry.grantedAt, server.now());
    assert.match(entry.id, /^[0-9a-f-]{36}$/);

    const second = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 15 } });
    assert.equal(second.body.policyVersion, 3);
    assert.equal(second.body.policy.overrides.extraTime.length, 2);

    for (const minutes of [0, 721, 1.5, 'trinta']) {
      const invalid = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes } });
      assert.equal(invalid.status, 400, `minutos ${minutes}`);
    }
  });

  test('tempo extra com mais de 2 dias e removido', async () => {
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 30 } });
    server.advance(2 * 24 * HOUR);
    await api(server, 'POST', '/v1/guardian/session/elevate', { token: guardian.token, body: { password: PASSWORD } });
    const kept = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 10 } });
    assert.deepEqual(
      kept.body.policy.overrides.extraTime.map((entry: { day: string }) => entry.day),
      ['2026-11-17', '2026-11-19'],
    );
    server.advance(24 * HOUR);
    await api(server, 'POST', '/v1/guardian/session/elevate', { token: guardian.token, body: { password: PASSWORD } });
    const pruned = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 5 } });
    assert.deepEqual(
      pruned.body.policy.overrides.extraTime.map((entry: { day: string }) => entry.day),
      ['2026-11-19', '2026-11-20'],
    );
  });

  test('o dia do tempo extra respeita o horario de reinicio da cota', async () => {
    await putPolicy(1, { dailyLimit: { enabled: true, minutes: 120, resetTime: '13:00' } });
    // Sao 12:00 locais: antes do reinicio das 13:00, ainda e o dia da cota anterior.
    const extra = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 20 } });
    assert.equal(extra.body.policy.overrides.extraTime[0].day, '2026-11-16');
    assert.equal((await getPolicy()).body.device.today, '2026-11-16');
    server.advance(61 * MINUTE);
    assert.equal((await getPolicy()).body.device.today, '2026-11-17');
  });

  test('bloquear agora, com e sem prazo, e desbloquear', async () => {
    const locked = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/lock`, { token: guardian.token });
    assert.equal(locked.status, 200);
    assert.deepEqual(locked.body.policy.overrides.manualLock, { active: true, until: null, setAt: server.now() });

    const until = server.now() + 2 * HOUR;
    const timed = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/lock`, { token: guardian.token, body: { until } });
    assert.deepEqual(timed.body.policy.overrides.manualLock, { active: true, until, setAt: server.now() });
    assert.equal(timed.body.policyVersion, 3);

    const past = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/lock`, { token: guardian.token, body: { until: server.now() - 1 } });
    assert.equal(past.status, 400);

    const unlocked = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/unlock`, { token: guardian.token });
    assert.deepEqual(unlocked.body.policy.overrides.manualLock, { active: false, until: null, setAt: null });
    assert.equal(unlocked.body.policyVersion, 4);
  });

  test('suspender regras por um periodo e encerrar a suspensao', async () => {
    const suspended = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/suspension`, {
      token: guardian.token,
      body: { minutes: 90, scopes: ['appBlocks', 'dailyLimit', 'dailyLimit'] },
    });
    assert.equal(suspended.status, 200);
    assert.deepEqual(suspended.body.policy.overrides.suspension, {
      until: server.now() + 90 * MINUTE,
      scopes: ['dailyLimit', 'appBlocks'],
      setAt: server.now(),
    });
    for (const body of [{ minutes: 0, scopes: ['dailyLimit'] }, { minutes: 1441, scopes: ['dailyLimit'] }, { minutes: 30, scopes: [] }, { minutes: 30, scopes: ['tudo'] }]) {
      const invalid = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/suspension`, { token: guardian.token, body });
      assert.equal(invalid.status, 400, JSON.stringify(body));
    }
    const resumed = await api(server, 'DELETE', `/v1/guardian/devices/${device.deviceId}/suspension`, { token: guardian.token });
    assert.deepEqual(resumed.body.policy.overrides.suspension, { until: 0, scopes: [], setAt: null });
    assert.equal(resumed.body.policyVersion, 3);
  });

  test('todos os comandos exigem elevacao', async () => {
    server.advance(16 * MINUTE);
    const base = `/v1/guardian/devices/${device.deviceId}`;
    const calls: [Parameters<typeof api>[1], string, unknown][] = [
      ['POST', `${base}/extra-time`, { minutes: 10 }],
      ['POST', `${base}/lock`, {}],
      ['POST', `${base}/unlock`, undefined],
      ['POST', `${base}/suspension`, { minutes: 10, scopes: ['dailyLimit'] }],
      ['DELETE', `${base}/suspension`, undefined],
      ['POST', `${base}/revoke`, undefined],
      ['DELETE', `${base}/data`, undefined],
      ['DELETE', base, undefined],
      ['PATCH', base, { childName: 'Outro' }],
      ['GET', `${base}/offline-secret`, undefined],
      ['GET', `${base}/export`, undefined],
    ];
    for (const [method, url, body] of calls) {
      const response = await api(server, method, url, { token: guardian.token, body });
      assert.equal(response.status, 403, `${method} ${url}`);
      assert.equal(response.body.error.code, 'elevation_required');
    }
    assert.equal((await getPolicy()).body.policyVersion, 1);
  });
});

describe('auditoria e aviso a outras sessoes', () => {
  test('cada alteracao fica na auditoria com resumo legivel', async () => {
    await putPolicy(1, {
      dailyLimit: { enabled: true, minutes: 150 },
      apps: { rules: { 'com.example.jogo': { state: 'blocked' } } },
    });
    await putPolicy(2, { dailyLimit: { minutes: 120 } });
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 30 } });
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/lock`, { token: guardian.token });

    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    const entries: { action: string; summary: string; targetId: string; deviceName: string; sessionId: string }[] = audit.body.entries;
    const byAction = (action: string) => entries.filter((entry) => entry.action === action).map((entry) => entry.summary);
    assert.deepEqual(byAction('policy.update'), [
      'Limite diário alterado de 2h30 para 2h',
      'Limite diário ativado (2h30); App com.example.jogo: padrão para bloqueado',
    ]);
    assert.deepEqual(byAction('policy.extra_time'), ['Tempo extra concedido a João: 30 min']);
    assert.deepEqual(byAction('policy.lock'), ['Aparelho de João bloqueado']);
    const update = entries.find((entry) => entry.action === 'policy.update');
    assert.equal(update?.targetId, device.deviceId);
    assert.equal(update?.deviceName, 'Galaxy da Maria');
    assert.equal(update?.sessionId, guardian.sessionId);
    assert.ok(byAction('device.approve').length === 1);
    assert.ok(byAction('pairing.code_create').length === 1);

    // Paginacao por identificador decrescente.
    const page = await api(server, 'GET', '/v1/guardian/audit?limit=2', { token: guardian.token });
    assert.equal(page.body.entries.length, 2);
    assert.equal(page.body.nextBefore, page.body.entries[1].id);
    const next = await api(server, 'GET', `/v1/guardian/audit?limit=200&before=${page.body.nextBefore}`, { token: guardian.token });
    assert.equal(next.body.nextBefore, null);
    assert.equal(next.body.entries.length, entries.length - 2);
  });

  test('outra sessao da conta recebe o alerta de regras alteradas, quem alterou nao', async () => {
    const other = await login(server, guardian.email, PASSWORD, 'Moto do Pedro');
    await putPolicy(1, { dailyLimit: { enabled: true, minutes: 150 } });
    await putPolicy(2, { dailyLimit: { minutes: 100 } });

    const mine = await api(server, 'GET', '/v1/guardian/alerts', { token: guardian.token });
    assert.equal(mine.body.alerts.filter((alert: { type: string }) => alert.type === 'policy_changed').length, 0);
    const theirs = await api(server, 'GET', '/v1/guardian/alerts', { token: other.body.session.token });
    const changed = theirs.body.alerts.filter((alert: { type: string }) => alert.type === 'policy_changed');
    assert.equal(changed.length, 1, 'alteracoes seguidas da mesma sessao geram um alerta so');
    assert.equal(changed[0].title, 'Regras alteradas');
    assert.equal(changed[0].body, 'As regras de João foram alteradas em Galaxy da Maria.');
    assert.equal(changed[0].deviceId, device.deviceId);
    assert.equal(changed[0].notify, true);
  });

  test('sem outra sessao ativa nao ha alerta de regras alteradas', async () => {
    await putPolicy(1, { dailyLimit: { enabled: true, minutes: 150 } });
    const alerts = server.ctx.db.all<{ type: string }>('SELECT type FROM alerts WHERE guardian_id = ?', guardian.guardianId);
    assert.ok(!alerts.some((alert) => alert.type === 'policy_changed'));
  });
});

describe('regras da politica (funcoes puras)', () => {
  test('limite efetivo soma o dia da semana e o tempo extra', () => {
    const policy = defaultPolicy(TIMEZONE);
    policy.dailyLimit = { enabled: true, minutes: 120, perWeekday: { '6': 240, '7': 0 }, resetTime: '00:00', warnAtMinutes: [] };
    policy.overrides.extraTime = [
      { id: 'a', day: '2026-11-17', minutes: 30, grantedAt: 0 },
      { id: 'b', day: '2026-11-17', minutes: 15, grantedAt: 0 },
      { id: 'c', day: '2026-11-18', minutes: 60, grantedAt: 0 },
    ];
    assert.equal(effectiveLimitMinutes(policy, '2026-11-17'), 165);
    assert.equal(effectiveLimitMinutes(policy, '2026-11-18'), 180);
    assert.equal(effectiveLimitMinutes(policy, '2026-11-21'), 240, 'sabado');
    assert.equal(effectiveLimitMinutes(policy, '2026-11-22'), 0, 'domingo sem tempo livre');
    assert.equal(effectiveLimitMinutes(policy, '2026-11-16'), 120);
  });

  test('regra efetiva de um pacote sem regra explicita', () => {
    const policy = defaultPolicy(TIMEZONE);
    policy.apps.rules = { 'com.whatsapp': { state: 'exception', countsTowardLimit: false, dailyLimitMinutes: null } };
    assert.deepEqual(resolveRule(policy, 'com.whatsapp', false), {
      state: 'exception',
      countsTowardLimit: false,
      dailyLimitMinutes: null,
      explicit: true,
    });
    assert.equal(resolveRule(policy, 'com.novo.app', false).state, 'allowed');
    policy.apps.defaultForNewApps = 'blocked';
    assert.equal(resolveRule(policy, 'com.novo.app', false).state, 'blocked');
    assert.equal(resolveRule(policy, 'com.android.settings', true).state, 'allowed', 'app de sistema nao e bloqueado por padrao');
    assert.equal(resolveRule(policy, 'constructor', false).explicit, false);
  });

  test('normaliza dominios para comparacao por sufixo', () => {
    assert.equal(normalizeDomain('https://WWW.Exemplo.com/pagina?x=1#topo'), 'exemplo.com');
    assert.equal(normalizeDomain('*.jogos.exemplo.org'), 'jogos.exemplo.org');
    assert.equal(normalizeDomain('usuario:senha@exemplo.com:8443'), 'exemplo.com');
    assert.equal(normalizeDomain('  sub.exemplo.com.  '), 'sub.exemplo.com');
    assert.equal(normalizeDomain('açúcar.com.br'), 'xn--acar-0oa8i.com.br');
    assert.equal(normalizeDomain('localhost'), null);
    assert.equal(normalizeDomain('nao e dominio'), null);
    assert.equal(normalizeDomain(''), null);
    assert.equal(normalizeDomain('-invalido.com'), null);
  });

  test('a validacao nao aceita chaves que alterariam o prototipo', () => {
    const current = defaultPolicy(TIMEZONE);
    const hostile = JSON.parse('{"apps":{"rules":{"__proto__":{"state":"blocked"},"constructor":{"state":"blocked"}}}}') as unknown;
    assert.throws(() => normalizePolicyInput(hostile, current));
    assert.equal(({} as Record<string, unknown>).state, undefined);
  });

  test('resumo das diferencas em portugues', () => {
    const before = defaultPolicy(TIMEZONE);
    const after = normalizePolicyInput(
      {
        dailyLimit: { enabled: true, minutes: 90, resetTime: '04:00' },
        allowedHours: { enabled: true, windows: [{ days: [1], start: '08:00', end: '20:00' }] },
        blockPeriods: [{ id: 'p1', label: 'Hora de dormir', kind: 'weekly', days: [1], start: '21:00', end: '07:00' }],
        apps: { defaultForNewApps: 'blocked', rules: { 'com.jogo.a': { state: 'blocked' }, 'com.escola.b': { state: 'exception' } } },
        web: { mode: 'allowlist', safeSearch: false },
        protection: { lockOnTamper: true },
      },
      before,
    );
    const labels: Record<string, string> = { 'com.jogo.a': 'Jogo A' };
    assert.equal(
      summarizePolicyChange(before, after, (pkg) => labels[pkg] ?? pkg),
      [
        'Limite diário ativado (1h30)',
        'Horário de reinício da cota alterado de 00:00 para 04:00',
        'Horários permitidos ativados',
        'Período de bloqueio criado: Hora de dormir',
        'Apps novos passam a ficar bloqueados até aprovação',
        'App com.escola.b: padrão para exceção',
        'App Jogo A: padrão para bloqueado',
        'Filtro de navegação alterado (somente sites autorizados, busca segura desligada)',
        'Opções de proteção alteradas',
      ].join('; '),
    );
    assert.equal(summarizePolicyChange(before, before), 'Sem alterações');
    const many = normalizePolicyInput(
      { apps: { rules: Object.fromEntries(Array.from({ length: 6 }, (_, index) => [`com.app.n${index}`, { state: 'blocked' }])) } },
      before,
    );
    assert.equal(summarizePolicyChange(before, many), 'Regras de 6 apps alteradas');
  });
});
