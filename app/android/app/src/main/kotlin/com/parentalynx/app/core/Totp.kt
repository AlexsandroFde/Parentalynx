package com.parentalynx.app.core

import java.nio.ByteBuffer
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** Base32 da RFC 4648, sem preenchimento obrigatório. */
object Base32 {
    private const val ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    fun decode(text: String): ByteArray {
        val clean = text.trim().trimEnd('=').uppercase().filterNot { it == ' ' || it == '-' }
        val out = ArrayList<Byte>(clean.length * 5 / 8)
        var buffer = 0
        var bits = 0
        for (c in clean) {
            val value = ALPHABET.indexOf(c)
            require(value >= 0) { "caractere Base32 inválido" }
            buffer = (buffer shl 5) or value
            bits += 5
            if (bits >= 8) {
                bits -= 8
                out.add(((buffer shr bits) and 0xFF).toByte())
            }
        }
        return out.toByteArray()
    }

    fun encode(bytes: ByteArray): String {
        val sb = StringBuilder((bytes.size * 8 + 4) / 5)
        var buffer = 0
        var bits = 0
        for (b in bytes) {
            buffer = (buffer shl 8) or (b.toInt() and 0xFF)
            bits += 8
            while (bits >= 5) {
                bits -= 5
                sb.append(ALPHABET[(buffer shr bits) and 0x1F])
            }
        }
        if (bits > 0) {
            sb.append(ALPHABET[(buffer shl (5 - bits)) and 0x1F])
        }
        return sb.toString()
    }
}

/**
 * Código de acesso offline do responsável: TOTP da RFC 6238.
 *
 * Padrão do protocolo: HMAC-SHA256, 8 dígitos, passo de 60 segundos, janela de 2 passos para
 * cada lado. Os parâmetros são configuráveis para conferir com os vetores de teste da RFC.
 */
object Totp {
    const val DEFAULT_ALGORITHM = "HmacSHA256"
    const val DEFAULT_DIGITS = 8
    const val DEFAULT_STEP_SECONDS = 60L
    const val DEFAULT_WINDOW = 2

    fun generate(
        secret: ByteArray,
        timeMs: Long,
        stepSeconds: Long = DEFAULT_STEP_SECONDS,
        digits: Int = DEFAULT_DIGITS,
        algorithm: String = DEFAULT_ALGORITHM,
    ): String = generateForCounter(secret, counterAt(timeMs, stepSeconds), digits, algorithm)

    fun verify(
        secret: ByteArray,
        code: String,
        timeMs: Long,
        window: Int = DEFAULT_WINDOW,
        stepSeconds: Long = DEFAULT_STEP_SECONDS,
        digits: Int = DEFAULT_DIGITS,
        algorithm: String = DEFAULT_ALGORITHM,
    ): Boolean {
        val candidate = code.filter { it.isDigit() }
        if (candidate.length != digits) return false
        val counter = counterAt(timeMs, stepSeconds)
        var matched = false
        // Percorre a janela inteira mesmo depois de achar, para o tempo não depender da posição.
        for (offset in -window..window) {
            val expected = generateForCounter(secret, counter + offset, digits, algorithm)
            if (constantTimeEquals(expected, candidate)) matched = true
        }
        return matched
    }

    private fun counterAt(timeMs: Long, stepSeconds: Long): Long =
        Math.floorDiv(timeMs / 1000L, stepSeconds)

    private fun generateForCounter(
        secret: ByteArray,
        counter: Long,
        digits: Int,
        algorithm: String,
    ): String {
        val mac = Mac.getInstance(algorithm)
        mac.init(SecretKeySpec(secret, algorithm))
        val hash = mac.doFinal(ByteBuffer.allocate(8).putLong(counter).array())
        val offset = hash[hash.size - 1].toInt() and 0x0F
        val binary =
            ((hash[offset].toInt() and 0x7F) shl 24) or
                ((hash[offset + 1].toInt() and 0xFF) shl 16) or
                ((hash[offset + 2].toInt() and 0xFF) shl 8) or
                (hash[offset + 3].toInt() and 0xFF)
        var modulus = 1L
        repeat(digits) { modulus *= 10L }
        return (binary.toLong() % modulus).toString().padStart(digits, '0')
    }

    private fun constantTimeEquals(a: String, b: String): Boolean =
        MessageDigest.isEqual(a.toByteArray(Charsets.US_ASCII), b.toByteArray(Charsets.US_ASCII))
}
