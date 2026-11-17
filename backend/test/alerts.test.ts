// Alertas gerados por eventos do aparelho, preferencias de notificacao e central de alertas.

import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';

import { api, event, HOUR, login, MINUTE, pairDevice, PASSWORD, registerGuardian, startServer, sync, TODAY } from './helpers.ts';
import type { GuardianAccount, PairedDevice, TestServer } from './helpers.ts';

interface Alert {
  id: number;
  type: string;
  deviceId: string | null;
  childName: string | null;
  createdAt: number;
  readAt: number | null;
  notify: boolean;
  title: string;
  body: string;
  data: Record<string, unknown>;
}

let server: TestServer;
let guardian: GuardianAccount;
let device: PairedDevice;
/** Maior id de alerta existente depois da vinculacao, para olhar so os alertas de cada teste. */
let baseline: number;

beforeEach(async () => {
  server = await startServer();
  guardian = await registerGuardian(server);
  device = await pairDevice(server, guardian);
  baseline = (await api(server, 'GET', '/v1/guardian/alerts', { token: guardian.token })).body.latestId;
});

afterEach(async () => {
  await server.close();
});

async function newAlerts(token = guardian.token, extra = ''): Promise<Alert[]> {
  const response = await api(server, 'GET', `/v1/guardian/alerts?after=${baseline}&limit=200${extra}`, { token });
  assert.equal(response.status, 200);
  return response.body.alerts;
}

describe('eventos do aparelho viram alertas', () => {
  test('cada tipo de evento gera o alerta previsto, com texto em portugues', async () => {
    await api(server, 'PUT', '/v1/device/apps', {
      token: device.deviceToken,
      body: { full: true, apps: [{ package: 'com.jogo.a', label: 'Jogo A', category: 'games', system: false, launchable: true }] },
    });
    const response = await sync(server, device, {
      events: [
        event(server, 'limit_reached', { day: TODAY, limitMs: 150 * MINUTE, quotaUsedMs: 150 * MINUTE }),
        event(server, 'low_time', { remainingMs: 10 * MINUTE, thresholdMinutes: 10 }),
        event(server, 'blocked_attempt', { reason: 'daily_limit' }, 'com.jogo.a'),
        event(server, 'policy_apply_failed', { version: 7, error: 'json invalido' }),
        event(server, 'enforcement_issue', { issue: 'accessibility_disabled', detail: 'servico parado' }),
        event(server, 'permission_changed', { permission: 'usageAccess', granted: false }),
        event(server, 'local_override', { minutes: 30, method: 'offline_code' }),
        event(server, 'admin_auth_failed', { method: 'password', attempts: 3 }),
        event(server, 'clock_changed', { kind: 'time', deltaMs: 7_200_000, timezone: 'America/Fortaleza' }),
        event(server, 'unlinked_locally', { method: 'offline_code' }),
        event(server, 'management_mode_changed', { from: 'standard', to: 'device_owner' }),
        event(server, 'app_installed', { label: 'TikTok' }, 'com.zhiliaoapp.musically'),
        // Eventos sem alerta previsto.
        event(server, 'device_boot'),
        event(server, 'lock_started', { reason: 'daily_limit', releaseAt: null }),
        event(server, 'policy_applied', { version: 1 }),
        event(server, 'app_removed', { label: 'Jogo A' }, 'com.jogo.a'),
        event(server, 'tipo_futuro_desconhecido', { qualquer: 'coisa' }),
      ],
    });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.ack.events.length, 17);

    const alerts = await newAlerts();
    assert.deepEqual(
      alerts.map((alert) => [alert.type, alert.title, alert.body]),
      [
        ['limit_reached', 'Limite diário atingido', 'João usou todo o tempo de hoje (2h30).'],
        ['low_time', 'Pouco tempo restante', 'João tem 10 min restantes hoje.'],
        ['blocked_app_attempt', 'Tentativa de abrir app bloqueado', 'João tentou abrir Jogo A: o limite diário foi atingido.'],
        ['enforcement_failure', 'Falha ao aplicar as regras', 'O aparelho de João não conseguiu aplicar a versão 7 das regras.'],
        [
          'enforcement_failure',
          'Controle parental com problema',
          'Aparelho de João: O serviço de acessibilidade foi desativado. O bloqueio de apps pode não funcionar.',
        ],
        ['permission_changed', 'Permissão revogada', 'Acesso ao uso foi revogada no aparelho de João.'],
        ['security_event', 'Uso liberado no próprio aparelho', 'O uso foi liberado por 30 min no aparelho de João, com código de acesso offline.'],
        ['security_event', 'Tentativa de acesso à área do responsável', 'Autenticação do responsável falhou no aparelho de João (3 tentativas).'],
        ['security_event', 'Relógio do aparelho alterado', 'A data ou a hora do aparelho de João foi alterado.'],
        ['security_event', 'Aparelho desvinculado localmente', 'O controle parental foi desativado no próprio aparelho de João.'],
        ['security_event', 'Modo de gerenciamento alterado', 'O aparelho de João passou do modo padrão para Device Owner.'],
        ['new_app_installed', 'Novo app instalado', 'TikTok foi instalado no aparelho de João.'],
      ],
    );
    for (const alert of alerts) {
      assert.equal(alert.deviceId, device.deviceId);
      assert.equal(alert.childName, 'João');
      assert.equal(alert.notify, true);
      assert.equal(alert.readAt, null);
      assert.equal(alert.createdAt, server.now());
    }
    const blocked = alerts.find((alert) => alert.type === 'blocked_app_attempt');
    assert.deepEqual(blocked?.data, { package: 'com.jogo.a', label: 'Jogo A', reason: 'daily_limit', eventAt: server.now() });
  });

  test('app novo fica aguardando aprovacao quando a politica bloqueia apps novos', async () => {
    await api(server, 'PUT', `/v1/guardian/devices/${device.deviceId}/policy`, {
      token: guardian.token,
      body: { baseVersion: 1, policy: { apps: { defaultForNewApps: 'blocked' } } },
    });
    await sync(server, device, { policyVersion: 2, events: [event(server, 'app_installed', { label: 'Jogo Novo' }, 'com.jogo.novo')] });
    const [alert] = await newAlerts();
    assert.equal(alert?.body, 'Jogo Novo foi instalado no aparelho de João. Ele fica bloqueado até você decidir.');
    assert.equal(alert?.data.awaitingApproval, true);
  });

  test('tentativas no mesmo app geram no maximo um alerta a cada 10 minutos', async () => {
    const attempt = (pkg: string) => event(server, 'blocked_attempt', { reason: 'app_blocked' }, pkg);
    await sync(server, device, { events: [attempt('com.jogo.a'), attempt('com.jogo.a'), attempt('com.jogo.b')] });
    server.advance(9 * MINUTE);
    await sync(server, device, { events: [attempt('com.jogo.a')] });
    let alerts = (await newAlerts()).filter((alert) => alert.type === 'blocked_app_attempt');
    assert.deepEqual(alerts.map((alert) => alert.data.package), ['com.jogo.a', 'com.jogo.b']);

    server.advance(MINUTE + 1);
    await sync(server, device, { events: [attempt('com.jogo.a')] });
    alerts = (await newAlerts()).filter((alert) => alert.type === 'blocked_app_attempt');
    assert.deepEqual(alerts.map((alert) => alert.data.package), ['com.jogo.a', 'com.jogo.b', 'com.jogo.a']);
    // Todos os eventos continuam registrados no historico, mesmo sem alerta.
    const events = await api(server, 'GET', `/v1/guardian/devices/${device.deviceId}/events?types=blocked_attempt`, { token: guardian.token });
    assert.equal(events.body.events.length, 5);
  });

  test('evento que chega com mais de 12 horas de atraso e registrado sem notificar', async () => {
    const old = { ...event(server, 'limit_reached', { day: '2026-11-16', limitMs: HOUR, quotaUsedMs: HOUR }), ts: server.now() - 13 * HOUR };
    const recent = { ...event(server, 'low_time', { remainingMs: 5 * MINUTE, thresholdMinutes: 10 }), ts: server.now() - 11 * HOUR };
    await sync(server, device, { events: [old, recent] });
    const alerts = await newAlerts();
    assert.deepEqual(alerts.map((alert) => [alert.type, alert.notify]), [
      ['limit_reached', false],
      ['low_time', true],
    ]);
  });
});

describe('preferencias de notificacao', () => {
  test('tipo desligado continua na central, mas nao notifica', async () => {
    const saved = await api(server, 'PUT', '/v1/guardian/notification-prefs', {
      token: guardian.token,
      body: { blocked_app_attempt: false, low_time: false },
    });
    assert.equal(saved.status, 200);
    assert.equal(saved.body.notificationPrefs.blocked_app_attempt, false);
    assert.equal(saved.body.notificationPrefs.low_time, false);
    assert.equal(saved.body.notificationPrefs.limit_reached, true, 'os demais nao mudam');
    assert.equal((await api(server, 'GET', '/v1/guardian/me', { token: guardian.token })).body.guardian.notificationPrefs.low_time, false);

    await sync(server, device, {
      events: [
        event(server, 'blocked_attempt', { reason: 'app_blocked' }, 'com.jogo.a'),
        event(server, 'low_time', { remainingMs: 5 * MINUTE, thresholdMinutes: 10 }),
        event(server, 'limit_reached', { day: TODAY, limitMs: HOUR, quotaUsedMs: HOUR }),
      ],
    });
    const all = await newAlerts();
    assert.deepEqual(all.map((alert) => [alert.type, alert.notify]), [
      ['blocked_app_attempt', false],
      ['low_time', false],
      ['limit_reached', true],
    ]);
    const notifying = await newAlerts(guardian.token, '&notifyOnly=1');
    assert.deepEqual(notifying.map((alert) => alert.type), ['limit_reached']);

    // Religar volta a notificar os proximos.
    await api(server, 'PUT', '/v1/guardian/notification-prefs', { token: guardian.token, body: { low_time: true } });
    server.advance(MINUTE);
    await sync(server, device, { events: [event(server, 'low_time', { remainingMs: 2 * MINUTE, thresholdMinutes: 10 })] });
    const after = await newAlerts(guardian.token, '&notifyOnly=1');
    assert.deepEqual(after.map((alert) => alert.type), ['limit_reached', 'low_time']);
  });

  test('preferencia invalida e recusada', async () => {
    const response = await api(server, 'PUT', '/v1/guardian/notification-prefs', {
      token: guardian.token,
      body: { limit_reached: 'sim', tipo_inexistente: true },
    });
    assert.equal(response.status, 400);
    assert.deepEqual(response.body.error.details.fields, ['limit_reached', 'tipo_inexistente']);
  });
});

describe('central de alertas', () => {
  test('busca incremental, paginacao, contagem de nao lidos e marcacao de leitura', async () => {
    for (let index = 0; index < 5; index += 1) {
      await sync(server, device, { events: [event(server, 'permission_changed', { permission: 'overlay', granted: index % 2 === 0 })] });
      server.advance(MINUTE);
    }
    const page = await api(server, 'GET', '/v1/guardian/alerts?limit=3', { token: guardian.token });
    assert.equal(page.body.alerts.length, 3);
    const ids: number[] = page.body.alerts.map((alert: Alert) => alert.id);
    assert.deepEqual(ids, [...ids].sort((a, b) => b - a), 'sem cursor, do mais novo para o mais antigo');
    assert.equal(page.body.latestId, ids[0]);
    assert.equal(page.body.unread, 5 + 1, 'cinco eventos e o alerta do pedido de vinculo');

    const older = await api(server, 'GET', `/v1/guardian/alerts?limit=10&before=${ids[2]}`, { token: guardian.token });
    assert.ok(older.body.alerts.every((alert: Alert) => alert.id < (ids[2] ?? 0)));
    assert.equal(older.body.alerts.length, 3);

    const incremental = await api(server, 'GET', `/v1/guardian/alerts?after=${ids[2]}`, { token: guardian.token });
    assert.deepEqual(incremental.body.alerts.map((alert: Alert) => alert.id), [ids[1], ids[0]], 'com after, em ordem crescente');
    const nothing = await api(server, 'GET', `/v1/guardian/alerts?after=${ids[0]}`, { token: guardian.token });
    assert.deepEqual(nothing.body.alerts, []);
    assert.equal(nothing.body.latestId, ids[0]);

    const some = await api(server, 'POST', '/v1/guardian/alerts/read', { token: guardian.token, body: { ids: [ids[0], ids[1], 999_999] } });
    assert.equal(some.body.unread, 4);
    const read = await api(server, 'GET', '/v1/guardian/alerts?limit=1', { token: guardian.token });
    assert.equal(read.body.alerts[0].readAt, server.now());
    const everything = await api(server, 'POST', '/v1/guardian/alerts/read', { token: guardian.token, body: { all: true } });
    assert.equal(everything.body.unread, 0);

    const invalid = await api(server, 'GET', '/v1/guardian/alerts?limit=abc', { token: guardian.token });
    assert.equal(invalid.status, 400);
  });

  test('quem aprovou o vinculo nao recebe o proprio alerta, a outra sessao recebe', async () => {
    const other = await login(server, guardian.email, PASSWORD, 'Moto do Pedro');
    // A outra sessao ja enxerga a aprovacao do primeiro aparelho: parte do que ela ve agora.
    baseline = (await api(server, 'GET', '/v1/guardian/alerts', { token: other.body.session.token })).body.latestId;
    const second = await pairDevice(server, guardian, { childName: 'Ana', info: { name: 'Galaxy da Ana' } });
    const mine = (await newAlerts()).filter((alert) => alert.type === 'device_linked');
    const theirs = (await newAlerts(other.body.session.token)).filter((alert) => alert.type === 'device_linked');
    // O pedido pendente vem do aparelho da crianca: todos veem. A aprovacao so a outra sessao ve.
    assert.deepEqual(mine.map((alert) => alert.data.status), ['pending']);
    assert.deepEqual(theirs.map((alert) => alert.data.status), ['pending', 'approved']);
    assert.equal(theirs[1]?.body, 'Galaxy da Ana foi vinculado como Ana.');
    assert.equal(theirs[1]?.deviceId, second.deviceId);
    assert.match(theirs[0]?.body ?? '', /Galaxy da Ana pediu vinculação\. Confira o código \d{4} nos dois aparelhos antes de aprovar\./);

    await api(server, 'POST', `/v1/guardian/devices/${second.deviceId}/revoke`, { token: guardian.token });
    const revoked = (await newAlerts(other.body.session.token)).filter((alert) => alert.data.status === 'revoked');
    assert.equal(revoked.length, 1);
    assert.equal(revoked[0]?.title, 'Vínculo removido');
    assert.equal((await newAlerts()).filter((alert) => alert.data.status === 'revoked').length, 0);
  });

  test('alertas de uma conta nao aparecem para outra', async () => {
    await sync(server, device, { events: [event(server, 'limit_reached', { day: TODAY, limitMs: HOUR, quotaUsedMs: HOUR })] });
    const stranger = await registerGuardian(server);
    const response = await api(server, 'GET', '/v1/guardian/alerts', { token: stranger.token });
    assert.deepEqual(response.body, { alerts: [], latestId: 0, unread: 0 });
    const marked = await api(server, 'POST', '/v1/guardian/alerts/read', { token: stranger.token, body: { all: true } });
    assert.equal(marked.body.unread, 0);
    assert.ok((await api(server, 'GET', '/v1/guardian/alerts', { token: guardian.token })).body.unread > 0);
  });
});
