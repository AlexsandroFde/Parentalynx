package com.parentalynx.app

import android.app.Application

/**
 * Aplicação. Sempre que o processo nasce (aberto pelo usuário, pelo sistema ao religar a
 * acessibilidade, por um alarme ou pela tarefa periódica), o controle parental é religado se o
 * aparelho está vinculado.
 */
class ParentaLynxApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val graph = AgentGraph.get(this)
        graph.notifier.ensureChannels()
        graph.agent.updateBrowserEntry()
        graph.agent.ensureRunning("process")
    }
}
