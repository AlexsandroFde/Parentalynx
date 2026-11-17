package com.parentalynx.app.service

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.core.AppLog

/** Referência ao serviço de acessibilidade conectado, para acionar a ação "tela inicial". */
object AccessibilityHolder {
    @Volatile
    private var service: ParentalAccessibilityService? = null

    val isConnected: Boolean
        get() = service != null

    internal fun attach(instance: ParentalAccessibilityService) {
        service = instance
    }

    internal fun detach(instance: ParentalAccessibilityService) {
        if (service === instance) service = null
    }

    /** Envia o app em primeiro plano para o segundo plano. Falso se o serviço não está conectado. */
    fun goHome(): Boolean =
        try {
            service?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME) ?: false
        } catch (e: RuntimeException) {
            false
        }
}

/**
 * Serviço de acessibilidade do controle parental.
 *
 * Uso restrito, por configuração (`res/xml/accessibility_service.xml`) e por código:
 * - recebe só `typeWindowStateChanged`, para saber qual app veio para o primeiro plano;
 * - `canRetrieveWindowContent` é falso: o serviço não consegue ler o conteúdo das telas, textos
 *   digitados nem senhas;
 * - a única ação que executa é a global "tela inicial", para tirar da frente um app bloqueado.
 *
 * Do evento só são usados o nome do pacote e o nome da classe da janela.
 */
class ParentalAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        AccessibilityHolder.attach(this)
        val graph = AgentGraph.get(this)
        // O sistema religa este serviço sozinho quando o processo morre: ele traz o motor de volta.
        graph.agent.ensureRunning("accessibility")
        graph.engine.onAccessibilityChanged()
        AppLog.i(TAG, "serviço de acessibilidade conectado")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        AgentGraph.get(this).engine.onAccessibilityWindow(event.packageName?.toString(), event.className?.toString())
    }

    override fun onInterrupt() {
        // Sem retorno falado ou visual para interromper.
    }

    override fun onUnbind(intent: Intent?): Boolean {
        release()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        release()
        super.onDestroy()
    }

    private fun release() {
        AccessibilityHolder.detach(this)
        AgentGraph.get(this).engine.onAccessibilityChanged()
    }

    private companion object {
        const val TAG = "Accessibility"
    }
}
