package com.parentalynx.app.sync

import com.parentalynx.app.core.AppLog
import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONException
import org.json.JSONObject

/** Resultado de uma chamada à API do ParentaLynx. */
sealed interface ApiResult {
    /** Sucesso. [body] é um objeto vazio em respostas sem corpo (204). */
    data class Ok(val body: JSONObject) : ApiResult

    /**
     * Falha.
     *
     * @property network verdadeiro quando não houve resposta HTTP (sem conexão, tempo esgotado).
     * @property status código HTTP, ou zero em falha de rede.
     * @property code código de erro do protocolo (`device_revoked`, `account_locked`, ...).
     * @property retryAfterSec segundos de espera informados em `details.retryAfterSec`.
     */
    data class Error(
        val network: Boolean,
        val status: Int = 0,
        val code: String? = null,
        val message: String? = null,
        val retryAfterSec: Long = 0L,
    ) : ApiResult {
        /** Código para registrar no estado de sincronização: o do protocolo ou `network`. */
        val wireCode: String
            get() = if (network) CODE_NETWORK else code ?: "http_$status"
    }

    companion object {
        const val CODE_NETWORK = "network"
        const val CODE_DEVICE_REVOKED = "device_revoked"
        const val CODE_INVALID_CREDENTIALS = "invalid_credentials"
        const val CODE_ACCOUNT_LOCKED = "account_locked"
        const val CODE_RATE_LIMITED = "rate_limited"
    }
}

/**
 * Cliente HTTP da API. Só fala JSON no formato de `docs/03-protocolo.md` e traduz as respostas de
 * erro. Nunca registra em log corpos, tokens ou senhas.
 */
class ApiClient(private val http: OkHttpClient) {
    fun postJson(baseUrl: String, path: String, token: String?, body: JSONObject): ApiResult =
        execute(baseUrl, path, emptyMap(), token) { post(body.toString().toRequestBody(JSON)) }

    fun putJson(baseUrl: String, path: String, token: String?, body: JSONObject): ApiResult =
        execute(baseUrl, path, emptyMap(), token) { put(body.toString().toRequestBody(JSON)) }

    fun putBytes(
        baseUrl: String,
        path: String,
        query: Map<String, String>,
        token: String?,
        contentType: String,
        bytes: ByteArray,
    ): ApiResult = execute(baseUrl, path, query, token) { put(bytes.toRequestBody(contentType.toMediaType())) }

    fun get(baseUrl: String, path: String, query: Map<String, String>, token: String?): ApiResult =
        execute(baseUrl, path, query, token) { get() }

    private fun execute(
        baseUrl: String,
        path: String,
        query: Map<String, String>,
        token: String?,
        method: Request.Builder.() -> Request.Builder,
    ): ApiResult {
        val url = buildUrl(baseUrl, path, query) ?: return ApiResult.Error(network = true, message = "endereço do servidor inválido")
        val builder = Request.Builder().url(url).header("Accept", "application/json").header("User-Agent", USER_AGENT)
        if (!token.isNullOrEmpty()) builder.header("Authorization", "Bearer $token")
        val request = builder.method().build()
        return try {
            http.newCall(request).execute().use { response ->
                val text = response.body?.string().orEmpty()
                if (response.isSuccessful) {
                    ApiResult.Ok(parseObject(text) ?: JSONObject())
                } else {
                    parseError(response.code, text)
                }
            }
        } catch (e: IOException) {
            AppLog.d(TAG, "falha de rede em $path: ${e.javaClass.simpleName}")
            ApiResult.Error(network = true, message = e.javaClass.simpleName)
        }
    }

    private fun parseError(status: Int, text: String): ApiResult.Error {
        val error = parseObject(text)?.optJSONObject("error")
        val details = error?.optJSONObject("details")
        return ApiResult.Error(
            network = false,
            status = status,
            code = error?.optString("code")?.takeIf { it.isNotEmpty() },
            message = error?.optString("message")?.takeIf { it.isNotEmpty() },
            retryAfterSec = details?.optLong("retryAfterSec", 0L) ?: 0L,
        )
    }

    private fun parseObject(text: String): JSONObject? {
        if (text.isBlank()) return null
        return try {
            JSONObject(text)
        } catch (e: JSONException) {
            null
        }
    }

    companion object {
        private const val TAG = "ApiClient"
        private const val USER_AGENT = "ParentaLynx-Android"
        private val JSON = "application/json; charset=utf-8".toMediaType()

        /** Cliente compartilhado pelo app: reaproveita conexões entre sincronização, ícones e DNS. */
        fun newHttpClient(): OkHttpClient =
            OkHttpClient
                .Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(20, TimeUnit.SECONDS)
                .writeTimeout(20, TimeUnit.SECONDS)
                .callTimeout(40, TimeUnit.SECONDS)
                .build()

        /** Junta a base do servidor (com ou sem barra final, com ou sem prefixo de caminho) e a rota. */
        fun buildUrl(baseUrl: String, path: String, query: Map<String, String>): HttpUrl? {
            val base = baseUrl.trim().trimEnd('/').toHttpUrlOrNull() ?: return null
            val builder = base.newBuilder()
            for (segment in path.trim('/').split('/')) {
                if (segment.isNotEmpty()) builder.addPathSegment(segment)
            }
            for ((name, value) in query) builder.addQueryParameter(name, value)
            return builder.build()
        }
    }
}
