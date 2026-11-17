package com.parentalynx.app.usage

import org.json.JSONArray
import org.json.JSONObject

enum class UsageEventType {
    /** Atividade retomada (veio para o primeiro plano). */
    RESUMED,

    /** Atividade pausada (perdeu o primeiro plano). */
    PAUSED,

    /** Atividade parada. Tratada como [PAUSED]. */
    STOPPED,
    SCREEN_ON,
    SCREEN_OFF,

    /** Tela de bloqueio do sistema exibida: as atividades por baixo deixam de estar em uso. */
    KEYGUARD_SHOWN,
    SHUTDOWN,
    STARTUP,
}

/** Evento de uso, já com o carimbo na hora confiável. */
data class UsageEvent(
    val tsMs: Long,
    val type: UsageEventType,
    val pkg: String? = null,
    val cls: String? = null,
)

/** Destino do que o rastreador apura. */
interface UsageSink {
    /**
     * Os apps estiveram em primeiro plano, com a tela ligada, no intervalo [fromMs, toMs). Mais
     * de um app aparece em tela dividida: o tempo total do aparelho deve ser contado uma vez só.
     */
    fun onUsage(appIds: Set<String>, fromMs: Long, toMs: Long)

    /** O app voltou ao primeiro plano depois de pelo menos [UsageTracker.OPEN_GAP_MS] fora. */
    fun onOpen(appId: String, atMs: Long)

    /** Sessão encerrada (já unida a trocas de tela internas do app). */
    fun onSession(appId: String, startMs: Long, endMs: Long)
}

/** Traduz (pacote, classe da atividade) no identificador do app usado na política. */
fun interface AppIdResolver {
    fun resolve(pkg: String, cls: String?): String
}

/**
 * Máquina de estados da contagem de tempo. Pura: não lê relógio nem sistema.
 *
 * Mantém o conjunto de atividades retomadas e um cursor na hora confiável. O tempo entre o cursor
 * e cada novo evento é creditado aos apps retomados naquele intervalo, se a tela estava
 * interativa. Ver `docs/02-arquitetura.md`, seção 4.2.
 */
class UsageTracker(private val sink: UsageSink, private val resolver: AppIdResolver) {
    private class Pending(val startMs: Long, val endMs: Long)

    /** Atividades retomadas: chave "pacote|classe" para o identificador do app. */
    private val resumed = LinkedHashMap<String, String>()

    /** Sessões em andamento: app para o início. */
    private val open = HashMap<String, Long>()

    /** Sessões recém-fechadas, aguardando a janela de união. */
    private val pending = HashMap<String, Pending>()

    /** Última vez que cada app saiu do primeiro plano, para contar aberturas. */
    private val lastLeftAt = HashMap<String, Long>()

    var interactive: Boolean = true
        private set

    /** Instante até onde o uso já foi creditado. Zero enquanto não iniciado. */
    var cursorMs: Long = 0L
        private set

    val isStarted: Boolean
        get() = cursorMs > 0L

    /** Define o ponto de partida. Não tem efeito se o rastreador já foi iniciado. */
    fun start(atMs: Long, interactive: Boolean) {
        if (isStarted) return
        cursorMs = atMs
        this.interactive = interactive
    }

    /** Processa eventos em ordem de tempo. Carimbos anteriores ao cursor são trazidos para ele. */
    fun process(events: List<UsageEvent>) {
        for (event in events) process(event)
    }

    fun process(event: UsageEvent) {
        val ts = maxOf(event.tsMs, cursorMs)
        if (event.type == UsageEventType.STARTUP) {
            // O aparelho esteve desligado entre o cursor e este evento: fecha tudo no último
            // ponto conhecido e salta o cursor sem creditar o intervalo.
            closeAll()
            cursorMs = ts
            interactive = true
            return
        }
        moveCursor(ts)
        when (event.type) {
            UsageEventType.RESUMED -> {
                val pkg = event.pkg ?: return
                val key = keyOf(pkg, event.cls)
                if (key in resumed) return
                val appId = resolver.resolve(pkg, event.cls)
                val alreadyForeground = appId in resumed.values
                resumed[key] = appId
                if (!alreadyForeground) enter(appId, ts)
            }
            UsageEventType.PAUSED, UsageEventType.STOPPED -> {
                val pkg = event.pkg ?: return
                val appId = resumed.remove(keyOf(pkg, event.cls)) ?: return
                if (appId !in resumed.values) leave(appId, ts)
            }
            UsageEventType.SCREEN_ON -> interactive = true
            UsageEventType.SCREEN_OFF, UsageEventType.SHUTDOWN -> {
                leaveAll(ts)
                interactive = false
            }
            UsageEventType.KEYGUARD_SHOWN -> leaveAll(ts)
            UsageEventType.STARTUP -> Unit
        }
    }

    /** Credita o uso até [nowMs] e encerra as sessões cuja janela de união venceu. */
    fun advanceTo(nowMs: Long) {
        moveCursor(nowMs)
    }

    /** Ajusta o estado da tela com a informação ao vivo do sistema, no instante [atMs]. */
    fun setInteractive(value: Boolean, atMs: Long) {
        if (value == interactive) return
        val ts = maxOf(atMs, cursorMs)
        moveCursor(ts)
        if (!value) leaveAll(ts)
        interactive = value
    }

    /** Apps em primeiro plano agora. */
    fun foregroundApps(): Set<String> = LinkedHashSet(resumed.values)

    /** Início da sessão em andamento do app, ou nulo se não está em primeiro plano. */
    fun foregroundSince(appId: String): Long? = open[appId]

    /**
     * Fecha tudo no cursor e esvazia o conjunto. Usado quando se detecta que o aparelho reiniciou
     * ou que o estado guardado é antigo demais para ser confiável.
     */
    fun closeAll() {
        leaveAll(cursorMs)
        val ids = pending.keys.toList()
        for (id in ids) finalize(id, pending.remove(id) ?: continue)
    }

    /**
     * Desloca todos os instantes guardados. Usado quando a hora confiável é corrigida pelo
     * servidor, para que durações em andamento continuem certas.
     */
    fun shiftTime(deltaMs: Long) {
        if (deltaMs == 0L || !isStarted) return
        cursorMs += deltaMs
        for (key in open.keys.toList()) open[key] = (open[key] ?: continue) + deltaMs
        for (key in pending.keys.toList()) {
            val p = pending[key] ?: continue
            pending[key] = Pending(p.startMs + deltaMs, p.endMs + deltaMs)
        }
        for (key in lastLeftAt.keys.toList()) lastLeftAt[key] = (lastLeftAt[key] ?: continue) + deltaMs
    }

    private fun moveCursor(toMs: Long) {
        if (toMs <= cursorMs) return
        if (isStarted && interactive && resumed.isNotEmpty()) {
            sink.onUsage(LinkedHashSet(resumed.values), cursorMs, toMs)
        }
        cursorMs = toMs
        if (pending.isNotEmpty()) {
            val expired = pending.filter { toMs - it.value.endMs >= MERGE_GAP_MS }.keys.toList()
            for (appId in expired) finalize(appId, pending.remove(appId) ?: continue)
        }
    }

    private fun enter(appId: String, ts: Long) {
        val previous = pending.remove(appId)
        if (previous != null && ts - previous.endMs < MERGE_GAP_MS) {
            // Troca de tela dentro do mesmo app: a sessão continua.
            open[appId] = previous.startMs
            return
        }
        if (previous != null) finalize(appId, previous)
        open[appId] = ts
        val left = lastLeftAt[appId]
        if (left == null || ts - left >= OPEN_GAP_MS) sink.onOpen(appId, ts)
    }

    private fun leave(appId: String, ts: Long) {
        val start = open.remove(appId) ?: return
        pending[appId] = Pending(start, ts)
        lastLeftAt[appId] = ts
    }

    private fun leaveAll(ts: Long) {
        for (appId in LinkedHashSet(resumed.values)) leave(appId, ts)
        resumed.clear()
    }

    private fun finalize(appId: String, session: Pending) {
        if (session.endMs - session.startMs >= MIN_SESSION_MS) {
            sink.onSession(appId, session.startMs, session.endMs)
        }
    }

    private fun keyOf(pkg: String, cls: String?): String = "$pkg|${cls.orEmpty()}"

    /** Estado em JSON, gravado junto com os contadores de uso para permitir a retomada. */
    fun exportState(): String {
        val root = JSONObject()
        root.put("cursor", cursorMs)
        root.put("interactive", interactive)
        root.put("resumed", JSONObject().also { o -> resumed.forEach { (k, v) -> o.put(k, v) } })
        root.put("open", JSONObject().also { o -> open.forEach { (k, v) -> o.put(k, v) } })
        root.put(
            "pending",
            JSONObject().also { o ->
                pending.forEach { (k, v) -> o.put(k, JSONArray().put(v.startMs).put(v.endMs)) }
            },
        )
        // Guarda só as saídas recentes: as antigas já contam como abertura nova de qualquer modo.
        val recent = cursorMs - LEFT_RETENTION_MS
        root.put(
            "left",
            JSONObject().also { o -> lastLeftAt.filter { it.value >= recent }.forEach { (k, v) -> o.put(k, v) } },
        )
        return root.toString()
    }

    /** Restaura o estado exportado. Entrada inválida deixa o rastreador como novo. */
    fun importState(json: String?) {
        resumed.clear()
        open.clear()
        pending.clear()
        lastLeftAt.clear()
        cursorMs = 0L
        interactive = true
        if (json.isNullOrBlank()) return
        val root = runCatching { JSONObject(json) }.getOrNull() ?: return
        cursorMs = root.optLong("cursor", 0L)
        interactive = root.optBoolean("interactive", true)
        root.optJSONObject("resumed")?.let { o -> o.keys().forEach { k -> resumed[k] = o.optString(k) } }
        root.optJSONObject("open")?.let { o -> o.keys().forEach { k -> open[k] = o.optLong(k) } }
        root.optJSONObject("pending")?.let { o ->
            o.keys().forEach { k ->
                val pair = o.optJSONArray(k)
                if (pair != null && pair.length() == 2) pending[k] = Pending(pair.optLong(0), pair.optLong(1))
            }
        }
        root.optJSONObject("left")?.let { o -> o.keys().forEach { k -> lastLeftAt[k] = o.optLong(k) } }
        // Coerência: todo app retomado precisa ter sessão aberta, e vice-versa.
        val foreground = resumed.values.toSet()
        open.keys.retainAll(foreground)
        for (appId in foreground) if (appId !in open) open[appId] = cursorMs
    }

    companion object {
        /** Sessões do mesmo app separadas por menos que isto são unidas. */
        const val MERGE_GAP_MS = 1500L

        /** Tempo mínimo fora do primeiro plano para a volta contar como nova abertura. */
        const val OPEN_GAP_MS = 2000L

        /** Sessões mais curtas que isto não entram no registro (o tempo é contado mesmo assim). */
        const val MIN_SESSION_MS = 1000L
        private const val LEFT_RETENTION_MS = 60L * 60 * 1000
    }
}
