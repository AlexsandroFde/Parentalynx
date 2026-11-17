// Alertas para os responsaveis: criacao, preferencias, listagem e leitura.

import type { AppContext } from '../../context.ts';
import { isPlainObject } from '../../core/validate.ts';
import type { AlertRow, GuardianRow } from '../../db/rows.ts';
import { readNotificationPrefs } from '../auth/service.ts';
import type { AlertType } from '../auth/service.ts';

export interface AlertJson {
  id: number;
  type: string;
  deviceId: string | null;
  childName: string | null;
  createdAt: number;
  readAt: number | null;
  notify: boolean;
  title: string;
  body: string;
  data: Record<string, unknown>;
}

export interface NewAlert {
  guardianId: string;
  type: AlertType;
  title: string;
  body: string;
  deviceId?: string | null;
  childName?: string | null;
  data?: Record<string, unknown>;
  /** Sessao que causou o alerta. Ela nao o recebe (nem na lista, nem por WebSocket). */
  originSessionId?: string | null;
  /** Chave para limitar repeticoes do mesmo tipo no mesmo aparelho. */
  dedupeKey?: string | null;
  /** Janela em que um alerta com a mesma chave suprime este. */
  dedupeWindowMs?: number;
  /** Falso para registrar sem notificar (por exemplo evento antigo que chegou atrasado). */
  notify?: boolean;
}

function parseData(json: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(json);
  return isPlainObject(parsed) ? parsed : {};
}

/**
 * O texto e os dados do alerta podem repetir conteudo de eventos (por exemplo a mensagem de um
 * pedido de tempo), por isso ficam cifrados em repouso como os proprios eventos.
 */
export function alertJson(ctx: AppContext, row: AlertRow): AlertJson {
  return {
    id: row.id,
    type: row.type,
    deviceId: row.device_id,
    childName: row.child_name,
    createdAt: row.created_at,
    readAt: row.read_at,
    notify: row.notify === 1,
    title: row.title,
    body: ctx.cipher.decrypt(row.body_enc, 'alerts.body'),
    data: parseData(ctx.cipher.decrypt(row.data_enc, 'alerts.data')),
  };
}

/**
 * Grava o alerta e o envia por WebSocket. Devolve `null` quando foi suprimido por repeticao.
 * O campo `notify` segue as preferencias da conta: tipo desligado continua na central, mas nao
 * gera notificacao.
 */
export function createAlert(ctx: AppContext, input: NewAlert): AlertJson | null {
  const now = ctx.now();
  const deviceId = input.deviceId ?? null;
  const dedupeKey = input.dedupeKey ?? null;
  if (dedupeKey !== null && input.dedupeWindowMs !== undefined) {
    const recent = ctx.db.get<{ id: number }>(
      `SELECT id FROM alerts WHERE guardian_id = ? AND device_id IS ? AND type = ? AND dedupe_key = ? AND created_at > ? LIMIT 1`,
      input.guardianId,
      deviceId,
      input.type,
      dedupeKey,
      now - input.dedupeWindowMs,
    );
    if (recent) return null;
  }

  const guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', input.guardianId);
  if (!guardian) return null;
  const enabled = readNotificationPrefs(guardian)[input.type];
  const notify = enabled && input.notify !== false;

  const result = ctx.db.run(
    `INSERT INTO alerts (guardian_id, device_id, child_name, type, created_at, notify, title, body_enc, data_enc, dedupe_key, origin_session_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    input.guardianId,
    deviceId,
    input.childName ?? null,
    input.type,
    now,
    notify ? 1 : 0,
    input.title,
    ctx.cipher.encrypt(input.body, 'alerts.body'),
    ctx.cipher.encrypt(JSON.stringify(input.data ?? {}), 'alerts.data'),
    dedupeKey,
    input.originSessionId ?? null,
  );
  const alert: AlertJson = {
    id: result.lastInsertRowid,
    type: input.type,
    deviceId,
    childName: input.childName ?? null,
    createdAt: now,
    readAt: null,
    notify,
    title: input.title,
    body: input.body,
    data: input.data ?? {},
  };
  ctx.hub.toGuardian(input.guardianId, { type: 'alert', alert }, input.originSessionId ?? null);
  return alert;
}

export interface AlertQuery {
  after?: number;
  before?: number;
  limit: number;
  notifyOnly: boolean;
}

export interface AlertPage {
  alerts: AlertJson[];
  latestId: number;
  unread: number;
}

function countUnread(ctx: AppContext, guardianId: string, sessionId: string): number {
  const row = ctx.db.get<{ total: number }>(
    `SELECT COUNT(*) AS total FROM alerts
     WHERE guardian_id = ? AND read_at IS NULL AND (origin_session_id IS NULL OR origin_session_id <> ?)`,
    guardianId,
    sessionId,
  );
  return row?.total ?? 0;
}

/**
 * Lista os alertas visiveis para a sessao (os que ela mesma causou ficam de fora).
 * - Com `after`: alertas mais novos que o identificador, em ordem crescente (busca periodica).
 * - Sem `after`: do mais novo para o mais antigo, com `before` para paginar.
 */
export function listAlerts(ctx: AppContext, guardianId: string, sessionId: string, query: AlertQuery): AlertPage {
  const notifyFilter = query.notifyOnly ? 'AND notify = 1' : '';
  const visible = '(origin_session_id IS NULL OR origin_session_id <> ?)';
  let rows: AlertRow[];
  if (query.after !== undefined) {
    rows = ctx.db.all<AlertRow>(
      `SELECT * FROM alerts WHERE guardian_id = ? AND ${visible} AND id > ? ${notifyFilter} ORDER BY id ASC LIMIT ?`,
      guardianId,
      sessionId,
      query.after,
      query.limit,
    );
  } else {
    rows = ctx.db.all<AlertRow>(
      `SELECT * FROM alerts WHERE guardian_id = ? AND ${visible} AND id < ? ${notifyFilter} ORDER BY id DESC LIMIT ?`,
      guardianId,
      sessionId,
      query.before ?? Number.MAX_SAFE_INTEGER,
      query.limit,
    );
  }
  const latest = ctx.db.get<{ latest: number | null }>(
    `SELECT MAX(id) AS latest FROM alerts WHERE guardian_id = ? AND ${visible}`,
    guardianId,
    sessionId,
  );
  return {
    alerts: rows.map((row) => alertJson(ctx, row)),
    latestId: latest?.latest ?? 0,
    unread: countUnread(ctx, guardianId, sessionId),
  };
}

export function markAlertsRead(
  ctx: AppContext,
  guardianId: string,
  sessionId: string,
  input: { ids?: number[]; all?: boolean },
): number {
  const now = ctx.now();
  if (input.all) {
    ctx.db.run('UPDATE alerts SET read_at = ? WHERE guardian_id = ? AND read_at IS NULL', now, guardianId);
  } else if (input.ids && input.ids.length > 0) {
    ctx.db.transaction(() => {
      for (const id of input.ids ?? []) {
        ctx.db.run('UPDATE alerts SET read_at = ? WHERE guardian_id = ? AND id = ? AND read_at IS NULL', now, guardianId, id);
      }
    });
  }
  return countUnread(ctx, guardianId, sessionId);
}
