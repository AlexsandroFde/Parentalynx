// Formatacao de textos em portugues para alertas e auditoria.

import { HOUR_MS, MINUTE_MS } from './time.ts';

/** `150` vira `2h30`, `120` vira `2h`, `45` vira `45 min`. */
export function formatMinutes(totalMinutes: number): string {
  const minutes = Math.max(0, Math.round(totalMinutes));
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return `${rest} min`;
  if (rest === 0) return `${hours}h`;
  return `${hours}h${String(rest).padStart(2, '0')}`;
}

export function formatDurationMs(durationMs: number): string {
  return formatMinutes(durationMs / MINUTE_MS);
}

/** Tempo decorrido aproximado: `40 minutos`, `3 horas`, `2 dias`. */
export function formatElapsed(durationMs: number): string {
  if (durationMs < HOUR_MS) {
    const minutes = Math.max(1, Math.round(durationMs / MINUTE_MS));
    return minutes === 1 ? '1 minuto' : `${minutes} minutos`;
  }
  if (durationMs < 48 * HOUR_MS) {
    const hours = Math.round(durationMs / HOUR_MS);
    return hours === 1 ? '1 hora' : `${hours} horas`;
  }
  const days = Math.round(durationMs / (24 * HOUR_MS));
  return `${days} dias`;
}

export function plural(count: number, singular: string, pluralForm: string): string {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}
