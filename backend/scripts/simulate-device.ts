// Simulador de aparelho da crianca, para testes manuais do backend e do painel.
//
// Uso:
//   node scripts/simulate-device.ts --url http://localhost:8080 --code AB12-CD34
//
// O simulador usa o codigo de vinculacao, espera a aprovacao no painel, envia o inventario de
// apps com icones e passa a sincronizar com uso crescente e alguns eventos. As credenciais ficam
// em um arquivo de estado: rodar de novo sem --code retoma o mesmo aparelho.

import { createHash, randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { deflateSync } from 'node:zlib';

import { WebSocket } from 'ws';

interface Options {
  url: string;
  code: string | null;
  name: string;
  intervalSec: number;
  minutesPerTick: number;
  ticks: number;
  state: string;
}

interface Credentials {
  deviceId: string;
  deviceToken: string;
  offlineSecret: string;
  hardwareId: string;
}

interface AppRule {
  state: 'allowed' | 'blocked' | 'exception';
  countsTowardLimit?: boolean;
}

interface Policy {
  timezone: string;
  dailyLimit: { enabled: boolean; minutes: number; perWeekday: Record<string, number>; resetTime: string };
  apps: { defaultForNewApps: string; rules: Record<string, AppRule> };
  overrides: {
    extraTime: { day: string; minutes: number }[];
    manualLock: { active: boolean; until: number | null };
  };
}

interface SimApp {
  package: string;
  label: string;
  category: string;
  system: boolean;
  essential: boolean;
  color: [number, number, number];
}

const APPS: SimApp[] = [
  { package: 'com.whatsapp', label: 'WhatsApp', category: 'communication', system: false, essential: false, color: [37, 211, 102] },
  { package: 'com.google.android.youtube', label: 'YouTube', category: 'video', system: true, essential: false, color: [255, 0, 0] },
  { package: 'com.supercell.brawlstars', label: 'Brawl Stars', category: 'games', system: false, essential: false, color: [255, 190, 0] },
  { package: 'com.zhiliaoapp.musically', label: 'TikTok', category: 'social', system: false, essential: false, color: [20, 20, 20] },
  { package: 'com.duolingo', label: 'Duolingo', category: 'productivity', system: false, essential: false, color: [88, 204, 2] },
  { package: 'com.android.chrome', label: 'Chrome', category: 'browser', system: true, essential: false, color: [66, 133, 244] },
  { package: 'com.parentalynx.app.browser', label: 'Navegador seguro', category: 'browser', system: false, essential: false, color: [48, 70, 197] },
  { package: 'com.android.settings', label: 'Configurações', category: 'system', system: true, essential: false, color: [120, 120, 120] },
  { package: 'com.google.android.dialer', label: 'Telefone', category: 'communication', system: true, essential: true, color: [0, 150, 136] },
];

function parseOptions(argv: string[]): Options {
  const values = new Map<string, string>();
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new Error('Uso: node scripts/simulate-device.ts --url <servidor> --code <codigo> [--name <nome>] [--interval <s>] [--minutes-per-tick <min>] [--ticks <n>] [--state <arquivo>]');
    }
    values.set(key.slice(2), value);
  }
  const name = values.get('name') ?? 'Aparelho simulado';
  return {
    url: (values.get('url') ?? 'http://localhost:8080').replace(/\/+$/, ''),
    code: values.get('code') ?? null,
    name,
    intervalSec: Number(values.get('interval') ?? 15),
    minutesPerTick: Number(values.get('minutes-per-tick') ?? 5),
    ticks: Number(values.get('ticks') ?? 0),
    state: values.get('state') ?? `./data/simulator-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}.json`,
  };
}

async function call(options: Options, method: string, path: string, token: string | null, body?: unknown): Promise<{ status: number; body: Record<string, unknown> }> {
  const headers: Record<string, string> = {};
  if (token) headers.authorization = `Bearer ${token}`;
  let payload: string | Buffer | undefined;
  if (Buffer.isBuffer(body)) {
    headers['content-type'] = 'image/png';
    payload = body;
  } else if (body !== undefined) {
    headers['content-type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const response = await fetch(`${options.url}${path}`, { method, headers, body: payload });
  const text = await response.text();
  return { status: response.status, body: text === '' ? {} : (JSON.parse(text) as Record<string, unknown>) };
}

function crc32(data: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type: string, data: Buffer): Buffer {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
}

/** Icone quadrado de cor unica, em PNG valido, gerado sem dependencias. */
function solidPng(size: number, [red, green, blue]: [number, number, number]): Buffer {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header.set([8, 2, 0, 0, 0], 8);
  const row = Buffer.concat([Buffer.from([0]), Buffer.from(Array.from({ length: size }, () => [red, green, blue]).flat())]);
  const pixels = Buffer.concat(Array.from({ length: size }, () => row));
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk('IHDR', header),
    pngChunk('IDAT', deflateSync(pixels)),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

function localDay(instantMs: number, timeZone: string, resetTime: string): { day: string; hour: number; offsetMin: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).formatToParts(new Date(instantMs));
  const read = (type: string): number => Number(parts.find((part) => part.type === type)?.value ?? 0);
  const local = Date.UTC(read('year'), read('month') - 1, read('day'), read('hour'), read('minute'));
  const [resetHour = 0, resetMinute = 0] = resetTime.split(':').map(Number);
  const beforeReset = read('hour') * 60 + read('minute') < resetHour * 60 + resetMinute;
  const day = new Date(local - (beforeReset ? 86_400_000 : 0)).toISOString().slice(0, 10);
  return { day, hour: read('hour'), offsetMin: Math.round((local - Math.floor(instantMs / 60_000) * 60_000) / 60_000) };
}

function limitMinutes(policy: Policy, day: string): number | null {
  if (!policy.dailyLimit.enabled) return null;
  const weekday = new Date(`${day}T00:00:00Z`).getUTCDay() || 7;
  const base = policy.dailyLimit.perWeekday[String(weekday)] ?? policy.dailyLimit.minutes;
  const extra = policy.overrides.extraTime.filter((entry) => entry.day === day).reduce((sum, entry) => sum + entry.minutes, 0);
  return base + extra;
}

function ruleOf(policy: Policy, app: SimApp): AppRule {
  if (app.essential) return { state: 'exception', countsTowardLimit: false };
  const rule = policy.apps.rules[app.package];
  if (rule) return rule;
  return policy.apps.defaultForNewApps === 'blocked' && !app.system ? { state: 'blocked' } : { state: 'allowed', countsTowardLimit: true };
}

async function pair(options: Options): Promise<{ credentials: Credentials; policyVersion: number; policy: Policy }> {
  if (!options.code) throw new Error('Informe --code com o código de vinculação gerado no painel do responsável.');
  const hardwareId = createHash('sha256').update(`simulador:${options.name}`).digest('hex');
  const claim = await call(options, 'POST', '/v1/pairing/claim', null, {
    code: options.code,
    device: {
      name: options.name,
      model: 'simulador',
      manufacturer: 'ParentaLynx',
      androidRelease: '15',
      sdkInt: 35,
      appVersion: '1.0.0-sim',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      hardwareId,
    },
  });
  if (claim.status !== 201) throw new Error(`Vinculação recusada (${claim.status}): ${JSON.stringify(claim.body)}`);
  console.log(`Pedido enviado a ${String(claim.body.guardianName)}. Código de confirmação: ${String(claim.body.confirmCode)}`);
  console.log('Aprove o aparelho no painel do responsável...');
  for (;;) {
    await new Promise((resolve) => setTimeout(resolve, 2000));
    const status = await call(options, 'GET', '/v1/pairing/status', String(claim.body.pollToken));
    if (status.status !== 200) throw new Error(`Consulta falhou (${status.status}): ${JSON.stringify(status.body)}`);
    if (status.body.status === 'pending') continue;
    if (status.body.status !== 'approved') throw new Error(`Vínculo ${String(status.body.status)}.`);
    const granted = status.body.credentials as { deviceId: string; deviceToken: string; offlineSecret: string };
    console.log(`Vinculado como ${String(status.body.childName)}. Aparelho ${granted.deviceId}.`);
    return {
      credentials: { ...granted, hardwareId },
      policyVersion: Number(status.body.policyVersion),
      policy: status.body.policy as Policy,
    };
  }
}

async function sendInventory(options: Options, token: string): Promise<void> {
  const icons = new Map(APPS.map((app) => [app.package, solidPng(48, app.color)]));
  const hashOf = (pkg: string): string => createHash('sha256').update(icons.get(pkg) ?? Buffer.alloc(0)).digest('hex').slice(0, 16);
  const response = await call(options, 'PUT', '/v1/device/apps', token, {
    full: true,
    apps: APPS.map((app) => ({
      package: app.package,
      label: app.label,
      category: app.category,
      system: app.system,
      launchable: true,
      essential: app.essential,
      versionName: '1.0',
      installedAt: Date.now() - 30 * 86_400_000,
      updatedAt: Date.now() - 86_400_000,
      iconHash: hashOf(app.package),
    })),
  });
  if (response.status !== 200) throw new Error(`Inventário recusado (${response.status}): ${JSON.stringify(response.body)}`);
  const need = response.body.needIcons as string[];
  for (const pkg of need) {
    const icon = icons.get(pkg);
    if (icon) await call(options, 'PUT', `/v1/device/apps/icon?package=${encodeURIComponent(pkg)}&hash=${hashOf(pkg)}`, token, icon);
  }
  console.log(`Inventário enviado: ${APPS.length} apps, ${need.length} ícones.`);
}

async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));
  let credentials: Credentials;
  let policyVersion = 0;
  let policy: Policy | null = null;

  if (!options.code && existsSync(options.state)) {
    credentials = JSON.parse(readFileSync(options.state, 'utf8')) as Credentials;
    console.log(`Retomando o aparelho ${credentials.deviceId} (${options.state}).`);
  } else {
    const paired = await pair(options);
    credentials = paired.credentials;
    policyVersion = paired.policyVersion;
    policy = paired.policy;
    mkdirSync(dirname(options.state), { recursive: true });
    writeFileSync(options.state, JSON.stringify(credentials, null, 2), { mode: 0o600 });
  }
  const token = credentials.deviceToken;
  await sendInventory(options, token);

  // Aviso em tempo real: o servidor pede sincronizacao quando o responsavel muda algo.
  let wake: (() => void) | null = null;
  const socket = new WebSocket(`${options.url.replace(/^http/, 'ws')}/v1/device/stream`, { headers: { authorization: `Bearer ${token}` } });
  socket.on('message', (raw) => {
    const message = JSON.parse(raw.toString()) as { type: string; reason?: string };
    if (message.type === 'sync_now') {
      console.log(`Servidor pediu sincronização (${message.reason ?? 'sem motivo'}).`);
      wake?.();
    } else if (message.type === 'revoked') {
      console.log('Vínculo revogado pelo responsável. Encerrando.');
      process.exit(0);
    }
  });
  socket.on('error', () => undefined);
  const ping = setInterval(() => socket.readyState === WebSocket.OPEN && socket.send(JSON.stringify({ type: 'ping' })), 30_000);

  const usage = new Map<string, { ms: number; opens: number }>();
  const hourly = new Array<number>(24).fill(0);
  let currentDay = '';
  let quotaMs = 0;
  let totalMs = 0;
  let limitReachedAt: number | null = null;
  let firstUseAt: number | null = null;
  let lowTimeSent = false;
  let lowTimeMinutes = 10;
  const events: Record<string, unknown>[] = [
    { id: randomUUID(), type: 'agent_started', ts: Date.now(), package: null, data: { reason: 'app_open' } },
  ];
  const sessions: Record<string, unknown>[] = [];
  const browsing: Record<string, unknown>[] = [];

  for (let tick = 1; options.ticks === 0 || tick <= options.ticks; tick += 1) {
    const now = Date.now();
    const zone = policy?.timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
    const local = localDay(now, zone, policy?.dailyLimit.resetTime ?? '00:00');
    if (local.day !== currentDay) {
      currentDay = local.day;
      usage.clear();
      hourly.fill(0);
      quotaMs = 0;
      totalMs = 0;
      limitReachedAt = null;
      firstUseAt = null;
      lowTimeSent = false;
    }
    const limit = policy ? limitMinutes(policy, currentDay) : null;
    const manualLock = policy?.overrides.manualLock.active === true && (policy.overrides.manualLock.until === null || policy.overrides.manualLock.until > now);
    const overLimit = limit !== null && quotaMs >= limit * 60_000;
    const app = APPS[(tick - 1) % APPS.length] as SimApp;
    const rule = policy ? ruleOf(policy, app) : { state: 'allowed' as const, countsTowardLimit: true };
    const generalBlock = manualLock || overLimit;

    if (rule.state === 'blocked' || (generalBlock && rule.state !== 'exception')) {
      const reason = rule.state === 'blocked' ? 'app_blocked' : manualLock ? 'manual_lock' : 'daily_limit';
      events.push({ id: randomUUID(), type: 'blocked_attempt', ts: now, package: app.package, data: { reason } });
      console.log(`[${tick}] ${app.label}: bloqueado (${reason}).`);
    } else {
      const usedMs = options.minutesPerTick * 60_000;
      const entry = usage.get(app.package) ?? { ms: 0, opens: 0 };
      entry.ms += usedMs;
      entry.opens += 1;
      usage.set(app.package, entry);
      totalMs += usedMs;
      // Em avanco rapido o uso simulado passa de uma hora real por hora: limita o balde para o
      // servidor nao recusar a sincronizacao.
      hourly[local.hour] = Math.min(3_600_000, (hourly[local.hour] ?? 0) + usedMs);
      firstUseAt ??= now - usedMs;
      const counts = rule.state === 'allowed' || rule.countsTowardLimit === true;
      if (counts && !app.essential) quotaMs += usedMs;
      sessions.push({ id: randomUUID(), package: app.package, start: now - usedMs, end: now, day: currentDay, tzOffsetMin: local.offsetMin });
      if (app.category === 'browser') {
        browsing.push({ id: randomUUID(), ts: now, url: `https://pt.wikipedia.org/wiki/Lince?visita=${tick}`, domain: 'pt.wikipedia.org', title: 'Lince', blocked: false, reason: null });
      }
      console.log(`[${tick}] ${app.label}: ${options.minutesPerTick} min. Cota usada: ${Math.round(quotaMs / 60_000)} min${limit === null ? '' : ` de ${limit}`}.`);
      if (limit !== null) {
        const remaining = limit * 60_000 - quotaMs;
        if (remaining <= 0 && limitReachedAt === null) {
          limitReachedAt = now;
          events.push({ id: randomUUID(), type: 'limit_reached', ts: now, package: null, data: { day: currentDay, limitMs: limit * 60_000, quotaUsedMs: quotaMs } });
        } else if (remaining > 0 && remaining <= lowTimeMinutes * 60_000 && !lowTimeSent) {
          lowTimeSent = true;
          events.push({ id: randomUUID(), type: 'low_time', ts: now, package: null, data: { remainingMs: remaining, thresholdMinutes: lowTimeMinutes } });
        }
      }
    }
    if (tick % 12 === 4) {
      events.push({ id: randomUUID(), type: 'time_request', ts: now, package: null, data: { minutes: 30, message: 'Posso jogar mais um pouco?' } });
    }

    const locked = manualLock ? 'manual_lock' : limit !== null && quotaMs >= limit * 60_000 ? 'daily_limit' : 'none';
    const response = await call(options, 'POST', '/v1/device/sync', token, {
      sentAt: now,
      policyVersion,
      policyAppliedAt: policyVersion === 0 ? null : now,
      status: {
        managementMode: 'standard',
        permissions: { usageAccess: true, accessibility: true, overlay: true, notifications: true, batteryOptimizationIgnored: true, deviceAdmin: false, exactAlarms: true },
        enforcement: { active: true, issues: [] },
        lock: { state: locked, releaseAt: null },
        foregroundApp: app.package,
        screenOn: true,
        batteryPercent: Math.max(5, 100 - tick),
        appVersion: '1.0.0-sim',
        sdkInt: 35,
        timezone: zone,
        tzOffsetMin: local.offsetMin,
        clockTrusted: true,
      },
      days: [
        {
          day: currentDay,
          quotaUsedMs: quotaMs,
          totalUsedMs: totalMs,
          limitMs: limit === null ? null : limit * 60_000,
          extraMs: 0,
          limitReachedAt,
          firstUseAt,
          lastUseAt: totalMs > 0 ? now : null,
          apps: [...usage.entries()].map(([pkg, value]) => ({ package: pkg, ms: value.ms, opens: value.opens })),
          hourly,
        },
      ],
      sessions,
      events,
      browsing,
    });
    if (response.status === 401) {
      console.log(`Token recusado (${JSON.stringify(response.body)}). Encerrando.`);
      break;
    }
    if (response.status !== 200) {
      console.log(`Sincronização falhou (${response.status}): ${JSON.stringify(response.body)}`);
    } else {
      sessions.length = 0;
      events.length = 0;
      browsing.length = 0;
      lowTimeMinutes = Number(response.body.lowTimeMinutes ?? 10);
      const reconcile = response.body.reconcile as { quotaUsedMs: number; totalUsedMs: number } | null;
      if (reconcile) {
        quotaMs = Math.max(quotaMs, reconcile.quotaUsedMs);
        totalMs = Math.max(totalMs, reconcile.totalUsedMs);
      }
      if (response.body.policy) {
        policy = response.body.policy as Policy;
        policyVersion = Number(response.body.policyVersion);
        events.push({ id: randomUUID(), type: 'policy_applied', ts: Date.now(), package: null, data: { version: policyVersion } });
        console.log(`Política versão ${policyVersion} aplicada.`);
      }
      for (const request of response.body.timeRequests as { status: string; grantedMinutes: number | null }[]) {
        if (request.status !== 'pending') console.log(`Pedido de tempo ${request.status}${request.grantedMinutes ? ` (+${request.grantedMinutes} min)` : ''}.`);
      }
    }
    await new Promise<void>((resolve) => {
      const timer = setTimeout(resolve, options.intervalSec * 1000);
      wake = () => {
        clearTimeout(timer);
        resolve();
      };
    });
    wake = null;
  }
  clearInterval(ping);
  socket.close();
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
