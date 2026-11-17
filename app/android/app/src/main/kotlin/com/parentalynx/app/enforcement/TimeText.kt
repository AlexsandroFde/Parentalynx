package com.parentalynx.app.enforcement

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Textos de tempo em português para a tela de bloqueio e as notificações. Puro, sem Android. */
object TimeText {
    private val clockFormat = DateTimeFormatter.ofPattern("HH:mm", Locale.ROOT)
    private val dateFormat = DateTimeFormatter.ofPattern("dd/MM", Locale.ROOT)

    /** Duração legível: "2 h 30 min", "45 min", "menos de 1 min". Arredonda para cima. */
    fun duration(ms: Long): String {
        if (ms < 60_000L) return if (ms <= 0L) "0 min" else "menos de 1 min"
        val totalMinutes = (ms + 59_999L) / 60_000L
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            hours == 0L -> "$minutes min"
            minutes == 0L -> "$hours h"
            else -> "$hours h $minutes min"
        }
    }

    /** Hora do relógio no fuso: "07:00". */
    fun clock(instantMs: Long, zone: ZoneId): String = clockFormat.format(Instant.ofEpochMilli(instantMs).atZone(zone))

    /**
     * Momento de liberação em relação a agora: "hoje às 21:00", "amanhã às 07:00" ou
     * "dia 23/11 às 07:00".
     */
    fun release(releaseAtMs: Long, nowMs: Long, zone: ZoneId): String {
        val release = Instant.ofEpochMilli(releaseAtMs).atZone(zone)
        val today = Instant.ofEpochMilli(nowMs).atZone(zone).toLocalDate()
        val time = clockFormat.format(release)
        return when (release.toLocalDate()) {
            today -> "hoje às $time"
            today.plusDays(1) -> "amanhã às $time"
            else -> "dia ${dateFormat.format(release)} às $time"
        }
    }
}
