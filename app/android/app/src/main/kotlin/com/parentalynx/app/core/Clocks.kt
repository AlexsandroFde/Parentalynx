package com.parentalynx.app.core

import android.os.SystemClock

/** Relógio de parede do aparelho. Pode ser alterado pelo usuário. */
fun interface WallClock {
    fun nowMs(): Long
}

/** Relógio monotônico desde o boot. Não pode ser alterado e conta o tempo em repouso. */
fun interface MonotonicClock {
    fun elapsedMs(): Long
}

object SystemWallClock : WallClock {
    override fun nowMs(): Long = System.currentTimeMillis()
}

object SystemMonotonicClock : MonotonicClock {
    override fun elapsedMs(): Long = SystemClock.elapsedRealtime()
}
