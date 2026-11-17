#!/usr/bin/env node
// Cliente de linha de comando do responsavel, para testes manuais e de ponta a ponta.
//
// Faz pelo protocolo HTTP o mesmo que o app do responsavel: cria a conta, gera o codigo de
// vinculacao, aprova o aparelho, altera a politica e consulta eventos, alertas e relatorios.
// Guarda o estado (servidor, token, senha de teste) em um arquivo JSON local.
//
// Uso:
//   node scripts/e2e/plx.mjs <comando> [argumentos] [--server URL] [--state arquivo]
//
// Requer Node 24 (fetch embutido). Nao usar em producao: a senha de teste fica no arquivo de
// estado em texto puro.

import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const args = process.argv.slice(2);

function flag(name, fallback = undefined) {
  const index = args.indexOf(`--${name}`);
  if (index < 0) return fallback;
  const value = args[index + 1];
  args.splice(index, 2);
  return value;
}

const statePath = resolve(flag('state', '.plx-e2e-state.json'));
const state = existsSync(statePath) ? JSON.parse(readFileSync(statePath, 'utf8')) : {};
const serverFlag = flag('server');
if (serverFlag) state.server = serverFlag.replace(/\/$/, '');
const command = args.shift();

function save() {
  writeFileSync(statePath, JSON.stringify(state, null, 2));
}

function fail(message) {
  console.error(`erro: ${message}`);
  process.exit(1);
}

async function call(method, path, body, { auth = true, retryElevation = true } = {}) {
  if (!state.server) fail('informe o servidor com --server http://host:porta');
  const headers = { accept: 'application/json' };
  if (auth) {
    if (!state.token) fail('sem sessao. Rode o comando "register" primeiro');
    headers.authorization = `Bearer ${state.token}`;
  }
  if (body !== undefined) headers['content-type'] = 'application/json';
  const response = await fetch(`${state.server}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : {};
  if (response.ok) return json;
  const code = json?.error?.code;
  if (code === 'elevation_required' && retryElevation) {
    await call('POST', '/v1/guardian/session/elevate', { password: state.password }, {
      retryElevation: false,
    });
    return call(method, path, body, { auth, retryElevation: false });
  }
  const error = new Error(`${method} ${path}: ${response.status} ${code ?? ''} ${json?.error?.message ?? text}`);
  error.code = code;
  error.status = response.status;
  throw error;
}

async function activeDeviceId(explicit) {
  if (explicit) return explicit;
  const { devices } = await call('GET', '/v1/guardian/devices');
  const active = devices.filter((device) => device.status === 'active');
  if (active.length === 0) fail('nenhum aparelho ativo');
  return active[0].id;
}

async function getPolicy(deviceId) {
  const detail = await call('GET', `/v1/guardian/devices/${deviceId}`);
  return { version: detail.policyVersion, policy: detail.policy, device: detail.device };
}

async function putPolicy(deviceId, mutate) {
  const { version, policy } = await getPolicy(deviceId);
  const next = structuredClone(policy);
  delete next.overrides;
  mutate(next);
  const result = await call('PUT', `/v1/guardian/devices/${deviceId}/policy`, {
    baseVersion: version,
    policy: next,
  });
  console.log(`politica gravada: versao ${result.policyVersion}`);
  return result;
}

function sleep(ms) {
  return new Promise((done) => setTimeout(done, ms));
}

function formatMs(ms) {
  if (ms == null) return 'sem limite';
  const minutes = Math.floor(ms / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}m${String(seconds).padStart(2, '0')}s`;
}

const commands = {
  async register() {
    const suffix = randomBytes(4).toString('hex');
    state.email = `conta-${suffix}@exemplo.test`;
    state.password = `Xk9-${randomBytes(6).toString('hex')}-Qw7!`;
    const result = await call(
      'POST',
      '/v1/auth/register',
      {
        email: state.email,
        displayName: 'Maria Clara',
        password: state.password,
        deviceName: 'Linha de comando',
      },
      { auth: false },
    );
    state.token = result.session.token;
    state.guardianId = result.guardian.id;
    save();
    console.log(`conta criada: ${state.email}`);
    console.log(`senha de teste: ${state.password}`);
    console.log(`chave de recuperacao: ${result.recoveryKey}`);
  },

  async login() {
    const result = await call(
      'POST',
      '/v1/auth/login',
      { email: state.email, password: state.password, deviceName: 'Linha de comando' },
      { auth: false },
    );
    state.token = result.session.token;
    save();
    console.log('sessao renovada');
  },

  async code() {
    const result = await call('POST', '/v1/guardian/pairing-codes');
    const formatted = `${result.code.slice(0, 4)}-${result.code.slice(4)}`;
    console.log(formatted);
  },

  async pending() {
    const result = await call('GET', '/v1/guardian/pairing-codes/active');
    for (const device of result.pending) {
      console.log(`${device.id}  confirmacao=${device.confirmCode}  ${device.deviceName} (${device.manufacturer} ${device.model})`);
    }
    if (result.pending.length === 0) console.log('(nenhum pedido pendente)');
  },

  // Espera aparecer um pedido de vinculo e aprova. Imprime o identificador do aparelho.
  async 'approve-next'() {
    const name = flag('name', 'Criança de Teste');
    const timeoutSec = Number(flag('timeout', '120'));
    const deadline = Date.now() + timeoutSec * 1000;
    while (Date.now() < deadline) {
      const result = await call('GET', '/v1/guardian/pairing-codes/active');
      if (result.pending.length > 0) {
        const device = result.pending[0];
        await call('POST', `/v1/guardian/devices/${device.id}/approve`, { childName: name });
        console.log(device.id);
        return;
      }
      await sleep(1000);
    }
    fail('nenhum pedido de vinculo chegou no tempo esperado');
  },

  async approve() {
    const deviceId = args.shift() ?? fail('informe o identificador do aparelho');
    const name = flag('name', 'Criança de Teste');
    await call('POST', `/v1/guardian/devices/${deviceId}/approve`, { childName: name });
    console.log(`aprovado: ${deviceId}`);
  },

  async devices() {
    const { devices } = await call('GET', '/v1/guardian/devices');
    for (const device of devices) {
      const s = device.state;
      const usage = s
        ? `usado=${formatMs(s.quotaUsedMs)} limite=${formatMs(s.limitMs)} bloqueio=${s.lock?.state ?? 'none'} frente=${s.foregroundApp ?? '-'}`
        : 'sem sincronizacao';
      console.log(
        `${device.id}  ${device.status}  ${device.childName || device.deviceName}  modo=${device.managementMode}  online=${device.online}  politica=${device.appliedPolicyVersion}/${device.policyVersion}  ${usage}`,
      );
    }
  },

  async device() {
    const deviceId = await activeDeviceId(args.shift());
    console.log(JSON.stringify(await call('GET', `/v1/guardian/devices/${deviceId}`), null, 2));
  },

  async limit() {
    const minutes = Number(args.shift() ?? fail('informe os minutos, ou "off"'));
    const deviceId = await activeDeviceId(flag('device'));
    await putPolicy(deviceId, (policy) => {
      policy.dailyLimit = { ...policy.dailyLimit, enabled: !Number.isNaN(minutes), minutes: Number.isNaN(minutes) ? 120 : minutes };
    });
  },

  async 'limit-off'() {
    const deviceId = await activeDeviceId(flag('device'));
    await putPolicy(deviceId, (policy) => {
      policy.dailyLimit = { ...policy.dailyLimit, enabled: false };
    });
  },

  async rule() {
    const pkg = args.shift() ?? fail('informe o pacote');
    const ruleState = args.shift() ?? fail('informe o estado: allowed, blocked ou exception');
    const deviceId = await activeDeviceId(flag('device'));
    await putPolicy(deviceId, (policy) => {
      policy.apps ??= { defaultForNewApps: 'allowed', rules: {} };
      policy.apps.rules ??= {};
      if (ruleState === 'allowed') delete policy.apps.rules[pkg];
      else policy.apps.rules[pkg] = { state: ruleState };
    });
  },

  async 'app-limit'() {
    const pkg = args.shift() ?? fail('informe o pacote');
    const minutes = Number(args.shift() ?? fail('informe os minutos'));
    const deviceId = await activeDeviceId(flag('device'));
    await putPolicy(deviceId, (policy) => {
      policy.apps ??= { defaultForNewApps: 'allowed', rules: {} };
      policy.apps.rules ??= {};
      policy.apps.rules[pkg] = { state: 'allowed', dailyLimitMinutes: minutes };
    });
  },

  // Cria um periodo de bloqueio pontual que comeca agora e dura os minutos informados.
  async 'block-now-period'() {
    const minutes = Number(args.shift() ?? '10');
    const deviceId = await activeDeviceId(flag('device'));
    const now = Date.now();
    await putPolicy(deviceId, (policy) => {
      policy.blockPeriods = [
        ...(policy.blockPeriods ?? []),
        {
          id: crypto.randomUUID(),
          label: 'Bloqueio de teste',
          enabled: true,
          kind: 'once',
          startAt: now - 1000,
          endAt: now + minutes * 60000,
        },
      ];
    });
  },

  async 'clear-periods'() {
    const deviceId = await activeDeviceId(flag('device'));
    await putPolicy(deviceId, (policy) => {
      policy.blockPeriods = [];
      policy.allowedHours = { enabled: false, windows: [] };
    });
  },

  async lock() {
    const deviceId = await activeDeviceId(flag('device'));
    const result = await call('POST', `/v1/guardian/devices/${deviceId}/lock`, { until: null });
    console.log(`bloqueio manual ligado: versao ${result.policyVersion}`);
  },

  async unlock() {
    const deviceId = await activeDeviceId(flag('device'));
    const result = await call('POST', `/v1/guardian/devices/${deviceId}/unlock`);
    console.log(`bloqueio manual desligado: versao ${result.policyVersion}`);
  },

  async extra() {
    const minutes = Number(args.shift() ?? '15');
    const deviceId = await activeDeviceId(flag('device'));
    const result = await call('POST', `/v1/guardian/devices/${deviceId}/extra-time`, { minutes });
    console.log(`tempo extra de ${minutes} min: versao ${result.policyVersion}`);
  },

  async suspend() {
    const minutes = Number(args.shift() ?? '15');
    const scopes = (flag('scopes', 'dailyLimit,schedules,appBlocks')).split(',');
    const deviceId = await activeDeviceId(flag('device'));
    const result = await call('POST', `/v1/guardian/devices/${deviceId}/suspension`, { minutes, scopes });
    console.log(`regras suspensas por ${minutes} min: versao ${result.policyVersion}`);
  },

  async resume() {
    const deviceId = await activeDeviceId(flag('device'));
    const result = await call('DELETE', `/v1/guardian/devices/${deviceId}/suspension`);
    console.log(`suspensao encerrada: versao ${result.policyVersion}`);
  },

  async revoke() {
    const deviceId = await activeDeviceId(args.shift());
    await call('POST', `/v1/guardian/devices/${deviceId}/revoke`);
    console.log(`vinculo revogado: ${deviceId}`);
  },

  async apps() {
    const deviceId = await activeDeviceId(flag('device'));
    const result = await call('GET', `/v1/guardian/devices/${deviceId}/apps`);
    for (const app of result.apps) {
      const marks = [app.essential ? 'essencial' : '', app.system ? 'sistema' : '', app.launchable ? '' : 'sem-icone']
        .filter(Boolean)
        .join(',');
      console.log(`${app.state.padEnd(9)} ${formatMs(app.todayMs).padEnd(10)} ${app.category.padEnd(13)} ${app.package}  "${app.label}" ${marks}`);
    }
    console.log(`${result.apps.length} apps, dia ${result.day}`);
  },

  async events() {
    const deviceId = await activeDeviceId(flag('device'));
    const types = flag('types');
    const limit = flag('limit', '30');
    const query = new URLSearchParams({ limit });
    if (types) query.set('types', types);
    const result = await call('GET', `/v1/guardian/devices/${deviceId}/events?${query}`);
    for (const event of result.events) {
      console.log(`${new Date(event.ts).toISOString()}  ${event.type.padEnd(22)} ${event.package ?? ''} ${JSON.stringify(event.data ?? {})}`);
    }
    if (result.events.length === 0) console.log('(sem eventos)');
  },

  // Espera ate existir um evento do tipo informado. Usado como verificacao nos roteiros.
  async 'wait-event'() {
    const type = args.shift() ?? fail('informe o tipo do evento');
    const pkg = flag('package');
    const timeoutSec = Number(flag('timeout', '90'));
    const sinceMs = Number(flag('since', '0'));
    const deviceId = await activeDeviceId(flag('device'));
    const deadline = Date.now() + timeoutSec * 1000;
    while (Date.now() < deadline) {
      const result = await call('GET', `/v1/guardian/devices/${deviceId}/events?types=${type}&limit=20`);
      const match = result.events.find(
        (event) => event.ts >= sinceMs && (!pkg || event.package === pkg),
      );
      if (match) {
        console.log(`ok: ${type} ${match.package ?? ''} ${JSON.stringify(match.data ?? {})}`);
        return;
      }
      await sleep(2000);
    }
    fail(`o evento ${type} nao apareceu em ${timeoutSec} s`);
  },

  // Espera o aparelho confirmar a versao atual da politica.
  async 'wait-applied'() {
    const timeoutSec = Number(flag('timeout', '90'));
    const deviceId = await activeDeviceId(flag('device'));
    const deadline = Date.now() + timeoutSec * 1000;
    while (Date.now() < deadline) {
      const { device } = await call('GET', `/v1/guardian/devices/${deviceId}`);
      if (device.appliedPolicyVersion >= device.policyVersion) {
        console.log(`ok: politica ${device.policyVersion} aplicada no aparelho`);
        return;
      }
      await sleep(1500);
    }
    fail(`o aparelho nao confirmou a politica em ${timeoutSec} s`);
  },

  // Espera o estado de bloqueio informado (none, daily_limit, schedule, manual_lock).
  async 'wait-lock'() {
    const expected = args.shift() ?? fail('informe o estado esperado');
    const timeoutSec = Number(flag('timeout', '120'));
    const deviceId = await activeDeviceId(flag('device'));
    const deadline = Date.now() + timeoutSec * 1000;
    let last = '(sem estado)';
    while (Date.now() < deadline) {
      const { device } = await call('GET', `/v1/guardian/devices/${deviceId}`);
      last = device.state?.lock?.state ?? '(sem estado)';
      if (last === expected) {
        console.log(`ok: bloqueio ${expected}, usado ${formatMs(device.state.quotaUsedMs)} de ${formatMs(device.state.limitMs)}`);
        return;
      }
      await sleep(2000);
    }
    fail(`esperava bloqueio ${expected}, mas o aparelho informa ${last}`);
  },

  async alerts() {
    const result = await call('GET', '/v1/guardian/alerts?limit=30');
    for (const alert of result.alerts) {
      console.log(`#${alert.id} ${new Date(alert.createdAt).toISOString()} [${alert.type}] ${alert.title}: ${alert.body}`);
    }
    console.log(`${result.alerts.length} alertas, ${result.unread} nao lidos`);
  },

  async report() {
    const deviceId = await activeDeviceId(flag('device'));
    const { device } = await call('GET', `/v1/guardian/devices/${deviceId}`);
    const to = flag('to', device.today);
    const from = flag('from', to);
    const result = await call('GET', `/v1/guardian/devices/${deviceId}/reports/summary?from=${from}&to=${to}`);
    console.log(`periodo ${result.from} a ${result.to} (${result.timezone})`);
    console.log(`total ${formatMs(result.totals.totalMs)}, cota ${formatMs(result.totals.quotaMs)}, tentativas bloqueadas ${result.totals.blockedAttempts}`);
    for (const app of result.apps.slice(0, 10)) {
      console.log(`  ${formatMs(app.totalMs).padEnd(10)} ${app.opens} aberturas  ${app.package} "${app.label}"`);
    }
  },

  async audit() {
    const result = await call('GET', '/v1/guardian/audit?limit=30');
    for (const entry of result.entries) {
      console.log(`${new Date(entry.at).toISOString()}  ${entry.action.padEnd(24)} ${entry.summary ?? ''}`);
    }
  },

  async 'offline-code'() {
    const deviceId = await activeDeviceId(flag('device'));
    const { secret } = await call('GET', `/v1/guardian/devices/${deviceId}/offline-secret`);
    const { createHmac } = await import('node:crypto');
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    let bits = '';
    for (const char of secret.replace(/=+$/, '')) bits += alphabet.indexOf(char).toString(2).padStart(5, '0');
    const key = Buffer.from(bits.match(/.{8}/g).map((byte) => parseInt(byte, 2)));
    const counter = Buffer.alloc(8);
    counter.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 1000 / 60)));
    const mac = createHmac('sha256', key).update(counter).digest();
    const offset = mac[mac.length - 1] & 0x0f;
    const binary = ((mac[offset] & 0x7f) << 24) | (mac[offset + 1] << 16) | (mac[offset + 2] << 8) | mac[offset + 3];
    console.log(String(binary % 100000000).padStart(8, '0'));
  },

  async password() {
    console.log(state.password ?? '(sem conta)');
  },
};

if (!command || !commands[command]) {
  console.error(`comandos: ${Object.keys(commands).join(', ')}`);
  process.exit(command ? 1 : 0);
}

try {
  await commands[command]();
  save();
} catch (error) {
  fail(error.message);
}
