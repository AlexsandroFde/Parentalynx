package com.parentalynx.app.enforcement

import com.parentalynx.app.core.MonotonicClock
import kotlin.math.min

/** Onde o contador de tentativas do código offline fica gravado. */
interface AttemptStore {
    var failures: Int
    var lockedUntilMs: Long
}

/** Resultado de registrar uma tentativa errada. */
data class AttemptOutcome(val attemptsLeft: Int, val retryAfterSec: Long)

/**
 * Limite de tentativas do código de acesso offline: [FREE_ATTEMPTS] erros seguidos bloqueiam por 5
 * minutos, dobrando a cada novo erro até 60 minutos. Acerto zera o contador.
 *
 * O bloqueio usa a hora confiável e fica gravado, então reiniciar o aparelho, matar o app ou
 * mudar a data não devolve tentativas.
 */
class AttemptLimiter(private val store: AttemptStore) {
    /** Segundos até poder tentar de novo. Zero quando não está bloqueado. */
    fun lockedForSec(nowMs: Long): Long {
        val remaining = store.lockedUntilMs - nowMs
        return if (remaining > 0) (remaining + 999) / 1000 else 0L
    }

    fun attemptsLeft(): Int = (FREE_ATTEMPTS - store.failures).coerceAtLeast(0)

    fun registerFailure(nowMs: Long): AttemptOutcome {
        val failures = store.failures + 1
        store.failures = failures
        if (failures < FREE_ATTEMPTS) return AttemptOutcome(FREE_ATTEMPTS - failures, 0L)
        val doublings = min(failures - FREE_ATTEMPTS, MAX_DOUBLINGS)
        val lockMs = min(BASE_LOCK_MS shl doublings, MAX_LOCK_MS)
        store.lockedUntilMs = nowMs + lockMs
        return AttemptOutcome(0, lockMs / 1000)
    }

    fun registerSuccess() {
        store.failures = 0
        store.lockedUntilMs = 0L
    }

    companion object {
        const val FREE_ATTEMPTS = 5
        const val BASE_LOCK_MS = 5L * 60 * 1000
        const val MAX_LOCK_MS = 60L * 60 * 1000
        private const val MAX_DOUBLINGS = 10
    }
}

/**
 * Autenticação do responsável no aparelho da criança.
 *
 * Depois de uma senha conferida pelo servidor ou de um código offline válido, as operações
 * administrativas (liberar uso, desvincular, trocar de modo, remover administrador) ficam
 * liberadas por [VALID_MS]. A validade fica só em memória e usa o relógio monotônico: fechar o app
 * ou mudar a hora não a estende.
 */
class AdminAuth(private val mono: MonotonicClock) {
    @Volatile
    private var validUntilElapsedMs: Long = 0L

    fun markAuthenticated() {
        validUntilElapsedMs = mono.elapsedMs() + VALID_MS
    }

    fun isValid(): Boolean = mono.elapsedMs() < validUntilElapsedMs

    fun invalidate() {
        validUntilElapsedMs = 0L
    }

    companion object {
        const val VALID_MS = 5L * 60 * 1000
    }
}
