package com.parentalynx.app

import android.content.Context
import android.provider.Settings
import com.parentalynx.app.apps.AppCatalog
import com.parentalynx.app.apps.IconEncoder
import com.parentalynx.app.core.MonotonicClock
import com.parentalynx.app.core.SecureStore
import com.parentalynx.app.core.SystemMonotonicClock
import com.parentalynx.app.core.SystemWallClock
import com.parentalynx.app.core.TrustedClock
import com.parentalynx.app.core.TrustedClockState
import com.parentalynx.app.core.TrustedClockStore
import com.parentalynx.app.core.WallClock
import com.parentalynx.app.data.AgentDatabase
import com.parentalynx.app.data.AgentPrefs
import com.parentalynx.app.data.KeyValueStore
import com.parentalynx.app.data.OutboxStore
import com.parentalynx.app.data.PolicyStore
import com.parentalynx.app.data.TimeRequestStore
import com.parentalynx.app.data.UsageStore
import com.parentalynx.app.enforcement.AdminAuth
import com.parentalynx.app.enforcement.AgentNotifier
import com.parentalynx.app.enforcement.AttemptLimiter
import com.parentalynx.app.enforcement.AttemptStore
import com.parentalynx.app.enforcement.BlockController
import com.parentalynx.app.enforcement.ChildOperations
import com.parentalynx.app.enforcement.DeviceOwnerController
import com.parentalynx.app.enforcement.EnforcementEngine
import com.parentalynx.app.enforcement.EventLog
import com.parentalynx.app.permissions.PermissionChecker
import com.parentalynx.app.permissions.SettingsIntents
import com.parentalynx.app.sync.ApiClient
import com.parentalynx.app.sync.RealtimeClient
import com.parentalynx.app.sync.SyncManager
import com.parentalynx.app.web.DohSafeDnsChecker
import com.parentalynx.app.web.WebFilter
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import okhttp3.OkHttpClient

/**
 * Composição do lado nativo: cria uma única instância de cada componente e entrega as
 * dependências por construtor. É o ponto de injeção de dependências do agente, usado por
 * serviços, receptores, workers e pela ponte com o Flutter.
 */
class AgentGraph private constructor(val context: Context) {
    val prefs = AgentPrefs(context)
    val secureStore = SecureStore(context)
    val database = AgentDatabase(context)
    val kv = KeyValueStore(database)

    val wall: WallClock = SystemWallClock
    val mono: MonotonicClock = SystemMonotonicClock

    /** Identidade do boot atual: muda a cada reinicialização do aparelho. */
    val bootId: Long = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, 0).toLong()
    val clock = TrustedClock(wall, mono, bootId, ClockPrefsStore(context))

    val appVersion: String =
        runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "0"

    val policyStore = PolicyStore(kv)
    val usageStore = UsageStore(database)
    val outbox = OutboxStore(database)
    val timeRequests = TimeRequestStore(database)
    val catalog = AppCatalog(context)
    val icons = IconEncoder(context)
    val permissions = PermissionChecker(context)
    val settingsIntents = SettingsIntents(context)
    val deviceOwner = DeviceOwnerController(context, kv)
    val blockController = BlockController(context)
    val notifier = AgentNotifier(context)
    val adminAuth = AdminAuth(mono)
    val offlineAttempts =
        AttemptLimiter(
            object : AttemptStore {
                override var failures: Int
                    get() = prefs.offlineCodeFailures
                    set(value) {
                        prefs.offlineCodeFailures = value
                    }
                override var lockedUntilMs: Long
                    get() = prefs.offlineCodeLockedUntilMs
                    set(value) {
                        prefs.offlineCodeLockedUntilMs = value
                    }
            },
        )
    val events = EventLog(outbox) { clock.nowMs() }

    val http: OkHttpClient = ApiClient.newHttpClient()
    val apiClient = ApiClient(http)
    val webFilter = WebFilter(DohSafeDnsChecker(http))

    /** Trabalho demorado fora da thread do motor e da principal (rede, políticas de dispositivo). */
    val background: Executor = Executors.newSingleThreadExecutor { r -> Thread(r, "plx-background") }

    // Componentes que dependem uns dos outros são criados sob demanda.
    val engine: EnforcementEngine by lazy { EnforcementEngine(this) }
    val syncManager: SyncManager by lazy { SyncManager(this) }
    val realtime: RealtimeClient by lazy { RealtimeClient(this, http) }
    val agent: AgentController by lazy { AgentController(this) }
    val childOps: ChildOperations by lazy { ChildOperations(this) }

    init {
        // Todo evento gravado agenda uma sincronização, agrupando os que chegam juntos.
        events.onRecorded = { type -> if (agent.isActive()) syncManager.requestSync("event:$type") }
    }

    /** Guarda a hora confiável fora do banco do agente, para sobreviver à desvinculação. */
    private class ClockPrefsStore(context: Context) : TrustedClockStore {
        private val prefs = context.getSharedPreferences("plx_clock", Context.MODE_PRIVATE)

        override fun load(): TrustedClockState? {
            if (!prefs.contains(KEY_BOOT)) return null
            return TrustedClockState(
                bootId = prefs.getLong(KEY_BOOT, 0L),
                anchorTrustedMs = prefs.getLong(KEY_ANCHOR_TRUSTED, 0L),
                anchorElapsedMs = prefs.getLong(KEY_ANCHOR_ELAPSED, 0L),
                serverAnchored = prefs.getBoolean(KEY_SERVER, false),
                lastKnownMs = prefs.getLong(KEY_LAST_KNOWN, 0L),
            )
        }

        override fun save(state: TrustedClockState) {
            prefs.edit()
                .putLong(KEY_BOOT, state.bootId)
                .putLong(KEY_ANCHOR_TRUSTED, state.anchorTrustedMs)
                .putLong(KEY_ANCHOR_ELAPSED, state.anchorElapsedMs)
                .putBoolean(KEY_SERVER, state.serverAnchored)
                .putLong(KEY_LAST_KNOWN, state.lastKnownMs)
                .apply()
        }

        private companion object {
            const val KEY_BOOT = "boot"
            const val KEY_ANCHOR_TRUSTED = "anchor_trusted"
            const val KEY_ANCHOR_ELAPSED = "anchor_elapsed"
            const val KEY_SERVER = "server"
            const val KEY_LAST_KNOWN = "last_known"
        }
    }

    companion object {
        @Volatile
        private var instance: AgentGraph? = null

        fun get(context: Context): AgentGraph =
            instance ?: synchronized(this) {
                instance ?: AgentGraph(context.applicationContext).also { instance = it }
            }
    }
}
