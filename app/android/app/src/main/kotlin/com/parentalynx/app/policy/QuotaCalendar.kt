package com.parentalynx.app.policy

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

/**
 * Calendário da cota diária.
 *
 * O dia da cota `D` vai de `D` no horário de reinício até `D+1` no mesmo horário, no fuso da
 * política. Com reinício às 04:00, o uso às 02:00 do dia 18 pertence ao dia da cota 17.
 */
class QuotaCalendar(val zone: ZoneId, private val resetMinutes: Int) {
    /** Instante em que o dia da cota [day] começa. */
    fun dayStartMs(day: LocalDate): Long = atLocal(day, resetMinutes)

    /** Instante em que o dia da cota [day] termina (início do seguinte). */
    fun dayEndMs(day: LocalDate): Long = dayStartMs(day.plusDays(1))

    /** Dia da cota a que o instante pertence. */
    fun dayOf(instantMs: Long): LocalDate {
        val local = Instant.ofEpochMilli(instantMs).atZone(zone).toLocalDate()
        // Decide pelas fronteiras reais, para continuar coerente em mudanças de horário de verão.
        var day = local
        while (instantMs < dayStartMs(day)) day = day.minusDays(1)
        while (instantMs >= dayEndMs(day)) day = day.plusDays(1)
        return day
    }

    /** Próximo reinício da cota depois do instante. */
    fun nextResetMs(instantMs: Long): Long = dayEndMs(dayOf(instantMs))

    /** Dia da semana ISO (1 = segunda, 7 = domingo) de um dia da cota. */
    fun weekdayOf(day: LocalDate): Int = day.dayOfWeek.value

    /** Hora local (0 a 23) do instante. */
    fun hourOf(instantMs: Long): Int = Instant.ofEpochMilli(instantMs).atZone(zone).hour

    /** Próxima virada de hora local depois do instante. */
    fun nextHourMs(instantMs: Long): Long =
        Instant.ofEpochMilli(instantMs)
            .atZone(zone)
            .truncatedTo(ChronoUnit.HOURS)
            .plusHours(1)
            .toInstant()
            .toEpochMilli()

    /** Deslocamento do fuso em relação a UTC, em minutos, no instante. */
    fun offsetMinutes(instantMs: Long): Int =
        zone.rules.getOffset(Instant.ofEpochMilli(instantMs)).totalSeconds / 60

    /** Data local (do relógio, sem deslocamento de reinício) do instante. */
    fun localDateOf(instantMs: Long): LocalDate = Instant.ofEpochMilli(instantMs).atZone(zone).toLocalDate()

    /** Instante correspondente a [minutesOfDay] (0 a 1440) da data local [date]. */
    fun atLocal(date: LocalDate, minutesOfDay: Int): Long {
        val targetDate = if (minutesOfDay >= MINUTES_PER_DAY) date.plusDays(1) else date
        val minutes = if (minutesOfDay >= MINUTES_PER_DAY) 0 else minutesOfDay
        return ZonedDateTime
            .of(targetDate, LocalTime.of(minutes / 60, minutes % 60), zone)
            .toInstant()
            .toEpochMilli()
    }

    companion object {
        const val MINUTES_PER_DAY = 1440

        fun dayKey(day: LocalDate): String = day.toString()

        fun parseDayKey(key: String): LocalDate? = runCatching { LocalDate.parse(key) }.getOrNull()
    }
}
