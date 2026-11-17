// Vinculacao: codigo, pedido, aprovacao, entrega unica das credenciais e reaproveitamento.

import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';

import { CODE_ALPHABET } from '../src/core/codes.ts';
import { sha256Hex } from '../src/core/crypto.ts';
import {
  api,
  count,
  dayBody,
  deviceInfo,
  MINUTE,
  newPairingCode,
  pairDevice,
  PASSWORD,
  registerGuardian,
  START,
  startServer,
  statusBody,
  sync,
  TIMEZONE,
  TODAY,
} from './helpers.ts';
import type { GuardianAccount, TestServer } from './helpers.ts';

let server: TestServer;
let guardian: GuardianAccount;

beforeEach(async () => {
  server = await startServer();
  guardian = await registerGuardian(server);
});

afterEach(async () => {
  await server.close();
});

async function claim(code: string, info: Record<string, unknown> = deviceInfo(), ip?: string) {
  return api(server, 'POST', '/v1/pairing/claim', { body: { code, device: info }, ...(ip ? { ip } : {}) });
}

describe('codigo de vinculacao', () => {
  test('gera codigo de 8 caracteres com validade de 15 minutos, guardado so como hash', async () => {
    const response = await api(server, 'POST', '/v1/guardian/pairing-codes', { token: guardian.token });
    assert.equal(response.status, 201);
    assert.equal(response.body.code.length, 8);
    for (const char of response.body.code) assert.ok(CODE_ALPHABET.includes(char));
    assert.equal(response.body.expiresAt, START + 15 * MINUTE);
    const row = server.ctx.db.get<{ code_hash: string }>('SELECT code_hash FROM pairing_codes WHERE id = ?', response.body.id);
    assert.equal(row?.code_hash, sha256Hex(response.body.code));

    const active = await api(server, 'GET', '/v1/guardian/pairing-codes/active', { token: guardian.token });
    assert.deepEqual(active.body.code, { id: response.body.id, expiresAt: START + 15 * MINUTE });
    assert.equal(active.body.code.code, undefined, 'o codigo em si nao pode ser consultado depois');
    assert.deepEqual(active.body.pending, []);
  });

  test('so existe um codigo ativo por conta: gerar outro invalida o anterior', async () => {
    const first = await newPairingCode(server, guardian);
    const second = await newPairingCode(server, guardian);
    assert.notEqual(first, second);
    const old = await claim(first);
    assert.equal(old.status, 410);
    assert.equal(old.body.error.code, 'code_expired');
    assert.equal((await claim(second)).status, 201);
  });

  test('o codigo e de uso unico', async () => {
    const code = await newPairingCode(server, guardian);
    assert.equal((await claim(code)).status, 201);
    const again = await claim(code);
    assert.equal(again.status, 410);
    assert.equal(again.body.error.code, 'code_expired');
    assert.equal(count(server, 'links'), 1);
  });

  test('o codigo vence em 15 minutos', async () => {
    const code = await newPairingCode(server, guardian);
    server.advance(15 * MINUTE);
    const expired = await claim(code);
    assert.equal(expired.status, 410);
    assert.equal(expired.body.error.code, 'code_expired');
    const active = await api(server, 'GET', '/v1/guardian/pairing-codes/active', { token: guardian.token });
    assert.equal(active.body.code, null);
  });

  test('aceita o codigo com hifen, espacos, minusculas e letras ambiguas', async () => {
    // Forca um codigo conhecido para exercitar a normalizacao de O, I e L.
    server.ctx.db.run(
      'INSERT INTO pairing_codes (id, guardian_id, code_hash, created_at, expires_at) VALUES (?, ?, ?, ?, ?)',
      'codigo-fixo',
      guardian.guardianId,
      sha256Hex('0110AB12'),
      START,
      START + 15 * MINUTE,
    );
    const response = await claim(' oil0 - ab12 ');
    assert.equal(response.status, 201);
  });

  test('codigo errado e recusado e 5 erros do mesmo IP bloqueiam novas tentativas', async () => {
    const code = await newPairingCode(server, guardian);
    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const wrong = await claim('ZZZZ-ZZZ' + attempt);
      assert.equal(wrong.status, 401, `tentativa ${attempt}`);
      assert.equal(wrong.body.error.code, 'invalid_credentials');
    }
    // Mesmo o codigo certo fica bloqueado para esse endereco.
    const limited = await claim(code);
    assert.equal(limited.status, 429);
    assert.equal(limited.body.error.code, 'rate_limited');
    // Outro endereco consegue usar o codigo, que continua intacto.
    assert.equal((await claim(code, deviceInfo(), '10.9.8.7')).status, 201);
  });

  test('cancelar o codigo impede o uso', async () => {
    const created = await api(server, 'POST', '/v1/guardian/pairing-codes', { token: guardian.token });
    const cancelled = await api(server, 'DELETE', `/v1/guardian/pairing-codes/${created.body.id}`, { token: guardian.token });
    assert.equal(cancelled.status, 204);
    assert.equal((await claim(created.body.code)).status, 410);
  });

  test('gerar codigo exige elevacao', async () => {
    server.advance(16 * MINUTE);
    const denied = await api(server, 'POST', '/v1/guardian/pairing-codes', { token: guardian.token });
    assert.equal(denied.status, 403);
    assert.equal(denied.body.error.code, 'elevation_required');
  });

  test('dados do aparelho sao validados', async () => {
    const code = await newPairingCode(server, guardian);
    const invalid = await claim(code, deviceInfo({ name: '', sdkInt: 'x', hardwareId: 'curto' }));
    assert.equal(invalid.status, 400);
    assert.deepEqual(invalid.body.error.details.fields, ['device.name', 'device.sdkInt', 'device.hardwareId']);
    // Dados invalidos nao consomem o codigo.
    assert.equal((await claim(code)).status, 201);
  });
});

describe('pedido de vinculo e aprovacao', () => {
  test('o pedido fica pendente ate o responsavel confirmar no outro aparelho', async () => {
    const code = await newPairingCode(server, guardian);
    const claimed = await claim(code);
    assert.equal(claimed.status, 201);
    assert.match(claimed.body.pollToken, /^pp_/);
    assert.match(claimed.body.confirmCode, /^\d{4}$/);
    assert.equal(claimed.body.guardianName, 'Maria');
    assert.equal(claimed.body.expiresAt, START + 30 * MINUTE);

    const poll = await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken });
    assert.deepEqual(poll.body, { status: 'pending' });

    const active = await api(server, 'GET', '/v1/guardian/pairing-codes/active', { token: guardian.token });
    assert.equal(active.body.code, null, 'o codigo foi consumido');
    assert.equal(active.body.pending.length, 1);
    const pending = active.body.pending[0];
    assert.equal(pending.id, claimed.body.linkId);
    assert.equal(pending.status, 'pending');
    assert.equal(pending.confirmCode, claimed.body.confirmCode);
    assert.equal(pending.relink, false);
    assert.equal(pending.deviceName, 'Moto G de João');
    assert.equal(pending.childName, null);
    assert.equal(pending.state, null);

    const list = await api(server, 'GET', '/v1/guardian/devices', { token: guardian.token });
    assert.equal(list.body.devices.length, 1);
    assert.equal(list.body.devices[0].status, 'pending');
    const detail = await api(server, 'GET', `/v1/guardian/devices/${claimed.body.linkId}`, { token: guardian.token });
    assert.equal(detail.body.device.status, 'pending');
    assert.equal(detail.body.policy, null);
    assert.equal(count(server, 'devices'), 0, 'nenhum aparelho existe antes da aprovacao');
  });

  test('aprovar cria o aparelho e entrega as credenciais uma unica vez', async () => {
    const code = await newPairingCode(server, guardian);
    const claimed = await claim(code);
    const approved = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(approved.status, 200);
    const device = approved.body.device;
    assert.equal(device.id, claimed.body.linkId, 'sem reaproveitamento o aparelho herda o id do pedido');
    assert.equal(device.status, 'active');
    assert.equal(device.childName, 'João');
    assert.equal(device.policyVersion, 1);
    assert.equal(device.appliedPolicyVersion, 0);
    assert.equal(device.today, TODAY);
    assert.equal(device.confirmCode, undefined);
    assert.equal(device.relink, undefined);

    const delivered = await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken });
    assert.equal(delivered.body.status, 'approved');
    assert.equal(delivered.body.credentials.deviceId, device.id);
    assert.match(delivered.body.credentials.deviceToken, /^dv_/);
    assert.match(delivered.body.credentials.offlineSecret, /^[A-Z2-7]{32}$/);
    assert.equal(delivered.body.childName, 'João');
    assert.equal(delivered.body.guardianName, 'Maria');
    assert.equal(delivered.body.policyVersion, 1);
    assert.equal(delivered.body.policy.timezone, TIMEZONE);
    assert.equal(delivered.body.policy.dailyLimit.enabled, false);

    // O token de consulta deixa de valer depois da entrega.
    const second = await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken });
    assert.equal(second.status, 401);
    assert.equal(second.body.error.code, 'unauthorized');

    // O token do aparelho e guardado como hash e ja autentica a sincronizacao.
    const row = server.ctx.db.get<{ token_hash: string; offline_secret_enc: string }>(
      'SELECT token_hash, offline_secret_enc FROM devices WHERE id = ?',
      device.id,
    );
    assert.equal(row?.token_hash, sha256Hex(delivered.body.credentials.deviceToken));
    assert.ok(row?.offline_secret_enc.startsWith('enc:v1:'));
    const synced = await api(server, 'POST', '/v1/device/sync', {
      token: delivered.body.credentials.deviceToken,
      body: { sentAt: START, policyVersion: 0, policyAppliedAt: null, status: statusBody() },
    });
    assert.equal(synced.status, 200);

    const secret = await api(server, 'GET', `/v1/guardian/devices/${device.id}/offline-secret`, { token: guardian.token });
    assert.equal(secret.body.secret, delivered.body.credentials.offlineSecret);
  });

  test('aprovar exige elevacao e o nome da crianca', async () => {
    const claimed = await claim(await newPairingCode(server, guardian));
    const missing = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, { token: guardian.token, body: {} });
    assert.equal(missing.status, 400);
    assert.deepEqual(missing.body.error.details.fields, ['childName']);
    server.advance(16 * MINUTE);
    const denied = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(denied.status, 403);
    assert.equal(denied.body.error.code, 'elevation_required');
  });

  test('recusar o pedido informa o aparelho da crianca', async () => {
    const claimed = await claim(await newPairingCode(server, guardian));
    const rejected = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/reject`, { token: guardian.token });
    assert.equal(rejected.status, 204);
    const poll = await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken });
    assert.deepEqual(poll.body, { status: 'rejected' });
    const approve = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(approve.status, 409);
    assert.equal(approve.body.error.code, 'conflict');
    assert.equal(count(server, 'devices'), 0);
  });

  test('pedido pendente expira em 30 minutos', async () => {
    const claimed = await claim(await newPairingCode(server, guardian));
    server.advance(30 * MINUTE);
    const poll = await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken });
    assert.deepEqual(poll.body, { status: 'expired' });
    await api(server, 'POST', '/v1/guardian/session/elevate', { token: guardian.token, body: { password: PASSWORD } });
    const approve = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(approve.status, 409);
    assert.match(approve.body.error.message, /expirou/);
    const list = await api(server, 'GET', '/v1/guardian/devices', { token: guardian.token });
    assert.deepEqual(list.body.devices, []);
  });

  test('aprovar duas vezes responde conflito', async () => {
    const claimed = await claim(await newPairingCode(server, guardian));
    const first = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(first.status, 200);
    const second = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(second.status, 409);
    assert.equal(count(server, 'devices'), 1);
  });

  test('outra conta nao aprova nem recusa o pedido', async () => {
    const stranger = await registerGuardian(server);
    const claimed = await claim(await newPairingCode(server, guardian));
    const approve = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: stranger.token,
      body: { childName: 'Invasor' },
    });
    assert.equal(approve.status, 403);
    assert.equal(approve.body.error.code, 'forbidden');
    const reject = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/reject`, { token: stranger.token });
    assert.equal(reject.status, 403);
    assert.deepEqual((await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken })).body, { status: 'pending' });
  });

  test('token de consulta invalido e recusado', async () => {
    assert.equal((await api(server, 'GET', '/v1/pairing/status', { token: 'pp_inexistente' })).status, 401);
    assert.equal((await api(server, 'GET', '/v1/pairing/status', { token: guardian.token })).status, 401);
    assert.equal((await api(server, 'GET', '/v1/pairing/status')).status, 401);
  });
});

describe('varios aparelhos e reaproveitamento', () => {
  test('uma conta vincula varios aparelhos, cada um com seu token e sua politica', async () => {
    const first = await pairDevice(server, guardian, { childName: 'João' });
    const second = await pairDevice(server, guardian, { childName: 'Ana', info: { name: 'Galaxy da Ana', timezone: 'America/Sao_Paulo' } });
    assert.notEqual(first.deviceId, second.deviceId);
    assert.notEqual(first.deviceToken, second.deviceToken);
    assert.notEqual(first.offlineSecret, second.offlineSecret);

    const list = await api(server, 'GET', '/v1/guardian/devices', { token: guardian.token });
    assert.deepEqual(
      list.body.devices.map((device: { childName: string; status: string }) => [device.childName, device.status]),
      [
        ['Ana', 'active'],
        ['João', 'active'],
      ],
    );
    const ana = await api(server, 'GET', `/v1/guardian/devices/${second.deviceId}`, { token: guardian.token });
    assert.equal(ana.body.policy.timezone, 'America/Sao_Paulo');
    assert.equal(ana.body.device.deviceName, 'Galaxy da Ana');

    // Mudar a politica de um nao afeta o outro.
    const extra = await api(server, 'POST', `/v1/guardian/devices/${first.deviceId}/extra-time`, {
      token: guardian.token,
      body: { minutes: 30 },
    });
    assert.equal(extra.body.policyVersion, 2);
    const untouched = await api(server, 'GET', `/v1/guardian/devices/${second.deviceId}`, { token: guardian.token });
    assert.equal(untouched.body.policyVersion, 1);
  });

  test('o mesmo aparelho vinculado de novo reaproveita o cadastro, a politica e o historico', async () => {
    const original = await pairDevice(server, guardian, { childName: 'João' });
    await api(server, 'POST', `/v1/guardian/devices/${original.deviceId}/extra-time`, { token: guardian.token, body: { minutes: 45 } });
    const used = await sync(server, original, {
      policyVersion: 2,
      days: [dayBody({ quotaUsedMs: 40 * MINUTE, totalUsedMs: 50 * MINUTE, apps: [{ package: 'com.whatsapp', ms: 50 * MINUTE, opens: 3 }] })],
    });
    assert.equal(used.status, 200);

    // O app perdeu os dados (por exemplo, dados limpos) e a crianca usa um novo codigo.
    const code = await newPairingCode(server, guardian);
    const claimed = await claim(code, deviceInfo({ hardwareId: original.hardwareId, name: 'Moto G renomeado', appVersion: '1.1.0' }));
    const pending = await api(server, 'GET', '/v1/guardian/pairing-codes/active', { token: guardian.token });
    assert.equal(pending.body.pending[0].relink, true);

    const approved = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João Pedro' },
    });
    assert.equal(approved.body.device.id, original.deviceId, 'mesmo cadastro');
    assert.notEqual(approved.body.device.id, claimed.body.linkId);
    assert.equal(approved.body.device.childName, 'João Pedro');
    assert.equal(approved.body.device.deviceName, 'Moto G renomeado');
    assert.equal(approved.body.device.policyVersion, 2, 'a politica e a versao sao mantidas');
    assert.equal(approved.body.device.appliedPolicyVersion, 0, 'a nova instalacao ainda nao aplicou nada');
    assert.equal(count(server, 'devices'), 1);

    const delivered = await api(server, 'GET', '/v1/pairing/status', { token: claimed.body.pollToken });
    assert.equal(delivered.body.credentials.deviceId, original.deviceId);
    assert.notEqual(delivered.body.credentials.deviceToken, original.deviceToken);
    assert.notEqual(delivered.body.credentials.offlineSecret, original.offlineSecret);
    assert.equal(delivered.body.policy.overrides.extraTime.length, 1);
    assert.equal(delivered.body.policyVersion, 2);

    // O token antigo deixa de valer e manda o agente antigo se desativar.
    const stale = await sync(server, original);
    assert.equal(stale.status, 401);
    assert.equal(stale.body.error.code, 'device_revoked');

    // O historico continua la e o uso do dia e devolvido para a nova instalacao nao ganhar tempo.
    const relinked = { ...original, deviceToken: delivered.body.credentials.deviceToken };
    const fresh = await sync(server, relinked, { policyVersion: 0, days: [dayBody()] });
    assert.equal(fresh.status, 200);
    assert.deepEqual(fresh.body.reconcile, { day: TODAY, quotaUsedMs: 40 * MINUTE, totalUsedMs: 50 * MINUTE });
    assert.equal(count(server, 'usage_app', 'device_id = ?', original.deviceId), 1);
  });

  test('aparelho revogado tambem e reaproveitado ao vincular de novo', async () => {
    const original = await pairDevice(server, guardian);
    await api(server, 'POST', `/v1/guardian/devices/${original.deviceId}/revoke`, { token: guardian.token });
    const claimed = await claim(await newPairingCode(server, guardian), deviceInfo({ hardwareId: original.hardwareId }));
    const approved = await api(server, 'POST', `/v1/guardian/devices/${claimed.body.linkId}/approve`, {
      token: guardian.token,
      body: { childName: 'João' },
    });
    assert.equal(approved.body.device.id, original.deviceId);
    assert.equal(approved.body.device.status, 'active');
    assert.equal(approved.body.device.revokedAt, null);
  });

  test('o mesmo aparelho em outra conta e um cadastro novo', async () => {
    const original = await pairDevice(server, guardian);
    const other = await registerGuardian(server);
    const paired = await pairDevice(server, other, { info: { hardwareId: original.hardwareId } });
    assert.notEqual(paired.deviceId, original.deviceId);
    assert.equal(count(server, 'devices'), 2);
  });
});
