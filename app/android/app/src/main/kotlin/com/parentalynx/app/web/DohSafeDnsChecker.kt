package com.parentalynx.app.web

import com.parentalynx.app.core.AppLog
import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONException
import org.json.JSONObject

/**
 * Consulta um resolvedor DNS familiar por DNS sobre HTTPS (formato JSON).
 *
 * O resolvedor padrão é o Cloudflare for Families, que responde com o endereço `0.0.0.0` para
 * domínios de conteúdo adulto e de malware. Só o nome do domínio é enviado ao resolvedor.
 *
 * Falha de rede ou resposta inesperada não bloqueia a página (a página também não carregaria sem
 * rede). O resultado fica em memória por alguns minutos para não repetir consultas.
 */
class DohSafeDnsChecker(
    baseClient: OkHttpClient,
    private val endpoint: String = DEFAULT_ENDPOINT,
    private val nowMs: () -> Long = System::currentTimeMillis,
) : SafeDnsChecker {
    private class Cached(val blocked: Boolean, val expiresAtMs: Long)

    private val client =
        baseClient
            .newBuilder()
            .callTimeout(TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .connectTimeout(TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .readTimeout(TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .build()
    private val lock = Any()
    private val cache =
        object : LinkedHashMap<String, Cached>(64, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Cached>?): Boolean = size > CACHE_SIZE
        }

    override fun isBlocked(host: String): Boolean {
        val now = nowMs()
        synchronized(lock) {
            cache[host]?.let { if (it.expiresAtMs > now) return it.blocked }
        }
        val blocked = query(host) ?: return false
        synchronized(lock) { cache[host] = Cached(blocked, now + CACHE_TTL_MS) }
        return blocked
    }

    /** Verdadeiro se bloqueado, falso se liberado, nulo se a consulta falhou. */
    private fun query(host: String): Boolean? {
        val url =
            try {
                endpoint.toHttpUrl().newBuilder().addQueryParameter("name", host).addQueryParameter("type", "A").build()
            } catch (e: IllegalArgumentException) {
                return null
            }
        val request = Request.Builder().url(url).header("Accept", "application/dns-json").build()
        return try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return null
                val body = response.body?.string() ?: return null
                parseBlocked(body)
            }
        } catch (e: IOException) {
            AppLog.d(TAG, "consulta ao DNS filtrado falhou")
            null
        }
    }

    companion object {
        const val DEFAULT_ENDPOINT = "https://family.cloudflare-dns.com/dns-query"

        /** Nome do mesmo resolvedor para DNS privado do sistema (DNS sobre TLS), no modo Device Owner. */
        const val PRIVATE_DNS_HOST = "family.cloudflare-dns.com"
        private const val TAG = "SafeDns"
        private const val TIMEOUT_MS = 2500L
        private const val CACHE_TTL_MS = 10L * 60 * 1000
        private const val CACHE_SIZE = 500

        /**
         * Interpreta a resposta JSON do resolvedor. Bloqueado quando há registro A apontando para
         * `0.0.0.0`. Devolve nulo se a resposta não puder ser lida.
         */
        fun parseBlocked(json: String): Boolean? {
            val root =
                try {
                    JSONObject(json)
                } catch (e: JSONException) {
                    return null
                }
            val answers = root.optJSONArray("Answer") ?: return false
            for (i in 0 until answers.length()) {
                val answer = answers.optJSONObject(i) ?: continue
                if (answer.optInt("type") == 1 && answer.optString("data") == "0.0.0.0") return true
            }
            return false
        }
    }
}
