package com.parentalynx.app.permissions

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.parentalynx.app.service.AccessibilityHolder
import com.parentalynx.app.service.AdminReceiver
import com.parentalynx.app.service.ParentalAccessibilityService

/** Retrato das permissões especiais de que o controle parental depende. */
data class PermissionState(
    val usageAccess: Boolean,
    val accessibility: Boolean,
    val overlay: Boolean,
    val notifications: Boolean,
    val batteryOptimizationIgnored: Boolean,
    val deviceAdmin: Boolean,
    val deviceOwner: Boolean,
    val exactAlarms: Boolean,
) {
    /** Nível de gerenciamento, no vocabulário do protocolo. */
    val managementMode: String
        get() =
            when {
                deviceOwner -> MODE_DEVICE_OWNER
                deviceAdmin -> MODE_DEVICE_ADMIN
                else -> MODE_STANDARD
            }

    /** Há algum meio de tirar da tela um app bloqueado. */
    val canBlock: Boolean
        get() = deviceOwner || accessibility || overlay

    /** Há alguma fonte para saber o que está em primeiro plano. */
    val canDetect: Boolean
        get() = usageAccess || accessibility

    /** Pares (nome do protocolo, concedida) usados nos eventos `permission_changed`. */
    fun asMap(): Map<String, Boolean> =
        linkedMapOf(
            "usageAccess" to usageAccess,
            "accessibility" to accessibility,
            "overlay" to overlay,
            "notifications" to notifications,
            "batteryOptimizationIgnored" to batteryOptimizationIgnored,
            "deviceAdmin" to deviceAdmin,
            "exactAlarms" to exactAlarms,
        )

    companion object {
        const val MODE_STANDARD = "standard"
        const val MODE_DEVICE_ADMIN = "device_admin"
        const val MODE_DEVICE_OWNER = "device_owner"
    }
}

class PermissionChecker(context: Context) {
    private val context = context.applicationContext
    private val adminComponent = ComponentName(this.context, AdminReceiver::class.java)
    private val accessibilityComponent = ComponentName(this.context, ParentalAccessibilityService::class.java)

    fun current(): PermissionState =
        PermissionState(
            usageAccess = hasUsageAccess(),
            accessibility = isAccessibilityEnabled(),
            overlay = Settings.canDrawOverlays(context),
            notifications = NotificationManagerCompat.from(context).areNotificationsEnabled(),
            batteryOptimizationIgnored = isIgnoringBatteryOptimizations(),
            deviceAdmin = isDeviceAdmin(),
            deviceOwner = isDeviceOwner(),
            exactAlarms = canScheduleExactAlarms(),
        )

    fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode =
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
                }
            } catch (e: RuntimeException) {
                return false
            }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Verdadeiro se o serviço está ligado nas Configurações ou conectado neste processo. */
    fun isAccessibilityEnabled(): Boolean {
        if (AccessibilityHolder.isConnected) return true
        return isAccessibilityEnabledInSettings()
    }

    fun isAccessibilityEnabledInSettings(): Boolean {
        val resolver = context.contentResolver
        val enabled = Settings.Secure.getInt(resolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1
        if (!enabled) return false
        val services = Settings.Secure.getString(resolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES).orEmpty()
        val full = accessibilityComponent.flattenToString()
        val short = accessibilityComponent.flattenToShortString()
        return services.split(':').any { it.equals(full, ignoreCase = true) || it.equals(short, ignoreCase = true) }
    }

    fun isIgnoringBatteryOptimizations(): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun isDeviceAdmin(): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        return dpm.isAdminActive(adminComponent)
    }

    fun isDeviceOwner(): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        return dpm.isDeviceOwnerApp(context.packageName)
    }

    fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false
        return alarms.canScheduleExactAlarms()
    }

    /**
     * Religa o serviço de acessibilidade quando ele foi desativado. Só funciona se a permissão
     * WRITE_SECURE_SETTINGS foi concedida por adb no provisionamento (reforço opcional descrito em
     * docs/05-device-owner.md). Sem ela, não faz nada.
     *
     * @return verdadeiro se o serviço foi religado.
     */
    fun tryRestoreAccessibility(): Boolean {
        if (context.checkSelfPermission(WRITE_SECURE_SETTINGS) != PackageManager.PERMISSION_GRANTED) return false
        return try {
            val resolver = context.contentResolver
            val component = accessibilityComponent.flattenToString()
            val existing = Settings.Secure.getString(resolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES).orEmpty()
            val services = existing.split(':').filter { it.isNotEmpty() }
            if (services.none { it.equals(component, ignoreCase = true) }) {
                Settings.Secure.putString(
                    resolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
                    (services + component).joinToString(":"),
                )
            }
            Settings.Secure.putInt(resolver, Settings.Secure.ACCESSIBILITY_ENABLED, 1)
            true
        } catch (e: SecurityException) {
            false
        }
    }

    /**
     * Android 13 ou superior bloqueia a ativação de acessibilidade para apps instalados por fora
     * de uma loja, até o usuário liberar "configurações restritas" na tela de informações do app.
     */
    fun restrictedSettingsLikely(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        if (isDeviceOwner() || isAccessibilityEnabled()) return false
        val installer =
            try {
                context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            } catch (e: Exception) {
                null
            }
        return installer == null || installer !in STORE_INSTALLERS
    }

    private companion object {
        const val WRITE_SECURE_SETTINGS = "android.permission.WRITE_SECURE_SETTINGS"

        /** Instaladores que o Android trata como loja (sessão de instalação confiável). */
        val STORE_INSTALLERS =
            setOf(
                "com.android.vending",
                "com.sec.android.app.samsungapps",
                "com.huawei.appmarket",
                "com.xiaomi.mipicks",
                "com.amazon.venezia",
                "com.aurora.store",
                "org.fdroid.fdroid",
            )
    }
}
