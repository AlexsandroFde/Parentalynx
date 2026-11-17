// Retencao de dados (protocolo, secao 8) e tarefas periodicas de manutencao.

import type { AppContext } from '../../context.ts';
import { addDays, DAY_MS } from '../../core/time.ts';
import type { GuardianRow } from '../../db/rows.ts';
import { runStalenessCheck } from '../alerts/monitor.ts';
import { readSettings } from '../auth/service.ts';
import { expireLinks, expireTimeRequests } from '../devices/service.ts';

/** Agregados diarios ficam 400 dias, a auditoria 365. */
const AGGREGATE_DAYS = 400;
const AUDIT_DAYS = 365;
/** Sessoes vencidas, codigos e pedidos de vinculo resolvidos saem depois de uma semana. */
const HOUSEKEEPING_DAYS = 7;

export interface RetentionResult {
  sessions: number;
  events: number;
  browsing: number;
  alerts: number;
  timeRequests: number;
  usageDays: number;
  usageApps: number;
  audit: number;
  housekeeping: number;
}

/**
 * Apaga o que passou do prazo. Sessoes de uso, eventos, navegacao, alertas e pedidos de tempo
 * seguem `retentionDays` de cada conta.
 */
export function runRetention(ctx: AppContext): RetentionResult {
  const now = ctx.now();
  const result: RetentionResult = {
    sessions: 0,
    events: 0,
    browsing: 0,
    alerts: 0,
    timeRequests: 0,
    usageDays: 0,
    usageApps: 0,
    audit: 0,
    housekeeping: 0,
  };
  const today = new Date(now).toISOString().slice(0, 10);
  const aggregateCutoff = addDays(today, -AGGREGATE_DAYS);

  ctx.db.transaction(() => {
    for (const guardian of ctx.db.all<GuardianRow>('SELECT * FROM guardians')) {
      const cutoff = now - readSettings(guardian).retentionDays * DAY_MS;
      const devices = 'SELECT id FROM devices WHERE guardian_id = ?';
      result.sessions += ctx.db.run(
        `DELETE FROM usage_sessions WHERE end_ms < ? AND device_id IN (${devices})`,
        cutoff,
        guardian.id,
      ).changes;
      result.events += ctx.db.run(
        `DELETE FROM events WHERE ts < ? AND created_at < ? AND device_id IN (${devices})`,
        cutoff,
        cutoff,
        guardian.id,
      ).changes;
      result.browsing += ctx.db.run(
        `DELETE FROM browsing WHERE ts < ? AND created_at < ? AND device_id IN (${devices})`,
        cutoff,
        cutoff,
        guardian.id,
      ).changes;
      result.timeRequests += ctx.db.run(
        `DELETE FROM time_requests WHERE created_at < ? AND device_id IN (${devices})`,
        cutoff,
        guardian.id,
      ).changes;
      result.alerts += ctx.db.run('DELETE FROM alerts WHERE guardian_id = ? AND created_at < ?', guardian.id, cutoff).changes;
    }

    result.usageDays = ctx.db.run('DELETE FROM usage_day WHERE day < ?', aggregateCutoff).changes;
    result.usageApps = ctx.db.run('DELETE FROM usage_app WHERE day < ?', aggregateCutoff).changes;
    result.audit = ctx.db.run('DELETE FROM audit_log WHERE at < ?', now - AUDIT_DAYS * DAY_MS).changes;

    const old = now - HOUSEKEEPING_DAYS * DAY_MS;
    result.housekeeping += ctx.db.run(
      'DELETE FROM sessions WHERE (revoked_at IS NOT NULL AND revoked_at < ?) OR expires_at < ?',
      old,
      old,
    ).changes;
    result.housekeeping += ctx.db.run('DELETE FROM pairing_codes WHERE expires_at < ?', old).changes;
    result.housekeeping += ctx.db.run(`DELETE FROM links WHERE status <> 'pending' AND created_at < ?`, old).changes;
    result.housekeeping += ctx.db.run(
      'DELETE FROM revoked_tokens WHERE revoked_at < ?',
      now - AGGREGATE_DAYS * DAY_MS,
    ).changes;
  });
  return result;
}

/** Tarefas de alta frequencia: prazos de pedidos, falta de sincronizacao e limpeza de memoria. */
export function runFrequentTasks(ctx: AppContext): void {
  expireLinks(ctx);
  expireTimeRequests(ctx);
  runStalenessCheck(ctx);
  ctx.rate.sweep(ctx.now());
}
