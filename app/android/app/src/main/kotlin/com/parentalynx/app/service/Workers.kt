package com.parentalynx.app.service

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.core.SecureStore
import com.parentalynx.app.core.objects
import com.parentalynx.app.sync.ApiResult
import java.util.concurrent.TimeUnit

/**
 * Tarefa periódica do modo criança (a cada 15 minutos, o mínimo do Android). É o terceiro caminho
 * para religar o motor, além da acessibilidade e do boot, e garante a sincronização mesmo com a
 * tela apagada. Sujeita a Doze e à economia de bateria do fabricante.
 */
class AgentWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val graph = AgentGraph.get(applicationContext)
        if (!graph.agent.isActive()) return Result.success()
        graph.agent.ensureRunning("worker")
        graph.syncManager.syncBlocking("worker")
        return Result.success()
    }

    companion object {
        private const val NAME = "plx-agent"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<AgentWorker>(15, TimeUnit.MINUTES).build()
            WorkManager
                .getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context.applicationContext).cancelUniqueWork(NAME)
        }
    }
}

/**
 * Busca de alertas em segundo plano no modo responsável.
 *
 * Sem serviço de push, um app fechado só consegue buscar alertas por tarefa periódica, com
 * intervalo mínimo de 15 minutos. Com o app aberto os alertas chegam na hora por WebSocket, pelo
 * lado Dart. O título e o texto vêm prontos do servidor.
 */
class GuardianAlertWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val graph = AgentGraph.get(applicationContext)
        val serverUrl = graph.prefs.guardianServerUrl
        val token = graph.secureStore.get(SecureStore.KEY_GUARDIAN_SESSION_TOKEN)
        if (serverUrl.isEmpty() || token.isNullOrEmpty()) return Result.success()

        val lastSeen = graph.prefs.guardianLastSeenAlertId
        val query = mapOf("after" to lastSeen.coerceAtLeast(0L).toString(), "notifyOnly" to "1", "limit" to MAX_ALERTS.toString())
        return when (val result = graph.apiClient.get(serverUrl, "/v1/guardian/alerts", query, token)) {
            is ApiResult.Ok -> {
                val alerts = result.body.optJSONArray("alerts")?.objects().orEmpty()
                var newest = maxOf(lastSeen, 0L)
                // Na primeira execução só posiciona o cursor: não notifica o histórico inteiro.
                val notify = lastSeen >= 0L
                for (alert in alerts) {
                    val id = alert.optLong("id", -1L)
                    if (id <= lastSeen) continue
                    if (id > newest) newest = id
                    if (notify && alert.optBoolean("notify", true)) {
                        graph.notifier.ensureChannels()
                        graph.notifier.notifyGuardianAlert(id, alert.optString("title"), alert.optString("body"))
                    }
                }
                val latest = result.body.optLong("latestId", newest)
                graph.prefs.guardianLastSeenAlertId = if (notify) newest else maxOf(newest, latest)
                Result.success()
            }
            is ApiResult.Error -> {
                if (!result.network && result.status == HTTP_UNAUTHORIZED) {
                    // Sessão expirada ou revogada: para de buscar até o responsável entrar de novo.
                    AppLog.i(TAG, "sessão do responsável inválida, busca de alertas suspensa")
                    cancel(applicationContext)
                    Result.success()
                } else {
                    Result.retry()
                }
            }
        }
    }

    companion object {
        private const val TAG = "GuardianAlerts"
        private const val NAME = "plx-guardian-alerts"
        private const val MAX_ALERTS = 50
        private const val HTTP_UNAUTHORIZED = 401

        fun schedule(context: Context) {
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val request =
                PeriodicWorkRequestBuilder<GuardianAlertWorker>(15, TimeUnit.MINUTES)
                    .setConstraints(constraints)
                    .build()
            WorkManager
                .getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context.applicationContext).cancelUniqueWork(NAME)
        }
    }
}
