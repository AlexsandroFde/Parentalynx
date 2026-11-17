package com.parentalynx.app.policy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class ScheduleEvaluatorTest {
    private val allDays = setOf(1, 2, 3, 4, 5, 6, 7)

    private fun evaluator(policy: Policy): ScheduleEvaluator = T.runtime(policy).schedules

    private fun bedtime(days: Set<Int> = allDays) =
        WeeklyBlockPeriod("p1", "Hora de dormir", true, days, 21 * 60, 7 * 60)

    @Test
    fun semRegrasNuncaBloqueia() {
        val ev = evaluator(Policy())
        val now = T.at("2026-11-17", "23:00")
        assertNull(ev.activeBlock(now))
        assertEquals(now, ev.releaseAt(now))
        assertNull(ev.nextBoundary(now))
    }

    @Test
    fun periodoSemanalAtravessandoAMeiaNoite() {
        val ev = evaluator(Policy(blockPeriods = listOf(bedtime())))
        assertNull(ev.activeBlock(T.at("2026-11-17", "20:59:59")))

        val night = ev.activeBlock(T.at("2026-11-17", "22:00"))
        assertNotNull(night)
        assertEquals("Hora de dormir", night!!.label)
        assertEquals(T.at("2026-11-18", "07:00"), night.untilMs)

        val dawn = ev.activeBlock(T.at("2026-11-18", "06:59"))
        assertEquals(T.at("2026-11-18", "07:00"), dawn!!.untilMs)
        assertNull(ev.activeBlock(T.at("2026-11-18", "07:00")))
    }

    @Test
    fun diasIndicamODiaEmQueOPeriodoComeca() {
        // Só sexta-feira (5). 20 de novembro de 2026 é sexta.
        val ev = evaluator(Policy(blockPeriods = listOf(bedtime(setOf(5)))))
        assertNotNull(ev.activeBlock(T.at("2026-11-20", "23:00")))
        assertNotNull("madrugada de sábado ainda pertence ao período de sexta", ev.activeBlock(T.at("2026-11-21", "03:00")))
        assertNull(ev.activeBlock(T.at("2026-11-21", "23:00")))
        assertNull("madrugada de sexta não pertence a período de quinta", ev.activeBlock(T.at("2026-11-20", "03:00")))
    }

    @Test
    fun periodoComInicioIgualAoFimDuraVinteEQuatroHoras() {
        val period = WeeklyBlockPeriod("p", "Dia sem telas", true, setOf(7), 8 * 60, 8 * 60)
        val ev = evaluator(Policy(blockPeriods = listOf(period)))
        // Domingo, 22 de novembro de 2026.
        assertNull(ev.activeBlock(T.at("2026-11-22", "07:59")))
        assertEquals(T.at("2026-11-23", "08:00"), ev.activeBlock(T.at("2026-11-22", "08:00"))!!.untilMs)
        assertNotNull(ev.activeBlock(T.at("2026-11-23", "07:59")))
        assertNull(ev.activeBlock(T.at("2026-11-23", "08:00")))
    }

    @Test
    fun periodoDesligadoNaoBloqueia() {
        val ev = evaluator(Policy(blockPeriods = listOf(bedtime().copy(enabled = false))))
        assertNull(ev.activeBlock(T.at("2026-11-17", "23:00")))
    }

    @Test
    fun periodoPontual() {
        val start = T.at("2026-11-17", "14:00")
        val end = T.at("2026-11-17", "16:00")
        val ev = evaluator(Policy(blockPeriods = listOf(OnceBlockPeriod("o", "Estudo", true, start, end))))
        assertNull(ev.activeBlock(start - 1))
        assertEquals(end, ev.activeBlock(start)!!.untilMs)
        assertEquals("Estudo", ev.activeBlock(start + T.HOUR)!!.label)
        assertNull(ev.activeBlock(end))
        assertEquals(start, ev.nextBoundary(start - T.HOUR))
        assertEquals(end, ev.nextBoundary(start))
    }

    @Test
    fun horariosPermitidosBloqueiamForaDasJanelas() {
        val hours = AllowedHours(true, listOf(TimeWindow(setOf(1, 2, 3, 4, 5), 7 * 60, 20 * 60 + 30)))
        val ev = evaluator(Policy(allowedHours = hours))
        // Terça-feira.
        val early = ev.activeBlock(T.at("2026-11-17", "06:00"))
        assertEquals(T.at("2026-11-17", "07:00"), early!!.untilMs)
        assertNull(early.label)
        assertNull(ev.activeBlock(T.at("2026-11-17", "07:00")))
        assertNull(ev.activeBlock(T.at("2026-11-17", "20:29:59")))
        assertEquals(T.at("2026-11-18", "07:00"), ev.activeBlock(T.at("2026-11-17", "20:30"))!!.untilMs)
    }

    @Test
    fun diaSemJanelaFicaBloqueadoOInteiro() {
        val hours = AllowedHours(true, listOf(TimeWindow(setOf(1, 2, 3, 4, 5), 7 * 60, 20 * 60)))
        val ev = evaluator(Policy(allowedHours = hours))
        // Sábado, 21 de novembro: sem janela. Libera segunda-feira às 07:00.
        val saturday = ev.activeBlock(T.at("2026-11-21", "12:00"))
        assertEquals(T.at("2026-11-23", "07:00"), saturday!!.untilMs)
    }

    @Test
    fun janelaAteVinteEQuatroHorasEmendaComODiaSeguinte() {
        val hours = AllowedHours(true, listOf(TimeWindow(allDays, 0, 1440)))
        val ev = evaluator(Policy(allowedHours = hours))
        assertNull(ev.activeBlock(T.at("2026-11-17", "00:00")))
        assertNull(ev.activeBlock(T.at("2026-11-17", "23:59:59")))
    }

    @Test
    fun variasJanelasNoMesmoDia() {
        val hours =
            AllowedHours(
                true,
                listOf(
                    TimeWindow(allDays, 7 * 60, 12 * 60),
                    TimeWindow(allDays, 14 * 60, 19 * 60),
                ),
            )
        val ev = evaluator(Policy(allowedHours = hours))
        assertNull(ev.activeBlock(T.at("2026-11-17", "11:00")))
        assertEquals(T.at("2026-11-17", "14:00"), ev.activeBlock(T.at("2026-11-17", "13:00"))!!.untilMs)
        assertNull(ev.activeBlock(T.at("2026-11-17", "18:59")))
        assertEquals(T.at("2026-11-18", "07:00"), ev.activeBlock(T.at("2026-11-17", "19:00"))!!.untilMs)
    }

    @Test
    fun liberacaoEncadeiaPeriodoEHorarioPermitido() {
        // Dormir até 07:00, mas o uso só é permitido a partir das 08:00.
        val hours = AllowedHours(true, listOf(TimeWindow(allDays, 8 * 60, 22 * 60)))
        val ev = evaluator(Policy(allowedHours = hours, blockPeriods = listOf(bedtime())))
        val block = ev.activeBlock(T.at("2026-11-17", "23:00"))
        assertEquals(T.at("2026-11-18", "08:00"), block!!.untilMs)
        assertEquals("Hora de dormir", block.label)
    }

    @Test
    fun bloqueioPermanenteNaoTemLiberacao() {
        val hours = AllowedHours(true, emptyList())
        val ev = evaluator(Policy(allowedHours = hours))
        val block = ev.activeBlock(T.at("2026-11-17", "12:00"))
        assertNotNull(block)
        assertNull(block!!.untilMs)
    }

    @Test
    fun proximaFronteiraEProximoBloqueio() {
        val ev = evaluator(Policy(blockPeriods = listOf(bedtime())))
        val afternoon = T.at("2026-11-17", "15:00")
        assertEquals(T.at("2026-11-17", "21:00"), ev.nextBoundary(afternoon))
        assertEquals(T.at("2026-11-18", "07:00"), ev.nextBoundary(T.at("2026-11-17", "22:00")))

        val next = ev.nextBlockStart(afternoon, 24 * T.HOUR)
        assertEquals(T.at("2026-11-17", "21:00"), next!!.startMs)
        assertEquals("Hora de dormir", next.label)
        assertNull(ev.nextBlockStart(afternoon, 2 * T.HOUR))
    }

    @Test
    fun consultasEmDatasDistantesRecalculamOsIntervalos() {
        val ev = evaluator(Policy(blockPeriods = listOf(bedtime())))
        assertNotNull(ev.activeBlock(T.at("2026-11-17", "22:00")))
        assertNotNull(ev.activeBlock(T.at("2027-03-02", "22:00")))
        assertNull(ev.activeBlock(T.at("2027-03-02", "12:00")))
        assertNotNull(ev.activeBlock(T.at("2026-11-17", "22:00")))
    }
}
