// Dependencias compartilhadas pelos modulos. Criado uma vez por instancia do servidor.

import type { AppConfig } from './config.ts';
import { FieldCipher } from './core/crypto.ts';
import { RateLimiter } from './core/rate-limit.ts';
import type { Db } from './db/database.ts';
import { RealtimeHub } from './modules/realtime/hub.ts';

export interface Logger {
  info(details: object, message?: string): void;
  warn(details: object, message?: string): void;
  error(details: object, message?: string): void;
}

export interface AppContext {
  config: AppConfig;
  db: Db;
  cipher: FieldCipher;
  hub: RealtimeHub;
  rate: RateLimiter;
  log: Logger;
  /** Instante atual em milissegundos, pelo relogio injetado na configuracao. */
  now(): number;
}

export const silentLogger: Logger = {
  info() {},
  warn() {},
  error() {},
};

export function createContext(config: AppConfig, db: Db, log: Logger = silentLogger): AppContext {
  return {
    config,
    db,
    cipher: new FieldCipher(config.dataKey),
    hub: new RealtimeHub(),
    rate: new RateLimiter(),
    log,
    now: () => config.now(),
  };
}
