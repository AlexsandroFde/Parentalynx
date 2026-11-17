package com.parentalynx.app.sync

import com.parentalynx.app.AgentGraph
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.core.SecureStore
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONException
import org.json.JSONObject

/**
 * Canal de tempo real do aparelho (`GET /v1/device/stream`, WebSocket).
 *
 * Fica aberto enquanto a tela está ligada, com reconexão progressiva. O WebSocket é só um aviso
 * para sincronizar: o estado sempre vem das rotas HTTP, então perder uma mensagem não causa
 * inconsistência. Ver `docs/03-protocolo.md`, seção 7.
 */
class RealtimeClient(private val g: AgentGraph, baseClient: OkHttpClient) {
    private val client = baseClient.newBuilder().callTimeout(0, TimeUnit.MILLISECONDS).readTimeout(0, TimeUnit.MILLISECONDS).build()
    private val executor = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "plx-realtime") }
    private val lock = Any()
    private var wanted = false
    private var socket: WebSocket? = null
    private var connected = false
    private var backoffMs = MIN_BACKOFF_MS
    private var reconnect: ScheduledFuture<*>? = null
    private var ping: ScheduledFuture<*>? = null
    private var linger: ScheduledFuture<*>? = null

    val isConnected: Boolean
        get() = synchronized(lock) { connected }

    /** Liga ou desliga o canal. Ao desligar, espera um pouco antes de fechar (tela apagou há pouco). */
    fun setWanted(value: Boolean) {
        synchronized(lock) {
            if (value) {
                linger?.cancel(false)
                linger = null
                if (wanted) return
                wanted = true
                backoffMs = MIN_BACKOFF_MS
                executor.execute { connect() }
            } else {
                if (!wanted || linger != null) return
                linger = executor.schedule({ close() }, LINGER_MS, TimeUnit.MILLISECONDS)
            }
        }
    }

    /** Fecha agora (desvinculação). */
    fun shutdown() {
        executor.execute { close() }
    }

    private fun close() {
        synchronized(lock) {
            wanted = false
            linger = null
            reconnect?.cancel(false)
            reconnect = null
            ping?.cancel(false)
            ping = null
            socket?.close(NORMAL_CLOSURE, null)
            socket = null
            connected = false
        }
    }

    private fun connect() {
        synchronized(lock) {
            if (!wanted || socket != null) return
            val token = g.secureStore.get(SecureStore.KEY_DEVICE_TOKEN)
            val url = ApiClient.buildUrl(g.prefs.serverUrl, "/v1/device/stream", emptyMap())
            if (token.isNullOrEmpty() || url == null || !g.agent.isActive()) {
                wanted = false
                return
            }
            val request = Request.Builder().url(url).header("Authorization", "Bearer $token").build()
            socket = client.newWebSocket(request, Listener())
        }
    }

    private fun scheduleReconnect() {
        synchronized(lock) {
            socket = null
            connected = false
            ping?.cancel(false)
            ping = null
            if (!wanted) return
            reconnect?.cancel(false)
            reconnect = executor.schedule({ connect() }, backoffMs, TimeUnit.MILLISECONDS)
            backoffMs = (backoffMs * 2).coerceAtMost(MAX_BACKOFF_MS)
        }
    }

    private inner class Listener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            synchronized(lock) {
                if (socket !== webSocket) return
                connected = true
                backoffMs = MIN_BACKOFF_MS
                ping?.cancel(false)
                ping =
                    executor.scheduleWithFixedDelay(
                        { webSocket.send(PING_MESSAGE) },
                        PING_INTERVAL_MS,
                        PING_INTERVAL_MS,
                        TimeUnit.MILLISECONDS,
                    )
            }
            // Pode ter havido mudança enquanto o canal esteve fechado.
            g.syncManager.requestSync("stream_open", 0L)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            val type =
                try {
                    JSONObject(text).optString("type")
                } catch (e: JSONException) {
                    return
                }
            when (type) {
                "sync_now", "revoked" -> g.syncManager.requestSync("stream_$type", 0L)
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            // O servidor pediu para fechar: conclui o fechamento do nosso lado.
            webSocket.close(NORMAL_CLOSURE, null)
            if (code == CLOSE_UNAUTHORIZED) g.syncManager.requestSync("stream_unauthorized", 0L)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (isCurrent(webSocket)) scheduleReconnect()
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            AppLog.d(TAG, "canal de tempo real caiu: ${t.javaClass.simpleName}")
            if (response?.code == HTTP_UNAUTHORIZED) {
                // Token recusado: a sincronização HTTP diz se o vínculo foi revogado.
                g.syncManager.requestSync("stream_unauthorized", 0L)
            }
            if (isCurrent(webSocket)) scheduleReconnect()
        }

        private fun isCurrent(webSocket: WebSocket): Boolean = synchronized(lock) { socket === webSocket }
    }

    private companion object {
        const val TAG = "Realtime"
        const val PING_MESSAGE = "{\"type\":\"ping\"}"
        const val PING_INTERVAL_MS = 30_000L
        const val MIN_BACKOFF_MS = 2_000L
        const val MAX_BACKOFF_MS = 60_000L

        /** Tempo que o canal continua aberto depois que a tela apaga. */
        const val LINGER_MS = 30_000L
        const val NORMAL_CLOSURE = 1000

        /** Código de fechamento do protocolo para token inválido. */
        const val CLOSE_UNAUTHORIZED = 4401
        const val HTTP_UNAUTHORIZED = 401
    }
}
