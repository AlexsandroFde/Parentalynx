package com.parentalynx.app.data

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import com.parentalynx.app.core.putNullable
import com.parentalynx.app.policy.UsageView
import org.json.JSONArray
import org.json.JSONObject

class AppUsage(var ms: Long = 0L, var opens: Int = 0)

/**
 * Uso de um dia da cota. Escrito só pela thread do motor. Outras threads recebem cópias
 * imutáveis por [UsageStore.snapshotForSync] e [UsageStore.todayEntries].
 */
class DayUsage(val day: String) : UsageView {
    var quotaMs: Long = 0L
    var totalMs: Long = 0L
    var limitMs: Long? = null
    var extraMs: Long = 0L
    var limitReachedAt: Long? = null
    var firstUseAt: Long? = null
    var lastUseAt: Long? = null
    val hourly = LongArray(24)
    val apps = HashMap<String, AppUsage>()

    /** Avisos de pouco tempo já mostrados à criança (minutos). */
    val warned = HashSet<Int>()

    /** Evento `low_time` já enviado ao responsável. */
    var lowTimeSent = false

    /** Valor do limite para o qual o evento `limit_reached` já foi enviado. */
    var limitEventForMs: Long = -1L

    /** Apps cujo limite próprio já gerou `app_limit_reached` hoje. */
    val appLimitNotified = HashSet<String>()

    /** Revisão dos dados: muda a cada alteração. Dia pendente de envio quando difere de [syncedRev]. */
    var rev: Long = 0L
    var syncedRev: Long = -1L

    internal var rowDirty = false
    internal val dirtyApps = HashSet<String>()

    override val quotaUsedMs: Long
        get() = quotaMs

    override fun appUsedMs(appId: String): Long = apps[appId]?.ms ?: 0L

    internal fun touch() {
        rev++
        rowDirty = true
    }
}

/** Cópia imutável de um dia, no formato de `SyncRequest.days` do protocolo. */
class DaySnapshot(val day: String, val rev: Long, val json: JSONObject)

class UsageEntrySnapshot(val appId: String, val ms: Long, val opens: Int)

/** Destino dos créditos de uso. Separado da implementação para testar o gravador na JVM. */
interface UsageWriter {
    /**
     * Credita tempo de uso.
     *
     * @param appIds apps rastreados que estavam em primeiro plano no trecho.
     * @param consumesQuota verdadeiro se o trecho consome a cota diária.
     * @param hour hora local (0 a 23) do trecho.
     */
    fun addUsage(dayKey: String, appIds: Collection<String>, ms: Long, hour: Int, consumesQuota: Boolean, fromMs: Long, toMs: Long)

    fun addOpen(dayKey: String, appId: String)
}

/**
 * Contadores de uso por dia e por app.
 *
 * Mantém os dias recentes em memória e grava em disco por [flushInto], dentro da mesma transação
 * que salva o estado do rastreador. Assim, depois de uma falha, o reprocessamento a partir do
 * cursor gravado não conta nada em dobro nem perde tempo.
 */
class UsageStore(private val database: AgentDatabase) : UsageWriter {
    private val lock = Any()
    private val days = HashMap<String, DayUsage>()
    private var loaded = false

    /** Dia da cota em memória, criado se não existir. */
    fun day(dayKey: String): DayUsage =
        synchronized(lock) {
            ensureLoaded()
            days.getOrPut(dayKey) { DayUsage(dayKey).also { it.rowDirty = true } }
        }

    override fun addUsage(dayKey: String, appIds: Collection<String>, ms: Long, hour: Int, consumesQuota: Boolean, fromMs: Long, toMs: Long) {
        if (ms <= 0L || appIds.isEmpty()) return
        synchronized(lock) {
            val d = day(dayKey)
            for (appId in appIds) {
                d.apps.getOrPut(appId) { AppUsage() }.ms += ms
                d.dirtyApps.add(appId)
            }
            d.totalMs += ms
            if (consumesQuota) d.quotaMs += ms
            if (hour in 0..23) d.hourly[hour] += ms
            if (d.firstUseAt == null || fromMs < (d.firstUseAt ?: fromMs)) d.firstUseAt = fromMs
            if (toMs > (d.lastUseAt ?: 0L)) d.lastUseAt = toMs
            d.touch()
        }
    }

    override fun addOpen(dayKey: String, appId: String) {
        synchronized(lock) {
            val d = day(dayKey)
            d.apps.getOrPut(appId) { AppUsage() }.opens += 1
            d.dirtyApps.add(appId)
            d.touch()
        }
    }

    /** Atualiza o limite efetivo e o tempo extra informados nos relatórios. */
    fun setLimit(dayKey: String, limitMs: Long?, extraMs: Long) {
        synchronized(lock) {
            val d = day(dayKey)
            if (d.limitMs != limitMs || d.extraMs != extraMs) {
                d.limitMs = limitMs
                d.extraMs = extraMs
                d.touch()
            }
        }
    }

    /** Marca alteração em campos mudados diretamente pelo motor (avisos, limite atingido). */
    fun markChanged(dayKey: String) {
        synchronized(lock) { day(dayKey).touch() }
    }

    /**
     * Reconciliação com o servidor: adota o maior valor entre o local e o do servidor, para que o
     * aparelho nunca recupere tempo.
     *
     * @return verdadeiro se algum contador local aumentou.
     */
    fun reconcile(dayKey: String, serverQuotaMs: Long, serverTotalMs: Long): Boolean =
        synchronized(lock) {
            val d = day(dayKey)
            var changed = false
            if (serverQuotaMs > d.quotaMs) {
                d.quotaMs = serverQuotaMs
                changed = true
            }
            if (serverTotalMs > d.totalMs) {
                d.totalMs = serverTotalMs
                changed = true
            }
            if (changed) {
                // Não precisa reenviar por causa disso: o servidor já tem esses valores.
                val wasSynced = d.rev == d.syncedRev
                d.touch()
                if (wasSynced) d.syncedRev = d.rev
            }
            changed
        }

    /**
     * Dias a enviar: os anteriores com alteração pendente (mais antigos primeiro) e, por último,
     * o dia corrente.
     */
    fun snapshotForSync(currentDay: String, maxDays: Int): List<DaySnapshot> =
        synchronized(lock) {
            ensureLoaded()
            val pending =
                days.values
                    .filter { it.day != currentDay && it.day < currentDay && it.rev != it.syncedRev }
                    .sortedBy { it.day }
                    .take((maxDays - 1).coerceAtLeast(0))
            (pending + day(currentDay)).map { DaySnapshot(it.day, it.rev, toJson(it)) }
        }

    /** Confirma o envio de um dia, se ele não mudou desde a cópia. */
    fun markSynced(dayKey: String, rev: Long) {
        synchronized(lock) {
            val d = days[dayKey] ?: return
            if (d.syncedRev != rev) {
                d.syncedRev = rev
                d.rowDirty = true
            }
        }
    }

    fun entries(dayKey: String): List<UsageEntrySnapshot> =
        synchronized(lock) {
            ensureLoaded()
            days[dayKey]?.apps?.map { UsageEntrySnapshot(it.key, it.value.ms, it.value.opens) }.orEmpty()
        }

    /** Grava o que mudou, dentro de uma transação aberta por quem chama. */
    fun flushInto(db: SQLiteDatabase) {
        synchronized(lock) {
            for (d in days.values) {
                if (d.rowDirty) {
                    val values =
                        ContentValues().apply {
                            put("day", d.day)
                            put("quota_ms", d.quotaMs)
                            put("total_ms", d.totalMs)
                            if (d.limitMs == null) putNull("limit_ms") else put("limit_ms", d.limitMs)
                            put("extra_ms", d.extraMs)
                            if (d.limitReachedAt == null) putNull("limit_reached_at") else put("limit_reached_at", d.limitReachedAt)
                            if (d.firstUseAt == null) putNull("first_use_at") else put("first_use_at", d.firstUseAt)
                            if (d.lastUseAt == null) putNull("last_use_at") else put("last_use_at", d.lastUseAt)
                            put("hourly", d.hourly.joinToString(","))
                            put("flags", flagsToJson(d))
                            put("rev", d.rev)
                            put("synced_rev", d.syncedRev)
                        }
                    db.insertWithOnConflict("usage_day", null, values, SQLiteDatabase.CONFLICT_REPLACE)
                    d.rowDirty = false
                }
                if (d.dirtyApps.isNotEmpty()) {
                    for (appId in d.dirtyApps) {
                        val usage = d.apps[appId] ?: continue
                        val values =
                            ContentValues().apply {
                                put("day", d.day)
                                put("package", appId)
                                put("ms", usage.ms)
                                put("opens", usage.opens)
                            }
                        db.insertWithOnConflict("usage_app", null, values, SQLiteDatabase.CONFLICT_REPLACE)
                    }
                    d.dirtyApps.clear()
                }
            }
        }
    }

    /** Remove dias antigos: os já enviados com mais de [keepDays], os pendentes com mais de [maxDays]. */
    fun prune(todayKey: String, keepDays: Long, maxDays: Long) {
        val today = runCatching { java.time.LocalDate.parse(todayKey) }.getOrNull() ?: return
        val keepFrom = today.minusDays(keepDays).toString()
        val hardFrom = today.minusDays(maxDays).toString()
        synchronized(lock) {
            ensureLoaded()
            val remove =
                days.values
                    .filter { it.day < hardFrom || (it.day < keepFrom && it.rev == it.syncedRev) }
                    .map { it.day }
            if (remove.isEmpty()) return
            database.transaction { db ->
                for (day in remove) {
                    db.delete("usage_day", "day = ?", arrayOf(day))
                    db.delete("usage_app", "day = ?", arrayOf(day))
                    days.remove(day)
                }
            }
        }
    }

    /** Esquece o que está em memória (depois de apagar o banco na desvinculação). */
    fun reset() {
        synchronized(lock) {
            days.clear()
            loaded = false
        }
    }

    private fun ensureLoaded() {
        if (loaded) return
        loaded = true
        val db = database.readableDatabase
        db.rawQuery(
            "SELECT day, quota_ms, total_ms, limit_ms, extra_ms, limit_reached_at, first_use_at, " +
                "last_use_at, hourly, flags, rev, synced_rev FROM usage_day",
            null,
        ).use { c ->
            while (c.moveToNext()) {
                val d = DayUsage(c.getString(0))
                d.quotaMs = c.getLong(1)
                d.totalMs = c.getLong(2)
                d.limitMs = if (c.isNull(3)) null else c.getLong(3)
                d.extraMs = c.getLong(4)
                d.limitReachedAt = if (c.isNull(5)) null else c.getLong(5)
                d.firstUseAt = if (c.isNull(6)) null else c.getLong(6)
                d.lastUseAt = if (c.isNull(7)) null else c.getLong(7)
                c.getString(8).split(",").mapNotNull { it.toLongOrNull() }.take(24).forEachIndexed { i, v -> d.hourly[i] = v }
                flagsFromJson(d, c.getString(9))
                d.rev = c.getLong(10)
                d.syncedRev = c.getLong(11)
                days[d.day] = d
            }
        }
        db.rawQuery("SELECT day, package, ms, opens FROM usage_app", null).use { c ->
            while (c.moveToNext()) {
                val d = days[c.getString(0)] ?: continue
                d.apps[c.getString(1)] = AppUsage(c.getLong(2), c.getInt(3))
            }
        }
    }

    private fun flagsToJson(d: DayUsage): String =
        JSONObject()
            .put("warned", JSONArray(d.warned.toList()))
            .put("low", d.lowTimeSent)
            .put("limitFor", d.limitEventForMs)
            .put("appLimits", JSONArray(d.appLimitNotified.toList()))
            .toString()

    private fun flagsFromJson(d: DayUsage, json: String?) {
        val o = runCatching { JSONObject(json ?: "{}") }.getOrNull() ?: return
        o.optJSONArray("warned")?.let { a -> for (i in 0 until a.length()) d.warned.add(a.optInt(i)) }
        d.lowTimeSent = o.optBoolean("low", false)
        d.limitEventForMs = o.optLong("limitFor", -1L)
        o.optJSONArray("appLimits")?.let { a -> for (i in 0 until a.length()) d.appLimitNotified.add(a.optString(i)) }
    }

    private fun toJson(d: DayUsage): JSONObject {
        val apps = JSONArray()
        for ((appId, usage) in d.apps) {
            apps.put(JSONObject().put("package", appId).put("ms", usage.ms).put("opens", usage.opens))
        }
        val hourly = JSONArray()
        for (value in d.hourly) hourly.put(value)
        return JSONObject()
            .put("day", d.day)
            .put("quotaUsedMs", d.quotaMs)
            .put("totalUsedMs", d.totalMs)
            .putNullable("limitMs", d.limitMs)
            .put("extraMs", d.extraMs)
            .putNullable("limitReachedAt", d.limitReachedAt)
            .putNullable("firstUseAt", d.firstUseAt)
            .putNullable("lastUseAt", d.lastUseAt)
            .put("apps", apps)
            .put("hourly", hourly)
    }
}
