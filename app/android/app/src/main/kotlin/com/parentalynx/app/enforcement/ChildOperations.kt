package com.parentalynx.app.enforcement

import android.content.Intent
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.BrowserActivity
import com.parentalynx.app.apps.PackageClassifier
import com.parentalynx.app.core.Base32
import com.parentalynx.app.core.SecureStore
import com.parentalynx.app.core.Totp
import com.parentalynx.app.data.BrowsingRow
import com.parentalynx.app.core.Ids
import com.parentalynx.app.sync.ApiResult
import com.parentalynx.app.sync.SyncManager
import org.json.JSONObject

/** Resultado de uma autenticação do responsável no aparelho da criança. */
data class AdminCheck(val outcome: Outcome, val retryAfterSec: Long = 0L, val attemptsLeft: Int = -1, val message: String? = null) {
    enum class Outcome { OK, INVALID, LOCKED, OFFLINE, ERROR }
}

class AdminAuthRequiredException : Exception("autenticação do responsável necessária")

/**
 * Operações do modo criança usadas pela ponte com o Flutter e pela tela de bloqueio nativa:
 * pedido de tempo, autenticação do responsável, liberação local, desvinculação, navegador.
 */
class ChildOperations(private val g: AgentGraph) {
    @Volatile
    private var lastAuthMethod: String = METHOD_PASSWORD

    /** Registra um pedido de tempo adicional e devolve o identificador. */
    fun submitTimeRequest(minutes: Int?, message: String?): String {
        val now = g.clock.nowMs()
        // Toques repetidos em sequência não geram vários pedidos.
        if (g.timeRequests.hasPendingSince(now - REQUEST_DEDUP_MS)) {
            g.timeRequests.recent(1).firstOrNull()?.let { return it.id }
        }
        val data = JSONObject()
        if (minutes != null) data.put("minutes", minutes)
        if (!message.isNullOrBlank()) data.put("message", message.take(MAX_MESSAGE))
        val id = g.events.record(EventLog.TIME_REQUEST, data = data)
        g.timeRequests.add(id, now, minutes, message?.take(MAX_MESSAGE))
        g.syncManager.requestSync("time_request", 0L)
        return id
    }

    /** Confere a senha administrativa no servidor. Bloqueante: chamar fora da thread principal. */
    fun verifyAdminPassword(password: String): AdminCheck {
        val token = g.secureStore.get(SecureStore.KEY_DEVICE_TOKEN)
        if (!g.agent.isActive() || token.isNullOrEmpty()) return AdminCheck(AdminCheck.Outcome.ERROR)
        val body = JSONObject().put("password", password)
        return when (val result = g.apiClient.postJson(g.prefs.serverUrl, "/v1/device/admin-verify", token, body)) {
            is ApiResult.Ok -> {
                lastAuthMethod = METHOD_PASSWORD
                g.adminAuth.markAuthenticated()
                AdminCheck(AdminCheck.Outcome.OK)
            }
            is ApiResult.Error ->
                when {
                    result.network -> AdminCheck(AdminCheck.Outcome.OFFLINE)
                    result.code == ApiResult.CODE_INVALID_CREDENTIALS -> AdminCheck(AdminCheck.Outcome.INVALID, message = result.message)
                    result.code == ApiResult.CODE_ACCOUNT_LOCKED || result.code == ApiResult.CODE_RATE_LIMITED ->
                        AdminCheck(AdminCheck.Outcome.LOCKED, retryAfterSec = result.retryAfterSec, attemptsLeft = 0, message = result.message)
                    result.code == ApiResult.CODE_DEVICE_REVOKED -> {
                        g.agent.deactivate(SyncManager.REASON_REVOKED)
                        AdminCheck(AdminCheck.Outcome.ERROR, message = result.message)
                    }
                    else -> AdminCheck(AdminCheck.Outcome.ERROR, message = result.message)
                }
        }
    }

    /** Confere localmente o código de acesso offline (TOTP), com limite de tentativas persistido. */
    fun verifyOfflineCode(code: String): AdminCheck {
        val now = g.clock.nowMs()
        val locked = g.offlineAttempts.lockedForSec(now)
        if (locked > 0L) return AdminCheck(AdminCheck.Outcome.LOCKED, retryAfterSec = locked, attemptsLeft = 0)
        val secret =
            g.secureStore.get(SecureStore.KEY_OFFLINE_SECRET)?.let { runCatching { Base32.decode(it) }.getOrNull() }
                ?: return AdminCheck(AdminCheck.Outcome.ERROR)
        if (Totp.verify(secret, code, now)) {
            g.offlineAttempts.registerSuccess()
            lastAuthMethod = METHOD_OFFLINE_CODE
            g.adminAuth.markAuthenticated()
            return AdminCheck(AdminCheck.Outcome.OK)
        }
        val outcome = g.offlineAttempts.registerFailure(now)
        g.events.record(
            EventLog.ADMIN_AUTH_FAILED,
            data = JSONObject().put("method", METHOD_OFFLINE_CODE).put("attempts", g.prefs.offlineCodeFailures),
        )
        return if (outcome.retryAfterSec > 0L) {
            AdminCheck(AdminCheck.Outcome.LOCKED, retryAfterSec = outcome.retryAfterSec, attemptsLeft = 0)
        } else {
            AdminCheck(AdminCheck.Outcome.INVALID, attemptsLeft = outcome.attemptsLeft)
        }
    }

    /** Operações administrativas só valem com autenticação recente, enquanto houver vínculo. */
    fun requireAdminAuth() {
        if (g.agent.isActive() && !g.adminAuth.isValid()) throw AdminAuthRequiredException()
    }

    /** Libera o uso por alguns minutos (limite, horários e bloqueio manual). Não libera apps bloqueados. */
    fun grantLocalOverride(minutes: Int) {
        requireAdminAuth()
        val granted = minutes.coerceIn(1, MAX_OVERRIDE_MINUTES)
        g.engine.setLocalOverride(g.clock.nowMs() + granted * 60_000L)
        g.events.record(EventLog.LOCAL_OVERRIDE, data = JSONObject().put("minutes", granted).put("method", lastAuthMethod))
    }

    fun clearLocalOverride() {
        g.engine.setLocalOverride(0L)
    }

    /**
     * Desvincula o aparelho. Com senha e conexão, o servidor revoga o vínculo. Sem conexão,
     * desativa localmente e tenta avisar o servidor. Bloqueante.
     */
    fun unlink(password: String?): Boolean {
        if (!g.agent.isActive()) return true
        requireAdminAuth()
        val token = g.secureStore.get(SecureStore.KEY_DEVICE_TOKEN)
        var revokedByServer = false
        if (password != null && !token.isNullOrEmpty()) {
            val result = g.apiClient.postJson(g.prefs.serverUrl, "/v1/device/unlink", token, JSONObject().put("password", password))
            revokedByServer = result is ApiResult.Ok
        }
        if (!revokedByServer) {
            g.events.record(EventLog.UNLINKED_LOCALLY, data = JSONObject().put("method", lastAuthMethod))
            g.syncManager.syncBlocking("unlink")
        }
        g.agent.deactivate(SyncManager.REASON_UNLINKED)
        return true
    }

    /** Registra uma página do navegador gerenciado, se o responsável mantém o histórico ligado. */
    fun recordVisit(url: String, title: String?, blocked: Boolean, reason: String?) {
        val web = g.policyStore.runtime()?.policy?.web ?: return
        if (!g.agent.isActive() || !web.logHistory) return
        val domain = g.webFilter.hostOf(url) ?: return
        g.outbox.addBrowsing(
            BrowsingRow(
                id = Ids.newId(),
                tsMs = g.clock.nowMs(),
                url = url.take(MAX_URL),
                domain = domain,
                title = title?.take(MAX_TITLE),
                blocked = blocked,
                reason = reason,
            ),
        )
        g.syncManager.requestSync("browsing", BROWSING_SYNC_DELAY_MS)
    }

    /** Abre o navegador gerenciado, opcionalmente em um endereço. */
    fun openManagedBrowser(url: String?) {
        val intent = Intent(g.context, BrowserActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (!url.isNullOrBlank()) intent.putExtra(BrowserActivity.EXTRA_URL, url)
        g.context.startActivity(intent)
    }

    /** Abre um app pelo ícone de launcher. Falso se o pacote não tem atividade de entrada. */
    fun launchApp(appId: String): Boolean {
        if (appId == PackageClassifier.BROWSER_APP_ID) {
            openManagedBrowser(null)
            return true
        }
        val intent = g.context.packageManager.getLaunchIntentForPackage(appId) ?: return false
        return try {
            g.context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: RuntimeException) {
            false
        }
    }

    private companion object {
        const val METHOD_PASSWORD = "password"
        const val METHOD_OFFLINE_CODE = "offline_code"
        const val REQUEST_DEDUP_MS = 60_000L
        const val MAX_OVERRIDE_MINUTES = 240
        const val MAX_MESSAGE = 200
        const val MAX_URL = 2000
        const val MAX_TITLE = 200
        const val BROWSING_SYNC_DELAY_MS = 30_000L
    }
}
