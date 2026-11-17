// Isolamento entre contas, protecao de dados em repouso, revogacao e exclusoes.

import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, test } from 'node:test';

import {
  api,
  count,
  dayBody,
  event,
  login,
  MINUTE,
  pairDevice,
  PASSWORD,
  PNG_1X1,
  registerGuardian,
  startServer,
  sync,
  syncBody,
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

async function seedHistory(target: PairedDevice = device): Promise<string> {
  const request = event(server, 'time_request', { minutes: 10 });
  const response = await sync(server, target, {
    days: [dayBody({ quotaUsedMs: 30 * MINUTE, totalUsedMs: 30 * MINUTE, apps: [{ package: 'com.jogo.a', ms: 30 * MINUTE, opens: 2 }] })],
    sessions: [{ id: randomUUID(), package: 'com.jogo.a', start: server.now() - 30 * MINUTE, end: server.now(), day: TODAY, tzOffsetMin: -180 }],
    events: [event(server, 'blocked_attempt', { reason: 'app_blocked' }, 'com.jogo.b'), request],
    browsing: [{ id: randomUUID(), ts: server.now(), url: 'https://exemplo.com/x', domain: 'exemplo.com', title: 'X', blocked: false, reason: null }],
  });
  assert.equal(response.status, 200, JSON.stringify(response.body));
  return String(request.id);
}

describe('isolamento entre contas', () => {
  test('um responsavel nao le nem altera nada de aparelho de outra conta', async () => {
    const requestId = await seedHistory();
    await api(server, 'PUT', '/v1/device/apps', {
      token: device.deviceToken,
      body: { full: true, apps: [{ package: 'com.jogo.a', label: 'Jogo A', category: 'games', system: false, launchable: true, iconHash: 'aabbccdd00112233' }] },
    });
    await api(server, 'PUT', '/v1/device/apps/icon?package=com.jogo.a&hash=aabbccdd00112233', {
      token: device.deviceToken,
      body: PNG_1X1,
      headers: { 'content-type': 'image/png' },
    });

    const stranger = await registerGuardian(server);
    const base = `/v1/guardian/devices/${device.deviceId}`;
    const calls: [Parameters<typeof api>[1], string, unknown][] = [
      ['GET', base, undefined],
      ['PATCH', base, { childName: 'Invadido' }],
      ['DELETE', base, undefined],
      ['DELETE', `${base}/data`, undefined],
      ['POST', `${base}/revoke`, undefined],
      ['GET', `${base}/offline-secret`, undefined],
      ['PUT', `${base}/policy`, { baseVersion: 1, policy: { dailyLimit: { enabled: true, minutes: 1 } } }],
      ['POST', `${base}/extra-time`, { minutes: 600 }],
      ['POST', `${base}/lock`, {}],
      ['POST', `${base}/unlock`, undefined],
      ['POST', `${base}/suspension`, { minutes: 60, scopes: ['dailyLimit'] }],
      ['DELETE', `${base}/suspension`, undefined],
      ['GET', `${base}/apps`, undefined],
      ['GET', `${base}/apps/icon?package=com.jogo.a`, undefined],
      ['GET', `${base}/time-requests`, undefined],
      ['POST', `/v1/guardian/time-requests/${requestId}/resolve`, { action: 'approve', minutes: 600 }],
      ['GET', `${base}/reports/summary`, undefined],
      ['GET', `${base}/sessions`, undefined],
      ['GET', `${base}/events`, undefined],
      ['GET', `${base}/browsing`, undefined],
      ['GET', `${base}/export`, undefined],
    ];
    for (const [method, url, body] of calls) {
      const response = await api(server, method, url, { token: stranger.token, body });
      assert.equal(response.status, 403, `${method} ${url} respondeu ${response.status}`);
      assert.equal(response.body.error.code, 'forbidden');
      assert.ok(!JSON.stringify(response.body).includes('João'), 'a resposta nao pode vazar dados');
    }

    // Nada mudou para o dono.
    const view = await api(server, 'GET', base, { token: guardian.token });
    assert.equal(view.body.device.childName, 'João');
    assert.equal(view.body.device.status, 'active');
    assert.equal(view.body.policyVersion, 1);
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', device.deviceId), 1);
    assert.deepEqual((await api(server, 'GET', '/v1/guardian/devices', { token: stranger.token })).body.devices, []);

    // Sessoes e codigos de outra conta tambem sao inacessiveis.
    assert.equal((await api(server, 'DELETE', `/v1/guardian/sessions/${guardian.sessionId}`, { token: stranger.token })).status, 403);
    const code = await api(server, 'POST', '/v1/guardian/pairing-codes', { token: guardian.token });
    assert.equal((await api(server, 'DELETE', `/v1/guardian/pairing-codes/${code.body.id}`, { token: stranger.token })).status, 403);
    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: stranger.token });
    assert.ok(audit.body.entries.every((entry: { targetId: string }) => entry.targetId !== device.deviceId));
  });

  test('aparelho inexistente responde nao encontrado', async () => {
    const response = await api(server, 'GET', `/v1/guardian/devices/${randomUUID()}`, { token: guardian.token });
    assert.equal(response.status, 404);
    assert.equal(response.body.error.code, 'not_found');
  });

  test('o token de um aparelho so grava no proprio aparelho', async () => {
    const other = await pairDevice(server, guardian, { childName: 'Ana' });
    await seedHistory(device);
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', other.deviceId), 0);
    assert.equal(count(server, 'events', 'device_id = ?', other.deviceId), 0);
    const view = await api(server, 'GET', `/v1/guardian/devices/${other.deviceId}`, { token: guardian.token });
    assert.equal(view.body.device.state, null);
  });
});

describe('protecao de dados em repouso', () => {
  test('campos sensiveis, senha e tokens nao aparecem em texto puro no arquivo do banco', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'parentalynx-test-'));
    const path = join(directory, 'dados.db');
    const file = await startServer({ databasePath: path });
    try {
      const owner = await registerGuardian(file, { email: 'dona.do.arquivo@exemplo.com', password: 'Segredo#Unico2026' });
      const linked = await pairDevice(file, owner);
      const secrets = {
        url: 'https://diario-secreto.exemplo.com/pagina-privada-7391',
        title: 'Titulo confidencial 7391',
        eventDetail: 'detalhe-sigiloso-do-evento-7391',
        message: 'mensagem-particular-do-pedido-7391',
      };
      const response = await sync(file, linked, {
        events: [
          event(file, 'enforcement_issue', { issue: 'suspend_failed', detail: secrets.eventDetail }),
          event(file, 'time_request', { minutes: 15, message: secrets.message }),
        ],
        browsing: [
          { id: randomUUID(), ts: file.now(), url: secrets.url, domain: 'diario-secreto.exemplo.com', title: secrets.title, blocked: false, reason: null },
        ],
      });
      assert.equal(response.status, 200, JSON.stringify(response.body));

      // Pela API, com a chave, tudo volta legivel.
      const browsing = await api(file, 'GET', `/v1/guardian/devices/${linked.deviceId}/browsing`, { token: owner.token });
      assert.equal(browsing.body.entries[0].url, secrets.url);
      assert.equal(browsing.body.entries[0].title, secrets.title);
      const requests = await api(file, 'GET', `/v1/guardian/devices/${linked.deviceId}/time-requests`, { token: owner.token });
      assert.equal(requests.body.requests[0].message, secrets.message);

      // Forca a gravacao do WAL no arquivo principal e le os bytes de todos os arquivos do banco.
      file.ctx.db.exec('PRAGMA wal_checkpoint(TRUNCATE)');
      const bytes = Buffer.concat(readdirSync(directory).map((name) => readFileSync(join(directory, name))));
      const raw = bytes.toString('latin1');
      assert.ok(raw.includes('dona.do.arquivo@exemplo.com'), 'controle: o e-mail e gravado em texto puro');
      assert.ok(raw.includes('diario-secreto.exemplo.com'), 'controle: o dominio e gravado para os relatorios');
      for (const [name, value] of Object.entries({
        ...secrets,
        path: 'pagina-privada-7391',
        password: 'Segredo#Unico2026',
        sessionToken: owner.token,
        deviceToken: linked.deviceToken,
        offlineSecret: linked.offlineSecret,
        recoveryKey: owner.recoveryKey,
      })) {
        assert.ok(!raw.includes(value), `${name} apareceu em texto puro no arquivo do banco`);
      }
      assert.ok(raw.includes('enc:v1:'));
    } finally {
      await file.close();
      rmSync(directory, { recursive: true, force: true });
    }
  });

  test('sem a chave certa os campos cifrados nao podem ser lidos', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'parentalynx-test-'));
    const path = join(directory, 'dados.db');
    try {
      const first = await startServer({ databasePath: path });
      const owner = await registerGuardian(first);
      const linked = await pairDevice(first, owner);
      await sync(first, linked, {
        browsing: [{ id: randomUUID(), ts: first.now(), url: 'https://exemplo.com/privado', domain: 'exemplo.com', title: 'T', blocked: false, reason: null }],
      });
      await first.close();

      // Mesmo arquivo, outra chave (startServer sorteia uma chave nova a cada chamada).
      const second = await startServer({ databasePath: path });
      try {
        const session = await login(second, owner.email, PASSWORD);
        assert.equal(session.status, 200, 'dados nao cifrados continuam acessiveis');
        const browsing = await api(second, 'GET', `/v1/guardian/devices/${linked.deviceId}/browsing`, { token: session.body.session.token });
        assert.equal(browsing.status, 500);
        assert.equal(browsing.body.error.code, 'internal');
        assert.ok(!JSON.stringify(browsing.body).includes('exemplo.com/privado'));
      } finally {
        await second.close();
      }
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });

  test('senhas, tokens e chaves nao aparecem no log do servidor', async () => {
    const lines: string[] = [];
    const logged = await startServer({ config: { logLevel: 'trace' }, logStream: { write: (message) => void lines.push(message) } });
    try {
      const owner = await registerGuardian(logged, { email: 'logada@exemplo.com', password: 'Senha#DoLog2026' });
      const linked = await pairDevice(logged, owner);
      await login(logged, owner.email, 'Senha#DoLog2026');
      await login(logged, owner.email, 'Senha#Errada2026');
      await api(logged, 'POST', '/v1/guardian/session/elevate', { token: owner.token, body: { password: 'Senha#DoLog2026' } });
      await api(logged, 'POST', '/v1/device/admin-verify', { token: linked.deviceToken, body: { password: 'Senha#DoLog2026' } });
      await sync(logged, linked, {
        browsing: [{ id: randomUUID(), ts: logged.now(), url: 'https://exemplo.com/url-que-nao-vai-pro-log', domain: 'exemplo.com', title: null, blocked: false, reason: null }],
      });
      await api(logged, 'GET', '/v1/guardian/devices/inexistente', { token: owner.token });
      const output = lines.join('');
      assert.ok(lines.length > 10, 'o log esta ativo');
      assert.ok(output.includes('/v1/auth/login'), 'as requisicoes sao registradas');
      for (const secret of ['Senha#DoLog2026', 'Senha#Errada2026', owner.token, linked.deviceToken, linked.offlineSecret, owner.recoveryKey, 'url-que-nao-vai-pro-log']) {
        assert.ok(!output.includes(secret), `segredo no log: ${secret.slice(0, 6)}...`);
      }
    } finally {
      await logged.close();
    }
  });
});

describe('cancelamento e revogacao da vinculacao', () => {
  test('revogar faz o token responder device_revoked em todas as rotas do aparelho', async () => {
    await seedHistory();
    const revoked = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/revoke`, { token: guardian.token });
    assert.equal(revoked.status, 204);

    const calls: [Parameters<typeof api>[1], string, unknown][] = [
      ['POST', '/v1/device/sync', syncBody(server)],
      ['PUT', '/v1/device/apps', { full: true, apps: [] }],
      ['POST', '/v1/device/admin-verify', { password: PASSWORD }],
      ['POST', '/v1/device/unlink', { password: PASSWORD }],
    ];
    for (const [method, url, body] of calls) {
      const response = await api(server, method, url, { token: device.deviceToken, body });
      assert.equal(response.status, 401, `${method} ${url}`);
      assert.equal(response.body.error.code, 'device_revoked');
    }

    // O aparelho continua listado como revogado, com o historico, ate ser apagado.
    const view = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token });
    assert.equal(view.body.device.status, 'revoked');
    assert.equal(view.body.device.revokedAt, server.now());
    assert.equal(view.body.device.online, false);
    assert.equal(view.body.device.pendingTimeRequests, 0, 'pedidos pendentes expiram com a revogacao');
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', device.deviceId), 1);
    assert.equal((await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/reports/summary`, { token: guardian.token })).status, 200);

    // Revogar de novo e inofensivo, e comandos passam a ser recusados.
    assert.equal((await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/revoke`, { token: guardian.token })).status, 204);
    const command = await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 10 } });
    assert.equal(command.status, 409);
    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    assert.equal(audit.body.entries.filter((entry: { action: string }) => entry.action === 'device.revoke').length, 1);
  });

  test('apagar o historico mantem o vinculo, a politica e o inventario', async () => {
    await seedHistory();
    await api(server, 'PUT', '/v1/device/apps', {
      token: device.deviceToken,
      body: { full: true, apps: [{ package: 'com.jogo.a', label: 'Jogo A', category: 'games', system: false, launchable: true }] },
    });
    await api(server, 'POST', `/v1/guardian/devices/${device.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 20 } });

    const deleted = await api(server, 'DELETE', `/v1/guardian/devices/${device.deviceId}/data`, { token: guardian.token });
    assert.equal(deleted.status, 204);
    for (const table of ['usage_day', 'usage_app', 'usage_sessions', 'events', 'browsing', 'time_requests']) {
      assert.equal(count(server, table, 'device_id = ?', device.deviceId), 0, table);
    }
    assert.equal(count(server, 'alerts', 'device_id = ?', device.deviceId), 0);
    const view = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token });
    assert.equal(view.body.device.status, 'active');
    assert.equal(view.body.device.state, null);
    assert.equal(view.body.policyVersion, 2);
    assert.equal(view.body.policy.overrides.extraTime.length, 1);
    assert.equal((await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/apps`, { token: guardian.token })).body.apps.length, 1);
    assert.equal((await sync(server, device)).status, 200, 'o aparelho continua vinculado');
    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: guardian.token });
    assert.ok(audit.body.entries.some((entry: { action: string; summary: string }) => entry.action === 'device.data_delete' && entry.summary === 'Histórico de João apagado'));
  });

  test('apagar o aparelho remove tudo e desativa o agente', async () => {
    await seedHistory();
    const other = await pairDevice(server, guardian, { childName: 'Ana' });
    await seedHistory(other);

    const deleted = await api(server, 'DELETE', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token });
    assert.equal(deleted.status, 204);
    assert.equal((await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}`, { token: guardian.token })).status, 404);
    for (const table of ['devices', 'apps', 'usage_day', 'usage_app', 'usage_sessions', 'events', 'browsing', 'time_requests', 'links']) {
      const column = table === 'devices' ? 'id' : 'device_id';
      assert.equal(count(server, table, `${column} = ?`, device.deviceId), 0, table);
    }
    const gone = await sync(server, device);
    assert.equal(gone.status, 401);
    assert.equal(gone.body.error.code, 'device_revoked', 'o agente precisa saber que deve se desativar');

    // O outro aparelho da conta nao e afetado.
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', other.deviceId), 1);
    assert.equal((await sync(server, other)).status, 200);
    const list = await api(server, 'GET', '/v1/guardian/devices', { token: guardian.token });
    assert.deepEqual(list.body.devices.map((item: { id: string }) => item.id), [other.deviceId]);
  });

  test('excluir a conta apaga todos os dados e exige a senha', async () => {
    await seedHistory();
    const other = await registerGuardian(server);
    const otherDevice = await pairDevice(server, other);
    await seedHistory(otherDevice);

    const wrong = await api(server, 'DELETE', '/v1/guardian/account', { token: guardian.token, body: { password: 'Senha#Errada99' } });
    assert.equal(wrong.status, 401);
    assert.equal(count(server, 'guardians'), 2);

    const deleted = await api(server, 'DELETE', '/v1/guardian/account', { token: guardian.token, body: { password: PASSWORD } });
    assert.equal(deleted.status, 204);
    assert.equal(count(server, 'guardians', 'id = ?', guardian.guardianId), 0);
    for (const table of ['sessions', 'pairing_codes', 'devices', 'links', 'alerts', 'audit_log']) {
      assert.equal(count(server, table, 'guardian_id = ?', guardian.guardianId), 0, table);
    }
    for (const table of ['apps', 'usage_day', 'usage_app', 'usage_sessions', 'events', 'browsing', 'time_requests']) {
      assert.equal(count(server, table, 'device_id = ?', device.deviceId), 0, table);
    }
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: guardian.token })).status, 401);
    assert.equal((await login(server, guardian.email, PASSWORD)).status, 401);
    assert.equal((await sync(server, device)).body.error.code, 'device_revoked');

    // A outra conta permanece intacta.
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: other.token })).status, 200);
    assert.equal(count(server, 'usage_sessions', 'device_id = ?', otherDevice.deviceId), 1);
    assert.equal((await sync(server, otherDevice)).status, 200);

    // O e-mail fica livre para um novo cadastro.
    const again = await registerGuardian(server, { email: guardian.email });
    assert.notEqual(again.guardianId, guardian.guardianId);
  });
});

describe('entrada hostil', () => {
  test('corpo acima do limite, tipo de conteudo estranho e JSON com __proto__ sao recusados', async () => {
    const huge = await server.app.inject({
      method: 'POST',
      url: '/v1/auth/login',
      headers: { 'content-type': 'application/json' },
      payload: JSON.stringify({ email: 'a@b.co', password: 'x'.repeat(2 * 1024 * 1024), deviceName: 'x' }),
    });
    assert.equal(huge.statusCode, 413);
    assert.equal(JSON.parse(huge.body).error.code, 'payload_too_large');

    const xml = await server.app.inject({ method: 'POST', url: '/v1/auth/login', headers: { 'content-type': 'application/xml' }, payload: '<a/>' });
    assert.equal(xml.statusCode, 400);
    assert.equal(JSON.parse(xml.body).error.code, 'validation_error');

    const poisoned = await server.app.inject({
      method: 'POST',
      url: '/v1/auth/login',
      headers: { 'content-type': 'application/json' },
      payload: '{"email":"a@b.co","password":"x","__proto__":{"admin":true}}',
    });
    assert.equal(poisoned.statusCode, 400);
    assert.equal(({} as Record<string, unknown>).admin, undefined);
  });

  test('injecao de SQL em parametros e tratada como texto', async () => {
    const hostile = "x'OR'1'='1";
    const view = await api(server, 'GET', `/v1/guardian/devices/${encodeURIComponent(hostile)}`, { token: guardian.token });
    assert.equal(view.status, 404);
    const attempt = await login(server, `${hostile}@exemplo.com`, PASSWORD);
    assert.equal(attempt.status, 401);
    const types = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/events?types=${encodeURIComponent("a') OR 1=1 --")}`, { token: guardian.token });
    assert.equal(types.status, 400);
    assert.equal(count(server, 'guardians'), 1);
  });
});
