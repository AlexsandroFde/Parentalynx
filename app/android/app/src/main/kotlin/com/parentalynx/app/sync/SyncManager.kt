package com.parentalynx.app.sync

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.core.SecureStore
import com.parentalynx.app.core.objects
import com.parentalynx.app.core.strings
import com.parentalynx.app.data.TimeRequestStore
import com.parentalynx.app.enforcement.AgentNotifier
import com.parentalynx.app.enforcement.EventLog
import com.parentalynx.app.policy.PolicyParseException
import com.parentalynx.app.policy.QuotaCalendar
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/** Resultado de uma sincronização, para a tela da criança. */
data class SyncResult(val ok: Boolean, val atMs: Long, val errorCode: String?)

/**
 * Sincronização do aparelho com o servidor (`POST /v1/device/sync` e inventário).
 *
 * Envia o estado, os contadores dos dias pendentes e o que está nas filas de saída. Da resposta
 * aplica a hora do servidor, a política nova, as confirmações (`ack`), a reconciliação dos
 * contadores e as respostas a pedidos de tempo. Ver `docs/02-arquitetura.md`, seção 4.6.
 *
 * Roda em uma thread própria, uma sincronização por vez.
 */
class SyncManager(private val g: AgentGraph) {
    private val context: Context = g.context
    private val executor = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "plx-sync") }
    private val lock = Any()
    private var scheduled: ScheduledFuture<*>? = null
    private var scheduledAtMs = Long.MAX_VALUE

    /**
     * Agenda uma sincronização para daqui a [delayMs]. Pedidos próximos são agrupados: vale o
     * mais cedo.
     */
    fun requestSync(reason: String, delayMs: Long = DEBOUNCE_MS) {
        synchronized(lock) {
            val target = System.nanoTime() / 1_000_000 + delayMs
            if (scheduled != null && scheduledAtMs <= target) return
            scheduled?.cancel(false)
            scheduledAtMs = target
            scheduled =
                executor.schedule({
                    synchronized(lock) {
                        scheduled = null
                        scheduledAtMs = Long.MAX_VALUE
                    }
                    runSync(reason)
                }, delayMs.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
        }
    }

    /** Sincroniza agora e espera o resultado. Não chamar da thread principal. */
    fun syncBlocking(reason: String): SyncResult =
        try {
            executor.submit<SyncResult> { runSync(reason) }.get(SYNC_TIMEOUT_SEC, TimeUnit.SECONDS)
        } catch (e: Exception) {
            SyncResult(false, g.clock.nowMs(), ApiResult.CODE_NETWORK)
        }

    private fun runSync(reason: String): SyncResult {
        if (!g.agent.isActive()) return SyncResult(false, g.clock.nowMs(), "inactive")
        val token = g.secureStore.get(SecureStore.KEY_DEVICE_TOKEN)
        val serverUrl = g.prefs.serverUrl
        if (token.isNullOrEmpty() || serverUrl.isEmpty()) return SyncResult(false, g.clock.nowMs(), "inactive")
        return try {
            var result = syncOnce(serverUrl, token, reason)
            // Filas grandes saem em lotes: continua enquanto houver lote cheio confirmado.
            var rounds = 1
            while (result.ok && rounds < MAX_ROUNDS && g.outbox.pendingCount() >= SyncPayloads.MAX_EVENTS) {
                result = syncOnce(serverUrl, token, reason)
                rounds++
            }
            result
        } catch (e: RuntimeException) {
            AppLog.e(TAG, "falha inesperada na sincronização", e)
            record(false, "internal")
        }
    }

    private fun syncOnce(serverUrl: String, token: String, reason: String): SyncResult {
        val snapshot = g.engine.snapshot
        val permissions = snapshot.permissions ?: g.permissions.current()
        val now = g.clock.nowMs()
        val zone = ZoneId.systemDefault()
        val currentDay = snapshot.day.ifEmpty { QuotaCalendar.dayKey(g.engine.calendar().dayOf(now)) }
        val days = g.usageStore.snapshotForSync(currentDay, SyncPayloads.MAX_DAYS)
        val sessions = g.outbox.sessions(SyncPayloads.MAX_SESSIONS)
        val events = g.outbox.events(SyncPayloads.MAX_EVENTS)
        val browsing = g.outbox.browsing(SyncPayloads.MAX_BROWSING)
        val body =
            SyncPayloads.syncRequest(
                sentAtMs = now,
                policyVersion = g.policyStore.version,
                policyAppliedAtMs = g.policyStore.appliedAtMs,
                snapshot = snapshot,
                permissions = permissions,
                device =
                    DeviceStatusInfo(
                        batteryPercent = batteryPercent(),
                        appVersion = g.appVersion,
                        sdkInt = Build.VERSION.SDK_INT,
                        timezone = zone.id,
                        tzOffsetMin = zone.rules.getOffset(Instant.ofEpochMilli(now)).totalSeconds / 60,
                    ),
                days = days,
                sessions = sessions,
                events = events,
                browsing = browsing,
            )

        val startedElapsed = g.mono.elapsedMs()
        val result = g.apiClient.postJson(serverUrl, "/v1/device/sync", token, body)
        val finishedElapsed = g.mono.elapsedMs()
        return when (result) {
            is ApiResult.Error -> {
                if (result.code == ApiResult.CODE_DEVICE_REVOKED) {
                    AppLog.i(TAG, "vínculo revogado pelo responsável")
                    g.agent.deactivate(REASON_REVOKED)
                }
                record(false, result.wireCode)
            }
            is ApiResult.Ok -> {
                applyResponse(result.body, days.associate { it.day to it.rev }, currentDay, startedElapsed, finishedElapsed)
                if (result.body.optBoolean("needAppInventory", false) || inventoryDue()) {
                    uploadInventory(serverUrl, token)
                }
                AppLog.d(TAG, "sincronizado ($reason)")
                record(true, null)
            }
        }
    }

    private fun applyResponse(
        body: JSONObject,
        sentDayRevs: Map<String, Long>,
        currentDay: String,
        startedElapsed: Long,
        finishedElapsed: Long,
    ) {
        // Hora do servidor, estimada no ponto médio entre o envio e a resposta.
        val serverTime = body.optLong("serverTime", 0L)
        if (serverTime > 0L) g.engine.onServerTime(serverTime, startedElapsed + (finishedElapsed - startedElapsed) / 2)

        // Confirmações: só agora os itens saem das filas.
        val ack = body.optJSONObject("ack")
        if (ack != null) {
            g.outbox.ackSessions(ack.optJSONArray("sessions")?.strings().orEmpty())
            val ackedEvents = ack.optJSONArray("events")?.strings().orEmpty()
            g.outbox.ackEvents(ackedEvents)
            g.timeRequests.markDelivered(ackedEvents)
            g.outbox.ackBrowsing(ack.optJSONArray("browsing")?.strings().orEmpty())
            for (day in ack.optJSONArray("days")?.strings().orEmpty()) {
                sentDayRevs[day]?.let { g.usageStore.markSynced(day, it) }
            }
        }
        // O dia corrente foi gravado se a resposta chegou: fica limpo até mudar de novo.
        sentDayRevs[currentDay]?.let { g.usageStore.markSynced(currentDay, it) }

        // Reconciliação: o aparelho adota o maior valor entre o local e o do servidor.
        body.optJSONObject("reconcile")?.let { r ->
            val day = r.optString("day")
            if (day.isNotEmpty()) g.engine.onReconcile(day, r.optLong("quotaUsedMs", 0L), r.optLong("totalUsedMs", 0L))
        }

        body.optString("childName").takeIf { it.isNotEmpty() }?.let { g.prefs.childName = it }
        body.optString("guardianName").takeIf { it.isNotEmpty() }?.let { g.prefs.guardianName = it }
        if (body.has("lowTimeMinutes")) g.prefs.lowTimeMinutes = body.optInt("lowTimeMinutes", 10).coerceIn(1, 60)

        applyTimeRequests(body)
        applyPolicy(body)
    }

    private fun applyPolicy(body: JSONObject) {
        val policy = body.optJSONObject("policy") ?: return
        val version = body.optLong("policyVersion", 0L)
        if (version <= g.policyStore.version) return
        try {
            g.policyStore.save(version, policy.toString(), g.clock.nowMs())
            g.events.record(EventLog.POLICY_APPLIED, data = JSONObject().put("version", version))
            g.engine.onPolicyChanged()
            // Confirma logo ao responsável a versão aplicada.
            requestSync("policy_ack", POLICY_ACK_DELAY_MS)
        } catch (e: PolicyParseException) {
            AppLog.w(TAG, "política $version recusada: ${e.message}")
            g.events.record(
                EventLog.POLICY_APPLY_FAILED,
                data = JSONObject().put("version", version).put("error", e.message ?: "inválida"),
            )
            g.engine.onPolicyRejected()
        }
    }

    private fun applyTimeRequests(body: JSONObject) {
        for (request in body.optJSONArray("timeRequests")?.objects().orEmpty()) {
            val id = request.optString("id")
            val status = request.optString("status")
            if (id.isEmpty() || status.isEmpty() || status == TimeRequestStore.STATUS_PENDING) continue
            val granted = if (request.isNull("grantedMinutes")) null else request.optInt("grantedMinutes")
            val resolvedAt = if (request.isNull("resolvedAt")) null else request.optLong("resolvedAt")
            if (!g.timeRequests.updateStatus(id, status, granted, resolvedAt)) continue
            when (status) {
                TimeRequestStore.STATUS_APPROVED ->
                    g.notifier.notifyChild(
                        AgentNotifier.ID_CHILD_REQUEST,
                        context.getString(R.string.notify_request_approved_title),
                        context.getString(R.string.notify_request_approved_text, granted ?: 0),
                    )
                TimeRequestStore.STATUS_DENIED ->
                    g.notifier.notifyChild(
                        AgentNotifier.ID_CHILD_REQUEST,
                        context.getString(R.string.notify_request_denied_title),
                        context.getString(R.string.notify_request_denied_text),
                    )
            }
        }
    }

    private fun inventoryDue(): Boolean =
        g.prefs.inventoryDirty || g.clock.nowMs() - g.prefs.lastInventoryAtMs > INVENTORY_MAX_AGE_MS

    /** Envia a lista de apps e, em seguida, os ícones que o servidor ainda não tem. */
    private fun uploadInventory(serverUrl: String, token: String) {
        val items =
            try {
                g.catalog.inventory()
            } catch (e: RuntimeException) {
                AppLog.w(TAG, "falha ao montar o inventário", e)
                return
            }
        val result = g.apiClient.putJson(serverUrl, "/v1/device/apps", token, SyncPayloads.inventory(items))
        if (result !is ApiResult.Ok) return
        g.prefs.inventoryDirty = false
        g.prefs.lastInventoryAtMs = g.clock.nowMs()
        val hashes = items.associate { it.entry.appId to it.iconHash }
        for (appId in result.body.optJSONArray("needIcons")?.strings().orEmpty()) {
            val hash = hashes[appId] ?: continue
            val png = g.icons.pngFor(appId) ?: continue
            val upload =
                g.apiClient.putBytes(
                    serverUrl,
                    "/v1/device/apps/icon",
                    mapOf("package" to appId, "hash" to hash),
                    token,
                    "image/png",
                    png,
                )
            // Sem rede não adianta insistir: o servidor pede os ícones de novo no próximo envio.
            if (upload is ApiResult.Error && upload.network) {
                g.prefs.inventoryDirty = true
                return
            }
        }
    }

    private fun batteryPercent(): Int? {
        val battery = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager ?: return null
        val value = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return value.takeIf { it in 0..100 }
    }

    private fun record(ok: Boolean, errorCode: String?): SyncResult {
        val now = g.clock.nowMs()
        if (g.agent.isActive()) {
            g.prefs.lastSyncOk = ok
            g.prefs.lastSyncError = errorCode
            if (ok) g.prefs.lastSyncAtMs = now
        }
        return SyncResult(ok, now, errorCode)
    }

    companion object {
        const val REASON_REVOKED = "revoked"
        const val REASON_UNLINKED = "unlinked"
        private const val TAG = "Sync"

        /** Espera para agrupar eventos próximos em uma só sincronização. */
        private const val DEBOUNCE_MS = 5_000L
        private const val POLICY_ACK_DELAY_MS = 1_000L
        private const val SYNC_TIMEOUT_SEC = 90L
        private const val MAX_ROUNDS = 10
        private const val INVENTORY_MAX_AGE_MS = 24L * 60 * 60 * 1000
    }
}
