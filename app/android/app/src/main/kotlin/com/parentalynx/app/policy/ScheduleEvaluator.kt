package com.parentalynx.app.policy

import java.time.LocalDate

/** Intervalo concreto em que o uso está bloqueado por horário: [startMs, endMs). */
data class BlockInterval(val startMs: Long, val endMs: Long, val label: String?) {
    fun contains(instantMs: Long): Boolean = instantMs in startMs until endMs
}

/** Bloqueio por horário em vigor. [untilMs] é nulo quando não há liberação no horizonte. */
data class ScheduleBlock(val label: String?, val untilMs: Long?)

/**
 * Avalia `allowedHours` e `blockPeriods` no relógio local do fuso da política.
 *
 * Tudo é reduzido a uma lista de intervalos bloqueados concretos para um trecho de datas em volta
 * do instante consultado. A lista é guardada por data, então consultas seguidas no mesmo dia não
 * refazem o cálculo.
 */
class ScheduleEvaluator(private val policy: Policy, private val calendar: QuotaCalendar) {
    private var cachedFor: LocalDate? = null
    private var cached: List<BlockInterval> = emptyList()

    /** Verdadeiro quando a política tem alguma regra de horário. */
    val hasRules: Boolean =
        (policy.allowedHours.enabled) || policy.blockPeriods.any { it.enabled }

    /** Bloqueio em vigor no instante, ou nulo. */
    fun activeBlock(nowMs: Long): ScheduleBlock? {
        if (!hasRules) return null
        val active = intervalsAround(nowMs).filter { it.contains(nowMs) }
        if (active.isEmpty()) return null
        val label = active.firstOrNull { !it.label.isNullOrBlank() }?.label
        return ScheduleBlock(label = label, untilMs = releaseAt(nowMs))
    }

    /**
     * Primeiro instante, a partir de [fromMs], em que nenhuma regra de horário bloqueia. Devolve
     * [fromMs] se já está livre e nulo se não há liberação dentro do horizonte calculado.
     */
    fun releaseAt(fromMs: Long): Long? {
        if (!hasRules) return fromMs
        var t = fromMs
        repeat(MAX_CHAIN) {
            val active = intervalsAround(t).filter { it.contains(t) }
            if (active.isEmpty()) return t
            t = active.maxOf { it.endMs }
            if (t - fromMs > HORIZON_MS) return null
        }
        return null
    }

    /** Próximo instante depois de [nowMs] em que o estado de bloqueio por horário pode mudar. */
    fun nextBoundary(nowMs: Long): Long? {
        if (!hasRules) return null
        var best: Long? = null
        for (interval in intervalsAround(nowMs)) {
            for (edge in longArrayOf(interval.startMs, interval.endMs)) {
                if (edge > nowMs && (best == null || edge < best)) best = edge
            }
        }
        return best
    }

    /** Próximo início de bloqueio dentro de [withinMs], quando o aparelho está livre agora. */
    fun nextBlockStart(nowMs: Long, withinMs: Long): BlockInterval? {
        if (!hasRules) return null
        return intervalsAround(nowMs)
            .filter { it.startMs > nowMs && it.startMs - nowMs <= withinMs }
            .minByOrNull { it.startMs }
    }

    @Synchronized
    private fun intervalsAround(instantMs: Long): List<BlockInterval> {
        val date = calendar.localDateOf(instantMs)
        val center = cachedFor
        // A lista cobre do dia anterior ao centro até DAYS_AHEAD - 1 dias depois. Reaproveita
        // enquanto a data consultada ainda tiver pelo menos um dia calculado à frente.
        val reusable =
            center != null && !date.isBefore(center) && date.isBefore(center.plusDays(DAYS_AHEAD - 1L))
        if (!reusable) {
            cached = build(date)
            cachedFor = date
        }
        return cached
    }

    private fun build(center: LocalDate): List<BlockInterval> {
        val out = ArrayList<BlockInterval>()
        val first = center.minusDays(1)
        for (offset in 0 until DAYS_AHEAD + 1) {
            val date = first.plusDays(offset.toLong())
            val weekday = date.dayOfWeek.value
            for (period in policy.blockPeriods) {
                if (!period.enabled || period !is WeeklyBlockPeriod || weekday !in period.days) continue
                val start = calendar.atLocal(date, period.startMinutes)
                val end =
                    if (period.endMinutes > period.startMinutes) {
                        calendar.atLocal(date, period.endMinutes)
                    } else {
                        calendar.atLocal(date.plusDays(1), period.endMinutes)
                    }
                if (end > start) out.add(BlockInterval(start, end, period.label))
            }
            if (policy.allowedHours.enabled) addOutsideAllowedHours(date, weekday, out)
        }
        for (period in policy.blockPeriods) {
            if (period.enabled && period is OnceBlockPeriod) {
                out.add(BlockInterval(period.startAtMs, period.endAtMs, period.label))
            }
        }
        return out
    }

    /** Acrescenta os trechos do dia que ficam fora de todas as janelas permitidas. */
    private fun addOutsideAllowedHours(date: LocalDate, weekday: Int, out: MutableList<BlockInterval>) {
        val windows =
            policy.allowedHours.windows
                .filter { weekday in it.days }
                .sortedBy { it.startMinutes }
        var cursor = 0
        for (window in windows) {
            if (window.startMinutes > cursor) {
                out.add(
                    BlockInterval(
                        calendar.atLocal(date, cursor),
                        calendar.atLocal(date, window.startMinutes),
                        null,
                    ),
                )
            }
            if (window.endMinutes > cursor) cursor = window.endMinutes
        }
        if (cursor < QuotaCalendar.MINUTES_PER_DAY) {
            out.add(
                BlockInterval(
                    calendar.atLocal(date, cursor),
                    calendar.atLocal(date, QuotaCalendar.MINUTES_PER_DAY),
                    null,
                ),
            )
        }
    }

    private companion object {
        /** Dias calculados à frente da data consultada (além do dia anterior). */
        const val DAYS_AHEAD = 9
        const val MAX_CHAIN = 64
        const val HORIZON_MS = 8L * 24 * 60 * 60 * 1000
    }
}
