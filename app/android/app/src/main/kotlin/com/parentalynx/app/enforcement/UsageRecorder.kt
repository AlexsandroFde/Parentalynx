package com.parentalynx.app.enforcement

import com.parentalynx.app.apps.CatalogEntry
import com.parentalynx.app.core.Ids
import com.parentalynx.app.data.EventRow
import com.parentalynx.app.data.OutboxStore
import com.parentalynx.app.data.SessionRow
import com.parentalynx.app.data.SessionWriter
import com.parentalynx.app.data.UsageWriter
import com.parentalynx.app.policy.EvalContext
import com.parentalynx.app.policy.PolicyEngine
import com.parentalynx.app.policy.PolicyRuntime
import com.parentalynx.app.policy.QuotaCalendar
import com.parentalynx.app.usage.UsageSink
import com.parentalynx.app.usage.UsageTracker
import org.json.JSONObject

/** Registro de eventos do aparelho na fila de saída (`docs/03-protocolo.md`, seção 5.3). */
class EventLog(private val outbox: OutboxStore, private val nowMs: () -> Long) {
    /** Chamado a cada evento gravado, para agendar uma sincronização. */
    @Volatile
    var onRecorded: ((type: String) -> Unit)? = null

    /** Grava um evento e devolve o identificador dele. */
    fun record(type: String, appId: String? = null, data: JSONObject = JSONObject()): String {
        val id = Ids.newId()
        outbox.addEvent(EventRow(id, type, nowMs(), appId, data.toString()))
        onRecorded?.invoke(type)
        return id
    }

    companion object {
        const val BLOCKED_ATTEMPT = "blocked_attempt"
        const val LIMIT_REACHED = "limit_reached"
        const val LOW_TIME = "low_time"
        const val APP_LIMIT_REACHED = "app_limit_reached"
        const val LOCK_STARTED = "lock_started"
        const val LOCK_ENDED = "lock_ended"
        const val POLICY_APPLIED = "policy_applied"
        const val POLICY_APPLY_FAILED = "policy_apply_failed"
        const val ENFORCEMENT_ISSUE = "enforcement_issue"
        const val PERMISSION_CHANGED = "permission_changed"
        const val TIME_REQUEST = "time_request"
        const val LOCAL_OVERRIDE = "local_override"
        const val ADMIN_AUTH_FAILED = "admin_auth_failed"
        const val CLOCK_CHANGED = "clock_changed"
        const val UNLINKED_LOCALLY = "unlinked_locally"
        const val DEVICE_BOOT = "device_boot"
        const val DEVICE_SHUTDOWN = "device_shutdown"
        const val AGENT_STARTED = "agent_started"
        const val MANAGEMENT_MODE_CHANGED = "management_mode_changed"
        const val APP_INSTALLED = "app_installed"
        const val APP_REMOVED = "app_removed"
    }
}

/** O que o gravador de uso precisa saber do motor no momento de cada crédito. */
interface RecorderEnvironment {
    /** Política em vigor, ou nulo. */
    fun runtime(): PolicyRuntime?

    /** Calendário da cota em vigor (o da política, ou o padrão do aparelho). */
    fun calendar(): QuotaCalendar

    /** Liberação local concedida pelo responsável. Zero quando não há. */
    fun localOverrideUntilMs(): Long

    /** Instante a partir do qual o uso é gravado. Antes dele o rastreador só se aquece. */
    fun recordFromMs(): Long

    fun entry(appId: String): CatalogEntry
}

/**
 * Recebe do rastreador os intervalos de uso e os grava: tempo por app, total do dia, cota, hora a
 * hora, aberturas e sessões. Divide cada intervalo nas viradas de dia da cota e de hora.
 */
class UsageRecorder(
    private val usage: UsageWriter,
    private val sessions: SessionWriter,
    private val env: RecorderEnvironment,
) : UsageSink {
    override fun onUsage(appIds: Set<String>, fromMs: Long, toMs: Long) {
        val start = maxOf(fromMs, env.recordFromMs())
        if (start >= toMs) return
        val tracked = appIds.map(env::entry).filter { it.tracked }
        if (tracked.isEmpty()) return
        val ids = tracked.map { it.appId }
        val calendar = env.calendar()
        val runtime = env.runtime()
        val override = env.localOverrideUntilMs()
        var t = start
        while (t < toMs) {
            val day = calendar.dayOf(t)
            val end = minOf(toMs, calendar.dayEndMs(day), calendar.nextHourMs(t))
            if (end <= t) break
            val ctx = EvalContext(nowMs = t, localOverrideUntilMs = override)
            // Em tela dividida o tempo do aparelho é um só: consome cota se algum dos apps consome.
            val consumesQuota = tracked.any { PolicyEngine.consumesQuota(runtime, it.toFacts(), ctx) }
            usage.addUsage(QuotaCalendar.dayKey(day), ids, end - t, calendar.hourOf(t), consumesQuota, t, end)
            t = end
        }
    }

    override fun onOpen(appId: String, atMs: Long) {
        if (atMs < env.recordFromMs() || !env.entry(appId).tracked) return
        usage.addOpen(QuotaCalendar.dayKey(env.calendar().dayOf(atMs)), appId)
    }

    override fun onSession(appId: String, startMs: Long, endMs: Long) {
        if (!env.entry(appId).tracked) return
        val start = maxOf(startMs, env.recordFromMs())
        if (endMs - start < UsageTracker.MIN_SESSION_MS) return
        val calendar = env.calendar()
        sessions.addSession(
            SessionRow(
                id = Ids.newId(),
                appId = appId,
                startMs = start,
                endMs = endMs,
                day = QuotaCalendar.dayKey(calendar.dayOf(start)),
                tzOffsetMin = calendar.offsetMinutes(start),
            ),
        )
    }
}
