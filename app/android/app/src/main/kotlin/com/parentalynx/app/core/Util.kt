package com.parentalynx.app.core

import android.util.Log
import java.security.MessageDigest
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

/** Registro de diagnóstico. Nunca recebe senhas, tokens, endereços visitados ou códigos. */
object AppLog {
    private const val PREFIX = "PLX/"

    fun d(tag: String, message: String) {
        Log.d(PREFIX + tag, message)
    }

    fun i(tag: String, message: String) {
        Log.i(PREFIX + tag, message)
    }

    fun w(tag: String, message: String, error: Throwable? = null) {
        if (error == null) Log.w(PREFIX + tag, message) else Log.w(PREFIX + tag, message, error)
    }

    fun e(tag: String, message: String, error: Throwable? = null) {
        if (error == null) Log.e(PREFIX + tag, message) else Log.e(PREFIX + tag, message, error)
    }
}

object Ids {
    fun newId(): String = UUID.randomUUID().toString()
}

object Hashing {
    fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    fun sha256Hex(text: String): String = sha256Hex(text.toByteArray(Charsets.UTF_8))
}

// Leitura tolerante de JSON: campo ausente, nulo ou de tipo errado vira nulo ou o padrão.

fun JSONObject.stringOrNull(key: String): String? {
    if (!has(key) || isNull(key)) return null
    return opt(key) as? String
}

fun JSONObject.longOrNull(key: String): Long? {
    if (!has(key) || isNull(key)) return null
    return (opt(key) as? Number)?.toLong()
}

fun JSONObject.intOrNull(key: String): Int? = longOrNull(key)?.toInt()

fun JSONObject.booleanOr(key: String, default: Boolean): Boolean {
    if (!has(key) || isNull(key)) return default
    return opt(key) as? Boolean ?: default
}

fun JSONObject.objectOrNull(key: String): JSONObject? = optJSONObject(key)

fun JSONObject.arrayOrEmpty(key: String): JSONArray = optJSONArray(key) ?: JSONArray()

fun JSONArray.objects(): List<JSONObject> = (0 until length()).mapNotNull { optJSONObject(it) }

fun JSONArray.strings(): List<String> = (0 until length()).mapNotNull { opt(it) as? String }

fun JSONArray.ints(): List<Int> = (0 until length()).mapNotNull { (opt(it) as? Number)?.toInt() }

fun JSONArray.longs(): List<Long> = (0 until length()).mapNotNull { (opt(it) as? Number)?.toLong() }

/** Grava nulo explícito quando o valor é nulo (o `put` do org.json removeria a chave). */
fun JSONObject.putNullable(key: String, value: Any?): JSONObject = put(key, value ?: JSONObject.NULL)
