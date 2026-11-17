package com.parentalynx.app.policy

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class QuotaCalendarTest {
    private val zone = T.FORTALEZA

    @Test
    fun reinicioAMeiaNoiteSegueADataLocal() {
        val cal = QuotaCalendar(zone, 0)
        assertEquals(LocalDate.parse("2026-11-17"), cal.dayOf(T.at("2026-11-17", "23:59:59")))
        assertEquals(LocalDate.parse("2026-11-18"), cal.dayOf(T.at("2026-11-18", "00:00")))
        assertEquals(T.at("2026-11-17", "00:00"), cal.dayStartMs(LocalDate.parse("2026-11-17")))
        assertEquals(T.at("2026-11-18", "00:00"), cal.dayEndMs(LocalDate.parse("2026-11-17")))
    }

    @Test
    fun reinicioAsQuatroDaManhaAtribuiAMadrugadaAoDiaAnterior() {
        val cal = QuotaCalendar(zone, 4 * 60)
        assertEquals(LocalDate.parse("2026-11-17"), cal.dayOf(T.at("2026-11-18", "02:00")))
        assertEquals(LocalDate.parse("2026-11-17"), cal.dayOf(T.at("2026-11-18", "03:59:59")))
        assertEquals(LocalDate.parse("2026-11-18"), cal.dayOf(T.at("2026-11-18", "04:00")))
        assertEquals(T.at("2026-11-18", "04:00"), cal.nextResetMs(T.at("2026-11-18", "02:00")))
        assertEquals(T.at("2026-11-19", "04:00"), cal.nextResetMs(T.at("2026-11-18", "04:00")))
    }

    @Test
    fun usaOFusoDaPoliticaENaoOUtc() {
        val cal = QuotaCalendar(zone, 0)
        // 01:00 UTC do dia 18 ainda é 22:00 do dia 17 em Fortaleza.
        val instant = T.at("2026-11-18", "01:00", ZoneId.of("UTC"))
        assertEquals(LocalDate.parse("2026-11-17"), cal.dayOf(instant))
        assertEquals(-180, cal.offsetMinutes(instant))
    }

    @Test
    fun diaDaSemanaIsoDoDiaDaCota() {
        val cal = QuotaCalendar(zone, 0)
        assertEquals(DayOfWeek.TUESDAY, LocalDate.parse("2026-11-17").dayOfWeek)
        assertEquals(2, cal.weekdayOf(LocalDate.parse("2026-11-17")))
        assertEquals(7, cal.weekdayOf(LocalDate.parse("2026-11-22")))
        assertEquals(1, cal.weekdayOf(LocalDate.parse("2026-11-23")))
    }

    @Test
    fun horaLocalEProximaViradaDeHora() {
        val cal = QuotaCalendar(zone, 0)
        val t = T.at("2026-11-17", "14:37:20")
        assertEquals(14, cal.hourOf(t))
        assertEquals(T.at("2026-11-17", "15:00"), cal.nextHourMs(t))
        assertEquals(T.at("2026-11-18", "00:00"), cal.nextHourMs(T.at("2026-11-17", "23:10")))
        assertEquals(T.at("2026-11-17", "15:00"), cal.nextHourMs(T.at("2026-11-17", "14:00")))
    }

    @Test
    fun atLocalAceitaVinteEQuatroHoras() {
        val cal = QuotaCalendar(zone, 0)
        val date = LocalDate.parse("2026-11-17")
        assertEquals(T.at("2026-11-18", "00:00"), cal.atLocal(date, 1440))
        assertEquals(T.at("2026-11-17", "20:30"), cal.atLocal(date, 20 * 60 + 30))
    }

    @Test
    fun fronteirasContinuamCoerentesEmMudancaDeHorarioDeVerao() {
        val ny = ZoneId.of("America/New_York")
        // 8 de março de 2026: 02:00 vira 03:00. Reinício às 02:30 cai no intervalo inexistente.
        val cal = QuotaCalendar(ny, 2 * 60 + 30)
        var t = T.at("2026-03-07", "20:00", ny)
        val end = T.at("2026-03-09", "08:00", ny)
        var previousDay = cal.dayOf(t)
        while (t < end) {
            val day = cal.dayOf(t)
            assertTrue("início <= instante", cal.dayStartMs(day) <= t)
            assertTrue("instante < fim", t < cal.dayEndMs(day))
            assertTrue("o dia nunca retrocede", !day.isBefore(previousDay))
            previousDay = day
            t += 7 * T.MIN
        }
        // Novembro de 2026: 02:00 se repete. O dia continua com fronteiras coerentes.
        t = T.at("2026-10-31", "20:00", ny)
        val end2 = T.at("2026-11-02", "08:00", ny)
        while (t < end2) {
            val day = cal.dayOf(t)
            assertTrue(cal.dayStartMs(day) <= t && t < cal.dayEndMs(day))
            t += 7 * T.MIN
        }
    }

    @Test
    fun chaveDoDiaTemFormatoIso() {
        assertEquals("2026-11-07", QuotaCalendar.dayKey(LocalDate.of(2026, 11, 7)))
        assertEquals(LocalDate.of(2026, 11, 7), QuotaCalendar.parseDayKey("2026-11-07"))
        assertEquals(null, QuotaCalendar.parseDayKey("ontem"))
    }
}
