package com.parentalynx.app.service

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.enforcement.AgentNotifier

/**
 * Serviço em primeiro plano do modo criança. Mantém o processo vivo para o motor de regras e
 * mostra a notificação permanente, que também informa que o controle parental está ativo.
 *
 * Tipo `specialUse` (controle parental não se encaixa em nenhum tipo específico) ou
 * `systemExempted` quando o app é o dono do dispositivo.
 */
class EnforcementService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val graph = AgentGraph.get(this)
        if (!graph.agent.isActive()) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        if (!enterForeground(graph)) {
            // O Android recusou o primeiro plano agora. O motor segue rodando enquanto o processo
            // viver, e a acessibilidade, o boot e a tarefa periódica voltam a tentar.
            stopSelf()
        }
        graph.engine.start("service")
        return START_STICKY
    }

    private fun enterForeground(graph: AgentGraph): Boolean {
        graph.notifier.ensureChannels()
        val notification = graph.notifier.buildStatus(getString(R.string.status_starting))
        val types = foregroundTypes(graph.permissions.isDeviceOwner())
        for (type in types) {
            try {
                ServiceCompat.startForeground(this, AgentNotifier.ID_STATUS, notification, type)
                return true
            } catch (e: RuntimeException) {
                // SecurityException (tipo não permitido) ou ForegroundServiceStartNotAllowedException.
                AppLog.w(TAG, "primeiro plano recusado para o tipo $type: ${e.javaClass.simpleName}")
            }
        }
        return false
    }

    private fun foregroundTypes(deviceOwner: Boolean): List<Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return listOf(0)
        return if (deviceOwner) {
            listOf(ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            listOf(ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        }
    }

    private fun stopForegroundCompat() {
        runCatching { ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE) }
    }

    companion object {
        private const val TAG = "EnforcementService"

        /**
         * Liga o serviço. Se o Android não permitir iniciar serviço em primeiro plano a partir do
         * segundo plano, liga só o motor no processo atual.
         */
        fun start(context: Context) {
            val app = context.applicationContext
            try {
                ContextCompat.startForegroundService(app, Intent(app, EnforcementService::class.java))
            } catch (e: RuntimeException) {
                AppLog.w(TAG, "não foi possível iniciar o serviço: ${e.javaClass.simpleName}")
                AgentGraph.get(app).engine.start("fallback")
            }
        }

        fun stop(context: Context) {
            val app = context.applicationContext
            runCatching { app.stopService(Intent(app, EnforcementService::class.java)) }
        }
    }
}
