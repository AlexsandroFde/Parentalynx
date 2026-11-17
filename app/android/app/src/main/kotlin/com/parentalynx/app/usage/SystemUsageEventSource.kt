package com.parentalynx.app.usage

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import com.parentalynx.app.core.AppLog

/**
 * Lê o registro de eventos de uso do sistema (`UsageStatsManager.queryEvents`).
 *
 * É a fonte de verdade da contagem de tempo: o registro é mantido pelo Android, sobrevive a
 * reinicializações e à morte do nosso processo. Exige o acesso especial "Acesso ao uso".
 */
class SystemUsageEventSource(context: Context) {
    private val usageStats =
        context.applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    /**
     * Eventos com carimbo em [fromWallMs, toWallMs), em ordem crescente. Devolve lista vazia se o
     * acesso não foi concedido ou se o armazenamento do usuário ainda está trancado.
     */
    fun read(fromWallMs: Long, toWallMs: Long): List<RawUsageEvent> {
        if (toWallMs <= fromWallMs) return emptyList()
        val out = ArrayList<RawUsageEvent>()
        try {
            val events = usageStats.queryEvents(fromWallMs, toWallMs) ?: return emptyList()
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                if (!events.getNextEvent(event)) break
                val type = mapType(event.eventType) ?: continue
                out.add(RawUsageEvent(event.timeStamp, type, event.packageName, event.className))
            }
        } catch (e: SecurityException) {
            AppLog.w(TAG, "sem acesso ao registro de uso", e)
            return emptyList()
        } catch (e: IllegalStateException) {
            AppLog.w(TAG, "registro de uso indisponível", e)
            return emptyList()
        }
        // O sistema já entrega em ordem. A ordenação estável é só uma garantia.
        out.sortBy { it.wallTsMs }
        return out
    }

    private fun mapType(eventType: Int): UsageEventType? =
        when (eventType) {
            EVENT_ACTIVITY_RESUMED -> UsageEventType.RESUMED
            EVENT_ACTIVITY_PAUSED -> UsageEventType.PAUSED
            EVENT_ACTIVITY_STOPPED -> UsageEventType.STOPPED
            EVENT_SCREEN_INTERACTIVE -> UsageEventType.SCREEN_ON
            EVENT_SCREEN_NON_INTERACTIVE -> UsageEventType.SCREEN_OFF
            EVENT_KEYGUARD_SHOWN -> UsageEventType.KEYGUARD_SHOWN
            EVENT_DEVICE_SHUTDOWN -> UsageEventType.SHUTDOWN
            EVENT_DEVICE_STARTUP -> UsageEventType.STARTUP
            else -> null
        }

    private companion object {
        const val TAG = "UsageSource"

        // Valores de UsageEvents.Event. Usados como números porque alguns nomes só existem a
        // partir da API 29 e os valores são os mesmos desde a API 28.
        const val EVENT_ACTIVITY_RESUMED = 1
        const val EVENT_ACTIVITY_PAUSED = 2
        const val EVENT_SCREEN_INTERACTIVE = 15
        const val EVENT_SCREEN_NON_INTERACTIVE = 16
        const val EVENT_KEYGUARD_SHOWN = 17
        const val EVENT_ACTIVITY_STOPPED = 23
        const val EVENT_DEVICE_SHUTDOWN = 26
        const val EVENT_DEVICE_STARTUP = 27
    }
}
