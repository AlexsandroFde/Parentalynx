// Monitor de falta de sincronizacao: gera `sync_stale` e `device_offline` (protocolo 5.3).
//
// Cada alerta e emitido uma unica vez por periodo sem sincronizar: a marca guarda o instante da
// ultima sincronizacao para a qual ja se alertou. Quando o aparelho volta a sincronizar, esse
// instante muda e um novo periodo pode gerar novo alerta.

import type { AppContext } from '../../context.ts';
import { formatElapsed } from '../../core/format.ts';
import { HOUR_MS, MINUTE_MS } from '../../core/time.ts';
import type { DeviceRow, GuardianRow } from '../../db/rows.ts';
import { readSettings } from '../auth/service.ts';
import { createAlert } from './service.ts';

export interface StalenessResult {
  stale: number;
  offline: number;
}

export function runStalenessCheck(ctx: AppContext): StalenessResult {
  const now = ctx.now();
  const result: StalenessResult = { stale: 0, offline: 0 };
  const guardians = new Map<string, GuardianRow>();
  const devices = ctx.db.all<DeviceRow>(`SELECT * FROM devices WHERE status = 'active'`);

  for (const device of devices) {
    let guardian = guardians.get(device.guardian_id);
    if (!guardian) {
      guardian = ctx.db.get<GuardianRow>('SELECT * FROM guardians WHERE id = ?', device.guardian_id);
      if (!guardian) continue;
      guardians.set(device.guardian_id, guardian);
    }
    const settings = readSettings(guardian);
    // Aparelho que nunca sincronizou conta a partir da aprovacao do vinculo.
    const reference = device.last_sync_at ?? device.approved_at;
    const silence = now - reference;

    if (silence > settings.offlineHours * HOUR_MS && device.offline_alert_for !== reference) {
      ctx.db.run(
        'UPDATE devices SET offline_alert_for = ?, stale_alert_for = ? WHERE id = ?',
        reference,
        reference,
        device.id,
      );
      createAlert(ctx, {
        guardianId: device.guardian_id,
        type: 'device_offline',
        deviceId: device.id,
        childName: device.child_name,
        title: 'Aparelho offline',
        body: `O aparelho de ${device.child_name} está sem conexão há ${formatElapsed(silence)}. Ele pode estar desligado, sem internet ou com o app removido.`,
        data: { lastSyncAt: device.last_sync_at, silenceMs: silence },
      });
      result.offline += 1;
      continue;
    }

    if (silence > settings.syncStaleMinutes * MINUTE_MS && device.stale_alert_for !== reference) {
      ctx.db.run('UPDATE devices SET stale_alert_for = ? WHERE id = ?', reference, device.id);
      createAlert(ctx, {
        guardianId: device.guardian_id,
        type: 'sync_stale',
        deviceId: device.id,
        childName: device.child_name,
        title: 'Sem sincronização',
        body: `O aparelho de ${device.child_name} não sincroniza há ${formatElapsed(silence)}. As regras continuam valendo no aparelho.`,
        data: { lastSyncAt: device.last_sync_at, silenceMs: silence },
      });
      result.stale += 1;
    }
  }
  return result;
}
