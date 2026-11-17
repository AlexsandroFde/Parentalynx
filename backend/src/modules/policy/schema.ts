// Modelo, padrao e validacao da politica (protocolo 4.2).

import { randomUUID } from 'node:crypto';
import { domainToASCII } from 'node:url';

import { validationError } from '../../core/errors.ts';
import type { FieldIssue } from '../../core/errors.ts';
import { addDays, isHourMinute, isValidTimeZone, isoWeekday, minutesOf } from '../../core/time.ts';
import { isPlainObject } from '../../core/validate.ts';

export type AppState = 'allowed' | 'blocked' | 'exception';
export type WebCategory = 'adult' | 'gambling' | 'social' | 'video' | 'games';
export type SuspensionScope = 'dailyLimit' | 'schedules' | 'appBlocks';

export const APP_STATES: readonly AppState[] = ['allowed', 'blocked', 'exception'];
export const WEB_CATEGORIES: readonly WebCategory[] = ['adult', 'gambling', 'social', 'video', 'games'];
export const SUSPENSION_SCOPES: readonly SuspensionScope[] = ['dailyLimit', 'schedules', 'appBlocks'];

/** Pacote virtual do navegador gerenciado. */
export const BROWSER_PACKAGE = 'com.parentalynx.app.browser';

export interface DailyLimit {
  enabled: boolean;
  minutes: number;
  perWeekday: Record<string, number>;
  resetTime: string;
  warnAtMinutes: number[];
}

export interface AllowedWindow {
  days: number[];
  start: string;
  end: string;
}

export interface AllowedHours {
  enabled: boolean;
  windows: AllowedWindow[];
}

export interface WeeklyBlockPeriod {
  id: string;
  label: string;
  enabled: boolean;
  kind: 'weekly';
  days: number[];
  start: string;
  end: string;
}

export interface OnceBlockPeriod {
  id: string;
  label: string;
  enabled: boolean;
  kind: 'once';
  startAt: number;
  endAt: number;
}

export type BlockPeriod = WeeklyBlockPeriod | OnceBlockPeriod;

export interface AppRule {
  state: AppState;
  countsTowardLimit: boolean;
  dailyLimitMinutes: number | null;
}

export interface AppsPolicy {
  defaultForNewApps: 'allowed' | 'blocked';
  rules: Record<string, AppRule>;
}

export interface WebPolicy {
  managedBrowser: boolean;
  logHistory: boolean;
  safeDns: boolean;
  safeSearch: boolean;
  mode: 'blocklist' | 'allowlist';
  blockedDomains: string[];
  allowedDomains: string[];
  blockedCategories: WebCategory[];
}

export interface Protection {
  lockOnTamper: boolean;
  blockUninstall: boolean;
  blockSafeBoot: boolean;
  blockFactoryReset: boolean;
  blockDateTimeChange: boolean;
  blockAddUser: boolean;
  blockUnknownSources: boolean;
  blockUsbDebugging: boolean;
}

export interface ExtraTime {
  id: string;
  day: string;
  minutes: number;
  grantedAt: number;
}

export interface ManualLock {
  active: boolean;
  until: number | null;
  setAt: number | null;
}

export interface Suspension {
  until: number;
  scopes: SuspensionScope[];
  setAt: number | null;
}

export interface Overrides {
  extraTime: ExtraTime[];
  manualLock: ManualLock;
  suspension: Suspension;
}

export interface Policy {
  schema: 1;
  timezone: string;
  dailyLimit: DailyLimit;
  allowedHours: AllowedHours;
  blockPeriods: BlockPeriod[];
  apps: AppsPolicy;
  web: WebPolicy;
  protection: Protection;
  overrides: Overrides;
}

const MAX_BLOCK_PERIODS = 50;
const MAX_WINDOWS = 50;
const MAX_RULES = 3000;
const MAX_DOMAINS = 500;
const MAX_LABEL = 60;
const MAX_MINUTES = 1440;

/** Nome de pacote Android: pelo menos dois segmentos. Recusa `__proto__` e afins. */
const RULE_PACKAGE = /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$/;

export function emptyOverrides(): Overrides {
  return {
    extraTime: [],
    manualLock: { active: false, until: null, setAt: null },
    suspension: { until: 0, scopes: [], setAt: null },
  };
}

/**
 * Politica inicial de um aparelho recem-vinculado. Nada e bloqueado ate o responsavel
 * configurar: o limite diario comeca desligado, com 2 horas ja preenchidas.
 */
export function defaultPolicy(timezone: string): Policy {
  return {
    schema: 1,
    timezone: isValidTimeZone(timezone) ? timezone : 'UTC',
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
    overrides: emptyOverrides(),
  };
}

/**
 * Reduz o que o responsavel digitou a um nome de dominio comparavel por sufixo: minusculas, sem
 * esquema, caminho, porta, `*.` e `www.` iniciais. Devolve `null` se nao for um dominio.
 */
export function normalizeDomain(input: string): string | null {
  let text = input.trim().toLowerCase();
  text = text.replace(/^[a-z][a-z0-9+.-]*:\/\//, '');
  text = text.split(/[/?#]/)[0] ?? '';
  text = text.replace(/^.*@/, '').replace(/:\d+$/, '');
  text = text.replace(/^\*\./, '').replace(/^\.+/, '').replace(/\.+$/, '');
  if (text.startsWith('www.')) text = text.slice(4);
  if (text === '') return null;
  const ascii = domainToASCII(text);
  if (ascii === '' || ascii.length > 253) return null;
  const label = '[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?';
  if (!new RegExp(`^${label}(\\.${label})+$`).test(ascii)) return null;
  return ascii;
}

class Collector {
  readonly issues: FieldIssue[] = [];

  add(field: string, message: string): void {
    this.issues.push({ field, message });
  }

  bool(value: unknown, field: string, current: boolean): boolean {
    if (value === undefined) return current;
    if (typeof value !== 'boolean') {
      this.add(field, 'Deve ser verdadeiro ou falso.');
      return current;
    }
    return value;
  }

  int(value: unknown, field: string, current: number, min: number, max: number): number {
    if (value === undefined) return current;
    if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
      this.add(field, `Deve ser um inteiro entre ${min} e ${max}.`);
      return current;
    }
    return value;
  }

  choice<T extends string>(value: unknown, field: string, current: T, options: readonly T[]): T {
    if (value === undefined) return current;
    if (typeof value !== 'string' || !options.includes(value as T)) {
      this.add(field, `Deve ser um de: ${options.join(', ')}.`);
      return current;
    }
    return value as T;
  }

  object(value: unknown, field: string): Record<string, unknown> | null {
    if (!isPlainObject(value)) {
      this.add(field, 'Deve ser um objeto.');
      return null;
    }
    return value;
  }

  list(value: unknown, field: string, max: number): unknown[] | null {
    if (!Array.isArray(value)) {
      this.add(field, 'Deve ser uma lista.');
      return null;
    }
    if (value.length > max) {
      this.add(field, `Máximo de ${max} itens.`);
      return null;
    }
    return value;
  }

  days(value: unknown, field: string): number[] | null {
    const list = this.list(value, field, 7);
    if (!list) return null;
    const days = new Set<number>();
    for (const entry of list) {
      if (typeof entry !== 'number' || !Number.isInteger(entry) || entry < 1 || entry > 7) {
        this.add(field, 'Dias da semana vão de 1 (segunda) a 7 (domingo).');
        return null;
      }
      days.add(entry);
    }
    if (days.size === 0) {
      this.add(field, 'Informe pelo menos um dia da semana.');
      return null;
    }
    return [...days].sort((a, b) => a - b);
  }

  hourMinute(value: unknown, field: string, allow24: boolean): string | null {
    if (typeof value !== 'string' || !isHourMinute(value, allow24)) {
      this.add(field, allow24 ? 'Use o formato HH:mm, de 00:00 a 24:00.' : 'Use o formato HH:mm, de 00:00 a 23:59.');
      return null;
    }
    return value;
  }
}

function parseTimezone(value: unknown, current: string, c: Collector): string {
  if (value === undefined) return current;
  if (typeof value !== 'string' || !isValidTimeZone(value)) {
    c.add('policy.timezone', 'Fuso horário desconhecido. Use um identificador IANA.');
    return current;
  }
  return value;
}

function parseDailyLimit(value: unknown, current: DailyLimit, c: Collector): DailyLimit {
  const path = 'policy.dailyLimit';
  const input = c.object(value, path);
  if (!input) return current;

  let perWeekday = current.perWeekday;
  if (input.perWeekday !== undefined) {
    const raw = c.object(input.perWeekday, `${path}.perWeekday`);
    if (raw) {
      const parsed: Record<string, number> = {};
      for (const key of Object.keys(raw).sort()) {
        if (!/^[1-7]$/.test(key)) {
          c.add(`${path}.perWeekday.${key}`, 'A chave deve ser um dia da semana de 1 a 7.');
          continue;
        }
        parsed[key] = c.int(raw[key], `${path}.perWeekday.${key}`, 0, 0, MAX_MINUTES);
      }
      perWeekday = parsed;
    }
  }

  let resetTime = current.resetTime;
  if (input.resetTime !== undefined) {
    resetTime = c.hourMinute(input.resetTime, `${path}.resetTime`, false) ?? current.resetTime;
  }

  let warnAtMinutes = current.warnAtMinutes;
  if (input.warnAtMinutes !== undefined) {
    const list = c.list(input.warnAtMinutes, `${path}.warnAtMinutes`, 4);
    if (list) {
      const values = new Set<number>();
      list.forEach((entry, index) => {
        values.add(c.int(entry, `${path}.warnAtMinutes[${index}]`, 1, 1, 120));
      });
      warnAtMinutes = [...values].sort((a, b) => b - a);
    }
  }

  return {
    enabled: c.bool(input.enabled, `${path}.enabled`, current.enabled),
    minutes: c.int(input.minutes, `${path}.minutes`, current.minutes, 0, MAX_MINUTES),
    perWeekday,
    resetTime,
    warnAtMinutes,
  };
}

function parseAllowedHours(value: unknown, current: AllowedHours, c: Collector): AllowedHours {
  const path = 'policy.allowedHours';
  const input = c.object(value, path);
  if (!input) return current;

  let windows = current.windows;
  if (input.windows !== undefined) {
    const list = c.list(input.windows, `${path}.windows`, MAX_WINDOWS);
    if (list) {
      const parsed: AllowedWindow[] = [];
      list.forEach((entry, index) => {
        const item = c.object(entry, `${path}.windows[${index}]`);
        if (!item) return;
        const days = c.days(item.days, `${path}.windows[${index}].days`);
        const start = c.hourMinute(item.start, `${path}.windows[${index}].start`, false);
        const end = c.hourMinute(item.end, `${path}.windows[${index}].end`, true);
        if (!days || !start || !end) return;
        if (minutesOf(start) >= minutesOf(end)) {
          c.add(`${path}.windows[${index}]`, 'O início precisa ser anterior ao fim, no mesmo dia.');
          return;
        }
        parsed.push({ days, start, end });
      });
      windows = parsed;
    }
  }

  return { enabled: c.bool(input.enabled, `${path}.enabled`, current.enabled), windows };
}

function parseBlockPeriods(value: unknown, current: BlockPeriod[], c: Collector): BlockPeriod[] {
  const path = 'policy.blockPeriods';
  const list = c.list(value, path, MAX_BLOCK_PERIODS);
  if (!list) return current;
  const parsed: BlockPeriod[] = [];
  const seen = new Set<string>();
  list.forEach((entry, index) => {
    const at = `${path}[${index}]`;
    const item = c.object(entry, at);
    if (!item) return;

    let id: string = randomUUID();
    if (item.id !== undefined) {
      if (typeof item.id !== 'string' || item.id.trim() === '' || item.id.length > 64) {
        c.add(`${at}.id`, 'Identificador inválido.');
        return;
      }
      id = item.id.trim();
    }
    if (seen.has(id)) {
      c.add(`${at}.id`, 'Identificador repetido.');
      return;
    }
    seen.add(id);

    let label = '';
    if (item.label !== undefined) {
      if (typeof item.label !== 'string' || item.label.trim().length > MAX_LABEL) {
        c.add(`${at}.label`, `O nome deve ter até ${MAX_LABEL} caracteres.`);
        return;
      }
      label = item.label.trim();
    }
    const enabled = c.bool(item.enabled, `${at}.enabled`, true);

    if (item.kind === 'weekly') {
      const days = c.days(item.days, `${at}.days`);
      const start = c.hourMinute(item.start, `${at}.start`, false);
      const end = c.hourMinute(item.end, `${at}.end`, true);
      if (!days || !start || !end) return;
      if (start === end) {
        c.add(at, 'O início e o fim não podem ser iguais.');
        return;
      }
      parsed.push({ id, label, enabled, kind: 'weekly', days, start, end });
    } else if (item.kind === 'once') {
      const startAt = c.int(item.startAt ?? null, `${at}.startAt`, 0, 0, Number.MAX_SAFE_INTEGER);
      const endAt = c.int(item.endAt ?? null, `${at}.endAt`, 0, 0, Number.MAX_SAFE_INTEGER);
      if (endAt <= startAt) {
        c.add(at, 'O fim precisa ser posterior ao início.');
        return;
      }
      parsed.push({ id, label, enabled, kind: 'once', startAt, endAt });
    } else {
      c.add(`${at}.kind`, 'Deve ser weekly ou once.');
    }
  });
  return parsed;
}

function parseApps(value: unknown, current: AppsPolicy, c: Collector): AppsPolicy {
  const path = 'policy.apps';
  const input = c.object(value, path);
  if (!input) return current;

  let rules = current.rules;
  if (input.rules !== undefined) {
    const raw = c.object(input.rules, `${path}.rules`);
    if (raw) {
      const names = Object.keys(raw).sort();
      if (names.length > MAX_RULES) {
        c.add(`${path}.rules`, `Máximo de ${MAX_RULES} regras.`);
      } else {
        const parsed: Record<string, AppRule> = Object.create(null) as Record<string, AppRule>;
        for (const name of names) {
          const at = `${path}.rules.${name}`;
          if (name.length > 255 || !RULE_PACKAGE.test(name)) {
            c.add(at, 'Nome de pacote inválido.');
            continue;
          }
          const item = c.object(raw[name], at);
          if (!item) continue;
          if (typeof item.state !== 'string' || !APP_STATES.includes(item.state as AppState)) {
            c.add(`${at}.state`, 'Deve ser allowed, blocked ou exception.');
            continue;
          }
          const state = item.state as AppState;
          const counts = c.bool(item.countsTowardLimit, `${at}.countsTowardLimit`, state !== 'exception');
          let limit: number | null = null;
          if (item.dailyLimitMinutes !== undefined && item.dailyLimitMinutes !== null) {
            limit = c.int(item.dailyLimitMinutes, `${at}.dailyLimitMinutes`, 1, 1, MAX_MINUTES);
          }
          parsed[name] = {
            state,
            // So a excecao pode ficar fora da cota. App permitido sempre conta, bloqueado nao roda.
            countsTowardLimit: state === 'exception' ? counts : state === 'allowed',
            dailyLimitMinutes: state === 'blocked' ? null : limit,
          };
        }
        rules = { ...parsed };
      }
    }
  }

  return {
    defaultForNewApps: c.choice(input.defaultForNewApps, `${path}.defaultForNewApps`, current.defaultForNewApps, [
      'allowed',
      'blocked',
    ] as const),
    rules,
  };
}

function parseDomains(value: unknown, field: string, current: string[], c: Collector): string[] {
  if (value === undefined) return current;
  const list = c.list(value, field, MAX_DOMAINS);
  if (!list) return current;
  const domains = new Set<string>();
  list.forEach((entry, index) => {
    const domain = typeof entry === 'string' ? normalizeDomain(entry) : null;
    if (!domain) {
      c.add(`${field}[${index}]`, 'Domínio inválido.');
      return;
    }
    domains.add(domain);
  });
  return [...domains].sort();
}

function parseWeb(value: unknown, current: WebPolicy, c: Collector): WebPolicy {
  const path = 'policy.web';
  const input = c.object(value, path);
  if (!input) return current;

  let blockedCategories = current.blockedCategories;
  if (input.blockedCategories !== undefined) {
    const list = c.list(input.blockedCategories, `${path}.blockedCategories`, WEB_CATEGORIES.length * 2);
    if (list) {
      const chosen = new Set<WebCategory>();
      list.forEach((entry, index) => {
        if (typeof entry !== 'string' || !WEB_CATEGORIES.includes(entry as WebCategory)) {
          c.add(`${path}.blockedCategories[${index}]`, `Deve ser um de: ${WEB_CATEGORIES.join(', ')}.`);
          return;
        }
        chosen.add(entry as WebCategory);
      });
      blockedCategories = WEB_CATEGORIES.filter((category) => chosen.has(category));
    }
  }

  return {
    managedBrowser: c.bool(input.managedBrowser, `${path}.managedBrowser`, current.managedBrowser),
    logHistory: c.bool(input.logHistory, `${path}.logHistory`, current.logHistory),
    safeDns: c.bool(input.safeDns, `${path}.safeDns`, current.safeDns),
    safeSearch: c.bool(input.safeSearch, `${path}.safeSearch`, current.safeSearch),
    mode: c.choice(input.mode, `${path}.mode`, current.mode, ['blocklist', 'allowlist'] as const),
    blockedDomains: parseDomains(input.blockedDomains, `${path}.blockedDomains`, current.blockedDomains, c),
    allowedDomains: parseDomains(input.allowedDomains, `${path}.allowedDomains`, current.allowedDomains, c),
    blockedCategories,
  };
}

function parseProtection(value: unknown, current: Protection, c: Collector): Protection {
  const path = 'policy.protection';
  const input = c.object(value, path);
  if (!input) return current;
  return {
    lockOnTamper: c.bool(input.lockOnTamper, `${path}.lockOnTamper`, current.lockOnTamper),
    blockUninstall: c.bool(input.blockUninstall, `${path}.blockUninstall`, current.blockUninstall),
    blockSafeBoot: c.bool(input.blockSafeBoot, `${path}.blockSafeBoot`, current.blockSafeBoot),
    blockFactoryReset: c.bool(input.blockFactoryReset, `${path}.blockFactoryReset`, current.blockFactoryReset),
    blockDateTimeChange: c.bool(input.blockDateTimeChange, `${path}.blockDateTimeChange`, current.blockDateTimeChange),
    blockAddUser: c.bool(input.blockAddUser, `${path}.blockAddUser`, current.blockAddUser),
    blockUnknownSources: c.bool(input.blockUnknownSources, `${path}.blockUnknownSources`, current.blockUnknownSources),
    blockUsbDebugging: c.bool(input.blockUsbDebugging, `${path}.blockUsbDebugging`, current.blockUsbDebugging),
  };
}

/**
 * Valida a politica enviada pelo responsavel e devolve o documento normalizado.
 *
 * Semantica de atualizacao: campo ausente mantem o valor atual, campo presente substitui o
 * atual por inteiro (listas e mapas nao sao mesclados). `overrides` enviado e ignorado: os
 * atuais sao preservados, porque so as rotas de comando os alteram.
 */
export function normalizePolicyInput(input: unknown, current: Policy): Policy {
  if (!isPlainObject(input)) {
    throw validationError([{ field: 'policy', message: 'Deve ser um objeto.' }]);
  }
  const c = new Collector();
  if (input.schema !== undefined && input.schema !== 1) {
    c.add('policy.schema', 'Versão de esquema não suportada. Use 1.');
  }
  const next: Policy = {
    schema: 1,
    timezone: parseTimezone(input.timezone, current.timezone, c),
    dailyLimit: input.dailyLimit === undefined ? current.dailyLimit : parseDailyLimit(input.dailyLimit, current.dailyLimit, c),
    allowedHours:
      input.allowedHours === undefined ? current.allowedHours : parseAllowedHours(input.allowedHours, current.allowedHours, c),
    blockPeriods:
      input.blockPeriods === undefined ? current.blockPeriods : parseBlockPeriods(input.blockPeriods, current.blockPeriods, c),
    apps: input.apps === undefined ? current.apps : parseApps(input.apps, current.apps, c),
    web: input.web === undefined ? current.web : parseWeb(input.web, current.web, c),
    protection:
      input.protection === undefined ? current.protection : parseProtection(input.protection, current.protection, c),
    overrides: current.overrides,
  };
  if (c.issues.length > 0) throw validationError(c.issues, 'Política inválida.');
  return next;
}

/** Le a politica gravada. O conteudo foi validado na gravacao. */
export function parseStoredPolicy(json: string): Policy {
  return JSON.parse(json) as Policy;
}

/** Limite efetivo do dia em minutos: dia da semana mais tempo extra (protocolo 4.3). */
export function effectiveLimitMinutes(policy: Policy, day: string): number {
  const weekday = String(isoWeekday(day));
  const base = policy.dailyLimit.perWeekday[weekday] ?? policy.dailyLimit.minutes;
  return base + extraMinutesFor(policy, day);
}

export function extraMinutesFor(policy: Policy, day: string): number {
  return policy.overrides.extraTime
    .filter((entry) => entry.day === day)
    .reduce((total, entry) => total + entry.minutes, 0);
}

/** Remove concessoes de tempo extra com mais de 2 dias. */
export function pruneExtraTime(overrides: Overrides, today: string): Overrides {
  const oldest = addDays(today, -2);
  return { ...overrides, extraTime: overrides.extraTime.filter((entry) => entry.day >= oldest) };
}

export interface ResolvedRule extends AppRule {
  /** Verdadeiro quando a regra veio do documento, falso quando e o padrao. */
  explicit: boolean;
}

/**
 * Regra efetiva de um pacote: a explicita, ou o padrao (protocolo 4.2). Pacote sem regra e
 * `allowed`, exceto quando `defaultForNewApps` e `blocked` e o app nao e de sistema.
 */
export function resolveRule(policy: Policy, packageName: string, isSystem: boolean): ResolvedRule {
  const rule = Object.hasOwn(policy.apps.rules, packageName) ? policy.apps.rules[packageName] : undefined;
  if (rule) return { ...rule, explicit: true };
  const blocked = policy.apps.defaultForNewApps === 'blocked' && !isSystem;
  return {
    state: blocked ? 'blocked' : 'allowed',
    countsTowardLimit: !blocked,
    dailyLimitMinutes: null,
    explicit: false,
  };
}
