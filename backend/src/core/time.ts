// Calendario: fusos IANA, dia da cota e aritmetica de dias `YYYY-MM-DD`.

export const MINUTE_MS = 60_000;
export const HOUR_MS = 3_600_000;
export const DAY_MS = 86_400_000;

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

export function isValidTimeZone(timeZone: string): boolean {
  if (timeZone.length === 0 || timeZone.length > 64) return false;
  try {
    formatterFor(timeZone);
    return true;
  } catch {
    return false;
  }
}

export interface LocalParts {
  /** Data local `YYYY-MM-DD`. */
  date: string;
  /** Minutos desde a meia-noite local. */
  minuteOfDay: number;
}

/** Data e hora locais de um instante no fuso informado. */
export function localParts(instantMs: number, timeZone: string): LocalParts {
  const parts = formatterFor(timeZone).formatToParts(new Date(instantMs));
  const read = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((part) => part.type === type)?.value ?? '0';
  const hour = Number(read('hour')) % 24;
  return {
    date: `${read('year')}-${read('month')}-${read('day')}`,
    minuteOfDay: hour * 60 + Number(read('minute')),
  };
}

const HM_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;

/** Verdadeiro para `HH:mm` de `00:00` a `23:59`. Com `allow24`, aceita tambem `24:00`. */
export function isHourMinute(text: string, allow24 = false): boolean {
  return HM_PATTERN.test(text) || (allow24 && text === '24:00');
}

/** Minutos desde a meia-noite de um `HH:mm` valido (`24:00` vale 1440). */
export function minutesOf(text: string): number {
  const [hours, minutes] = text.split(':');
  return Number(hours) * 60 + Number(minutes);
}

const DAY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

function dayToUtc(day: string): number {
  const match = DAY_PATTERN.exec(day);
  if (!match) return Number.NaN;
  return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

/** Verdadeiro para uma data de calendario real no formato `YYYY-MM-DD`. */
export function isDay(text: unknown): text is string {
  if (typeof text !== 'string') return false;
  const utc = dayToUtc(text);
  return !Number.isNaN(utc) && new Date(utc).toISOString().slice(0, 10) === text;
}

export function addDays(day: string, amount: number): string {
  return new Date(dayToUtc(day) + amount * DAY_MS).toISOString().slice(0, 10);
}

/** Quantos dias `to` esta depois de `from` (negativo se antes). */
export function diffDays(from: string, to: string): number {
  return Math.round((dayToUtc(to) - dayToUtc(from)) / DAY_MS);
}

/** Lista de dias de `from` a `to`, inclusive. */
export function dayRange(from: string, to: string): string[] {
  const out: string[] = [];
  const total = diffDays(from, to);
  for (let offset = 0; offset <= total; offset += 1) out.push(addDays(from, offset));
  return out;
}

/** Dia da semana ISO de uma data: 1 = segunda-feira, 7 = domingo. */
export function isoWeekday(day: string): number {
  const weekday = new Date(dayToUtc(day)).getUTCDay();
  return weekday === 0 ? 7 : weekday;
}

/**
 * Dia da cota de um instante (protocolo 4.2): o dia `D` vai de `D` no horario de reinicio ate
 * `D+1` no mesmo horario. Antes do horario de reinicio, o instante pertence ao dia anterior.
 */
export function quotaDayOf(instantMs: number, timeZone: string, resetTime: string): string {
  const local = localParts(instantMs, timeZone);
  return local.minuteOfDay < minutesOf(resetTime) ? addDays(local.date, -1) : local.date;
}
