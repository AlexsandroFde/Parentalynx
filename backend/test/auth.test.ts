// Contas, sessoes, elevacao, bloqueio por tentativas e recuperacao.

import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';

import { sha256Hex } from '../src/core/crypto.ts';
import { api, count, DAY, login, MINUTE, PASSWORD, registerGuardian, START, startServer } from './helpers.ts';
import type { TestServer } from './helpers.ts';

let server: TestServer;

beforeEach(async () => {
  server = await startServer();
});

afterEach(async () => {
  await server.close();
});

describe('criacao do perfil de responsavel', () => {
  test('registra a conta, abre sessao elevada e entrega a chave de recuperacao uma vez', async () => {
    const response = await api(server, 'POST', '/v1/auth/register', {
      body: { email: ' Maria@Exemplo.com ', displayName: 'Maria', password: PASSWORD, deviceName: 'Galaxy da Maria' },
    });
    assert.equal(response.status, 201);
    const { guardian, session, recoveryKey } = response.body;
    assert.equal(guardian.email, 'maria@exemplo.com');
    assert.equal(guardian.displayName, 'Maria');
    assert.equal(guardian.createdAt, START);
    assert.deepEqual(guardian.settings, { retentionDays: 90, syncStaleMinutes: 180, offlineHours: 24, lowTimeMinutes: 10 });
    assert.equal(Object.keys(guardian.notificationPrefs).length, 12);
    assert.ok(Object.values(guardian.notificationPrefs).every((value) => value === true));
    assert.match(session.token, /^gs_/);
    assert.equal(session.deviceName, 'Galaxy da Maria');
    assert.equal(session.current, true);
    assert.equal(session.elevatedUntil, START + 15 * MINUTE);
    assert.equal(session.expiresAt, START + 30 * DAY);
    assert.match(recoveryKey, /^RK(-[0-9A-Z]{5}){5}$/);

    const me = await api(server, 'GET', '/v1/guardian/me', { token: session.token });
    assert.equal(me.status, 200);
    assert.equal(me.body.guardian.id, guardian.id);
    assert.equal(me.body.session.id, session.id);
    assert.equal(me.body.session.token, undefined, 'o token so aparece na criacao');
  });

  test('a senha, o token e a chave de recuperacao nunca ficam em texto puro no banco', async () => {
    const account = await registerGuardian(server);
    const guardian = server.ctx.db.get<{ password_hash: string; recovery_key_hash: string }>(
      'SELECT password_hash, recovery_key_hash FROM guardians WHERE id = ?',
      account.guardianId,
    );
    assert.ok(guardian);
    assert.match(guardian.password_hash, /^\$argon2id\$v=19\$m=19456,t=2,p=1\$/);
    assert.ok(!guardian.password_hash.includes(PASSWORD));
    assert.match(guardian.recovery_key_hash, /^[0-9a-f]{64}$/);
    const session = server.ctx.db.get<{ token_hash: string }>('SELECT token_hash FROM sessions WHERE id = ?', account.sessionId);
    assert.equal(session?.token_hash, sha256Hex(account.token));
    const dump = JSON.stringify(server.ctx.db.all('SELECT * FROM guardians')) + JSON.stringify(server.ctx.db.all('SELECT * FROM sessions'));
    assert.ok(!dump.includes(PASSWORD));
    assert.ok(!dump.includes(account.token));
    assert.ok(!dump.includes(account.recoveryKey));
  });

  test('recusa senha fora da politica, com os motivos', async () => {
    const attempt = async (password: string) =>
      api(server, 'POST', '/v1/auth/register', {
        body: { email: 'joana.souza@exemplo.com', displayName: 'Joana Souza', password, deviceName: 'Aparelho' },
      });
    const short = await attempt('Abc#1');
    assert.equal(short.status, 400);
    assert.equal(short.body.error.code, 'weak_password');
    assert.deepEqual(short.body.error.details.reasons, ['too_short']);
    assert.match(short.body.error.message, /10 caracteres/);
    assert.deepEqual((await attempt('somenteminusculas')).body.error.details.reasons, ['few_classes']);
    assert.deepEqual((await attempt('Casa#Joana#2026')).body.error.details.reasons, ['contains_identity']);
    assert.deepEqual((await attempt('Xjoana.souza#99')).body.error.details.reasons, ['contains_identity']);
    assert.deepEqual((await attempt('Password123!')).body.error.details.reasons, ['common']);
    assert.equal(count(server, 'guardians'), 0);
  });

  test('recusa e-mail repetido e dados invalidos no formato do protocolo', async () => {
    const account = await registerGuardian(server);
    const duplicate = await api(server, 'POST', '/v1/auth/register', {
      body: { email: account.email.toUpperCase(), displayName: 'Outra', password: PASSWORD, deviceName: 'Aparelho' },
    });
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.body.error.code, 'email_in_use');

    const invalid = await api(server, 'POST', '/v1/auth/register', {
      body: { email: 'sem-arroba', displayName: '', password: PASSWORD },
    });
    assert.equal(invalid.status, 400);
    assert.equal(invalid.body.error.code, 'validation_error');
    assert.deepEqual(invalid.body.error.details.fields, ['email', 'displayName']);
    assert.equal(typeof invalid.body.error.message, 'string');

    const malformed = await server.app.inject({
      method: 'POST',
      url: '/v1/auth/register',
      headers: { 'content-type': 'application/json' },
      payload: '{ "email": ',
    });
    assert.equal(malformed.statusCode, 400);
    assert.equal(JSON.parse(malformed.body).error.code, 'validation_error');
  });
});

describe('login e protecao contra tentativas', () => {
  test('entra com a senha certa e recusa credenciais erradas sem dizer qual falhou', async () => {
    const account = await registerGuardian(server);
    const ok = await login(server, account.email, PASSWORD);
    assert.equal(ok.status, 200);
    assert.match(ok.body.session.token, /^gs_/);
    assert.notEqual(ok.body.session.token, account.token);
    assert.equal(ok.body.recoveryKey, undefined);

    const wrongPassword = await login(server, account.email, 'Senha#Errada99');
    const unknownEmail = await login(server, 'ninguem@exemplo.com', PASSWORD);
    for (const response of [wrongPassword, unknownEmail]) {
      assert.equal(response.status, 401);
      assert.equal(response.body.error.code, 'invalid_credentials');
      assert.equal(response.body.error.message, 'E-mail ou senha incorretos.');
    }
  });

  test('bloqueio progressivo: 1 minuto a partir de 5 falhas, dobrando a cada nova falha', async () => {
    const account = await registerGuardian(server);
    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const response = await login(server, account.email, 'Senha#Errada99');
      assert.equal(response.status, 401, `tentativa ${attempt}`);
    }
    // Bloqueado: nem a senha certa entra.
    const locked = await login(server, account.email, PASSWORD);
    assert.equal(locked.status, 423);
    assert.equal(locked.body.error.code, 'account_locked');
    assert.equal(locked.body.error.details.retryAfterSec, 60);
    assert.equal(locked.headers['retry-after'], '60');

    server.advance(30_000);
    assert.equal((await login(server, account.email, PASSWORD)).body.error.details.retryAfterSec, 30);

    // Passado o bloqueio, a sexta falha dobra o prazo para 2 minutos.
    server.advance(31_000);
    assert.equal((await login(server, account.email, 'Senha#Errada99')).status, 401);
    const second = await login(server, account.email, PASSWORD);
    assert.equal(second.status, 423);
    assert.equal(second.body.error.details.retryAfterSec, 120);

    // A senha certa depois do prazo zera o contador.
    server.advance(121_000);
    assert.equal((await login(server, account.email, PASSWORD)).status, 200);
    for (let attempt = 1; attempt <= 4; attempt += 1) {
      assert.equal((await login(server, account.email, 'Senha#Errada99')).status, 401);
    }
    assert.equal((await login(server, account.email, PASSWORD)).status, 200, 'quatro falhas nao bloqueiam');
  });

  test('o bloqueio dobra ate o teto de 60 minutos', async () => {
    const account = await registerGuardian(server);
    const expected = [60, 120, 240, 480, 960, 1920, 3600, 3600];
    for (let attempt = 1; attempt <= 4; attempt += 1) await login(server, account.email, 'Senha#Errada99');
    for (const seconds of expected) {
      assert.equal((await login(server, account.email, 'Senha#Errada99')).status, 401);
      const locked = await login(server, account.email, PASSWORD);
      assert.equal(locked.status, 423);
      assert.equal(locked.body.error.details.retryAfterSec, seconds);
      server.advance(seconds * 1000 + 1);
    }
  });

  test('limite por IP nas rotas publicas', async () => {
    const quick = await startServer({
      config: {
        rateLimits: { ...server.ctx.config.rateLimits, login: { limit: 3, windowMs: MINUTE } },
      },
    });
    try {
      for (let attempt = 1; attempt <= 3; attempt += 1) {
        assert.equal((await login(quick, `ninguem${attempt}@exemplo.com`, PASSWORD)).status, 401);
      }
      const limited = await login(quick, 'ninguem4@exemplo.com', PASSWORD);
      assert.equal(limited.status, 429);
      assert.equal(limited.body.error.code, 'rate_limited');
      assert.ok(limited.body.error.details.retryAfterSec > 0);
      // Outro endereco tem a sua propria janela.
      const other = await api(quick, 'POST', '/v1/auth/login', {
        body: { email: 'ninguem5@exemplo.com', password: PASSWORD, deviceName: 'x' },
        ip: '10.1.2.3',
      });
      assert.equal(other.status, 401);
      quick.advance(MINUTE + 1);
      assert.equal((await login(quick, 'ninguem6@exemplo.com', PASSWORD)).status, 401);
    } finally {
      await quick.close();
    }
  });
});

describe('sessoes e elevacao', () => {
  test('token ausente, desconhecido ou de outro tipo e recusado', async () => {
    const missing = await api(server, 'GET', '/v1/guardian/me');
    assert.equal(missing.status, 401);
    assert.equal(missing.body.error.code, 'unauthorized');
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: 'gs_naoexiste' })).body.error.code, 'unauthorized');
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: 'dv_naoexiste' })).body.error.code, 'unauthorized');
    assert.equal((await api(server, 'GET', '/v1/guardian/devices')).status, 401);
  });

  test('rotas administrativas exigem senha confirmada nos ultimos 15 minutos', async () => {
    const account = await registerGuardian(server);
    const elevated = await api(server, 'PATCH', '/v1/guardian/me', { token: account.token, body: { displayName: 'Maria Clara' } });
    assert.equal(elevated.status, 200);
    assert.equal(elevated.body.guardian.displayName, 'Maria Clara');

    server.advance(15 * MINUTE + 1);
    const denied = await api(server, 'PATCH', '/v1/guardian/me', { token: account.token, body: { displayName: 'Outro' } });
    assert.equal(denied.status, 403);
    assert.equal(denied.body.error.code, 'elevation_required');
    assert.equal((await api(server, 'POST', '/v1/guardian/pairing-codes', { token: account.token })).status, 403);
    // Leitura continua liberada sem elevacao.
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: account.token })).status, 200);

    const wrong = await api(server, 'POST', '/v1/guardian/session/elevate', { token: account.token, body: { password: 'Senha#Errada99' } });
    assert.equal(wrong.status, 401);
    assert.equal(wrong.body.error.code, 'invalid_credentials');

    const granted = await api(server, 'POST', '/v1/guardian/session/elevate', { token: account.token, body: { password: PASSWORD } });
    assert.equal(granted.status, 200);
    assert.equal(granted.body.elevatedUntil, server.now() + 15 * MINUTE);
    const retried = await api(server, 'PATCH', '/v1/guardian/me', { token: account.token, body: { displayName: 'Outro' } });
    assert.equal(retried.status, 200);
  });

  test('elevacao usa o mesmo contador de tentativas da conta', async () => {
    const account = await registerGuardian(server);
    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const response = await api(server, 'POST', '/v1/guardian/session/elevate', { token: account.token, body: { password: 'Senha#Errada99' } });
      assert.equal(response.status, 401);
    }
    const locked = await api(server, 'POST', '/v1/guardian/session/elevate', { token: account.token, body: { password: PASSWORD } });
    assert.equal(locked.status, 423);
    assert.equal((await login(server, account.email, PASSWORD)).status, 423, 'o login tambem fica bloqueado');
    // A sessao existente continua valendo para leitura.
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: account.token })).status, 200);
  });

  test('lista sessoes, revoga outra sessao e encerra a propria', async () => {
    const account = await registerGuardian(server);
    const second = await login(server, account.email, PASSWORD, 'Moto do Pedro');
    const list = await api(server, 'GET', '/v1/guardian/sessions', { token: account.token });
    assert.equal(list.body.sessions.length, 2);
    assert.deepEqual(
      list.body.sessions.map((session: { deviceName: string; current: boolean }) => [session.deviceName, session.current]).sort(),
      [
        ['Galaxy da Maria', true],
        ['Moto do Pedro', false],
      ],
    );

    const revoke = await api(server, 'DELETE', `/v1/guardian/sessions/${second.body.session.id}`, { token: account.token });
    assert.equal(revoke.status, 204);
    const revoked = await api(server, 'GET', '/v1/guardian/me', { token: second.body.session.token });
    assert.equal(revoked.status, 401);
    assert.equal(revoked.body.error.code, 'session_expired');
    assert.equal((await api(server, 'DELETE', '/v1/guardian/sessions/nao-existe', { token: account.token })).status, 404);

    assert.equal((await api(server, 'POST', '/v1/auth/logout', { token: account.token })).status, 204);
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: account.token })).body.error.code, 'session_expired');
  });

  test('a sessao expira em 30 dias sem uso e se renova a cada uso', async () => {
    const account = await registerGuardian(server);
    server.advance(20 * DAY);
    const used = await api(server, 'GET', '/v1/guardian/me', { token: account.token });
    assert.equal(used.status, 200);
    assert.equal(used.body.session.expiresAt, server.now() + 30 * DAY);
    server.advance(25 * DAY);
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: account.token })).status, 200, 'renovada pelo uso no dia 20');
    server.advance(30 * DAY + 1);
    const expired = await api(server, 'GET', '/v1/guardian/me', { token: account.token });
    assert.equal(expired.status, 401);
    assert.equal(expired.body.error.code, 'session_expired');
  });

  test('troca de senha revoga as outras sessoes', async () => {
    const account = await registerGuardian(server);
    const second = await login(server, account.email, PASSWORD);
    const wrong = await api(server, 'POST', '/v1/guardian/password', {
      token: account.token,
      body: { currentPassword: 'Senha#Errada99', newPassword: 'Outra#Senha2026' },
    });
    assert.equal(wrong.status, 401);
    const weak = await api(server, 'POST', '/v1/guardian/password', {
      token: account.token,
      body: { currentPassword: PASSWORD, newPassword: 'fraca' },
    });
    assert.equal(weak.body.error.code, 'weak_password');

    const changed = await api(server, 'POST', '/v1/guardian/password', {
      token: account.token,
      body: { currentPassword: PASSWORD, newPassword: 'Outra#Senha2026' },
    });
    assert.equal(changed.status, 204);
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: account.token })).status, 200);
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: second.body.session.token })).body.error.code, 'session_expired');
    assert.equal((await login(server, account.email, PASSWORD)).status, 401);
    assert.equal((await login(server, account.email, 'Outra#Senha2026')).status, 200);
  });

  test('configuracoes da conta respeitam os limites', async () => {
    const account = await registerGuardian(server);
    const ok = await api(server, 'PATCH', '/v1/guardian/me', {
      token: account.token,
      body: { settings: { retentionDays: 30, lowTimeMinutes: 5 } },
    });
    assert.deepEqual(ok.body.guardian.settings, { retentionDays: 30, syncStaleMinutes: 180, offlineHours: 24, lowTimeMinutes: 5 });
    const invalid = await api(server, 'PATCH', '/v1/guardian/me', {
      token: account.token,
      body: { settings: { retentionDays: 5, offlineHours: 1000, desconhecida: 1 } },
    });
    assert.equal(invalid.status, 400);
    assert.deepEqual(invalid.body.error.details.fields, ['settings.retentionDays', 'settings.offlineHours', 'settings.desconhecida']);
  });
});

describe('recuperacao administrativa', () => {
  test('a chave de recuperacao troca a senha, gera nova chave e revoga as sessoes', async () => {
    const account = await registerGuardian(server);
    const other = await login(server, account.email, PASSWORD);

    const wrongKey = await api(server, 'POST', '/v1/auth/recover', {
      body: { email: account.email, recoveryKey: 'RK-AAAAA-AAAAA-AAAAA-AAAAA-AAAAA', newPassword: 'Nova#Senha2026', deviceName: 'Novo' },
    });
    assert.equal(wrongKey.status, 401);
    assert.equal(wrongKey.body.error.code, 'invalid_credentials');

    const weak = await api(server, 'POST', '/v1/auth/recover', {
      body: { email: account.email, recoveryKey: account.recoveryKey, newPassword: 'fraca', deviceName: 'Novo' },
    });
    assert.equal(weak.body.error.code, 'weak_password');

    // A chave e aceita em minusculas e sem hifens.
    const recovered = await api(server, 'POST', '/v1/auth/recover', {
      body: {
        email: account.email,
        recoveryKey: account.recoveryKey.toLowerCase().replace(/-/g, ' '),
        newPassword: 'Nova#Senha2026',
        deviceName: 'Aparelho novo',
      },
    });
    assert.equal(recovered.status, 200);
    assert.match(recovered.body.recoveryKey, /^RK-/);
    assert.notEqual(recovered.body.recoveryKey, account.recoveryKey);
    assert.match(recovered.body.session.token, /^gs_/);
    assert.equal(recovered.body.session.elevatedUntil, START + 15 * MINUTE);

    for (const token of [account.token, other.body.session.token]) {
      assert.equal((await api(server, 'GET', '/v1/guardian/me', { token })).body.error.code, 'session_expired');
    }
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: recovered.body.session.token })).status, 200);
    assert.equal((await login(server, account.email, PASSWORD)).status, 401);
    assert.equal((await login(server, account.email, 'Nova#Senha2026')).status, 200);

    // A chave antiga deixou de valer.
    const reused = await api(server, 'POST', '/v1/auth/recover', {
      body: { email: account.email, recoveryKey: account.recoveryKey, newPassword: 'Mais#Uma2026x', deviceName: 'x' },
    });
    assert.equal(reused.status, 401);

    const audit = await api(server, 'GET', '/v1/guardian/audit', { token: recovered.body.session.token });
    const actions = audit.body.entries.map((entry: { action: string }) => entry.action);
    assert.ok(actions.includes('auth.recover'));
    assert.ok(actions.includes('auth.recover_failed'));
  });

  test('recuperacao libera uma conta bloqueada por tentativas de login', async () => {
    const account = await registerGuardian(server);
    for (let attempt = 1; attempt <= 5; attempt += 1) await login(server, account.email, 'Senha#Errada99');
    assert.equal((await login(server, account.email, PASSWORD)).status, 423);
    const recovered = await api(server, 'POST', '/v1/auth/recover', {
      body: { email: account.email, recoveryKey: account.recoveryKey, newPassword: 'Nova#Senha2026', deviceName: 'x' },
    });
    assert.equal(recovered.status, 200);
    assert.equal((await login(server, account.email, 'Nova#Senha2026')).status, 200);
  });

  test('5 chaves erradas bloqueiam a recuperacao por 60 minutos', async () => {
    const account = await registerGuardian(server);
    const attempt = (key: string) =>
      api(server, 'POST', '/v1/auth/recover', {
        body: { email: account.email, recoveryKey: key, newPassword: 'Nova#Senha2026', deviceName: 'x' },
      });
    for (let index = 1; index <= 5; index += 1) {
      assert.equal((await attempt('RK-BBBBB-BBBBB-BBBBB-BBBBB-BBBBB')).status, 401);
    }
    const locked = await attempt(account.recoveryKey);
    assert.equal(locked.status, 423);
    assert.equal(locked.body.error.details.retryAfterSec, 3600);
    // O login normal nao e afetado pelo contador de recuperacao.
    assert.equal((await login(server, account.email, PASSWORD)).status, 200);
    server.advance(60 * MINUTE + 1);
    assert.equal((await attempt(account.recoveryKey)).status, 200);
  });

  test('gera nova chave de recuperacao mediante senha', async () => {
    const account = await registerGuardian(server);
    const wrong = await api(server, 'POST', '/v1/guardian/recovery-key', { token: account.token, body: { password: 'Senha#Errada99' } });
    assert.equal(wrong.status, 401);
    const rotated = await api(server, 'POST', '/v1/guardian/recovery-key', { token: account.token, body: { password: PASSWORD } });
    assert.equal(rotated.status, 200);
    assert.notEqual(rotated.body.recoveryKey, account.recoveryKey);
    const old = await api(server, 'POST', '/v1/auth/recover', {
      body: { email: account.email, recoveryKey: account.recoveryKey, newPassword: 'Nova#Senha2026', deviceName: 'x' },
    });
    assert.equal(old.status, 401);
    const fresh = await api(server, 'POST', '/v1/auth/recover', {
      body: { email: account.email, recoveryKey: rotated.body.recoveryKey, newPassword: 'Nova#Senha2026', deviceName: 'x' },
    });
    assert.equal(fresh.status, 200);
  });
});

describe('rotas basicas', () => {
  test('saude, metadados e rota inexistente', async () => {
    const health = await api(server, 'GET', '/health');
    assert.deepEqual(health.body, { status: 'ok', time: START });
    const meta = await api(server, 'GET', '/v1/meta');
    assert.deepEqual(meta.body, { serverTime: START, apiVersion: 1, name: 'ParentaLynx' });
    assert.equal(meta.headers['x-content-type-options'], 'nosniff');
    assert.equal(meta.headers['cache-control'], 'no-store');
    const missing = await api(server, 'GET', '/v1/nao-existe');
    assert.equal(missing.status, 404);
    assert.equal(missing.body.error.code, 'not_found');
  });
});
