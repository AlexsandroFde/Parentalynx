// Configuracao do servidor, lida de variaveis de ambiente.

import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

import type { RateRule } from './core/rate-limit.ts';
import { HOUR_MS, MINUTE_MS } from './core/time.ts';

export type Environment = 'production' | 'development' | 'test';

export interface RateLimits {
  /** Consulta de metadados e hora do servidor. */
  meta: RateRule;
  register: RateRule;
  login: RateRule;
  recover: RateRule;
  /** Todas as tentativas de uso de codigo de vinculacao. */
  claim: RateRule;
  /** Tentativas com codigo errado. */
  claimFailures: RateRule;
  pairingStatus: RateRule;
}

export interface AppConfig {
  env: Environment;
  port: number;
  host: string;
  /** Caminho do arquivo SQLite, ou `:memory:`. */
  databasePath: string;
  /** Chave de 32 bytes da cifra de campos. */
  dataKey: Buffer;
  trustProxy: boolean;
  logLevel: string;
  sessionTtlDays: number;
  elevationMinutes: number;
  pairingCodeTtlMinutes: number;
  /** Validade de um pedido de vinculo aguardando aprovacao. */
  linkTtlMinutes: number;
  rateLimits: RateLimits;
  /** Relogio injetavel. Os testes o substituem para avancar o tempo. */
  now: () => number;
}

export const DEFAULT_RATE_LIMITS: RateLimits = {
  meta: { limit: 120, windowMs: MINUTE_MS },
  register: { limit: 10, windowMs: HOUR_MS },
  login: { limit: 20, windowMs: MINUTE_MS },
  recover: { limit: 10, windowMs: HOUR_MS },
  claim: { limit: 20, windowMs: 15 * MINUTE_MS },
  claimFailures: { limit: 5, windowMs: 15 * MINUTE_MS },
  pairingStatus: { limit: 240, windowMs: MINUTE_MS },
};

function readInt(value: string | undefined, fallback: number, name: string, min: number, max: number): number {
  if (value === undefined || value.trim() === '') return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new Error(`Variável ${name} inválida: esperado inteiro entre ${min} e ${max}.`);
  }
  return parsed;
}

function readBool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined || value.trim() === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function readEnvironment(value: string | undefined): Environment {
  if (value === 'production' || value === 'test') return value;
  return 'development';
}

function decodeKey(encoded: string): Buffer {
  const key = Buffer.from(encoded.trim(), 'base64');
  if (key.length !== 32) {
    throw new Error('DATA_ENCRYPTION_KEY precisa ser o base64 de exatamente 32 bytes.');
  }
  return key;
}

/**
 * Resolve a chave da cifra de campos.
 * - Em producao a variavel e obrigatoria.
 * - Em desenvolvimento, sem a variavel, a chave e gerada e gravada ao lado do banco, para que
 *   os dados continuem legiveis entre execucoes.
 */
function resolveDataKey(
  encoded: string | undefined,
  environment: Environment,
  databasePath: string,
  warn: (message: string) => void,
): Buffer {
  if (encoded && encoded.trim() !== '') return decodeKey(encoded);
  if (environment === 'production') {
    throw new Error(
      'DATA_ENCRYPTION_KEY é obrigatória em produção. Gere com: ' +
        'node -e "console.log(require(\'node:crypto\').randomBytes(32).toString(\'base64\'))"',
    );
  }
  if (databasePath === ':memory:') return randomBytes(32);
  const keyPath = `${databasePath}.key`;
  if (existsSync(keyPath)) return decodeKey(readFileSync(keyPath, 'utf8'));
  const key = randomBytes(32);
  mkdirSync(dirname(keyPath), { recursive: true });
  writeFileSync(keyPath, key.toString('base64'), { mode: 0o600 });
  warn(
    `DATA_ENCRYPTION_KEY não definida: chave de desenvolvimento gerada em ${keyPath}. ` +
      'Em produção defina a variável e guarde a chave fora do servidor.',
  );
  return key;
}

export function loadConfig(
  env: NodeJS.ProcessEnv = process.env,
  warn: (message: string) => void = (message) => console.warn(`[config] ${message}`),
): AppConfig {
  const environment = readEnvironment(env.NODE_ENV);
  const databasePath = env.DATABASE_PATH?.trim() || './data/parentalynx.db';
  return {
    env: environment,
    port: readInt(env.PORT, 8080, 'PORT', 0, 65_535),
    host: env.HOST?.trim() || '0.0.0.0',
    databasePath,
    dataKey: resolveDataKey(env.DATA_ENCRYPTION_KEY, environment, databasePath, warn),
    trustProxy: readBool(env.TRUST_PROXY, false),
    logLevel: env.LOG_LEVEL?.trim() || (environment === 'test' ? 'silent' : 'info'),
    sessionTtlDays: readInt(env.SESSION_TTL_DAYS, 30, 'SESSION_TTL_DAYS', 1, 365),
    elevationMinutes: readInt(env.ELEVATION_MINUTES, 15, 'ELEVATION_MINUTES', 1, 240),
    pairingCodeTtlMinutes: readInt(env.PAIRING_CODE_TTL_MINUTES, 15, 'PAIRING_CODE_TTL_MINUTES', 1, 120),
    linkTtlMinutes: 30,
    rateLimits: DEFAULT_RATE_LIMITS,
    now: () => Date.now(),
  };
}
