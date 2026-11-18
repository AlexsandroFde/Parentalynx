package com.parentalynx.app.bridge

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.core.Hashing
import com.parentalynx.app.core.SecureStore
import com.parentalynx.app.data.AgentPrefs
import com.parentalynx.app.enforcement.AdminAuthRequiredException
import com.parentalynx.app.enforcement.AdminCheck
import com.parentalynx.app.permissions.PermissionState
import com.parentalynx.app.policy.LockKind
import com.parentalynx.app.policy.PolicyParseException
import com.parentalynx.app.service.GuardianAlertWorker
import io.flutter.plugin.common.BinaryMessenger
import java.time.ZoneId
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private fun adminRequired(): FlutterError =
    FlutterError("admin_auth_required", "Autenticação do responsável necessária.", null)

/** Converte a falta de autenticação do responsável no erro que o Dart reconhece. */
private inline fun <T> guarded(block: () -> T): T =
    try {
        block()
    } catch (e: AdminAuthRequiredException) {
        throw adminRequired()
    }

private fun PermissionState.toPigeon(restrictedSettingsLikely: Boolean): PermissionSnapshot =
    PermissionSnapshot(
        usageAccess = usageAccess,
        accessibility = accessibility,
        overlay = overlay,
        notifications = notifications,
        batteryOptimizationIgnored = batteryOptimizationIgnored,
        deviceAdmin = deviceAdmin,
        deviceOwner = deviceOwner,
        exactAlarms = exactAlarms,
        restrictedSettingsLikely = restrictedSettingsLikely,
    )

private fun PermissionState.toManagementMode(): ManagementMode =
    when {
        deviceOwner -> ManagementMode.DEVICE_OWNER
        deviceAdmin -> ManagementMode.DEVICE_ADMIN
        else -> ManagementMode.STANDARD
    }

private fun AdminCheck.toPigeon(): AdminAuthResult =
    AdminAuthResult(
        outcome =
            when (outcome) {
                AdminCheck.Outcome.OK -> AdminAuthOutcome.OK
                AdminCheck.Outcome.INVALID -> AdminAuthOutcome.INVALID
                AdminCheck.Outcome.LOCKED -> AdminAuthOutcome.LOCKED
                AdminCheck.Outcome.OFFLINE -> AdminAuthOutcome.OFFLINE
                AdminCheck.Outcome.ERROR -> AdminAuthOutcome.ERROR
            },
        retryAfterSec = retryAfterSec,
        attemptsLeft = attemptsLeft.toLong(),
        message = message,
    )

/** Modo do app e ações de abertura. */
class AppModeBridge(private val g: AgentGraph, private val consumeAction: () -> String?) : AppModeApi {
    override fun getMode(): AppMode =
        when (g.prefs.mode) {
            AgentPrefs.MODE_GUARDIAN -> AppMode.GUARDIAN
            AgentPrefs.MODE_CHILD -> AppMode.CHILD
            else -> AppMode.UNSET
        }

    override fun setMode(mode: AppMode) {
        val current = getMode()
        if (current == mode) return
        // Com o aparelho vinculado, o modo criança só termina pela desvinculação, que exige o responsável.
        if (current == AppMode.CHILD && g.agent.isActive()) {
            throw FlutterError("mode_locked", "Desvincule o aparelho antes de trocar o modo.", null)
        }
        if (current == AppMode.GUARDIAN) {
            runCatching { GuardianAlertWorker.cancel(g.context) }
            g.prefs.guardianServerUrl = ""
        }
        g.prefs.mode =
            when (mode) {
                AppMode.GUARDIAN -> AgentPrefs.MODE_GUARDIAN
                AppMode.CHILD -> AgentPrefs.MODE_CHILD
                AppMode.UNSET -> AgentPrefs.MODE_UNSET
            }
    }

    override fun consumeLaunchAction(): String? = consumeAction()
}

/** Armazenamento cifrado. As chaves do agente nativo ficam fora do alcance do Dart. */
class SecureStorageBridge(private val g: AgentGraph) : SecureStorageApi {
    private fun check(key: String) {
        BridgeValidation.storageKey(key)
        if (key.startsWith(SecureStore.AGENT_PREFIX)) {
            throw FlutterError("forbidden_key", "Chave reservada ao agente nativo.", null)
        }
    }

    override fun read(key: String): String? {
        check(key)
        return g.secureStore.get(key)
    }

    override fun write(key: String, value: String) {
        check(key)
        g.secureStore.put(key, value)
    }

    override fun delete(key: String) {
        check(key)
        g.secureStore.remove(key)
    }
}

/** Informações do aparelho, permissões especiais e atalhos para as telas do sistema. */
class DeviceBridge(private val g: AgentGraph, private val activity: Activity) : DeviceApi {
    private var pendingNotificationRequest: CompletableDeferred<Boolean>? = null

    override fun getDeviceInfo(): NativeDeviceInfo {
        val resolver = g.context.contentResolver
        val model = Build.MODEL.orEmpty()
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val name =
            runCatching { Settings.Global.getString(resolver, Settings.Global.DEVICE_NAME) }.getOrNull()?.takeIf { it.isNotBlank() }
                ?: "$manufacturer $model".trim()
        val androidId = runCatching { Settings.Secure.getString(resolver, Settings.Secure.ANDROID_ID) }.getOrNull().orEmpty()
        return NativeDeviceInfo(
            name = name,
            model = model,
            manufacturer = manufacturer,
            androidRelease = Build.VERSION.RELEASE.orEmpty(),
            sdkInt = Build.VERSION.SDK_INT.toLong(),
            appVersion = g.appVersion,
            timezone = ZoneId.systemDefault().id,
            // Identificador do aparelho para este app, sem expor o valor original.
            hardwareId = Hashing.sha256Hex("parentalynx:$androidId"),
        )
    }

    override fun getPermissions(): PermissionSnapshot {
        // O usuário pode ter acabado de voltar das Configurações: o motor confere já.
        g.engine.requestPermissionCheck()
        return g.permissions.current().toPigeon(g.permissions.restrictedSettingsLikely())
    }

    override fun openUsageAccessSettings() = g.settingsIntents.openUsageAccess()

    override fun openAccessibilitySettings() = g.settingsIntents.openAccessibility()

    override fun openOverlaySettings() = g.settingsIntents.openOverlay()

    override fun requestIgnoreBatteryOptimizations() = g.settingsIntents.requestIgnoreBatteryOptimizations()

    override fun openExactAlarmSettings() = g.settingsIntents.openExactAlarms()

    override fun openNotificationSettings() = g.settingsIntents.openNotifications()

    override fun openAppDetailsSettings() {
        g.settingsIntents.openAppDetails()
    }

    override fun openManufacturerAutostartSettings(): Boolean = g.settingsIntents.openManufacturerAutostart()

    override suspend fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return g.permissions.current().notifications
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return true
        val deferred = CompletableDeferred<Boolean>()
        pendingNotificationRequest?.complete(false)
        pendingNotificationRequest = deferred
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        return deferred.await()
    }

    /** Resultado do pedido de permissão, repassado pela atividade. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingNotificationRequest?.complete(granted)
        pendingNotificationRequest = null
        g.engine.requestPermissionCheck()
    }

    override fun requestDeviceAdmin() = g.settingsIntents.requestDeviceAdmin(activity)

    override fun removeDeviceAdmin() =
        guarded {
            g.childOps.requireAdminAuth()
            g.deviceOwner.removeActiveAdmin()
            g.engine.requestPermissionCheck()
        }

    override suspend fun releaseDeviceOwner(): Boolean =
        guarded {
            g.childOps.requireAdminAuth()
            val released = withContext(Dispatchers.IO) { g.deviceOwner.release() }
            g.engine.requestPermissionCheck()
            released
        }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 4101
    }
}

/** Agente de controle parental do modo criança. */
class ChildAgentBridge(private val g: AgentGraph) : ChildAgentApi {
    override fun activate(credentials: ChildCredentials, policyVersion: Long, policyJson: String) {
        try {
            g.agent.activate(
                serverUrl = credentials.serverUrl,
                deviceId = credentials.deviceId,
                deviceToken = credentials.deviceToken,
                offlineSecret = credentials.offlineSecret,
                childName = credentials.childName,
                guardianName = credentials.guardianName,
                policyVersion = policyVersion,
                policyJson = policyJson,
            )
        } catch (e: PolicyParseException) {
            throw FlutterError("policy_invalid", e.message ?: "Política inicial inválida.", null)
        }
    }

    override fun ensureRunning() {
        g.agent.ensureRunning("app_open")
        g.engine.requestPermissionCheck()
    }

    override fun getStatus(): AgentStatus {
        val snapshot = g.engine.snapshot
        val permissions = snapshot.permissions ?: g.permissions.current()
        val active = g.agent.isActive()
        return AgentStatus(
            active = active,
            childName = g.prefs.childName,
            guardianName = g.prefs.guardianName,
            managementMode = permissions.toManagementMode(),
            lockState =
                when (snapshot.lock.kind) {
                    LockKind.NONE -> LockState.NONE
                    LockKind.DAILY_LIMIT -> LockState.DAILY_LIMIT
                    LockKind.SCHEDULE -> LockState.SCHEDULE
                    LockKind.MANUAL_LOCK -> LockState.MANUAL_LOCK
                    LockKind.TAMPER_LOCK -> LockState.TAMPER_LOCK
                },
            releaseAtMs = snapshot.lock.releaseAtMs,
            activeScheduleLabel = snapshot.lock.label,
            limitEnabled = snapshot.limitEnabled,
            limitMs = snapshot.limitMs,
            extraMs = snapshot.extraMs,
            quotaUsedMs = snapshot.quotaUsedMs,
            totalUsedMs = snapshot.totalUsedMs,
            remainingMs = snapshot.remainingMs,
            day = snapshot.day,
            nextResetAtMs = snapshot.nextResetAtMs,
            policyVersion = g.policyStore.version,
            lastSyncAtMs = g.prefs.lastSyncAtMs.takeIf { it > 0L },
            lastSyncOk = g.prefs.lastSyncOk,
            lastSyncError = g.prefs.lastSyncError,
            suspensionUntilMs = snapshot.suspensionUntilMs,
            suspensionScopes = snapshot.suspensionScopes,
            localOverrideUntilMs = snapshot.localOverrideUntilMs,
            permissions = permissions.toPigeon(g.permissions.restrictedSettingsLikely()),
            issues = snapshot.issues,
            clockTrusted = g.clock.isTrusted,
            nowMs = g.clock.nowMs(),
            nextBlockAtMs = snapshot.nextBlockAtMs,
            nextBlockLabel = snapshot.nextBlockLabel,
            blockedAppsCount = snapshot.blockedAppsCount.toLong(),
            exceptionAppsCount = snapshot.exceptionAppsCount.toLong(),
            managedBrowserEnabled = active && snapshot.managedBrowserEnabled,
        )
    }

    override fun getPolicyJson(): String? = if (g.agent.isActive()) g.policyStore.json else null

    override fun getTodayUsage(): List<UsageEntry> {
        val day = g.engine.snapshot.day
        if (day.isEmpty()) return emptyList()
        return g.usageStore
            .entries(day)
            .filter { it.ms > 0L }
            .sortedByDescending { it.ms }
            .map { UsageEntry(packageName = it.appId, label = g.catalog.entry(it.appId).label, ms = it.ms, opens = it.opens.toLong()) }
    }

    override fun getExceptionApps(): List<NativeAppInfo> =
        g.engine.exceptionEntries().map {
            NativeAppInfo(packageName = it.appId, label = it.label, category = it.category, system = it.system, essential = it.essential)
        }

    override fun getAppIcon(packageName: String): ByteArray? =
        g.icons.pngFor(BridgeValidation.packageName(packageName))

    override suspend fun syncNow(): SyncOutcome {
        val result = withContext(Dispatchers.IO) { g.syncManager.syncBlocking("manual") }
        return SyncOutcome(ok = result.ok, atMs = result.atMs, errorCode = result.errorCode)
    }

    override fun submitTimeRequest(minutes: Long?, message: String?): String =
        g.childOps.submitTimeRequest(BridgeValidation.requestMinutes(minutes), message)

    override fun getTimeRequests(): List<TimeRequestInfo> =
        g.timeRequests.recent(MAX_TIME_REQUESTS).map {
            TimeRequestInfo(
                id = it.id,
                createdAtMs = it.createdAtMs,
                minutes = it.minutes?.toLong(),
                message = it.message,
                status = it.status,
                grantedMinutes = it.grantedMinutes?.toLong(),
                delivered = it.delivered,
            )
        }

    override suspend fun verifyAdminPassword(password: String): AdminAuthResult =
        withContext(Dispatchers.IO) { g.childOps.verifyAdminPassword(password) }.toPigeon()

    override fun verifyOfflineCode(code: String): AdminAuthResult = g.childOps.verifyOfflineCode(code).toPigeon()

    override fun isAdminAuthValid(): Boolean = g.adminAuth.isValid()

    override fun grantLocalOverride(minutes: Long) {
        val valid = BridgeValidation.overrideMinutes(minutes)
        guarded { g.childOps.grantLocalOverride(valid) }
    }

    override fun clearLocalOverride() = g.childOps.clearLocalOverride()

    override suspend fun unlink(password: String?): Boolean =
        guarded { withContext(Dispatchers.IO) { g.childOps.unlink(password) } }

    override fun openManagedBrowser(url: String?) = g.childOps.openManagedBrowser(url)

    override fun launchApp(packageName: String): Boolean =
        g.childOps.launchApp(BridgeValidation.packageName(packageName))

    private companion object {
        const val MAX_TIME_REQUESTS = 20
    }
}

/** Navegador gerenciado. */
class BrowserBridge(private val g: AgentGraph, private val consumeUrl: () -> String?) : BrowserApi {
    override fun getConfig(): BrowserConfig {
        val web = if (g.agent.isActive()) g.policyStore.runtime()?.policy?.web else null
        return BrowserConfig(
            enabled = web?.managedBrowser ?: false,
            logHistory = web?.logHistory ?: false,
            safeSearch = web?.safeSearch ?: false,
            allowlistMode = web?.allowlistMode ?: false,
        )
    }

    override suspend fun evaluateUrl(url: String): UrlDecision {
        val web = (if (g.agent.isActive()) g.policyStore.runtime()?.policy?.web else null) ?: return UrlDecision(allowed = true)
        // A consulta ao DNS filtrado usa a rede.
        val decision = withContext(Dispatchers.IO) { g.webFilter.evaluate(web, url) }
        return UrlDecision(
            allowed = decision.allowed,
            reason = decision.reason,
            category = decision.category,
            rewrittenUrl = decision.rewrittenUrl,
        )
    }

    override fun recordVisit(url: String, title: String?, blocked: Boolean, reason: String?) =
        g.childOps.recordVisit(url, title, blocked, reason)

    override fun consumeInitialUrl(): String? = consumeUrl()
}

/** Recursos nativos do modo responsável: busca de alertas em segundo plano. */
class GuardianBridge(private val g: AgentGraph) : GuardianNativeApi {
    override fun enableAlertPolling(serverUrl: String) {
        g.prefs.guardianServerUrl = serverUrl
        g.notifier.ensureChannels()
        GuardianAlertWorker.schedule(g.context)
    }

    override fun disableAlertPolling() {
        GuardianAlertWorker.cancel(g.context)
        g.prefs.guardianServerUrl = ""
    }

    override fun setLastSeenAlertId(id: Long) {
        g.prefs.guardianLastSeenAlertId = id
    }

    override fun getLastSeenAlertId(): Long = g.prefs.guardianLastSeenAlertId.coerceAtLeast(0L)
}

/** Registra todas as APIs da ponte em um motor Flutter. */
object Bridges {
    fun register(
        messenger: BinaryMessenger,
        graph: AgentGraph,
        activity: Activity,
        consumeAction: () -> String?,
        consumeUrl: () -> String?,
    ): DeviceBridge {
        val device = DeviceBridge(graph, activity)
        AppModeApi.setUp(messenger, AppModeBridge(graph, consumeAction))
        SecureStorageApi.setUp(messenger, SecureStorageBridge(graph))
        DeviceApi.setUp(messenger, device)
        ChildAgentApi.setUp(messenger, ChildAgentBridge(graph))
        BrowserApi.setUp(messenger, BrowserBridge(graph, consumeUrl))
        GuardianNativeApi.setUp(messenger, GuardianBridge(graph))
        return device
    }
}
