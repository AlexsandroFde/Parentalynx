package com.parentalynx.app.service

import android.app.PendingIntent
import android.app.admin.DeviceAdminReceiver
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog

/**
 * Religa o controle parental depois de reiniciar o aparelho e depois de atualizar o app. O estado
 * (política, tempo usado, bloqueio manual) está em disco, então reiniciar não devolve tempo.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_QUICKBOOT_POWERON,
            -> {
                AppLog.i(TAG, "religando após ${intent.action}")
                val graph = AgentGraph.get(context)
                graph.agent.ensureRunning(if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) "update" else "boot")
                graph.agent.ensureGuardianPolling()
            }
        }
    }

    private companion object {
        const val TAG = "BootReceiver"

        /** Alguns fabricantes usam um aviso próprio na inicialização rápida. */
        const val ACTION_QUICKBOOT_POWERON = "android.intent.action.QUICKBOOT_POWERON"
    }
}

/**
 * Mudança de hora e de fuso com o processo parado. Com o motor rodando, o receptor dinâmico dele
 * trata os mesmos avisos. Aqui basta acordar o motor, que detecta o salto do relógio.
 */
class SystemEventsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED ->
                AgentGraph.get(context).agent.ensureRunning("clock")
        }
    }
}

/** Alarme de fronteira: reinício da cota, início ou fim de período, fim de suspensão. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_BOUNDARY) return
        val graph = AgentGraph.get(context)
        graph.agent.ensureRunning("alarm")
        graph.engine.requestTick()
    }

    companion object {
        private const val ACTION_BOUNDARY = "com.parentalynx.app.action.BOUNDARY"

        fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, AlarmReceiver::class.java).setAction(ACTION_BOUNDARY)
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}

/**
 * Administrador do dispositivo. Tem dois usos:
 * - modo padrão com administrador ativo: a desinstalação exige desativar o administrador antes, e
 *   a desativação gera aviso na tela e alerta ao responsável;
 * - modo Device Owner: é o componente que o sistema reconhece como dono do dispositivo.
 *
 * Não declara nenhuma política de administrador legado (senha, apagar dados, câmera).
 */
class AdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        AgentGraph.get(context).engine.requestPermissionCheck()
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        context.getString(R.string.device_admin_disable_warning)

    override fun onDisabled(context: Context, intent: Intent) {
        val graph = AgentGraph.get(context)
        if (graph.agent.isActive()) {
            // O motor compara com o último estado gravado e registra `permission_changed`, que
            // vira alerta para o responsável. Se o processo acabou de nascer, é religado aqui.
            graph.agent.ensureRunning("admin_disabled")
            graph.engine.requestPermissionCheck()
            graph.syncManager.requestSync("admin_disabled", SYNC_DELAY_MS)
        }
    }

    private companion object {
        /** Dá tempo de o motor registrar o evento antes de sincronizar. */
        const val SYNC_DELAY_MS = 2_000L
    }
}
