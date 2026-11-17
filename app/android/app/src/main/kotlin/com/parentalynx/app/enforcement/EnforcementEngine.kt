package com.parentalynx.app.enforcement

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.PowerManager
import androidx.core.content.ContextCompat
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.R
import com.parentalynx.app.apps.CatalogEntry
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.data.DayUsage
import com.parentalynx.app.data.KeyValueStore
import com.parentalynx.app.permissions.PermissionState
import com.parentalynx.app.policy.AppState
import com.parentalynx.app.policy.BlockReason
import com.parentalynx.app.policy.Decision
import com.parentalynx.app.policy.DeviceLock
import com.parentalynx.app.policy.EvalContext
import com.parentalynx.app.policy.LockKind
import com.parentalynx.app.policy.PolicyEngine
import com.parentalynx.app.policy.PolicyRuntime
import com.parentalynx.app.policy.QuotaCalendar
import com.parentalynx.app.policy.SuspensionScope
import com.parentalynx.app.service.AlarmReceiver
import com.parentalynx.app.usage.CursorFilter
import com.parentalynx.app.usage.SourceCursor
import com.parentalynx.app.usage.SystemUsageEventSource
import com.parentalynx.app.usage.UsageEvent
import com.parentalynx.app.usage.UsageEventType
import com.parentalynx.app.usage.UsageTracker
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.abs
import org.json.JSONObject

/** Retrato imutável do motor, lido por outras threads (ponte com o Flutter, sincronização). */
data class EngineSnapshot(
    val active: Boolean,
    val atMs: Long,
    val day: String,
    val lock: DeviceLock,
    val limitEnabled: Boolean,
    val limitMs: Long,
    val extraMs: Long,
    val quotaUsedMs: Long,
    val totalUsedMs: Long,
    /** Tempo restante da cota. -1 quando não há limite. */
    val remainingMs: Long,
    val nextResetAtMs: Long,
    val policyVersion: Long,
    val suspensionUntilMs: Long,
    val suspensionScopes: List<String>,
    val localOverrideUntilMs: Long,
    val permissions: PermissionState?,
    val issues: List<String>,
    val tampered: Boolean,
    val clockTrusted: Boolean,
    val foregroundApp: String?,
    val screenOn: Boolean,
    val nextBlockAtMs: Long?,
    val nextBlockLabel: String?,
    val blockedAppsCount: Int,
    val exceptionAppsCount: Int,
    val managedBrowserEnabled: Boolean,
) {
    companion object {
        val INACTIVE =
            EngineSnapshot(
                active = false, atMs = 0L, day = "", lock = DeviceLock(LockKind.NONE), limitEnabled = false,
                limitMs = 0L, extraMs = 0L, quotaUsedMs = 0L, totalUsedMs = 0L, remainingMs = -1L,
                nextResetAtMs = 0L, policyVersion = 0L, suspensionUntilMs = 0L, suspensionScopes = emptyList(),
                localOverrideUntilMs = 0L, permissions = null, issues = emptyList(), tampered = false,
                clockTrusted = false, foregroundApp = null, screenOn = false, nextBlockAtMs = null,
                nextBlockLabel = null, blockedAppsCount = 0, exceptionAppsCount = 0, managedBrowserEnabled = false,
            )
    }
}

/**
 * Motor do controle parental: conta o tempo, avalia a política, aciona o bloqueio e mantém o
 * estado geral do aparelho. Ver `docs/02-arquitetura.md`, seção 4.3.
 *
 * Tudo roda em uma única thread própria. Outras threads só entram por métodos que postam nessa
 * thread e leem o resultado em [snapshot].
 */
class EnforcementEngine(private val g: AgentGraph) : RecorderEnvironment {
    private class Hint(val appId: String, val atElapsedMs: Long)

    private class ServerTime(val serverMs: Long, val elapsedAtMs: Long)

    private val context: Context = g.context
    private val thread = HandlerThread("plx-engine").apply { start() }
    private val handler = Handler(thread.looper)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val source = SystemUsageEventSource(context)
    private val recorder = UsageRecorder(g.usageStore, g.outbox, this)
    private val tracker = UsageTracker(recorder) { pkg, cls -> g.catalog.appIdFor(pkg, cls) }

    @Volatile
    var snapshot: EngineSnapshot = EngineSnapshot.INACTIVE
        private set

    @Volatile
    private var running = false

    // Estado da thread do motor.
    private var cursor: SourceCursor? = null
    private var recordFrom = 0L
    private var lastPollWall = 0L
    private var lastPollElapsed = 0L
    private var lock = DeviceLock(LockKind.NONE)
    private var lockSince = 0L
    private var permissions: PermissionState? = null
    private var lastPermissionCheck = 0L
    private var lastCatalogRefresh = 0L
    private var permissionCheckRequested = true
    private var tampered = false
    private var localOverrideUntil = 0L
    private var currentDay: String? = null
    private var lastPersist = 0L
    private var lastClockPersist = 0L
    private var forcePersist = false
    private var suspensionDirty = true
    private var lastSuspensionSync = 0L
    private var suspendFailed = false
    private val unsuspendable = HashSet<String>()
    private var policyInvalid = false
    private var hint: Hint? = null
    private var accessibilityCurrent: Pair<String, String?>? = null
    private var pendingBootEvent = false
    private var pendingServerTime: ServerTime? = null
    private var lastPeriodicSync = 0L
    private var fgConsumesQuota = false
    private var fgAppLimitLeftMs = Long.MAX_VALUE
    private var alarmTarget = 0L
    private var receiversRegistered = false
    private var packagesChangePending = false
    private val lastBlockAt = HashMap<String, Long>()
    private val lastAttemptAt = HashMap<String, Long>()
    private val appLimitSince = HashMap<String, Long>()
    private val tickRunnable = Runnable { tick() }

    // RecorderEnvironment

    override fun runtime(): PolicyRuntime? = g.policyStore.runtime()

    override fun calendar(): QuotaCalendar = g.policyStore.runtime()?.calendar ?: QuotaCalendar(ZoneId.systemDefault(), 0)

    override fun localOverrideUntilMs(): Long = localOverrideUntil

    override fun recordFromMs(): Long = recordFrom

    override fun entry(appId: String): CatalogEntry = g.catalog.entry(appId)

    // Entradas vindas de outras threads

    /** Liga o motor se o aparelho está vinculado. Chamar mais de uma vez não tem efeito colateral. */
    fun start(reason: String) {
        handler.post { startOnThread(reason) }
    }

    /** Desliga o motor e, na thread dele, executa [then] (usado para apagar os dados na desvinculação). */
    fun stop(then: (() -> Unit)? = null) {
        handler.post {
            stopOnThread()
            then?.invoke()
        }
    }

    fun requestTick() {
        handler.post(tickRunnable)
    }

    /** Pede que as permissões sejam conferidas já no próximo passo (o usuário voltou das Configurações). */
    fun requestPermissionCheck() {
        handler.post {
            permissionCheckRequested = true
            tick()
        }
    }

    /** Troca de janela informada pelo serviço de acessibilidade. */
    fun onAccessibilityWindow(pkg: String?, cls: String?) {
        if (pkg.isNullOrEmpty()) return
        handler.post {
            if (!running || !g.catalog.isActivity(pkg, cls)) return@post
            hint = Hint(g.catalog.appIdFor(pkg, cls), g.mono.elapsedMs())
            if (permissions?.usageAccess != true) feedAccessibilityEvent(pkg, cls)
            tick()
        }
    }

    /** O serviço de acessibilidade conectou ou desconectou. */
    fun onAccessibilityChanged() {
        requestPermissionCheck()
    }

    fun onPolicyChanged() {
        handler.post {
            policyInvalid = false
            suspensionDirty = true
            applyPolicyEffects()
            tick()
        }
    }

    /** O servidor mandou uma política que este app não conseguiu ler. A anterior continua valendo. */
    fun onPolicyRejected() {
        handler.post {
            policyInvalid = true
            tick()
        }
    }

    /** Hora do servidor recebida em uma sincronização. */
    fun onServerTime(serverMs: Long, elapsedAtMs: Long) {
        handler.post {
            pendingServerTime = ServerTime(serverMs, elapsedAtMs)
            tick()
        }
    }

    /** Reconciliação: o servidor informou os maiores valores que já recebeu para o dia. */
    fun onReconcile(dayKey: String, quotaMs: Long, totalMs: Long) {
        handler.post {
            if (running && dayKey == currentDay && g.usageStore.reconcile(dayKey, quotaMs, totalMs)) {
                forcePersist = true
                tick()
            }
        }
    }

    fun setLocalOverride(untilMs: Long) {
        handler.post {
            localOverrideUntil = untilMs
            g.prefs.localOverrideUntilMs = untilMs
            suspensionDirty = true
            tick()
        }
    }

    /** Avalia um app agora e entrega a decisão na thread principal (usado pela tela de bloqueio). */
    fun evaluateAsync(appId: String, callback: (Decision) -> Unit) {
        handler.post {
            val decision =
                if (!running) {
                    Decision.Allowed
                } else {
                    val now = g.clock.nowMs()
                    val runtime = g.policyStore.runtime()
                    val today = g.usageStore.day(QuotaCalendar.dayKey(calendar().dayOf(now)))
                    PolicyEngine.evaluate(runtime, g.catalog.facts(appId), today, EvalContext(now, tampered, localOverrideUntil))
                }
            mainHandler.post { callback(decision) }
        }
    }

    /** Apps liberados como exceção que estão instalados e têm ícone, para a tela de bloqueio. */
    fun exceptionEntries(): List<CatalogEntry> {
        val runtime = g.policyStore.runtime() ?: return emptyList()
        val launchable = g.catalog.launchablePackages()
        return runtime.policy.apps.rules
            .filter { it.value.state == AppState.EXCEPTION }
            .keys
            .filter { it in launchable || it == com.parentalynx.app.apps.PackageClassifier.BROWSER_APP_ID }
            .map { g.catalog.entry(it) }
            .sortedBy { it.label.lowercase() }
    }

    // Ciclo de vida

    private fun startOnThread(reason: String) {
        if (!g.agent.isActive()) {
            stopOnThread()
            return
        }
        if (running) {
            tick()
            return
        }
        running = true
        runCatching { g.catalog.refresh() }.onFailure { AppLog.w(TAG, "falha ao ler o catálogo de apps", it) }
        lastCatalogRefresh = g.mono.elapsedMs()
        localOverrideUntil = g.prefs.localOverrideUntilMs
        restoreState()
        registerReceivers()
        g.events.record(EventLog.AGENT_STARTED, data = JSONObject().put("reason", reason))
        detectPackageChanges()
        applyPolicyEffects()
        tick()
    }

    private fun stopOnThread() {
        running = false
        handler.removeCallbacks(tickRunnable)
        unregisterReceivers()
        cancelAlarm()
        g.realtime.setWanted(false)
        g.notifier.cancelStatus()
        snapshot = EngineSnapshot.INACTIVE
        cursor = null
        currentDay = null
        permissions = null
        hint = null
        accessibilityCurrent = null
        lock = DeviceLock(LockKind.NONE)
        tracker.importState(null)
    }

    private fun restoreState() {
        val now = g.clock.nowMs()
        tracker.importState(g.kv.getString(KeyValueStore.TRACKER_STATE))
        val ts = g.kv.getLong(KeyValueStore.CURSOR_TS)
        cursor = if (ts != null) SourceCursor(ts, (g.kv.getLong(KeyValueStore.CURSOR_SEEN) ?: 0L).toInt()) else null
        recordFrom = g.kv.getLong(KeyValueStore.RECORD_FROM) ?: 0L
        val savedKind = g.kv.getString(KeyValueStore.LOCK_KIND)
        lock = DeviceLock(LockKind.entries.firstOrNull { it.wire == savedKind } ?: LockKind.NONE)
        lockSince = g.kv.getLong(KeyValueStore.LOCK_SINCE) ?: 0L
        permissions = g.kv.getString(KeyValueStore.PERMISSIONS)?.let(::parsePermissions)
        permissionCheckRequested = true

        val savedBoot = g.kv.getLong(KeyValueStore.BOOT_ID)
        val rebooted = savedBoot != null && savedBoot != g.bootId
        val heartbeat = g.kv.getLong(KeyValueStore.HEARTBEAT)
        if (tracker.isStarted && heartbeat != null && now - heartbeat > STALE_STATE_MS) {
            // Estado antigo demais: o registro do sistema pode não cobrir mais o intervalo.
            tracker.closeAll()
        }
        if (rebooted) {
            g.events.record(EventLog.DEVICE_BOOT)
            // O tempo com o aparelho desligado não pode ser creditado: marca o instante do boot.
            pendingBootEvent = true
            lastPollWall = 0L
            lastPollElapsed = 0L
        } else {
            lastPollWall = g.kv.getLong(KeyValueStore.POLL_WALL) ?: 0L
            lastPollElapsed = g.kv.getLong(KeyValueStore.POLL_ELAPSED) ?: 0L
        }
        if (savedBoot != g.bootId) g.kv.putLong(KeyValueStore.BOOT_ID, g.bootId)
        if (cursor == null) beginFirstRun(now)
    }

    /**
     * Primeira execução depois da vinculação: reprocessa o registro do sistema desde o início do
     * dia da cota corrente, para que limpar os dados do app e vincular de novo não zere o tempo
     * já usado. Começa algumas horas antes só para conhecer o que já estava em primeiro plano.
     */
    private fun beginFirstRun(now: Long) {
        val calendar = calendar()
        val dayStart = calendar.dayStartMs(calendar.dayOf(now))
        recordFrom = dayStart
        val warmStart = dayStart - WARMUP_MS
        tracker.importState(null)
        tracker.start(warmStart, interactive = true)
        cursor = SourceCursor(warmStart - g.clock.wallOffsetMs(), 0)
        g.kv.putLong(KeyValueStore.RECORD_FROM, recordFrom)
    }

    // Passo do motor

    private fun tick() {
        handler.removeCallbacks(tickRunnable)
        if (!running) return
        try {
            step()
        } catch (e: RuntimeException) {
            AppLog.e(TAG, "falha no passo do motor", e)
        }
        scheduleNext()
    }

    private fun step() {
        val elapsed = g.mono.elapsedMs()
        val wallNow = g.wall.nowMs()
        applyServerTime()
        detectWallClockJump(wallNow, elapsed)
        val now = g.clock.nowMs()
        val runtime = g.policyStore.runtime()
        val calendar = runtime?.calendar ?: calendar()

        if (permissionCheckRequested || permissions == null || elapsed - lastPermissionCheck >= PERMISSION_CHECK_MS) {
            checkPermissions(wallNow, elapsed)
        }
        val perms = permissions ?: return

        // 1 e 2: hora e eventos novos.
        val interactive = power.isInteractive
        if (perms.usageAccess) pollSystemEvents(wallNow)
        tracker.setInteractive(interactive, now)
        tracker.advanceTo(now)

        val day = calendar.dayOf(now)
        val dayKey = QuotaCalendar.dayKey(day)
        if (dayKey != currentDay) onDayChanged(dayKey, now)
        val today = g.usageStore.day(dayKey)
        val limit = runtime?.limitMs(day)
        g.usageStore.setLimit(dayKey, limit, runtime?.extraMs(day) ?: 0L)
        val ctx = EvalContext(now, tampered, localOverrideUntil)

        // 4: bloqueio geral (antes do passo 3, para saber desde quando ele vale).
        updateDeviceLock(runtime, today, ctx, dayKey, limit, now)
        // 3: apps em primeiro plano.
        val foreground = enforceForeground(runtime, today, ctx, now, elapsed)
        // 5: avisos de pouco tempo.
        updateWarnings(runtime, today, dayKey, limit, now)

        if (perms.deviceOwner) syncSuspension(runtime, today, ctx, elapsed)

        g.realtime.setWanted(interactive)
        if (interactive && elapsed - lastPeriodicSync >= PERIODIC_SYNC_MS) {
            lastPeriodicSync = elapsed
            g.syncManager.requestSync("periodic", 0L)
        }

        publish(runtime, today, perms, day, dayKey, limit, now, interactive, foreground)
        if (forcePersist || elapsed - lastPersist >= PERSIST_MS) persist(now, elapsed)
    }

    private fun applyServerTime() {
        val pending = pendingServerTime ?: return
        pendingServerTime = null
        val predicted = g.clock.fromElapsed(pending.elapsedAtMs)
        // Pequenas diferenças são só latência de rede: não vale reancorar a cada sincronização.
        if (g.clock.isTrusted && abs(pending.serverMs - predicted) < CLOCK_JUMP_MS) return
        val delta = g.clock.applyServerTime(pending.serverMs, pending.elapsedAtMs)
        if (delta == 0L) return
        tracker.shiftTime(delta)
        if (lockSince > 0L) lockSince += delta
        for (key in appLimitSince.keys.toList()) appLimitSince[key] = (appLimitSince[key] ?: continue) + delta
        if (recordFrom > 0L && abs(delta) >= CLOCK_ALERT_MS) {
            // Correção grande: o dia da cota pode ter mudado. O início de gravação acompanha.
            recordFrom += delta
            g.kv.putLong(KeyValueStore.RECORD_FROM, recordFrom)
        }
        forcePersist = true
    }

    /** Detecta mudança manual do relógio de parede e mantém o cursor do registro alinhado. */
    private fun detectWallClockJump(wallNow: Long, elapsed: Long) {
        if (lastPollElapsed in 1..elapsed) {
            val expected = lastPollWall + (elapsed - lastPollElapsed)
            val jump = wallNow - expected
            if (abs(jump) > CLOCK_JUMP_MS) {
                // O sistema desloca o registro inteiro junto com o relógio: o cursor acompanha.
                cursor = cursor?.shifted(jump)
                forcePersist = true
                if (abs(jump) >= CLOCK_ALERT_MS) {
                    g.events.record(
                        EventLog.CLOCK_CHANGED,
                        data = JSONObject().put("kind", "time").put("deltaMs", jump).put("timezone", ZoneId.systemDefault().id),
                    )
                }
            }
        }
        lastPollWall = wallNow
        lastPollElapsed = elapsed
    }

    private fun pollSystemEvents(wallNow: Long) {
        var current = cursor ?: return
        if (current.lastTsMs > wallNow + CLOCK_JUMP_MS) {
            // O relógio voltou enquanto o processo estava morto: recomeça de pouco antes de agora.
            current = SourceCursor(wallNow - RECOVERY_WINDOW_MS, 0)
        }
        val raw = source.read(current.lastTsMs, wallNow + 1)
        val (fresh, next) = CursorFilter.filterNew(raw, current)
        cursor = next
        if (fresh.isEmpty() && !pendingBootEvent) return
        val offset = g.clock.wallOffsetMs()
        val events = ArrayList<UsageEvent>(fresh.size + 1)
        for (event in fresh) events.add(UsageEvent(event.wallTsMs + offset, event.type, event.pkg, event.cls))
        if (pendingBootEvent) {
            pendingBootEvent = false
            events.add(UsageEvent(g.clock.fromElapsed(0L), UsageEventType.STARTUP))
            events.sortBy { it.tsMs }
        }
        tracker.process(events)
    }

    /** Sem "Acesso ao uso": sintetiza os eventos de troca de app a partir das trocas de janela. */
    private fun feedAccessibilityEvent(pkg: String, cls: String?) {
        val current = accessibilityCurrent
        if (current != null && current.first == pkg && current.second == cls) return
        val now = g.clock.nowMs()
        if (current != null) tracker.process(UsageEvent(now, UsageEventType.PAUSED, current.first, current.second))
        tracker.process(UsageEvent(now, UsageEventType.RESUMED, pkg, cls))
        accessibilityCurrent = pkg to cls
    }

    private fun checkPermissions(wallNow: Long, elapsed: Long) {
        permissionCheckRequested = false
        lastPermissionCheck = elapsed
        if (elapsed - lastCatalogRefresh >= CATALOG_REFRESH_MS) {
            // Launcher padrão, discador e teclados podem mudar sem instalar nem remover pacote.
            lastCatalogRefresh = elapsed
            runCatching { g.catalog.refresh() }
        }
        var current = g.permissions.current()
        if (!current.accessibility && g.permissions.tryRestoreAccessibility()) {
            current = g.permissions.current()
        }
        val previous = permissions
        if (previous != null && previous != current) {
            val before = previous.asMap()
            for ((name, granted) in current.asMap()) {
                if (before[name] != granted) {
                    g.events.record(
                        EventLog.PERMISSION_CHANGED,
                        data = JSONObject().put("permission", name).put("granted", granted),
                    )
                }
            }
            if (previous.managementMode != current.managementMode) {
                g.events.record(
                    EventLog.MANAGEMENT_MODE_CHANGED,
                    data = JSONObject().put("from", previous.managementMode).put("to", current.managementMode),
                )
                applyPolicyEffects()
            }
            if (previous.usageAccess != current.usageAccess) {
                // Troca de fonte de eventos: fecha as sessões para não deixar entradas órfãs.
                tracker.closeAll()
                accessibilityCurrent = null
                if (current.usageAccess) cursor = SourceCursor(wallNow, 0)
            }
            suspensionDirty = true
        }
        if (previous != current) g.kv.putString(KeyValueStore.PERMISSIONS, permissionsToJson(current))
        permissions = current

        val essentialsGranted = current.usageAccess && (current.accessibility || current.deviceOwner)
        if (essentialsGranted && !g.prefs.setupCompleted) g.prefs.setupCompleted = true
        tampered = g.prefs.setupCompleted && !essentialsGranted
    }

    private fun onDayChanged(dayKey: String, now: Long) {
        currentDay = dayKey
        appLimitSince.clear()
        lastAttemptAt.clear()
        suspensionDirty = true
        forcePersist = true
        g.usageStore.prune(dayKey, keepDays = KEEP_SYNCED_DAYS, maxDays = KEEP_PENDING_DAYS)
        g.timeRequests.prune(now - TIME_REQUEST_RETENTION_MS)
        g.outbox.trim(MAX_OUTBOX_ROWS)
    }

    private fun limitSuspended(runtime: PolicyRuntime?, now: Long): Boolean =
        localOverrideUntil > now || runtime?.suspended(SuspensionScope.DAILY_LIMIT, now) == true

    private fun updateDeviceLock(
        runtime: PolicyRuntime?,
        today: DayUsage,
        ctx: EvalContext,
        dayKey: String,
        limit: Long?,
        now: Long,
    ) {
        if (limit != null && today.quotaMs >= limit && !limitSuspended(runtime, now)) {
            if (today.limitReachedAt == null) {
                today.limitReachedAt = now
                g.usageStore.markChanged(dayKey)
            }
            if (today.limitEventForMs != limit) {
                today.limitEventForMs = limit
                g.usageStore.markChanged(dayKey)
                g.events.record(
                    EventLog.LIMIT_REACHED,
                    data = JSONObject().put("day", dayKey).put("limitMs", limit).put("quotaUsedMs", today.quotaMs),
                )
                g.notifier.notifyChild(
                    AgentNotifier.ID_CHILD_LIMIT,
                    context.getString(R.string.notify_limit_title),
                    context.getString(R.string.notify_limit_text),
                )
            }
        }
        val next = PolicyEngine.deviceLock(runtime, today, ctx)
        if (next.kind != lock.kind) {
            if (lock.kind != LockKind.NONE) {
                g.events.record(EventLog.LOCK_ENDED, data = JSONObject().put("reason", lock.kind.wire))
            }
            if (next.kind != LockKind.NONE) {
                lockSince = now
                g.events.record(
                    EventLog.LOCK_STARTED,
                    data =
                        JSONObject()
                            .put("reason", next.kind.wire)
                            .put("releaseAt", next.releaseAtMs ?: JSONObject.NULL),
                )
            }
            g.kv.putString(KeyValueStore.LOCK_KIND, next.kind.wire)
            g.kv.putLong(KeyValueStore.LOCK_SINCE, lockSince)
            suspensionDirty = true
            forcePersist = true
        }
        lock = next
    }

    /** Avalia cada app em primeiro plano e bloqueia os não autorizados. Devolve o app principal. */
    private fun enforceForeground(
        runtime: PolicyRuntime?,
        today: DayUsage,
        ctx: EvalContext,
        now: Long,
        elapsed: Long,
    ): String? {
        val foreground = LinkedHashSet(tracker.foregroundApps())
        hint?.let { if (elapsed - it.atElapsedMs <= HINT_FRESH_MS) foreground.add(it.appId) }
        var primary: String? = null
        var consumes = false
        var appLimitLeft = Long.MAX_VALUE
        for (appId in foreground) {
            val entry = g.catalog.entry(appId)
            if (primary == null && entry.tracked) primary = appId
            val facts = entry.toFacts()
            when (val decision = PolicyEngine.evaluate(runtime, facts, today, ctx)) {
                is Decision.Blocked -> blockApp(entry, decision, today, now, elapsed)
                is Decision.Allowed -> {
                    if (PolicyEngine.consumesQuota(runtime, facts, ctx)) consumes = true
                    val appLimit = runtime?.resolveRule(facts)?.dailyLimitMinutes
                    if (appLimit != null && !entry.essential) {
                        val left = appLimit * PolicyRuntime.MINUTE_MS - today.appUsedMs(appId)
                        if (left in 1 until appLimitLeft) appLimitLeft = left
                    }
                }
            }
        }
        fgConsumesQuota = consumes
        fgAppLimitLeftMs = appLimitLeft
        return primary ?: foreground.firstOrNull()
    }

    private fun blockApp(entry: CatalogEntry, decision: Decision.Blocked, today: DayUsage, now: Long, elapsed: Long) {
        val appId = entry.appId
        val last = lastBlockAt[appId]
        if (last != null && elapsed - last < BLOCK_RETRY_MS) return
        lastBlockAt[appId] = elapsed

        if (decision.reason == BlockReason.APP_LIMIT && today.appLimitNotified.add(appId)) {
            g.usageStore.markChanged(today.day)
            appLimitSince[appId] = now
            val limitMs = (runtime()?.resolveRule(entry.toFacts())?.dailyLimitMinutes ?: 0) * PolicyRuntime.MINUTE_MS
            g.events.record(EventLog.APP_LIMIT_REACHED, appId, JSONObject().put("limitMs", limitMs))
        }

        // É tentativa de abertura quando o app veio para a frente depois de o bloqueio já valer.
        // No instante em que o limite é atingido com o app aberto, não é tentativa.
        val foregroundSince = tracker.foregroundSince(appId) ?: now
        val isAttempt =
            when (decision.reason) {
                BlockReason.APP_BLOCKED, BlockReason.NEW_APP -> true
                BlockReason.APP_LIMIT -> foregroundSince > (appLimitSince[appId] ?: 0L) + ATTEMPT_GRACE_MS
                else -> foregroundSince > lockSince + ATTEMPT_GRACE_MS
            }
        if (isAttempt) {
            val lastEvent = lastAttemptAt[appId]
            if (lastEvent == null || elapsed - lastEvent >= ATTEMPT_EVENT_GAP_MS) {
                lastAttemptAt[appId] = elapsed
                g.events.record(EventLog.BLOCKED_ATTEMPT, appId, JSONObject().put("reason", decision.reason.wire))
            }
        }
        g.blockController.block(
            BlockRequest(
                appId = appId,
                pkg = entry.pkg,
                label = entry.label,
                reason = decision.reason,
                releaseAtMs = decision.releaseAtMs,
                scheduleLabel = decision.label,
            ),
        )
    }

    private fun updateWarnings(runtime: PolicyRuntime?, today: DayUsage, dayKey: String, limit: Long?, now: Long) {
        if (runtime == null || limit == null || limitSuspended(runtime, now)) return
        val remaining = limit - today.quotaMs
        var changed = false
        // Com mais tempo disponível (tempo extra), os avisos voltam a valer.
        if (today.warned.removeAll { remaining > it * PolicyRuntime.MINUTE_MS }) changed = true
        if (remaining > 0L && today.quotaMs > 0L) {
            val crossed =
                runtime.policy.dailyLimit.warnAtMinutes.filter {
                    remaining <= it * PolicyRuntime.MINUTE_MS && it !in today.warned
                }
            if (crossed.isNotEmpty()) {
                today.warned.addAll(crossed)
                changed = true
                g.notifier.notifyChild(
                    AgentNotifier.ID_CHILD_WARNING,
                    context.getString(R.string.notify_low_title),
                    context.getString(R.string.notify_low_text, TimeText.duration(remaining)),
                )
            }
        }
        val lowMs = g.prefs.lowTimeMinutes * PolicyRuntime.MINUTE_MS
        if (today.lowTimeSent && remaining > lowMs) {
            today.lowTimeSent = false
            changed = true
        }
        if (!today.lowTimeSent && remaining in 1..lowMs && today.quotaMs > 0L && limit > lowMs) {
            today.lowTimeSent = true
            changed = true
            g.events.record(
                EventLog.LOW_TIME,
                data = JSONObject().put("remainingMs", remaining).put("thresholdMinutes", g.prefs.lowTimeMinutes),
            )
        }
        if (changed) g.usageStore.markChanged(dayKey)
    }

    /** Modo Device Owner: mantém suspensos pelo sistema exatamente os apps que a política bloqueia agora. */
    private fun syncSuspension(runtime: PolicyRuntime?, today: DayUsage, ctx: EvalContext, elapsed: Long) {
        if (!suspensionDirty && elapsed - lastSuspensionSync < SUSPENSION_RESYNC_MS) return
        suspensionDirty = false
        lastSuspensionSync = elapsed
        val desired = HashSet<String>()
        if (runtime != null) {
            for (pkg in g.catalog.launchablePackages()) {
                if (pkg in unsuspendable) continue
                val entry = g.catalog.entry(pkg)
                if (entry.essential) continue
                if (PolicyEngine.evaluate(runtime, entry.toFacts(), today, ctx) is Decision.Blocked) desired.add(pkg)
            }
        }
        val failed = g.deviceOwner.syncSuspended(desired)
        unsuspendable.addAll(failed)
        // Pacotes de sistema que o Android não deixa suspender são esperados: ficam com a
        // interceptação. Falha em app instalado pelo usuário é que indica problema.
        val userAppFailed = failed.any { !g.catalog.entry(it).system }
        if (userAppFailed && !suspendFailed) {
            g.events.record(
                EventLog.ENFORCEMENT_ISSUE,
                data = JSONObject().put("issue", ISSUE_SUSPEND_FAILED).put("detail", failed.take(10).joinToString(",")),
            )
        }
        suspendFailed = userAppFailed
    }

    /** Aplica o que não depende do laço: proteções de Device Owner e DNS privado. */
    private fun applyPolicyEffects() {
        g.agent.updateBrowserEntry()
        val policy = g.policyStore.runtime()?.policy ?: return
        if (!g.deviceOwner.isDeviceOwner()) return
        // Fora da thread do motor: definir o DNS privado testa a rede e pode levar segundos.
        g.background.execute {
            val ok = g.deviceOwner.applyProtection(policy.protection, policy.web.safeDns)
            if (!ok) AppLog.w(TAG, "alguma proteção de dono do dispositivo não pôde ser aplicada")
        }
    }

    private fun publish(
        runtime: PolicyRuntime?,
        today: DayUsage,
        perms: PermissionState,
        day: LocalDate,
        dayKey: String,
        limit: Long?,
        now: Long,
        interactive: Boolean,
        foreground: String?,
    ) {
        val issues = ArrayList<String>()
        if (!perms.accessibility && !perms.deviceOwner) issues.add("accessibility_disabled")
        if (!perms.usageAccess) issues.add("usage_access_missing")
        if (!perms.overlay && !perms.accessibility && !perms.deviceOwner) issues.add("overlay_missing")
        if (!perms.notifications) issues.add("notifications_disabled")
        if (!perms.batteryOptimizationIgnored && !perms.deviceOwner) issues.add("battery_optimized")
        if (suspendFailed) issues.add(ISSUE_SUSPEND_FAILED)
        if (policyInvalid) issues.add("policy_invalid")
        if (!g.clock.isTrusted) issues.add("clock_untrusted")

        val calendar = runtime?.calendar ?: calendar()
        val suspension = runtime?.policy?.overrides?.suspension
        val suspensionActive = suspension != null && suspension.untilMs > now
        val schedulesOff = localOverrideUntil > now || runtime?.suspended(SuspensionScope.SCHEDULES, now) == true
        val nextBlock =
            if (lock.kind == LockKind.NONE && !schedulesOff) runtime?.schedules?.nextBlockStart(now, NEXT_BLOCK_HORIZON_MS) else null
        val rules = runtime?.policy?.apps?.rules?.values.orEmpty()

        snapshot =
            EngineSnapshot(
                active = true,
                atMs = now,
                day = dayKey,
                lock = lock,
                limitEnabled = limit != null,
                limitMs = limit ?: 0L,
                extraMs = runtime?.extraMs(day) ?: 0L,
                quotaUsedMs = today.quotaMs,
                totalUsedMs = today.totalMs,
                remainingMs = if (limit == null) -1L else (limit - today.quotaMs).coerceAtLeast(0L),
                nextResetAtMs = calendar.nextResetMs(now),
                policyVersion = g.policyStore.version,
                suspensionUntilMs = if (suspensionActive) suspension?.untilMs ?: 0L else 0L,
                suspensionScopes = if (suspensionActive) suspension?.scopes?.map { it.wire }.orEmpty() else emptyList(),
                localOverrideUntilMs = if (localOverrideUntil > now) localOverrideUntil else 0L,
                permissions = perms,
                issues = issues,
                tampered = tampered,
                clockTrusted = g.clock.isTrusted,
                foregroundApp = foreground,
                screenOn = interactive,
                nextBlockAtMs = nextBlock?.startMs,
                nextBlockLabel = nextBlock?.label,
                blockedAppsCount = rules.count { it.state == AppState.BLOCKED },
                exceptionAppsCount = rules.count { it.state == AppState.EXCEPTION },
                managedBrowserEnabled = runtime?.policy?.web?.managedBrowser ?: false,
            )
        g.notifier.updateStatus(statusText(limit, today, now, calendar.zone))
    }

    private fun statusText(limit: Long?, today: DayUsage, now: Long, zone: ZoneId): String {
        if (localOverrideUntil > now) {
            return context.getString(R.string.status_override, TimeText.clock(localOverrideUntil, zone))
        }
        val release = lock.releaseAtMs?.let { TimeText.release(it, now, zone) }
        return when (lock.kind) {
            LockKind.MANUAL_LOCK -> context.getString(R.string.status_manual_lock)
            LockKind.TAMPER_LOCK -> context.getString(R.string.status_tamper_lock)
            LockKind.SCHEDULE ->
                if (release != null) context.getString(R.string.status_schedule_until, release) else context.getString(R.string.status_schedule)
            LockKind.DAILY_LIMIT ->
                if (release != null) context.getString(R.string.status_limit_until, release) else context.getString(R.string.status_limit)
            LockKind.NONE ->
                if (limit == null) {
                    context.getString(R.string.status_no_limit)
                } else {
                    context.getString(R.string.status_remaining, TimeText.duration((limit - today.quotaMs).coerceAtLeast(0L)))
                }
        }
    }

    /** Grava contadores, estado do rastreador e cursor na mesma transação. */
    private fun persist(now: Long, elapsed: Long) {
        forcePersist = false
        lastPersist = elapsed
        val state = tracker.exportState()
        val current = cursor
        g.database.transaction { db ->
            g.usageStore.flushInto(db)
            g.kv.put(db, KeyValueStore.TRACKER_STATE, state)
            if (current != null) {
                g.kv.put(db, KeyValueStore.CURSOR_TS, current.lastTsMs.toString())
                g.kv.put(db, KeyValueStore.CURSOR_SEEN, current.seenAtLastTs.toString())
            }
            g.kv.put(db, KeyValueStore.HEARTBEAT, now.toString())
            g.kv.put(db, KeyValueStore.POLL_WALL, lastPollWall.toString())
            g.kv.put(db, KeyValueStore.POLL_ELAPSED, lastPollElapsed.toString())
        }
        if (elapsed - lastClockPersist >= CLOCK_PERSIST_MS) {
            lastClockPersist = elapsed
            g.clock.persist()
        }
    }

    /**
     * Agenda o próximo passo para o menor entre 1 s e o tempo até a próxima fronteira (fim da
     * cota, limite próprio de um app, início ou fim de período). É isso que faz o bloqueio
     * acontecer no instante exato do limite. Com a tela apagada o laço para e o alarme o acorda.
     */
    private fun scheduleNext() {
        if (!running) return
        val now = g.clock.nowMs()
        val runtime = g.policyStore.runtime()
        val boundary = PolicyEngine.nextTimeBoundaryMs(runtime, EvalContext(now, tampered, localOverrideUntil))
        scheduleAlarm(boundary, now)
        if (!power.isInteractive) return
        var delay = TICK_MS
        if (boundary != null) delay = minOf(delay, boundary - now)
        if (fgConsumesQuota && runtime != null && !limitSuspended(runtime, now)) {
            val day = runtime.calendar.dayOf(now)
            val limit = runtime.limitMs(day)
            if (limit != null) {
                val left = limit - g.usageStore.day(QuotaCalendar.dayKey(day)).quotaMs
                if (left > 0L) delay = minOf(delay, left)
            }
        }
        if (fgAppLimitLeftMs in 1 until delay) delay = fgAppLimitLeftMs
        handler.postDelayed(tickRunnable, delay.coerceIn(MIN_TICK_MS, TICK_MS))
    }

    private fun scheduleAlarm(boundaryMs: Long?, now: Long) {
        if (boundaryMs == null) {
            cancelAlarm()
            return
        }
        if (boundaryMs == alarmTarget) return
        alarmTarget = boundaryMs
        val triggerAt = g.mono.elapsedMs() + (boundaryMs - now).coerceAtLeast(MIN_ALARM_MS)
        val intent = AlarmReceiver.pendingIntent(context)
        try {
            if (g.permissions.canScheduleExactAlarms()) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, intent)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, intent)
            }
        } catch (e: SecurityException) {
            alarms.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, intent)
        }
    }

    private fun cancelAlarm() {
        if (alarmTarget == 0L) return
        alarmTarget = 0L
        alarms.cancel(AlarmReceiver.pendingIntent(context))
    }

    // Broadcasts do sistema

    private val systemReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (!running) return
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> onScreenChanged(true)
                    Intent.ACTION_SCREEN_OFF -> onScreenChanged(false)
                    Intent.ACTION_TIME_CHANGED -> tick()
                    Intent.ACTION_TIMEZONE_CHANGED -> {
                        g.events.record(
                            EventLog.CLOCK_CHANGED,
                            data = JSONObject().put("kind", "timezone").put("deltaMs", 0).put("timezone", ZoneId.systemDefault().id),
                        )
                        tick()
                    }
                    Intent.ACTION_SHUTDOWN -> {
                        g.events.record(EventLog.DEVICE_SHUTDOWN)
                        tracker.advanceTo(g.clock.nowMs())
                        persist(g.clock.nowMs(), g.mono.elapsedMs())
                        g.clock.persist()
                    }
                    Intent.ACTION_PACKAGE_ADDED, Intent.ACTION_PACKAGE_REMOVED, Intent.ACTION_PACKAGE_CHANGED -> onPackagesChanged()
                }
            }
        }

    private val networkCallback =
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (running) g.syncManager.requestSync("network", NETWORK_SYNC_DELAY_MS)
            }
        }

    private fun registerReceivers() {
        if (receiversRegistered) return
        receiversRegistered = true
        val filter =
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_TIME_CHANGED)
                addAction(Intent.ACTION_TIMEZONE_CHANGED)
                addAction(Intent.ACTION_SHUTDOWN)
            }
        ContextCompat.registerReceiver(context, systemReceiver, filter, null, handler, ContextCompat.RECEIVER_NOT_EXPORTED)
        val packages =
            IntentFilter().apply {
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addAction(Intent.ACTION_PACKAGE_REMOVED)
                addAction(Intent.ACTION_PACKAGE_CHANGED)
                addDataScheme("package")
            }
        ContextCompat.registerReceiver(context, systemReceiver, packages, null, handler, ContextCompat.RECEIVER_NOT_EXPORTED)
        runCatching { connectivity.registerDefaultNetworkCallback(networkCallback, handler) }
    }

    private fun unregisterReceivers() {
        if (!receiversRegistered) return
        receiversRegistered = false
        runCatching { context.unregisterReceiver(systemReceiver) }
        runCatching { connectivity.unregisterNetworkCallback(networkCallback) }
    }

    private fun onScreenChanged(on: Boolean) {
        if (permissions?.usageAccess != true) {
            tracker.process(UsageEvent(g.clock.nowMs(), if (on) UsageEventType.SCREEN_ON else UsageEventType.SCREEN_OFF))
            if (!on) accessibilityCurrent = null
        }
        if (!on) forcePersist = true
        tick()
    }

    private fun onPackagesChanged() {
        if (packagesChangePending) return
        packagesChangePending = true
        // Instalações disparam vários avisos seguidos: espera assentar.
        handler.postDelayed({
            packagesChangePending = false
            if (!running) return@postDelayed
            runCatching { g.catalog.refresh() }
            unsuspendable.clear()
            suspensionDirty = true
            detectPackageChanges()
            g.prefs.inventoryDirty = true
            g.syncManager.requestSync("packages", PACKAGE_SYNC_DELAY_MS)
            tick()
        }, PACKAGE_SETTLE_MS)
    }

    /** Compara o inventário com o último conhecido e registra instalações e remoções. */
    private fun detectPackageChanges() {
        val current = HashMap<String, CatalogEntry>()
        try {
            for (item in g.catalog.inventory()) current[item.entry.appId] = item.entry
        } catch (e: RuntimeException) {
            AppLog.w(TAG, "falha ao ler o inventário", e)
            return
        }
        val knownJson = g.kv.getString(KeyValueStore.KNOWN_PACKAGES)
        val known = knownJson?.let { runCatching { JSONObject(it) }.getOrNull() }
        if (known != null) {
            for ((appId, entry) in current) {
                if (!known.has(appId) && !entry.system) {
                    g.events.record(EventLog.APP_INSTALLED, appId, JSONObject().put("label", entry.label))
                }
            }
            for (appId in known.keys()) {
                if (appId !in current) {
                    g.events.record(EventLog.APP_REMOVED, appId, JSONObject().put("label", known.optString(appId, appId)))
                }
            }
        }
        val next = JSONObject()
        for ((appId, entry) in current) next.put(appId, entry.label)
        val nextJson = next.toString()
        if (nextJson != knownJson) {
            g.kv.putString(KeyValueStore.KNOWN_PACKAGES, nextJson)
            g.prefs.inventoryDirty = true
        }
    }

    private fun permissionsToJson(state: PermissionState): String {
        val json = JSONObject()
        for ((name, granted) in state.asMap()) json.put(name, granted)
        json.put("deviceOwner", state.deviceOwner)
        return json.toString()
    }

    private fun parsePermissions(json: String): PermissionState? {
        val o = runCatching { JSONObject(json) }.getOrNull() ?: return null
        return PermissionState(
            usageAccess = o.optBoolean("usageAccess"),
            accessibility = o.optBoolean("accessibility"),
            overlay = o.optBoolean("overlay"),
            notifications = o.optBoolean("notifications"),
            batteryOptimizationIgnored = o.optBoolean("batteryOptimizationIgnored"),
            deviceAdmin = o.optBoolean("deviceAdmin"),
            deviceOwner = o.optBoolean("deviceOwner"),
            exactAlarms = o.optBoolean("exactAlarms"),
        )
    }

    private companion object {
        const val TAG = "Engine"
        const val ISSUE_SUSPEND_FAILED = "suspend_failed"

        /** Intervalo do laço com a tela ligada. */
        const val TICK_MS = 1000L
        const val MIN_TICK_MS = 50L
        const val MIN_ALARM_MS = 1000L
        const val PERSIST_MS = 5_000L
        const val CLOCK_PERSIST_MS = 60_000L
        const val PERMISSION_CHECK_MS = 15_000L
        const val CATALOG_REFRESH_MS = 10L * 60 * 1000
        const val PERIODIC_SYNC_MS = 2L * 60 * 1000
        const val SUSPENSION_RESYNC_MS = 30_000L
        const val NETWORK_SYNC_DELAY_MS = 3_000L
        const val PACKAGE_SETTLE_MS = 2_000L
        const val PACKAGE_SYNC_DELAY_MS = 5_000L

        /** Diferença do relógio de parede acima da qual o sistema desloca o registro de uso. */
        const val CLOCK_JUMP_MS = 2_000L

        /** Mudança de relógio que vale um evento para o responsável. */
        const val CLOCK_ALERT_MS = 60_000L
        const val RECOVERY_WINDOW_MS = 60_000L

        /** Quanto antes do início do dia o reprocessamento da ativação começa. */
        const val WARMUP_MS = 6L * 60 * 60 * 1000

        /** Estado gravado mais antigo que isto não é retomado: o registro do sistema guarda poucos dias. */
        const val STALE_STATE_MS = 3L * 24 * 60 * 60 * 1000

        /** Validade do pacote informado pela acessibilidade antes de o evento de uso chegar. */
        const val HINT_FRESH_MS = 3_000L

        /** Intervalo mínimo entre duas ações de bloqueio sobre o mesmo app. */
        const val BLOCK_RETRY_MS = 1_500L
        const val ATTEMPT_GRACE_MS = 1_000L

        /** No máximo um evento de tentativa por app a cada meio minuto. */
        const val ATTEMPT_EVENT_GAP_MS = 30_000L
        const val NEXT_BLOCK_HORIZON_MS = 24L * 60 * 60 * 1000
        const val KEEP_SYNCED_DAYS = 10L
        const val KEEP_PENDING_DAYS = 35L
        const val TIME_REQUEST_RETENTION_MS = 7L * 24 * 60 * 60 * 1000
        const val MAX_OUTBOX_ROWS = 20_000
    }
}
