// Auditoria administrativa: toda alteracao feita por um responsavel fica registrada.

import type { AppContext } from '../../context.ts';
import type { AuditRow, SessionRow } from '../../db/rows.ts';

export type AuditTarget = 'device' | 'guardian' | 'session' | 'pairing';

export interface AuditInput {
  guardianId: string;
  action: string;
  summary: string;
  session?: SessionRow | null;
  targetType?: AuditTarget;
  targetId?: string | null;
  ip?: string | null;
  /** Rotulo de origem quando a acao nao veio de uma sessao (por exemplo o aparelho da crianca). */
  origin?: string;
}

export function audit(ctx: AppContext, input: AuditInput): void {
  ctx.db.run(
    `INSERT INTO audit_log (guardian_id, at, action, session_id, session_device_name, target_type, target_id, summary, ip)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    input.guardianId,
    ctx.now(),
    input.action,
    input.session?.id ?? null,
    input.session?.device_name ?? input.origin ?? null,
    input.targetType ?? null,
    input.targetId ?? null,
    input.summary,
    input.ip ?? null,
  );
}

export interface AuditEntryJson {
  id: number;
  at: number;
  action: string;
  sessionId: string | null;
  deviceName: string | null;
  targetType: string | null;
  targetId: string | null;
  summary: string;
  ip: string | null;
}

export function listAudit(
  ctx: AppContext,
  guardianId: string,
  before: number | undefined,
  limit: number,
): { entries: AuditEntryJson[]; nextBefore: number | null } {
  const rows = ctx.db.all<AuditRow>(
    `SELECT * FROM audit_log WHERE guardian_id = ? AND id < ? ORDER BY id DESC LIMIT ?`,
    guardianId,
    before ?? Number.MAX_SAFE_INTEGER,
    limit + 1,
  );
  const page = rows.slice(0, limit);
  const last = page[page.length - 1];
  return {
    entries: page.map((row) => ({
      id: row.id,
      at: row.at,
      action: row.action,
      sessionId: row.session_id,
      deviceName: row.session_device_name,
      targetType: row.target_type,
      targetId: row.target_id,
      summary: row.summary,
      ip: row.ip,
    })),
    nextBefore: rows.length > limit && last ? last.id : null,
  };
}
