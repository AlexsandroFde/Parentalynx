// Conexao SQLite (node:sqlite) com cache de comandos, transacoes e migracoes numeradas.
//
// A API e sincrona. Por isso nenhuma transacao pode conter `await`: todo trabalho assincrono
// (por exemplo derivar senha) acontece antes de abrir a transacao.

import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import type { SQLInputValue, StatementSync } from 'node:sqlite';

export type SqlParam = SQLInputValue;

export interface RunResult {
  changes: number;
  lastInsertRowid: number;
}

export class Db {
  private readonly raw: DatabaseSync;
  private readonly statements = new Map<string, StatementSync>();
  private depth = 0;

  constructor(path: string) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.raw = new DatabaseSync(path);
    this.raw.exec('PRAGMA foreign_keys = ON');
    this.raw.exec('PRAGMA busy_timeout = 5000');
    if (path !== ':memory:') {
      this.raw.exec('PRAGMA journal_mode = WAL');
      this.raw.exec('PRAGMA synchronous = NORMAL');
    }
  }

  private statement(sql: string): StatementSync {
    let statement = this.statements.get(sql);
    if (!statement) {
      statement = this.raw.prepare(sql);
      this.statements.set(sql, statement);
    }
    return statement;
  }

  exec(sql: string): void {
    this.raw.exec(sql);
  }

  run(sql: string, ...params: SqlParam[]): RunResult {
    const result = this.statement(sql).run(...params);
    return { changes: Number(result.changes), lastInsertRowid: Number(result.lastInsertRowid) };
  }

  get<T>(sql: string, ...params: SqlParam[]): T | undefined {
    return this.statement(sql).get(...params) as T | undefined;
  }

  all<T>(sql: string, ...params: SqlParam[]): T[] {
    return this.statement(sql).all(...params) as T[];
  }

  /**
   * Executa `work` em uma transacao. Chamadas aninhadas usam pontos de salvamento, entao uma
   * falha interna desfaz so a parte interna se o chamador tratar o erro.
   */
  transaction<T>(work: () => T): T {
    const name = `sp_${this.depth}`;
    if (this.depth === 0) this.raw.exec('BEGIN IMMEDIATE');
    else this.raw.exec(`SAVEPOINT ${name}`);
    this.depth += 1;
    try {
      const result = work();
      this.depth -= 1;
      if (this.depth === 0) this.raw.exec('COMMIT');
      else this.raw.exec(`RELEASE SAVEPOINT ${name}`);
      return result;
    } catch (error) {
      this.depth -= 1;
      if (this.depth === 0) this.raw.exec('ROLLBACK');
      else this.raw.exec(`ROLLBACK TO SAVEPOINT ${name}; RELEASE SAVEPOINT ${name}`);
      throw error;
    }
  }

  close(): void {
    this.statements.clear();
    this.raw.close();
  }
}

const MIGRATIONS_DIR = join(import.meta.dirname, 'migrations');

/** Aplica, em ordem, as migracoes `NNN_nome.sql` ainda nao registradas. */
export function migrate(db: Db): number[] {
  db.exec(
    'CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at INTEGER NOT NULL) STRICT',
  );
  const applied = new Set(db.all<{ version: number }>('SELECT version FROM schema_migrations').map((row) => row.version));
  const files = readdirSync(MIGRATIONS_DIR)
    .filter((file) => /^\d{3}_.+\.sql$/.test(file))
    .sort();
  const ran: number[] = [];
  for (const file of files) {
    const version = Number(file.slice(0, 3));
    if (applied.has(version)) continue;
    const sql = readFileSync(join(MIGRATIONS_DIR, file), 'utf8');
    db.transaction(() => {
      db.exec(sql);
      db.run('INSERT INTO schema_migrations (version, name, applied_at) VALUES (?, ?, ?)', version, file, Date.now());
    });
    ran.push(version);
  }
  return ran;
}

export function openDatabase(path: string): Db {
  const db = new Db(path);
  migrate(db);
  return db;
}
