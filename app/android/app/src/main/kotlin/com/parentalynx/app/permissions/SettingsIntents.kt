package com.parentalynx.app.permissions

import android.annotation.SuppressLint
import android.app.admin.DevicePolicyManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.service.AdminReceiver

/** Atalhos para as telas do sistema onde o usuário concede as permissões especiais. */
class SettingsIntents(context: Context) {
    private val context = context.applicationContext
    private val packageUri: Uri = Uri.parse("package:${this.context.packageName}")

    fun openUsageAccess() {
        // Alguns aparelhos aceitam ir direto para a tela do app. Os demais abrem a lista.
        startFirst(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).setData(packageUri),
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS),
        )
    }

    fun openAccessibility() {
        startFirst(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    fun openOverlay() {
        startFirst(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, packageUri),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
        )
    }

    @SuppressLint("BatteryLife")
    fun requestIgnoreBatteryOptimizations() {
        startFirst(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
        )
    }

    fun openExactAlarms() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startFirst(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri),
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM),
            )
        } else {
            openAppDetails()
        }
    }

    fun openNotifications() {
        val intent =
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        startFirst(intent)
    }

    fun openAppDetails(): Boolean = start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))

    /** Abre o pedido do sistema para ativar o ParentaLynx como administrador do dispositivo. */
    fun requestDeviceAdmin() {
        val intent =
            Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, ComponentName(context, AdminReceiver::class.java))
                .putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, context.getString(R.string.device_admin_explanation))
        start(intent)
    }

    /**
     * Tenta abrir a tela de início automático do fabricante. Não existe API pública para isso:
     * são telas conhecidas de cada fabricante, que podem mudar entre versões.
     */
    fun openManufacturerAutostart(): Boolean {
        for (component in AUTOSTART_SCREENS) {
            val intent = Intent().setComponent(component)
            if (context.packageManager.resolveActivity(intent, 0) != null && start(intent)) return true
        }
        return false
    }

    /** Abre a primeira tela que existir no aparelho. Sem nenhuma, cai nas informações do app. */
    private fun startFirst(vararg intents: Intent) {
        if (intents.none { start(it) }) openAppDetails()
    }

    private fun start(intent: Intent): Boolean =
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            AppLog.w(TAG, "tela de configuração protegida: ${intent.action ?: intent.component}")
            false
        }

    private companion object {
        const val TAG = "SettingsIntents"

        val AUTOSTART_SCREENS =
            listOf(
                // Xiaomi, Redmi e POCO
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
                // OPPO e realme
                ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
                ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
                ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
                ComponentName("com.oplus.safecenter", "com.oplus.safecenter.startupapp.view.StartupAppListActivity"),
                // vivo e iQOO
                ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
                // Huawei e Honor
                ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
                ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                // OnePlus
                ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
                // Asus
                ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.powersaver.PowerSaverSettings"),
                // Samsung (apps em suspensão)
                ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            )
    }
}
