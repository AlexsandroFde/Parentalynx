package com.parentalynx.app.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrustedClockTest {
    private class FakeClocks(var wall: Long, var elapsed: Long) {
        val wallClock = WallClock { wall }
        val monoClock = MonotonicClock { elapsed }

        fun pass(ms: Long) {
            wall += ms
            elapsed += ms
        }
    }

    private class MemoryStore(var state: TrustedClockState? = null) : TrustedClockStore {
        override fun load(): TrustedClockState? = state

        override fun save(state: TrustedClockState) {
            this.state = state
        }
    }

    private fun clock(clocks: FakeClocks, store: MemoryStore, bootId: Long = 1): TrustedClock =
        TrustedClock(clocks.wallClock, clocks.monoClock, bootId, store)

    @Test
    fun semServidorUsaORelogioDoAparelhoEAvancaPeloMonotonico() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val trusted = clock(clocks, MemoryStore())
        assertEquals(1_000_000, trusted.nowMs())
        assertFalse(trusted.isTrusted)
        clocks.pass(30_000)
        assertEquals(1_030_000, trusted.nowMs())
    }

    @Test
    fun mudarORelogioDoAparelhoNaoAlteraAHoraConfiavel() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val trusted = clock(clocks, MemoryStore())
        clocks.wall += 24L * 60 * 60 * 1000 // a criança adianta um dia
        assertEquals(1_000_000, trusted.nowMs())
        clocks.wall -= 48L * 60 * 60 * 1000 // e depois atrasa dois
        clocks.elapsed += 1_000
        assertEquals(1_001_000, trusted.nowMs())
    }

    @Test
    fun horaDoServidorViraAncoraEInformaODeslocamento() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val trusted = clock(clocks, MemoryStore())
        clocks.pass(10_000)
        // Servidor diz que a hora real é 2_000_000 no instante monotônico 15_000.
        val delta = trusted.applyServerTime(serverMs = 2_000_000, elapsedAtMs = 15_000)
        assertEquals(990_000, delta)
        assertTrue(trusted.isTrusted)
        assertEquals(2_000_000, trusted.nowMs())
        clocks.pass(500)
        assertEquals(2_000_500, trusted.nowMs())
        assertEquals(2_000_500 - clocks.wall, trusted.wallOffsetMs())
    }

    @Test
    fun mesmoBootReaproveitaAAncoraGravada() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val store = MemoryStore()
        val first = clock(clocks, store)
        first.applyServerTime(serverMs = 9_000_000, elapsedAtMs = 5_000)
        clocks.pass(60_000)
        // Processo reiniciado no mesmo boot, com o relógio do aparelho adulterado.
        clocks.wall = 123
        val second = clock(clocks, store)
        assertTrue(second.isTrusted)
        assertEquals(9_060_000, second.nowMs())
    }

    @Test
    fun aposReiniciarNuncaRetrocedeAbaixoDaMaiorHoraGravada() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val store = MemoryStore()
        val first = clock(clocks, store, bootId = 1)
        first.applyServerTime(serverMs = 9_000_000, elapsedAtMs = 5_000)
        clocks.pass(60_000)
        first.persist()

        // Novo boot: monotônico zera e a criança atrasou o relógio.
        clocks.elapsed = 2_000
        clocks.wall = 500_000
        val second = clock(clocks, store, bootId = 2)
        assertFalse(second.isTrusted)
        assertEquals(9_060_000, second.nowMs())
        clocks.elapsed += 1_000
        assertEquals(9_061_000, second.nowMs())
    }

    @Test
    fun aposReiniciarComRelogioCorretoUsaORelogioDoAparelho() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val store = MemoryStore()
        clock(clocks, store, bootId = 1).persist()
        clocks.elapsed = 1_000
        clocks.wall = 5_000_000 // aparelho ficou desligado
        val second = clock(clocks, store, bootId = 2)
        assertEquals(5_000_000, second.nowMs())
    }

    @Test
    fun converteInstanteMonotonicoEmHoraConfiavel() {
        val clocks = FakeClocks(wall = 1_000_000, elapsed = 5_000)
        val trusted = clock(clocks, MemoryStore())
        assertEquals(1_002_000, trusted.fromElapsed(7_000))
    }
}
