// Validacao tipada de entrada, sem dependencias.
//
// Cada parser recebe o valor bruto, o caminho do campo e a lista de problemas. Ele devolve o
// valor convertido e registra em `issues` o que estiver errado. `parse` lanca `validation_error`
// se houver qualquer problema, entao o valor devolvido so e usado quando esta integro.

import { validationError } from './errors.ts';
import type { FieldIssue } from './errors.ts';

export type Parser<T> = (value: unknown, path: string, issues: FieldIssue[]) => T;

type Shape = Record<string, Parser<unknown>>;
type Infer<S extends Shape> = { [K in keyof S]: S[K] extends Parser<infer T> ? T : never };

function fail<T>(issues: FieldIssue[], path: string, message: string, fallback: T): T {
  issues.push({ field: path || '(corpo)', message });
  return fallback;
}

export function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export interface StringOptions {
  min?: number;
  max?: number;
  /** Remove espacos nas pontas antes de validar. Padrao: verdadeiro. */
  trim?: boolean;
  pattern?: RegExp;
  lower?: boolean;
}

export const v = {
  string(options: StringOptions = {}): Parser<string> {
    const { min = 0, max = 10_000, trim = true, pattern, lower = false } = options;
    return (value, path, issues) => {
      if (typeof value !== 'string') return fail(issues, path, 'Deve ser um texto.', '');
      let text = trim ? value.trim() : value;
      if (lower) text = text.toLowerCase();
      if (text.length < min) {
        return fail(issues, path, min === 1 ? 'Campo obrigatório.' : `Mínimo de ${min} caracteres.`, text);
      }
      if (text.length > max) return fail(issues, path, `Máximo de ${max} caracteres.`, text);
      if (pattern && !pattern.test(text)) return fail(issues, path, 'Formato inválido.', text);
      return text;
    };
  },

  int(options: { min?: number; max?: number } = {}): Parser<number> {
    const { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = options;
    return (value, path, issues) => {
      if (typeof value !== 'number' || !Number.isSafeInteger(value)) {
        return fail(issues, path, 'Deve ser um número inteiro.', 0);
      }
      if (value < min || value > max) {
        return fail(issues, path, `Deve estar entre ${min} e ${max}.`, value);
      }
      return value;
    };
  },

  bool(): Parser<boolean> {
    return (value, path, issues) => {
      if (typeof value !== 'boolean') return fail(issues, path, 'Deve ser verdadeiro ou falso.', false);
      return value;
    };
  },

  oneOf<const T extends string>(values: readonly T[]): Parser<T> {
    return (value, path, issues) => {
      if (typeof value !== 'string' || !values.includes(value as T)) {
        return fail(issues, path, `Deve ser um de: ${values.join(', ')}.`, values[0] as T);
      }
      return value as T;
    };
  },

  array<T>(item: Parser<T>, options: { min?: number; max?: number } = {}): Parser<T[]> {
    const { min = 0, max = 10_000 } = options;
    return (value, path, issues) => {
      if (!Array.isArray(value)) return fail(issues, path, 'Deve ser uma lista.', []);
      if (value.length < min) return fail(issues, path, `Mínimo de ${min} itens.`, []);
      if (value.length > max) return fail(issues, path, `Máximo de ${max} itens.`, []);
      return value.map((entry, index) => item(entry, `${path}[${index}]`, issues));
    };
  },

  object<S extends Shape>(shape: S): Parser<Infer<S>> {
    return (value, path, issues) => {
      const out: Record<string, unknown> = {};
      if (!isPlainObject(value)) {
        return fail(issues, path, 'Deve ser um objeto.', out as Infer<S>);
      }
      for (const key of Object.keys(shape)) {
        const parser = shape[key] as Parser<unknown>;
        out[key] = parser(value[key], path ? `${path}.${key}` : key, issues);
      }
      return out as Infer<S>;
    };
  },

  /** Aceita ausencia (`undefined`). */
  optional<T>(parser: Parser<T>): Parser<T | undefined> {
    return (value, path, issues) => (value === undefined ? undefined : parser(value, path, issues));
  },

  /** Aceita ausencia e `null`, devolvendo `null` nos dois casos. */
  nullable<T>(parser: Parser<T>): Parser<T | null> {
    return (value, path, issues) =>
      value === undefined || value === null ? null : parser(value, path, issues);
  },

  /** Aceita ausencia ou `null`, devolvendo o valor padrao. */
  withDefault<T>(parser: Parser<T>, fallback: T): Parser<T> {
    return (value, path, issues) =>
      value === undefined || value === null ? fallback : parser(value, path, issues);
  },

  /** Objeto de chaves livres, com valores validados. */
  record<T>(item: Parser<T>, options: { maxKeys?: number; key?: RegExp } = {}): Parser<Record<string, T>> {
    const { maxKeys = 10_000, key } = options;
    return (value, path, issues) => {
      const out: Record<string, T> = Object.create(null) as Record<string, T>;
      if (!isPlainObject(value)) return fail(issues, path, 'Deve ser um objeto.', out);
      const keys = Object.keys(value);
      if (keys.length > maxKeys) return fail(issues, path, `Máximo de ${maxKeys} chaves.`, out);
      for (const name of keys) {
        if (key && !key.test(name)) {
          fail(issues, `${path}.${name}`, 'Chave inválida.', undefined);
          continue;
        }
        out[name] = item(value[name], `${path}.${name}`, issues);
      }
      return out;
    };
  },

  /** Objeto qualquer, usado para dados livres de eventos. */
  anyObject(): Parser<Record<string, unknown>> {
    return (value, path, issues) => {
      if (!isPlainObject(value)) return fail(issues, path, 'Deve ser um objeto.', {});
      return value;
    };
  },
};

/** Valida `value` e lanca `validation_error` se houver problemas. */
export function parse<T>(parser: Parser<T>, value: unknown): T {
  const issues: FieldIssue[] = [];
  const result = parser(value, '', issues);
  if (issues.length > 0) throw validationError(issues);
  return result;
}

/** Converte um parametro de consulta em inteiro, ou devolve `undefined` se ausente. */
export function queryInt(
  query: unknown,
  name: string,
  options: { min?: number; max?: number } = {},
): number | undefined {
  if (!isPlainObject(query)) return undefined;
  const raw = query[name];
  if (raw === undefined || raw === '') return undefined;
  const text = Array.isArray(raw) ? String(raw[0]) : String(raw);
  if (!/^-?\d{1,15}$/.test(text)) {
    throw validationError([{ field: name, message: 'Deve ser um número inteiro.' }]);
  }
  const value = Number(text);
  const { min = Number.MIN_SAFE_INTEGER, max = Number.MAX_SAFE_INTEGER } = options;
  if (value < min || value > max) {
    throw validationError([{ field: name, message: `Deve estar entre ${min} e ${max}.` }]);
  }
  return value;
}

/** Le um parametro de consulta como texto, ou `undefined` se ausente ou vazio. */
export function queryString(query: unknown, name: string): string | undefined {
  if (!isPlainObject(query)) return undefined;
  const raw = query[name];
  if (raw === undefined) return undefined;
  const text = (Array.isArray(raw) ? String(raw[0]) : String(raw)).trim();
  return text === '' ? undefined : text;
}

/** Le um parametro de consulta booleano (`1`, `true`). */
export function queryBool(query: unknown, name: string): boolean {
  const text = queryString(query, name);
  return text === '1' || text === 'true';
}
