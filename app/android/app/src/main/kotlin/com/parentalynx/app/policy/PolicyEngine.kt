package com.parentalynx.app.policy

import java.time.LocalDate
import java.time.ZoneId

/** Motivo de bloqueio. [wire] é o valor de `reason` do protocolo. */
enum class BlockReason(val wire: String) {
    MANUAL_LOCK("manual_lock"),
    TAMPER_LOCK("tamper_lock"),
    APP_BLOCKED("app_blocked"),
    NEW_APP("new_app"),
    APP_LIMIT("app_limit"),
    SCHEDULE("schedule"),
    DAILY_LIMIT("daily_limit"),
    ;

    companion object {
        fun fromWire(value: String?): BlockReason? = entries.firstOrNull { it.wire == value }
    }
}

/** Bloqueio geral do aparelho. [wire] é o valor de `lock.state` do protocolo. */
enum class LockKind(val wire: String) {
    NONE("none"),
    DAILY_LIMIT("daily_limit"),
    SCHEDULE("schedule"),
    MANUAL_LOCK("manual_lock"),
    TAMPER_LOCK("tamper_lock"),
}

/**
 * O que o motor precisa saber de um app para decidir. Ver a classificação de pacotes em
 * `docs/02-arquitetura.md`, seção 4.1.
 *
 * @property appId nome do pacote, ou o pacote virtual do navegador gerenciado.
 * @property essential nunca é bloqueado e nunca consome cota.
 * @property tracked o tempo aparece nos relatórios.
 */
data class AppFacts(
    val appId: String,
    val essential: Boolean,
    val system: Boolean,
    val tracked: Boolean,
)

/** Uso do dia da cota corrente. */
interface UsageView {
    val quotaUsedMs: Long

    fun appUsedMs(appId: String): Long
}

/**
 * Contexto da avaliação.
 *
 * @property tampered controle degradado: uma permissão essencial foi revogada depois da
 *   configuração.
 * @property localOverrideUntilMs liberação concedida pelo responsável no próprio aparelho. Zero
 *   quando não há.
 */
data class EvalContext(
    val nowMs: Long,
    val tampered: Boolean = false,
    val localOverrideUntilMs: Long = 0L,
) {
    val localOverrideActive: Boolean
        get() = localOverrideUntilMs > nowMs
}

sealed interface Decision {
    data object Allowed : Decision

    /**
     * @property releaseAtMs instante previsto de liberação, ou nulo quando depende do responsável.
     * @property label nome do período de bloqueio, quando o motivo é horário.
     */
    data class Blocked(
        val reason: BlockReason,
        val releaseAtMs: Long? = null,
        val label: String? = null,
    ) : Decision
}

data class DeviceLock(
    val kind: LockKind,
    val releaseAtMs: Long? = null,
    val label: String? = null,
)

/** Regra efetiva de um app depois de aplicar o padrão para apps sem regra. */
data class ResolvedRule(
    val state: AppState,
    val countsTowardLimit: Boolean,
    val dailyLimitMinutes: Int?,
    val isNewApp: Boolean,
)

/**
 * Política pronta para avaliação: resolve o fuso uma vez e mantém o calendário da cota e o
 * avaliador de horários.
 */
class PolicyRuntime(val policy: Policy, fallbackZone: ZoneId) {
    val zone: ZoneId =
        policy.timezone
            .takeIf { it.isNotBlank() }
            ?.let { runCatching { ZoneId.of(it) }.getOrNull() }
            ?: fallbackZone
    val calendar = QuotaCalendar(zone, policy.dailyLimit.resetMinutes)
    val schedules = ScheduleEvaluator(policy, calendar)

    fun extraMs(day: LocalDate): Long {
        val key = QuotaCalendar.dayKey(day)
        return policy.overrides.extraTime.filter { it.day == key }.sumOf { it.minutes.toLong() } * MINUTE_MS
    }

    /** Limite efetivo do dia (base do dia da semana mais tempo extra), ou nulo se desligado. */
    fun limitMs(day: LocalDate): Long? {
        if (!policy.dailyLimit.enabled) return null
        val base = policy.dailyLimit.minutesFor(calendar.weekdayOf(day)).toLong() * MINUTE_MS
        return base + extraMs(day)
    }

    fun resolveRule(app: AppFacts): ResolvedRule {
        val explicit = policy.apps.rules[app.appId]
        if (explicit != null) {
            return ResolvedRule(
                state = explicit.state,
                countsTowardLimit = explicit.state != AppState.EXCEPTION || explicit.countsTowardLimit,
                dailyLimitMinutes = explicit.dailyLimitMinutes,
                isNewApp = false,
            )
        }
        val blockedAsNew = policy.apps.blockNewApps && !app.system
        return ResolvedRule(
            state = if (blockedAsNew) AppState.BLOCKED else AppState.ALLOWED,
            countsTowardLimit = true,
            dailyLimitMinutes = null,
            isNewApp = blockedAsNew,
        )
    }

    fun suspended(scope: SuspensionScope, nowMs: Long): Boolean =
        policy.overrides.suspension.covers(scope, nowMs)

    companion object {
        const val MINUTE_MS = 60_000L
    }
}

/**
 * Avaliação da política. Função pura: a mesma entrada produz sempre a mesma saída, sem acesso a
 * relógio, disco ou sistema. A ordem das verificações é a de `docs/03-protocolo.md`, seção 4.3.
 */
object PolicyEngine {
    fun evaluate(runtime: PolicyRuntime?, app: AppFacts, usage: UsageView, ctx: EvalContext): Decision {
        // 1. Pacote essencial: sempre permitido.
        if (app.essential) return Decision.Allowed
        // 2. Sem política ativa.
        if (runtime == null) return Decision.Allowed
        // 3. Regra do pacote.
        val rule = runtime.resolveRule(app)
        return evaluateRule(runtime, rule, usage.appUsedMs(app.appId), usage.quotaUsedMs, ctx)
    }

    /**
     * Bloqueio geral do aparelho: o motivo que atingiria um app comum, permitido e sem limite
     * próprio, neste instante.
     */
    fun deviceLock(runtime: PolicyRuntime?, usage: UsageView, ctx: EvalContext): DeviceLock {
        if (runtime == null) return DeviceLock(LockKind.NONE)
        val ordinary = ResolvedRule(AppState.ALLOWED, countsTowardLimit = true, dailyLimitMinutes = null, isNewApp = false)
        return when (val decision = evaluateRule(runtime, ordinary, 0L, usage.quotaUsedMs, ctx)) {
            is Decision.Allowed -> DeviceLock(LockKind.NONE)
            is Decision.Blocked ->
                DeviceLock(
                    kind =
                        when (decision.reason) {
                            BlockReason.MANUAL_LOCK -> LockKind.MANUAL_LOCK
                            BlockReason.TAMPER_LOCK -> LockKind.TAMPER_LOCK
                            BlockReason.SCHEDULE -> LockKind.SCHEDULE
                            BlockReason.DAILY_LIMIT -> LockKind.DAILY_LIMIT
                            else -> LockKind.NONE
                        },
                    releaseAtMs = decision.releaseAtMs,
                    label = decision.label,
                )
        }
    }

    /** Verdadeiro quando o tempo do app em primeiro plano consome a cota diária. */
    fun consumesQuota(runtime: PolicyRuntime?, app: AppFacts, ctx: EvalContext): Boolean {
        if (app.essential || !app.tracked) return false
        if (runtime == null) return true
        if (limitSuspended(runtime, ctx)) return false
        return runtime.resolveRule(app).countsTowardLimit
    }

    /** Tempo restante da cota no dia, ou nulo quando não há limite em vigor. */
    fun remainingQuotaMs(runtime: PolicyRuntime?, day: LocalDate, quotaUsedMs: Long): Long? {
        val limit = runtime?.limitMs(day) ?: return null
        return (limit - quotaUsedMs).coerceAtLeast(0L)
    }

    /**
     * Próximo instante em que a decisão pode mudar só pela passagem do tempo: reinício da cota,
     * início ou fim de período, fim de suspensão, de bloqueio manual ou de liberação local. Não
     * inclui o esgotamento da cota, que depende do que está em primeiro plano.
     */
    fun nextTimeBoundaryMs(runtime: PolicyRuntime?, ctx: EvalContext): Long? {
        val now = ctx.nowMs
        val candidates = ArrayList<Long>()
        if (ctx.localOverrideUntilMs > now) candidates.add(ctx.localOverrideUntilMs)
        if (runtime != null) {
            candidates.add(runtime.calendar.nextResetMs(now))
            runtime.schedules.nextBoundary(now)?.let(candidates::add)
            val overrides = runtime.policy.overrides
            if (overrides.suspension.untilMs > now) candidates.add(overrides.suspension.untilMs)
            val lockUntil = overrides.manualLock.untilMs
            if (overrides.manualLock.active && lockUntil != null && lockUntil > now) candidates.add(lockUntil)
        }
        return candidates.minOrNull()
    }

    private fun limitSuspended(runtime: PolicyRuntime, ctx: EvalContext): Boolean =
        ctx.localOverrideActive || runtime.suspended(SuspensionScope.DAILY_LIMIT, ctx.nowMs)

    private fun schedulesSuspended(runtime: PolicyRuntime, ctx: EvalContext): Boolean =
        ctx.localOverrideActive || runtime.suspended(SuspensionScope.SCHEDULES, ctx.nowMs)

    private fun evaluateRule(
        runtime: PolicyRuntime,
        rule: ResolvedRule,
        appUsedMs: Long,
        quotaUsedMs: Long,
        ctx: EvalContext,
    ): Decision {
        val now = ctx.nowMs
        val policy = runtime.policy
        val isException = rule.state == AppState.EXCEPTION

        // 4. Bloqueio manual. A liberação local do responsável passa por cima.
        val manualLock = policy.overrides.manualLock
        if (!isException && !ctx.localOverrideActive && manualLock.isActive(now)) {
            return Decision.Blocked(BlockReason.MANUAL_LOCK, releaseAtMs = manualLock.untilMs)
        }

        // 5. Bloqueio por adulteração.
        if (!isException && !ctx.localOverrideActive && policy.protection.lockOnTamper && ctx.tampered) {
            return Decision.Blocked(BlockReason.TAMPER_LOCK)
        }

        // 6. App bloqueado, explicitamente ou por ser novo.
        if (rule.state == AppState.BLOCKED && !runtime.suspended(SuspensionScope.APP_BLOCKS, now)) {
            return Decision.Blocked(if (rule.isNewApp) BlockReason.NEW_APP else BlockReason.APP_BLOCKED)
        }

        // 7. Limite próprio do app.
        val appLimitMinutes = rule.dailyLimitMinutes
        if (appLimitMinutes != null && !limitSuspended(runtime, ctx) &&
            appUsedMs >= appLimitMinutes * PolicyRuntime.MINUTE_MS
        ) {
            return Decision.Blocked(BlockReason.APP_LIMIT, releaseAtMs = runtime.calendar.nextResetMs(now))
        }

        // 8. Exceção: disponível mesmo durante bloqueio por horário ou por limite.
        if (isException) return Decision.Allowed

        // 9. Horários.
        val schedulesOff = schedulesSuspended(runtime, ctx)
        if (!schedulesOff) {
            val block = runtime.schedules.activeBlock(now)
            if (block != null) {
                return Decision.Blocked(BlockReason.SCHEDULE, releaseAtMs = block.untilMs, label = block.label)
            }
        }

        // 10. Limite diário.
        if (!limitSuspended(runtime, ctx)) {
            val day = runtime.calendar.dayOf(now)
            val limit = runtime.limitMs(day)
            if (limit != null && quotaUsedMs >= limit) {
                val reset = runtime.calendar.nextResetMs(now)
                // Se no reinício da cota ainda houver bloqueio por horário, informa a liberação real.
                val release = if (schedulesOff) reset else runtime.schedules.releaseAt(reset) ?: reset
                return Decision.Blocked(BlockReason.DAILY_LIMIT, releaseAtMs = release)
            }
        }

        // 11. Permitido.
        return Decision.Allowed
    }
}
