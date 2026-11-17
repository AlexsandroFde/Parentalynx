package com.parentalynx.app.enforcement

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.parentalynx.app.MainActivity
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog

/**
 * Notificações do app: a permanente do modo criança (que também avisa que o controle parental
 * está ativo), os avisos para a criança e os alertas do modo responsável.
 */
class AgentNotifier(context: Context) {
    private val context = context.applicationContext
    private val manager = NotificationManagerCompat.from(this.context)

    @Volatile
    private var lastStatusText: String? = null

    fun ensureChannels() {
        val system = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        system.createNotificationChannel(
            NotificationChannel(
                CHANNEL_STATUS,
                context.getString(R.string.channel_status_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.channel_status_description)
                setShowBadge(false)
            },
        )
        system.createNotificationChannel(
            NotificationChannel(
                CHANNEL_CHILD,
                context.getString(R.string.channel_child_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = context.getString(R.string.channel_child_description) },
        )
        system.createNotificationChannel(
            NotificationChannel(
                CHANNEL_GUARDIAN,
                context.getString(R.string.channel_guardian_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = context.getString(R.string.channel_guardian_description) },
        )
    }

    /** Notificação permanente do serviço do modo criança. */
    fun buildStatus(text: String): Notification =
        NotificationCompat
            .Builder(context, CHANNEL_STATUS)
            .setSmallIcon(R.drawable.ic_stat_shield)
            .setContentTitle(context.getString(R.string.status_title))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openApp(ACTION_CHILD_HOME, REQUEST_STATUS))
            .build()

    /** Atualiza o texto da notificação permanente, se mudou. */
    fun updateStatus(text: String) {
        if (text == lastStatusText) return
        lastStatusText = text
        post(ID_STATUS, buildStatus(text))
    }

    fun cancelStatus() {
        lastStatusText = null
        manager.cancel(ID_STATUS)
    }

    /** Aviso para a criança (pouco tempo, limite atingido, resposta a pedido de tempo). */
    fun notifyChild(id: Int, title: String, text: String) {
        val notification =
            NotificationCompat
                .Builder(context, CHANNEL_CHILD)
                .setSmallIcon(R.drawable.ic_stat_shield)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setContentIntent(openApp(ACTION_CHILD_HOME, REQUEST_CHILD))
                .build()
        post(id, notification)
    }

    /** Alerta para o responsável, com título e texto já prontos vindos do servidor. */
    fun notifyGuardianAlert(alertId: Long, title: String, body: String) {
        val notification =
            NotificationCompat
                .Builder(context, CHANNEL_GUARDIAN)
                .setSmallIcon(R.drawable.ic_stat_shield)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setGroup(GROUP_GUARDIAN)
                .setContentIntent(openApp(ACTION_ALERTS, REQUEST_GUARDIAN))
                .build()
        post(ID_GUARDIAN_BASE + (alertId % GUARDIAN_ID_SPAN).toInt(), notification)
    }

    private fun post(id: Int, notification: Notification) {
        if (!manager.areNotificationsEnabled()) return
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            AppLog.d(TAG, "sem permissão para notificar")
        }
    }

    private fun openApp(action: String, requestCode: Int): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java)
                .putExtra(EXTRA_LAUNCH_ACTION, action)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        /** Extra de intent com a ação pedida à atividade principal. */
        const val EXTRA_LAUNCH_ACTION = "plx.action"
        const val ACTION_ALERTS = "alerts"
        const val ACTION_GUARDIAN_AREA = "guardian_area"
        const val ACTION_CHILD_HOME = "child_home"
        const val ACTION_PERMISSIONS = "permissions"

        const val ID_STATUS = 1001
        const val ID_CHILD_WARNING = 1002
        const val ID_CHILD_LIMIT = 1003
        const val ID_CHILD_REQUEST = 1004
        const val ID_CHILD_UNLINKED = 1005
        private const val ID_GUARDIAN_BASE = 20_000
        private const val GUARDIAN_ID_SPAN = 10_000L

        private const val TAG = "Notifier"
        private const val CHANNEL_STATUS = "plx_status"
        private const val CHANNEL_CHILD = "plx_child"
        private const val CHANNEL_GUARDIAN = "plx_guardian"
        private const val GROUP_GUARDIAN = "plx_guardian_alerts"
        private const val REQUEST_STATUS = 1
        private const val REQUEST_CHILD = 2
        private const val REQUEST_GUARDIAN = 3
    }
}
