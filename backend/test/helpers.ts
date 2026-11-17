// Apoio aos testes: servidor em memoria com relogio controlado e atalhos para os fluxos comuns.

import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';

import type { FastifyInstance } from 'fastify';

import { buildApp } from '../src/app.ts';
import type { LogStream } from '../src/app.ts';
import { DEFAULT_RATE_LIMITS } from '../src/config.ts';
import type { AppConfig } from '../src/config.ts';
import type { AppContext } from '../src/context.ts';
import { openDatabase } from '../src/db/database.ts';

/** 17/11/2026 12:00 em America/Fortaleza (15:00 UTC), uma terca-feira. */
export const START = Date.UTC(2026, 10, 17, 15, 0, 0);
export const TODAY = '2026-11-17';
export const TIMEZONE = 'America/Fortaleza';
export const PASSWORD = 'Girassol#Azul27';

export const MINUTE = 60_000;
export const HOUR = 3_600_000;
export const DAY = 86_400_000;

export interface TestServer {
  app: FastifyInstance;
  ctx: AppContext;
  /** Avanca o relogio do servidor. */
  advance(ms: number): void;
  now(): number;
  close(): Promise<void>;
}

export interface ServerOptions {
  config?: Partial<AppConfig>;
  databasePath?: string;
  logStream?: LogStream;
}

export async function startServer(options: ServerOptions = {}): Promise<TestServer> {
  let now = START;
  const config: AppConfig = {
    env: 'test',
    port: 0,
    host: '127.0.0.1',
    databasePath: options.databasePath ?? ':memory:',
    dataKey: randomBytes(32),
    trustProxy: false,
    logLevel: 'silent',
    sessionTtlDays: 30,
    elevationMinutes: 15,
    pairingCodeTtlMinutes: 15,
    linkTtlMinutes: 30,
    rateLimits: DEFAULT_RATE_LIMITS,
    now: () => now,
    ...options.config,
  };
  const { app, ctx } = await buildApp(config, openDatabase(config.databasePath), options.logStream);
  await app.ready();
  return {
    app,
    ctx,
    advance(ms: number) {
      now += ms;
    },
    now: () => now,
    close: () => app.close(),
  };
}

export interface ApiResponse {
  status: number;
  // Corpo JSON ja decodificado. Os testes navegam nele livremente, por isso o tipo aberto.
  body: any;
  headers: Record<string, string | string[] | number | undefined>;
  raw: Buffer;
}

export interface ApiOptions {
  token?: string;
  body?: unknown;
  headers?: Record<string, string>;
  ip?: string;
}

export async function api(
  server: TestServer,
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  url: string,
  options: ApiOptions = {},
): Promise<ApiResponse> {
  const headers: Record<string, string> = { ...options.headers };
  if (options.token) headers.authorization = `Bearer ${options.token}`;
  const response = await server.app.inject({
    method,
    url,
    headers,
    ...(options.body === undefined ? {} : { payload: options.body as object }),
    ...(options.ip ? { remoteAddress: options.ip } : {}),
  });
  const type = String(response.headers['content-type'] ?? '');
  let body: unknown = null;
  if (type.includes('application/json') && response.body !== '') body = JSON.parse(response.body);
  return { status: response.statusCode, body, headers: response.headers, raw: response.rawPayload };
}

export interface GuardianAccount {
  email: string;
  password: string;
  token: string;
  sessionId: string;
  guardianId: string;
  recoveryKey: string;
}

let counter = 0;

export async function registerGuardian(
  server: TestServer,
  overrides: { email?: string; displayName?: string; password?: string; deviceName?: string } = {},
): Promise<GuardianAccount> {
  counter += 1;
  const email = overrides.email ?? `responsavel${counter}@exemplo.com`;
  const password = overrides.password ?? PASSWORD;
  const response = await api(server, 'POST', '/v1/auth/register', {
    body: {
      email,
      displayName: overrides.displayName ?? 'Maria',
      password,
      deviceName: overrides.deviceName ?? 'Galaxy da Maria',
    },
  });
  assert.equal(response.status, 201, JSON.stringify(response.body));
  return {
    email,
    password,
    token: response.body.session.token,
    sessionId: response.body.session.id,
    guardianId: response.body.guardian.id,
    recoveryKey: response.body.recoveryKey,
  };
}

export async function login(server: TestServer, email: string, password: string, deviceName = 'Moto do Pedro'): Promise<ApiResponse> {
  return api(server, 'POST', '/v1/auth/login', { body: { email, password, deviceName } });
}

export function deviceInfo(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    name: 'Moto G de João',
    model: 'moto g54',
    manufacturer: 'motorola',
    androidRelease: '14',
    sdkInt: 34,
    appVersion: '1.0.0',
    timezone: TIMEZONE,
    hardwareId: randomBytes(32).toString('hex'),
    ...overrides,
  };
}

export interface PairedDevice {
  deviceId: string;
  deviceToken: string;
  offlineSecret: string;
  linkId: string;
  hardwareId: string;
  policyVersion: number;
  policy: Record<string, unknown>;
}

export async function newPairingCode(server: TestServer, guardian: GuardianAccount): Promise<string> {
  const response = await api(server, 'POST', '/v1/guardian/pairing-codes', { token: guardian.token });
  assert.equal(response.status, 201, JSON.stringify(response.body));
  return response.body.code;
}

/** Fluxo completo de vinculacao: codigo, pedido, aprovacao e entrega das credenciais. */
export async function pairDevice(
  server: TestServer,
  guardian: GuardianAccount,
  options: { childName?: string; info?: Record<string, unknown> } = {},
): Promise<PairedDevice> {
  const code = await newPairingCode(server, guardian);
  const info = deviceInfo(options.info);
  const claim = await api(server, 'POST', '/v1/pairing/claim', { body: { code, device: info } });
  assert.equal(claim.status, 201, JSON.stringify(claim.body));
  const approve = await api(server, 'POST', `/v1/guardian/devices/${claim.body.linkId}/approve`, {
    token: guardian.token,
    body: { childName: options.childName ?? 'João' },
  });
  assert.equal(approve.status, 200, JSON.stringify(approve.body));
  const status = await api(server, 'GET', '/v1/pairing/status', { token: claim.body.pollToken });
  assert.equal(status.status, 200, JSON.stringify(status.body));
  assert.equal(status.body.status, 'approved');
  return {
    deviceId: status.body.credentials.deviceId,
    deviceToken: status.body.credentials.deviceToken,
    offlineSecret: status.body.credentials.offlineSecret,
    linkId: claim.body.linkId,
    hardwareId: String(info.hardwareId),
    policyVersion: status.body.policyVersion,
    policy: status.body.policy,
  };
}

export function statusBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    managementMode: 'standard',
    permissions: {
      usageAccess: true,
      accessibility: true,
      overlay: false,
      notifications: true,
      batteryOptimizationIgnored: true,
      deviceAdmin: false,
      exactAlarms: true,
    },
    enforcement: { active: true, issues: [] },
    lock: { state: 'none', releaseAt: null },
    foregroundApp: 'com.whatsapp',
    screenOn: true,
    batteryPercent: 80,
    appVersion: '1.0.0',
    sdkInt: 34,
    timezone: TIMEZONE,
    tzOffsetMin: -180,
    clockTrusted: true,
    ...overrides,
  };
}

export function hourly(values: Record<number, number> = {}): number[] {
  const out = new Array<number>(24).fill(0);
  for (const [hour, ms] of Object.entries(values)) out[Number(hour)] = ms;
  return out;
}

export function dayBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    day: TODAY,
    quotaUsedMs: 0,
    totalUsedMs: 0,
    limitMs: null,
    extraMs: 0,
    limitReachedAt: null,
    firstUseAt: null,
    lastUseAt: null,
    apps: [],
    hourly: hourly(),
    ...overrides,
  };
}

export function syncBody(server: TestServer, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    sentAt: server.now(),
    policyVersion: 1,
    policyAppliedAt: server.now(),
    status: statusBody(),
    days: [dayBody()],
    sessions: [],
    events: [],
    browsing: [],
    ...overrides,
  };
}

export async function sync(server: TestServer, device: PairedDevice, overrides: Record<string, unknown> = {}): Promise<ApiResponse> {
  return api(server, 'POST', '/v1/device/sync', { token: device.deviceToken, body: syncBody(server, overrides) });
}

export function event(server: TestServer, type: string, data: Record<string, unknown> = {}, pkg: string | null = null): Record<string, unknown> {
  return { id: randomUUID(), type, ts: server.now(), package: pkg, data };
}

/** PNG minimo valido (1x1), para os testes de icone. */
export const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

export function count(server: TestServer, table: string, where = '1 = 1', ...params: (string | number)[]): number {
  const row = server.ctx.db.get<{ total: number }>(`SELECT COUNT(*) AS total FROM ${table} WHERE ${where}`, ...params);
  return row?.total ?? 0;
}
