package com.parentalynx.app.policy

import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/** Apoio para os testes de política: instantes legíveis e construção de cenários. */
object T {
    val FORTALEZA: ZoneId = ZoneId.of("America/Fortaleza")

    /** Instante de "AAAA-MM-DD" às "HH:mm[:ss]" no fuso informado. */
    fun at(date: String, time: String, zone: ZoneId = FORTALEZA): Long =
        ZonedDateTime.of(LocalDate.parse(date), LocalTime.parse(time), zone).toInstant().toEpochMilli()

    const val MIN = 60_000L
    const val HOUR = 60 * MIN

    fun runtime(policy: Policy, zone: ZoneId = FORTALEZA): PolicyRuntime =
        PolicyRuntime(policy.copy(timezone = zone.id), ZoneId.of("UTC"))

    fun app(
        id: String = "com.exemplo.app",
        essential: Boolean = false,
        system: Boolean = false,
        tracked: Boolean = true,
    ): AppFacts = AppFacts(appId = id, essential = essential, system = system, tracked = tracked)

    fun usage(quotaUsedMs: Long = 0, apps: Map<String, Long> = emptyMap()): UsageView =
        object : UsageView {
            override val quotaUsedMs: Long = quotaUsedMs

            override fun appUsedMs(appId: String): Long = apps[appId] ?: 0L
        }
}
