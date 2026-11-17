package com.parentalynx.app.enforcement

import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.policy.BlockReason
import com.parentalynx.app.service.AccessibilityHolder

/**
 * Pedido de bloqueio de um app que está em primeiro plano.
 *
 * @property appId identificador do app na política (pode ser o navegador gerenciado).
 * @property pkg pacote real.
 * @property scheduleLabel nome do período de bloqueio, quando o motivo é horário.
 */
data class BlockRequest(
    val appId: String,
    val pkg: String,
    val label: String,
    val reason: BlockReason,
    val releaseAtMs: Long?,
    val scheduleLabel: String?,
)

/**
 * Tira da tela um app não autorizado e abre a tela de bloqueio nativa.
 *
 * Camadas, na ordem de `docs/02-arquitetura.md`, seção 4.4. No modo Device Owner o sistema já
 * suspendeu o pacote e ele nem abre: este controlador só entra para os pacotes que o sistema não
 * suspende e para os outros modos.
 *
 * 1. Abre a tela de bloqueio por cima do app. O Android só permite abrir uma atividade a partir
 *    do segundo plano com o serviço de acessibilidade vinculado, com a permissão de sobreposição
 *    ou como dono do dispositivo. Sem nenhuma delas ele recusa em silêncio.
 * 2. Se a tela de bloqueio não apareceu, tira o app da tela pela ação global "tela inicial" da
 *    acessibilidade (ou abrindo a tela inicial) e tenta a tela de bloqueio de novo. Sem nenhum
 *    desses meios, o motor sinaliza o controle como degradado.
 * 3. Em todos os casos, encerra os processos em segundo plano do app bloqueado.
 */
class BlockController(context: Context) {
    private val context = context.applicationContext
    private val activityManager = this.context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val mainHandler = Handler(Looper.getMainLooper())

    fun block(request: BlockRequest) {
        // A tela de bloqueio abre direto por cima do app. Pedir a tela inicial ao mesmo tempo
        // não funciona: a ação global é assíncrona, chega alguns milissegundos depois e cobre a
        // tela de bloqueio (visto em emulador com Android 16).
        showBlockScreen(request)
        mainHandler.postDelayed({ ensureCovered(request) }, COVER_CHECK_DELAY_MS)
        if (request.pkg != context.packageName) {
            mainHandler.postDelayed({ killBackground(request.pkg) }, KILL_DELAY_MS)
        }
    }

    /**
     * Plano de reserva: se o Android recusou abrir a tela de bloqueio a partir do segundo plano
     * (sem acessibilidade, sem sobreposição e sem ser dono do dispositivo), pelo menos tira o
     * app bloqueado da tela e tenta a tela de bloqueio de novo por cima da tela inicial.
     */
    private fun ensureCovered(request: BlockRequest) {
        if (BlockActivity.isInForeground) return
        val wentHome = AccessibilityHolder.goHome() || startHome()
        if (!wentHome) {
            AppLog.w(TAG, "não foi possível voltar à tela inicial")
            return
        }
        mainHandler.postDelayed({
            if (!BlockActivity.isInForeground) showBlockScreen(request)
        }, RETRY_AFTER_HOME_MS)
    }

    private fun startHome(): Boolean =
        try {
            context.startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }

    private fun showBlockScreen(request: BlockRequest) {
        try {
            context.startActivity(BlockActivity.intent(context, request))
        } catch (e: RuntimeException) {
            AppLog.w(TAG, "não foi possível abrir a tela de bloqueio", e)
        }
    }

    private fun killBackground(pkg: String) {
        try {
            activityManager.killBackgroundProcesses(pkg)
        } catch (e: RuntimeException) {
            AppLog.d(TAG, "não foi possível encerrar processos em segundo plano")
        }
    }

    private companion object {
        const val TAG = "BlockController"

        /** Espera o app ir para o segundo plano antes de encerrar seus processos. */
        const val KILL_DELAY_MS = 1200L

        /** Tempo para a tela de bloqueio aparecer antes de acionar o plano de reserva. */
        const val COVER_CHECK_DELAY_MS = 600L

        /** Tempo para a tela inicial assentar antes de tentar a tela de bloqueio de novo. */
        const val RETRY_AFTER_HOME_MS = 450L
    }
}
