package com.parentalynx.app.usage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageTrackerTest {
    private data class Session(val appId: String, val startMs: Long, val endMs: Long)

    private class RecordingSink : UsageSink {
        val usedMs = HashMap<String, Long>()
        val opens = HashMap<String, Int>()
        val sessions = ArrayList<Session>()
        val intervals = ArrayList<Triple<Set<String>, Long, Long>>()

        override fun onUsage(appIds: Set<String>, fromMs: Long, toMs: Long) {
            intervals.add(Triple(appIds, fromMs, toMs))
            for (id in appIds) usedMs[id] = (usedMs[id] ?: 0L) + (toMs - fromMs)
        }

        override fun onOpen(appId: String, atMs: Long) {
            opens[appId] = (opens[appId] ?: 0) + 1
        }

        override fun onSession(appId: String, startMs: Long, endMs: Long) {
            sessions.add(Session(appId, startMs, endMs))
        }

        fun used(appId: String): Long = usedMs[appId] ?: 0L
    }

    private val base = 1_000_000_000L
    private val sink = RecordingSink()
    private val browserResolver =
        AppIdResolver { pkg, cls ->
            if (pkg == "com.parentalynx.app" && cls == "com.parentalynx.app.BrowserActivity") {
                "com.parentalynx.app.browser"
            } else {
                pkg
            }
        }
    private val tracker = UsageTracker(sink, browserResolver).also { it.start(base, interactive = true) }

    private fun resumed(at: Long, pkg: String, cls: String = "Main") = UsageEvent(base + at, UsageEventType.RESUMED, pkg, cls)

    private fun paused(at: Long, pkg: String, cls: String = "Main") = UsageEvent(base + at, UsageEventType.PAUSED, pkg, cls)

    private fun stopped(at: Long, pkg: String, cls: String = "Main") = UsageEvent(base + at, UsageEventType.STOPPED, pkg, cls)

    private fun screenOff(at: Long) = UsageEvent(base + at, UsageEventType.SCREEN_OFF)

    private fun screenOn(at: Long) = UsageEvent(base + at, UsageEventType.SCREEN_ON)

    @Test
    fun trocaDeAppCreditaCadaUmPeloSeuIntervalo() {
        tracker.process(
            listOf(
                resumed(1_000, "jogo"),
                paused(61_000, "jogo"),
                resumed(61_020, "chat"),
                stopped(61_500, "jogo"),
            ),
        )
        tracker.advanceTo(base + 91_020)
        assertEquals(60_000, sink.used("jogo"))
        assertEquals(30_000, sink.used("chat"))
        assertEquals(setOf("chat"), tracker.foregroundApps())
        assertEquals(1, sink.opens["jogo"])
        assertEquals(1, sink.opens["chat"])
        // A sessão do jogo fecha quando vence a janela de união.
        assertEquals(listOf(Session("jogo", base + 1_000, base + 61_000)), sink.sessions)
    }

    @Test
    fun semAppEmPrimeiroPlanoNadaECreditado() {
        tracker.advanceTo(base + 60_000)
        assertTrue(sink.intervals.isEmpty())
        tracker.process(listOf(resumed(60_000, "jogo"), paused(70_000, "jogo")))
        tracker.advanceTo(base + 200_000)
        assertEquals(10_000, sink.used("jogo"))
    }

    @Test
    fun telaApagadaFechaTudoEParaDeContar() {
        tracker.process(listOf(resumed(0, "jogo"), screenOff(30_000)))
        tracker.advanceTo(base + 500_000)
        assertEquals(30_000, sink.used("jogo"))
        assertFalse(tracker.interactive)
        assertTrue(tracker.foregroundApps().isEmpty())
        assertEquals(listOf(Session("jogo", base, base + 30_000)), sink.sessions)

        // Ao religar, só conta depois que a atividade é retomada de novo.
        tracker.process(listOf(screenOn(600_000), resumed(605_000, "jogo")))
        tracker.advanceTo(base + 615_000)
        assertEquals(40_000, sink.used("jogo"))
        assertEquals(2, sink.opens["jogo"])
    }

    @Test
    fun atividadeRetomadaComTelaApagadaNaoContaAteATelaLigar() {
        tracker.process(listOf(screenOff(0), resumed(1_000, "alarme"), screenOn(5_000)))
        tracker.advanceTo(base + 9_000)
        assertEquals(4_000, sink.used("alarme"))
    }

    @Test
    fun telaDeBloqueioDoSistemaEncerraAsSessoes() {
        tracker.process(listOf(resumed(0, "jogo"), UsageEvent(base + 10_000, UsageEventType.KEYGUARD_SHOWN)))
        tracker.advanceTo(base + 60_000)
        assertEquals(10_000, sink.used("jogo"))
        assertTrue(tracker.interactive)
        // Atividade exibida por cima da tela de bloqueio (por exemplo a câmera) volta a contar.
        tracker.process(resumed(60_000, "camera"))
        tracker.advanceTo(base + 65_000)
        assertEquals(5_000, sink.used("camera"))
    }

    @Test
    fun telaDivididaCreditaOsDoisAppsNoMesmoIntervalo() {
        tracker.process(listOf(resumed(0, "video"), resumed(0, "chat")))
        tracker.advanceTo(base + 20_000)
        tracker.process(paused(20_000, "chat"))
        tracker.advanceTo(base + 30_000)
        assertEquals(30_000, sink.used("video"))
        assertEquals(20_000, sink.used("chat"))
        // O intervalo compartilhado é entregue uma única vez com os dois apps, para que o tempo
        // total do aparelho não seja contado em dobro.
        assertEquals(setOf("video", "chat"), sink.intervals.first().first)
        val wallTime = sink.intervals.sumOf { it.third - it.second }
        assertEquals(30_000, wallTime)
    }

    @Test
    fun trocaDeTelaDentroDoAppUneAsSessoesEContaUmaAbertura() {
        tracker.process(
            listOf(
                resumed(0, "loja", "Lista"),
                paused(10_000, "loja", "Lista"),
                resumed(10_300, "loja", "Detalhe"),
                stopped(10_800, "loja", "Lista"),
                paused(25_000, "loja", "Detalhe"),
            ),
        )
        tracker.advanceTo(base + 60_000)
        assertEquals(1, sink.opens["loja"])
        assertEquals(listOf(Session("loja", base, base + 25_000)), sink.sessions)
        // O intervalo de 300 ms sem atividade retomada não é creditado.
        assertEquals(24_700, sink.used("loja"))
    }

    @Test
    fun voltaDepoisDeDoisSegundosContaNovaAberturaENovaSessao() {
        tracker.process(
            listOf(
                resumed(0, "jogo"),
                paused(10_000, "jogo"),
                resumed(12_500, "jogo"),
                paused(20_000, "jogo"),
            ),
        )
        tracker.advanceTo(base + 60_000)
        assertEquals(2, sink.opens["jogo"])
        assertEquals(
            listOf(Session("jogo", base, base + 10_000), Session("jogo", base + 12_500, base + 20_000)),
            sink.sessions,
        )
    }

    @Test
    fun voltaEntreUmSegundoEMeioEDoisNaoContaAberturaMasAbreNovaSessao() {
        tracker.process(listOf(resumed(0, "jogo"), paused(10_000, "jogo"), resumed(11_700, "jogo"), paused(20_000, "jogo")))
        tracker.advanceTo(base + 60_000)
        assertEquals(1, sink.opens["jogo"])
        assertEquals(2, sink.sessions.size)
    }

    @Test
    fun sessaoMuitoCurtaNaoEntraNoRegistroMasOTempoConta() {
        tracker.process(listOf(resumed(0, "bloqueado"), paused(400, "bloqueado")))
        tracker.advanceTo(base + 10_000)
        assertTrue(sink.sessions.isEmpty())
        assertEquals(400, sink.used("bloqueado"))
    }

    @Test
    fun atividadeDoNavegadorGerenciadoViraPacoteVirtual() {
        tracker.process(
            listOf(
                resumed(0, "com.parentalynx.app", "com.parentalynx.app.MainActivity"),
                paused(5_000, "com.parentalynx.app", "com.parentalynx.app.MainActivity"),
                resumed(5_010, "com.parentalynx.app", "com.parentalynx.app.BrowserActivity"),
            ),
        )
        tracker.advanceTo(base + 15_010)
        assertEquals(5_000, sink.used("com.parentalynx.app"))
        assertEquals(10_000, sink.used("com.parentalynx.app.browser"))
        assertEquals(setOf("com.parentalynx.app.browser"), tracker.foregroundApps())
    }

    @Test
    fun eventosRepetidosOuSemParSaoIgnorados() {
        tracker.process(
            listOf(
                resumed(0, "jogo"),
                resumed(1_000, "jogo"),
                stopped(2_000, "outro"),
                paused(10_000, "jogo"),
                stopped(10_100, "jogo"),
            ),
        )
        tracker.advanceTo(base + 30_000)
        assertEquals(10_000, sink.used("jogo"))
        assertEquals(1, sink.opens["jogo"])
        assertEquals(1, sink.sessions.size)
    }

    @Test
    fun carimboAnteriorAoCursorETrazidoParaOCursor() {
        tracker.advanceTo(base + 50_000)
        tracker.process(resumed(10_000, "jogo")) // chegou atrasado
        tracker.advanceTo(base + 60_000)
        assertEquals(10_000, sink.used("jogo"))
        assertEquals(base + 50_000, tracker.foregroundSince("jogo"))
    }

    @Test
    fun desligamentoEInicializacaoFechamAsSessoes() {
        tracker.process(
            listOf(
                resumed(0, "jogo"),
                UsageEvent(base + 20_000, UsageEventType.SHUTDOWN),
                UsageEvent(base + 500_000, UsageEventType.STARTUP),
                resumed(510_000, "jogo"),
            ),
        )
        tracker.advanceTo(base + 520_000)
        assertEquals(30_000, sink.used("jogo"))
        assertTrue(tracker.interactive)
    }

    @Test
    fun quedaDeEnergiaNaoCreditaOTempoDesligado() {
        // Sem evento de desligamento: o último ponto conhecido é o cursor (batimento do motor).
        tracker.process(resumed(0, "jogo"))
        tracker.advanceTo(base + 12_000)
        tracker.process(
            listOf(
                UsageEvent(base + 900_000, UsageEventType.STARTUP),
                resumed(910_000, "jogo"),
            ),
        )
        tracker.advanceTo(base + 915_000)
        assertEquals(17_000, sink.used("jogo"))
        assertEquals(Session("jogo", base, base + 12_000), sink.sessions.first())
        assertEquals(2, sink.opens["jogo"])
    }

    @Test
    fun ajusteAoVivoDoEstadoDaTela() {
        tracker.process(resumed(0, "jogo"))
        tracker.setInteractive(false, base + 15_000) // evento de tela perdido
        tracker.advanceTo(base + 100_000)
        assertEquals(15_000, sink.used("jogo"))
        assertTrue(tracker.foregroundApps().isEmpty())
        tracker.setInteractive(true, base + 100_000)
        assertTrue(tracker.interactive)
    }

    @Test
    fun retomadaPeloEstadoGravadoContinuaDeOndeParou() {
        tracker.process(listOf(resumed(0, "jogo"), paused(8_000, "jogo"), resumed(8_200, "chat")))
        tracker.advanceTo(base + 20_000)
        val saved = tracker.exportState()

        // Processo morto e recriado: novo rastreador com o estado gravado.
        val sink2 = RecordingSink()
        val restored = UsageTracker(sink2, browserResolver)
        restored.importState(saved)
        assertEquals(base + 20_000, restored.cursorMs)
        assertEquals(setOf("chat"), restored.foregroundApps())
        assertEquals(base + 8_200, restored.foregroundSince("chat"))

        // Eventos do período em que o processo esteve morto, lidos do registro do sistema.
        restored.process(listOf(paused(50_000, "chat"), resumed(50_100, "jogo"), screenOff(80_000)))
        restored.advanceTo(base + 300_000)
        assertEquals(30_000, sink2.used("chat"))
        assertEquals(29_900, sink2.used("jogo"))
        assertEquals(Session("chat", base + 8_200, base + 50_000), sink2.sessions.first { it.appId == "chat" })
        // O jogo saiu aos 8 s e voltou aos 50,1 s: nova abertura.
        assertEquals(1, sink2.opens["jogo"])
    }

    @Test
    fun estadoInvalidoDeixaORastreadorComoNovo() {
        val fresh = UsageTracker(RecordingSink(), browserResolver)
        fresh.importState("isto não é json")
        assertFalse(fresh.isStarted)
        fresh.importState(null)
        assertFalse(fresh.isStarted)
        assertTrue(fresh.foregroundApps().isEmpty())
    }

    @Test
    fun fecharTudoAposReinicioDetectado() {
        tracker.process(resumed(0, "jogo"))
        tracker.advanceTo(base + 12_000) // último ponto gravado antes de o aparelho apagar
        tracker.closeAll()
        assertTrue(tracker.foregroundApps().isEmpty())
        assertEquals(listOf(Session("jogo", base, base + 12_000)), sink.sessions)
        // Horas depois, o tempo desligado não é creditado.
        tracker.advanceTo(base + 5_000_000)
        assertEquals(12_000, sink.used("jogo"))
    }

    @Test
    fun deslocamentoDeHoraMantemADuracaoEmAndamento() {
        tracker.process(resumed(0, "jogo"))
        tracker.advanceTo(base + 10_000)
        // A hora confiável foi corrigida em +1 hora pelo servidor.
        val hour = 3_600_000L
        tracker.shiftTime(hour)
        assertEquals(base + 10_000 + hour, tracker.cursorMs)
        tracker.process(UsageEvent(base + 25_000 + hour, UsageEventType.PAUSED, "jogo", "Main"))
        tracker.advanceTo(base + 60_000 + hour)
        assertEquals(25_000, sink.used("jogo"))
        assertEquals(listOf(Session("jogo", base + hour, base + 25_000 + hour)), sink.sessions)
    }

    @Test
    fun deslocamentoParaTrasNaoCongelaAContagem() {
        tracker.process(resumed(0, "jogo"))
        tracker.advanceTo(base + 10_000)
        tracker.shiftTime(-3_600_000L)
        tracker.advanceTo(base + 20_000 - 3_600_000L)
        assertEquals(20_000, sink.used("jogo"))
    }

    @Test
    fun primeiroEventoIniciaRastreadorNaoIniciado() {
        val s = RecordingSink()
        val t = UsageTracker(s, browserResolver)
        assertFalse(t.isStarted)
        t.process(UsageEvent(base, UsageEventType.RESUMED, "jogo", "Main"))
        assertTrue(t.isStarted)
        t.advanceTo(base + 5_000)
        assertEquals(5_000, s.used("jogo"))
        assertNull(t.foregroundSince("outro"))
    }
}
