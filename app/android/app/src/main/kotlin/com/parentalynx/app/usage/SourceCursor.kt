package com.parentalynx.app.usage

/**
 * Ponto até onde o registro de eventos do sistema já foi lido.
 *
 * O registro tem resolução de milissegundo e pode ter vários eventos com o mesmo carimbo. Por
 * isso o cursor guarda o carimbo do último evento e quantos eventos com esse carimbo já foram
 * processados. A leitura seguinte recomeça nesse mesmo carimbo e pula os já vistos.
 *
 * Os carimbos aqui são do relógio de parede do aparelho, como o sistema os grava.
 */
data class SourceCursor(val lastTsMs: Long, val seenAtLastTs: Int) {
    /** Desloca o cursor quando o relógio de parede do aparelho é alterado. */
    fun shifted(deltaMs: Long): SourceCursor = copy(lastTsMs = lastTsMs + deltaMs)
}

/** Evento bruto do sistema, com carimbo do relógio de parede. */
data class RawUsageEvent(
    val wallTsMs: Long,
    val type: UsageEventType,
    val pkg: String?,
    val cls: String?,
)

object CursorFilter {
    /**
     * Separa os eventos novos de uma leitura que começou em `cursor.lastTsMs` (inclusive).
     *
     * @param events eventos em ordem crescente de carimbo.
     * @return os eventos ainda não processados e o cursor atualizado.
     */
    fun filterNew(events: List<RawUsageEvent>, cursor: SourceCursor): Pair<List<RawUsageEvent>, SourceCursor> {
        if (events.isEmpty()) return emptyList<RawUsageEvent>() to cursor
        val fresh = ArrayList<RawUsageEvent>(events.size)
        var skipped = 0
        for (event in events) {
            when {
                event.wallTsMs < cursor.lastTsMs -> Unit
                event.wallTsMs == cursor.lastTsMs && skipped < cursor.seenAtLastTs -> skipped++
                else -> fresh.add(event)
            }
        }
        val lastTs = events.last().wallTsMs
        if (lastTs < cursor.lastTsMs) return fresh to cursor
        val countAtLast = events.count { it.wallTsMs == lastTs }
        return fresh to SourceCursor(lastTs, countAtLast)
    }
}
