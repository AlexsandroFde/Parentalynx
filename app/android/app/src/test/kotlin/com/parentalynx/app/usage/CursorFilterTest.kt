package com.parentalynx.app.usage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CursorFilterTest {
    private fun ev(ts: Long, pkg: String = "p", type: UsageEventType = UsageEventType.RESUMED) =
        RawUsageEvent(ts, type, pkg, "Main")

    @Test
    fun leituraVaziaMantemOCursor() {
        val cursor = SourceCursor(100, 2)
        val (fresh, next) = CursorFilter.filterNew(emptyList(), cursor)
        assertTrue(fresh.isEmpty())
        assertEquals(cursor, next)
    }

    @Test
    fun primeiraLeituraEntregaTudoEGuardaQuantosTemOUltimoCarimbo() {
        val events = listOf(ev(100, "a"), ev(150, "b"), ev(150, "c"))
        val (fresh, next) = CursorFilter.filterNew(events, SourceCursor(100, 0))
        assertEquals(events, fresh)
        assertEquals(SourceCursor(150, 2), next)
    }

    @Test
    fun releituraDoMesmoCarimboPulaOsJaProcessados() {
        // A leitura recomeça em 150 (inclusive) e o sistema devolve de novo os dois já vistos,
        // mais um terceiro que foi gravado depois com o mesmo carimbo.
        val events = listOf(ev(150, "b"), ev(150, "c"), ev(150, "d"), ev(200, "e"))
        val (fresh, next) = CursorFilter.filterNew(events, SourceCursor(150, 2))
        assertEquals(listOf("d", "e"), fresh.map { it.pkg })
        assertEquals(SourceCursor(200, 1), next)
    }

    @Test
    fun releituraSemNovidadeNaoEntregaNadaENaoPerdeAContagem() {
        val events = listOf(ev(150, "b"), ev(150, "c"))
        val (fresh, next) = CursorFilter.filterNew(events, SourceCursor(150, 2))
        assertTrue(fresh.isEmpty())
        assertEquals(SourceCursor(150, 2), next)
    }

    @Test
    fun eventosAnterioresAoCursorSaoDescartados() {
        val events = listOf(ev(90, "velho"), ev(100, "visto"), ev(120, "novo"))
        val (fresh, next) = CursorFilter.filterNew(events, SourceCursor(100, 1))
        assertEquals(listOf("novo"), fresh.map { it.pkg })
        assertEquals(SourceCursor(120, 1), next)
    }

    @Test
    fun leiturasEncadeadasNuncaDuplicamNemPerdemEventos() {
        val log = ArrayList<RawUsageEvent>()
        var cursor = SourceCursor(0, 0)
        val delivered = ArrayList<String>()

        fun poll() {
            val batch = log.filter { it.wallTsMs >= cursor.lastTsMs }
            val (fresh, next) = CursorFilter.filterNew(batch, cursor)
            delivered.addAll(fresh.map { it.pkg!! })
            cursor = next
        }

        log.add(ev(10, "1"))
        log.add(ev(10, "2"))
        poll()
        log.add(ev(10, "3")) // mesmo milissegundo, gravado depois da leitura
        log.add(ev(11, "4"))
        poll()
        poll()
        log.add(ev(11, "5"))
        log.add(ev(11, "6"))
        log.add(ev(30, "7"))
        poll()
        assertEquals(listOf("1", "2", "3", "4", "5", "6", "7"), delivered)
        assertEquals(SourceCursor(30, 1), cursor)
    }

    @Test
    fun cursorDeslocadoAcompanhaMudancaDoRelogioDoAparelho() {
        val day = 24L * 60 * 60 * 1000
        assertEquals(SourceCursor(1_000 + day, 3), SourceCursor(1_000, 3).shifted(day))
        assertEquals(SourceCursor(1_000 - 500, 3), SourceCursor(1_000, 3).shifted(-500))
    }
}
