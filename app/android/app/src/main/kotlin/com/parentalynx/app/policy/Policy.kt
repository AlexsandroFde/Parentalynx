package com.parentalynx.app.policy

/** Estado de autorização de um app. Valores de `apps.rules[*].state` do protocolo. */
enum class AppState(val wire: String) {
    ALLOWED("allowed"),
    BLOCKED("blocked"),
    EXCEPTION("exception"),
    ;

    companion object {
        fun fromWire(value: String?): AppState? = entries.firstOrNull { it.wire == value }
    }
}

/** Escopos de suspensão temporária de regras. */
enum class SuspensionScope(val wire: String) {
    DAILY_LIMIT("dailyLimit"),
    SCHEDULES("schedules"),
    APP_BLOCKS("appBlocks"),
    ;

    companion object {
        fun fromWire(value: String?): SuspensionScope? = entries.firstOrNull { it.wire == value }
    }
}

/**
 * Regra de um app.
 *
 * @property countsTowardLimit só tem efeito em [AppState.EXCEPTION]: indica se o uso do app
 *   consome a cota diária.
 * @property dailyLimitMinutes limite próprio do app, ou nulo.
 */
data class AppRule(
    val state: AppState,
    val countsTowardLimit: Boolean = false,
    val dailyLimitMinutes: Int? = null,
)

/**
 * Limite diário.
 *
 * @property perWeekday minutos por dia da semana ISO (1 = segunda), sobrepondo [minutes].
 * @property resetMinutes horário de reinício da cota, em minutos desde a meia-noite.
 */
data class DailyLimit(
    val enabled: Boolean = false,
    val minutes: Int = 0,
    val perWeekday: Map<Int, Int> = emptyMap(),
    val resetMinutes: Int = 0,
    val warnAtMinutes: List<Int> = emptyList(),
) {
    fun minutesFor(isoWeekday: Int): Int = perWeekday[isoWeekday] ?: minutes
}

/** Janela de horário permitido. [endMinutes] pode ser 1440 (24:00). */
data class TimeWindow(val days: Set<Int>, val startMinutes: Int, val endMinutes: Int)

data class AllowedHours(val enabled: Boolean = false, val windows: List<TimeWindow> = emptyList())

sealed interface BlockPeriod {
    val id: String
    val label: String
    val enabled: Boolean
}

/** Período semanal. Se [startMinutes] >= [endMinutes], atravessa a meia-noite. */
data class WeeklyBlockPeriod(
    override val id: String,
    override val label: String,
    override val enabled: Boolean,
    val days: Set<Int>,
    val startMinutes: Int,
    val endMinutes: Int,
) : BlockPeriod

data class OnceBlockPeriod(
    override val id: String,
    override val label: String,
    override val enabled: Boolean,
    val startAtMs: Long,
    val endAtMs: Long,
) : BlockPeriod

data class AppsPolicy(
    val blockNewApps: Boolean = false,
    val rules: Map<String, AppRule> = emptyMap(),
)

data class WebPolicy(
    val managedBrowser: Boolean = true,
    val logHistory: Boolean = true,
    val safeDns: Boolean = false,
    val safeSearch: Boolean = false,
    val allowlistMode: Boolean = false,
    val blockedDomains: List<String> = emptyList(),
    val allowedDomains: List<String> = emptyList(),
    val blockedCategories: Set<String> = emptySet(),
)

data class ProtectionPolicy(
    val lockOnTamper: Boolean = false,
    val blockUninstall: Boolean = true,
    val blockSafeBoot: Boolean = true,
    val blockFactoryReset: Boolean = true,
    val blockDateTimeChange: Boolean = true,
    val blockAddUser: Boolean = true,
    val blockUnknownSources: Boolean = false,
    val blockUsbDebugging: Boolean = false,
)

data class ExtraTime(val id: String, val day: String, val minutes: Int, val grantedAtMs: Long)

data class ManualLock(val active: Boolean = false, val untilMs: Long? = null) {
    fun isActive(nowMs: Long): Boolean = active && (untilMs == null || nowMs < untilMs)
}

data class Suspension(val untilMs: Long = 0L, val scopes: Set<SuspensionScope> = emptySet()) {
    fun covers(scope: SuspensionScope, nowMs: Long): Boolean = untilMs > nowMs && scope in scopes
}

data class Overrides(
    val extraTime: List<ExtraTime> = emptyList(),
    val manualLock: ManualLock = ManualLock(),
    val suspension: Suspension = Suspension(),
)

/** Documento de política, versão `schema: 1` do protocolo. */
data class Policy(
    val schema: Int = 1,
    val timezone: String = "",
    val dailyLimit: DailyLimit = DailyLimit(),
    val allowedHours: AllowedHours = AllowedHours(),
    val blockPeriods: List<BlockPeriod> = emptyList(),
    val apps: AppsPolicy = AppsPolicy(),
    val web: WebPolicy = WebPolicy(),
    val protection: ProtectionPolicy = ProtectionPolicy(),
    val overrides: Overrides = Overrides(),
)
