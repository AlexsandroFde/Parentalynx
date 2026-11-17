package com.parentalynx.app

import android.content.ComponentName
import android.content.pm.PackageManager
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.core.SecureStore
import com.parentalynx.app.data.AgentPrefs
import com.parentalynx.app.enforcement.AgentNotifier
import com.parentalynx.app.enforcement.EventLog
import com.parentalynx.app.service.AgentWorker
import com.parentalynx.app.service.EnforcementService
import com.parentalynx.app.service.GuardianAlertWorker
import com.parentalynx.app.sync.SyncManager
import org.json.JSONObject

/** Ciclo de vida do controle parental no aparelho da criança: ativar, manter rodando, desativar. */
class AgentController(private val g: AgentGraph) {
    /** Verdadeiro quando o aparelho está no modo criança e vinculado. */
    fun isActive(): Boolean = g.prefs.mode == AgentPrefs.MODE_CHILD && g.prefs.active

    /**
     * Grava as credenciais, aplica a política inicial e liga o serviço. Chamado uma única vez,
     * quando o responsável aprova a vinculação.
     *
     * @throws com.parentalynx.app.policy.PolicyParseException se a política inicial for ilegível.
     */
    fun activate(
        serverUrl: String,
        deviceId: String,
        deviceToken: String,
        offlineSecret: String,
        childName: String,
        guardianName: String,
        policyVersion: Long,
        policyJson: String,
    ) {
        // Valida e grava a política antes de qualquer outra coisa: se falhar, nada muda.
        g.policyStore.save(policyVersion, policyJson, g.clock.nowMs())
        g.secureStore.put(SecureStore.KEY_DEVICE_TOKEN, deviceToken)
        g.secureStore.put(SecureStore.KEY_OFFLINE_SECRET, offlineSecret)
        g.prefs.serverUrl = serverUrl
        g.prefs.deviceId = deviceId
        g.prefs.childName = childName
        g.prefs.guardianName = guardianName
        g.prefs.inventoryDirty = true
        g.prefs.lastDeactivationReason = null
        g.prefs.mode = AgentPrefs.MODE_CHILD
        g.prefs.active = true
        g.events.record(EventLog.POLICY_APPLIED, data = JSONObject().put("version", policyVersion))
        updateBrowserEntry()
        ensureRunning("activation")
        g.syncManager.requestSync("activation", 0L)
    }

    /** Liga o serviço, o motor e a tarefa periódica, se o aparelho está vinculado. */
    fun ensureRunning(reason: String) {
        if (!isActive()) return
        g.notifier.ensureChannels()
        EnforcementService.start(g.context)
        g.engine.start(reason)
        runCatching { AgentWorker.schedule(g.context) }
    }

    /** Modo responsável: garante a busca periódica de alertas depois de reiniciar ou atualizar. */
    fun ensureGuardianPolling() {
        if (g.prefs.mode == AgentPrefs.MODE_GUARDIAN && g.prefs.guardianServerUrl.isNotEmpty()) {
            runCatching { GuardianAlertWorker.schedule(g.context) }
        }
    }

    /**
     * Desativa o controle parental: remove suspensões e restrições, abre mão do modo Device Owner
     * e do administrador, apaga credenciais e dados locais.
     *
     * @param reason [SyncManager.REASON_REVOKED] (o responsável revogou o vínculo) ou
     *   [SyncManager.REASON_UNLINKED] (desvinculado no próprio aparelho).
     */
    fun deactivate(reason: String) {
        if (!g.prefs.active) return
        AppLog.i(TAG, "controle parental desativado: $reason")
        g.prefs.active = false
        g.prefs.lastDeactivationReason = reason
        runCatching { AgentWorker.cancel(g.context) }
        g.realtime.shutdown()
        EnforcementService.stop(g.context)
        g.engine.stop {
            // Na thread do motor, depois que o laço parou.
            runCatching {
                if (g.deviceOwner.isDeviceOwner()) g.deviceOwner.release() else g.deviceOwner.removeActiveAdmin()
            }
            g.secureStore.removeByPrefix(SecureStore.AGENT_PREFIX)
            runCatching { g.database.wipe() }
            g.usageStore.reset()
            g.policyStore.reset()
            g.prefs.clearChildLink()
            g.adminAuth.invalidate()
            updateBrowserEntry()
        }
        g.notifier.notifyChild(
            AgentNotifier.ID_CHILD_UNLINKED,
            g.context.getString(R.string.notify_unlinked_title),
            g.context.getString(
                if (reason == SyncManager.REASON_REVOKED) R.string.notify_unlinked_revoked else R.string.notify_unlinked_local,
            ),
        )
    }

    /**
     * Mostra ou esconde o ícone do navegador gerenciado no launcher. Ele só existe em aparelho
     * vinculado e enquanto o responsável mantiver o navegador ligado na política.
     */
    fun updateBrowserEntry() {
        val enabled = isActive() && g.policyStore.runtime()?.policy?.web?.managedBrowser == true
        val state =
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        runCatching {
            g.context.packageManager.setComponentEnabledSetting(
                ComponentName(g.context, BROWSER_ALIAS),
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private companion object {
        const val TAG = "Agent"

        /** `activity-alias` do manifesto com o ícone e os filtros de link do navegador. */
        const val BROWSER_ALIAS = "com.parentalynx.app.BrowserLauncher"
    }
}
