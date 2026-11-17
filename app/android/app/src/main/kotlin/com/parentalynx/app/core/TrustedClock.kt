package com.parentalynx.app.core

import kotlin.math.max

/**
 * Estado persistido da hora confiável.
 *
 * @property bootId identidade do boot em que a âncora foi criada.
 * @property anchorTrustedMs hora confiável no instante da âncora.
 * @property anchorElapsedMs relógio monotônico no instante da âncora.
 * @property serverAnchored verdadeiro quando a âncora veio do servidor neste boot.
 * @property lastKnownMs maior hora confiável já gravada. A hora nunca retrocede abaixo dela.
 */
data class TrustedClockState(
    val bootId: Long,
    val anchorTrustedMs: Long,
    val anchorElapsedMs: Long,
    val serverAnchored: Boolean,
    val lastKnownMs: Long,
)

interface TrustedClockStore {
    fun load(): TrustedClockState?

    fun save(state: TrustedClockState)
}

/**
 * Hora que a criança não consegue manipular mudando a data do aparelho.
 *
 * Dentro de um mesmo boot a hora avança só pelo relógio monotônico, a partir de uma âncora. A
 * âncora vem do servidor (confiável) ou, enquanto não houve sincronização neste boot, do relógio
 * de parede lido uma única vez na inicialização e limitado para nunca retroceder.
 */
class TrustedClock(
    private val wall: WallClock,
    private val mono: MonotonicClock,
    private val bootId: Long,
    private val store: TrustedClockStore,
) {
    @Volatile
    private var state: TrustedClockState

    init {
        val saved = store.load()
        val elapsed = mono.elapsedMs()
        state =
            if (saved != null && saved.bootId == bootId && elapsed >= saved.anchorElapsedMs) {
                saved
            } else {
                val floor = saved?.lastKnownMs ?: 0L
                val now = max(wall.nowMs(), floor)
                TrustedClockState(
                    bootId = bootId,
                    anchorTrustedMs = now,
                    anchorElapsedMs = elapsed,
                    serverAnchored = false,
                    lastKnownMs = now,
                )
            }
        store.save(state)
    }

    /** Hora confiável atual, em milissegundos desde a época Unix. */
    fun nowMs(): Long {
        val s = state
        return s.anchorTrustedMs + (mono.elapsedMs() - s.anchorElapsedMs)
    }

    /** Verdadeiro quando a âncora deste boot veio do servidor. */
    val isTrusted: Boolean
        get() = state.serverAnchored

    /** Diferença a somar em um carimbo do relógio de parede para obter a hora confiável. */
    fun wallOffsetMs(): Long = nowMs() - wall.nowMs()

    /** Converte um instante do relógio monotônico deste boot em hora confiável. */
    fun fromElapsed(elapsedMs: Long): Long {
        val s = state
        return s.anchorTrustedMs + (elapsedMs - s.anchorElapsedMs)
    }

    /**
     * Adota a hora do servidor.
     *
     * @param serverMs hora informada pelo servidor.
     * @param elapsedAtMs relógio monotônico estimado no instante em que o servidor leu a hora
     *   (ponto médio entre o envio e a chegada da resposta).
     * @return quanto a hora confiável mudou (nova menos antiga). Quem mantém cursores na hora
     *   confiável precisa deslocá-los por esse valor.
     */
    @Synchronized
    fun applyServerTime(serverMs: Long, elapsedAtMs: Long): Long {
        val before = nowMs()
        val next =
            state.copy(
                anchorTrustedMs = serverMs,
                anchorElapsedMs = elapsedAtMs,
                serverAnchored = true,
            )
        state = next.copy(lastKnownMs = max(state.lastKnownMs, nowOf(next)))
        store.save(state)
        return nowMs() - before
    }

    /** Grava a maior hora conhecida, para valer como piso depois de reiniciar. */
    @Synchronized
    fun persist() {
        state = state.copy(lastKnownMs = max(state.lastKnownMs, nowMs()))
        store.save(state)
    }

    private fun nowOf(s: TrustedClockState): Long =
        s.anchorTrustedMs + (mono.elapsedMs() - s.anchorElapsedMs)
}
