package com.parentalynx.app.enforcement

import com.parentalynx.app.apps.CatalogEntry
import com.parentalynx.app.apps.PackageClassifier
import com.parentalynx.app.apps.SystemPackageSets
import com.parentalynx.app.core.MonotonicClock
import com.parentalynx.app.data.SessionRow
import com.parentalynx.app.data.SessionWriter
import com.parentalynx.app.data.UsageWriter
import com.parentalynx.app.policy.AppRule
import com.parentalynx.app.policy.AppState
import com.parentalynx.app.policy.AppsPolicy
import com.parentalynx.app.policy.DailyLimit
import com.parentalynx.app.policy.Overrides
import com.parentalynx.app.policy.Policy
import com.parentalynx.app.policy.PolicyRuntime
import com.parentalynx.app.policy.QuotaCalendar
import com.parentalynx.app.policy.Suspension
import com.parentalynx.app.policy.SuspensionScope
import com.parentalynx.app.policy.T
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Lógica pura do agente fora do motor de política: classificação, tentativas, gravação e textos. */
class AgentLogicTest {
    // Classificação de pacotes (docs/02-arquitetura.md, seção 4.1)

    private val sets =
        SystemPackageSets(
            ownPackage = "com.parentalynx.app",
            homePackages = setOf("com.android.launcher3"),
            dialerPackages = setOf("com.fabricante.discador"),
            imePackages = setOf("com.fabricante.teclado"),
            launchablePackages =
                setOf("com.android.launcher3", "com.fabricante.discador", "com.android.settings", "com.exemplo.jogo", "com.parentalynx.app"),
        )

    private fun classify(pkg: String, system: Boolean) = PackageClassifier.classify(pkg, system, sets)

    @Test
    fun essenciaisNuncaBloqueaveis() {
        assertTrue(classify("com.parentalynx.app", false).essential)
        assertTrue(classify("com.android.launcher3", true).essential)
        assertTrue(classify("com.fabricante.discador", true).essential)
        assertTrue(classify("com.fabricante.teclado", true).essential)
        assertTrue(classify("com.android.systemui", true).essential)
        assertTrue(classify("com.android.phone", true).essential)
        assertTrue(classify("com.android.emergency", true).essential)
        assertTrue(classify("com.google.android.permissioncontroller", true).essential)
        assertTrue("componente de sistema sem ícone", classify("com.android.documentsui.picker", true).essential)
    }

    @Test
    fun appsComunsSeguemAsRegras() {
        assertFalse("Configurações são um app comum", classify("com.android.settings", true).essential)
        assertFalse(classify("com.exemplo.jogo", false).essential)
        assertFalse("app do usuário sem ícone", classify("com.exemplo.semicone", false).essential)
    }

    @Test
    fun rastreadosAparecemNosRelatorios() {
        assertTrue(classify("com.exemplo.jogo", false).tracked)
        assertTrue(classify("com.android.settings", true).tracked)
        assertTrue("discador: essencial, mas o tempo aparece", classify("com.fabricante.discador", true).tracked)
        assertTrue(classify("com.exemplo.semicone", false).tracked)
        assertFalse("launcher", classify("com.android.launcher3", true).tracked)
        assertFalse("interface do próprio app", classify("com.parentalynx.app", false).tracked)
        assertFalse("componente de sistema sem ícone", classify("com.android.systemui", true).tracked)
    }

    // Limite de tentativas do código offline

    private class MemoryAttempts(override var failures: Int = 0, override var lockedUntilMs: Long = 0) : AttemptStore

    @Test
    fun cincoErrosBloqueiamPorCincoMinutosEDobram() {
        val store = MemoryAttempts()
        val limiter = AttemptLimiter(store)
        val now = 1_000_000L
        for (expectedLeft in 4 downTo 1) {
            assertEquals(AttemptOutcome(expectedLeft, 0), limiter.registerFailure(now))
            assertEquals(0L, limiter.lockedForSec(now))
        }
        assertEquals(AttemptOutcome(0, 300), limiter.registerFailure(now))
        assertEquals(300L, limiter.lockedForSec(now))
        assertEquals(1L, limiter.lockedForSec(now + 299_500))
        assertEquals(0L, limiter.lockedForSec(now + 300_000))
        assertEquals(600L, limiter.registerFailure(now).retryAfterSec)
        assertEquals(1200L, limiter.registerFailure(now).retryAfterSec)
        assertEquals(2400L, limiter.registerFailure(now).retryAfterSec)
        assertEquals(3600L, limiter.registerFailure(now).retryAfterSec)
        assertEquals("teto de 60 minutos", 3600L, limiter.registerFailure(now).retryAfterSec)
    }

    @Test
    fun acertoZeraOContadorEOBloqueioFicaGravado() {
        val store = MemoryAttempts()
        repeat(5) { AttemptLimiter(store).registerFailure(0) }
        // Outro processo (app reiniciado) enxerga o mesmo bloqueio.
        assertEquals(300L, AttemptLimiter(store).lockedForSec(0))
        AttemptLimiter(store).registerSuccess()
        assertEquals(0L, AttemptLimiter(store).lockedForSec(0))
        assertEquals(5, AttemptLimiter(store).attemptsLeft())
    }

    @Test
    fun autenticacaoDoResponsavelValeCincoMinutos() {
        var elapsed = 10_000L
        val auth = AdminAuth(MonotonicClock { elapsed })
        assertFalse(auth.isValid())
        auth.markAuthenticated()
        assertTrue(auth.isValid())
        elapsed += AdminAuth.VALID_MS - 1
        assertTrue(auth.isValid())
        elapsed += 1
        assertFalse(auth.isValid())
        auth.markAuthenticated()
        auth.invalidate()
        assertFalse(auth.isValid())
    }

    // Gravador de uso

    private class Credit(val day: String, val apps: List<String>, val ms: Long, val hour: Int, val quota: Boolean)

    private class FakeWriter : UsageWriter, SessionWriter {
        val credits = ArrayList<Credit>()
        val opens = ArrayList<Pair<String, String>>()
        val sessions = ArrayList<SessionRow>()

        override fun addUsage(dayKey: String, appIds: Collection<String>, ms: Long, hour: Int, consumesQuota: Boolean, fromMs: Long, toMs: Long) {
            credits.add(Credit(dayKey, appIds.toList(), ms, hour, consumesQuota))
        }

        override fun addOpen(dayKey: String, appId: String) {
            opens.add(dayKey to appId)
        }

        override fun addSession(row: SessionRow) {
            sessions.add(row)
        }
    }

    private class Env(val policy: Policy?, var recordFrom: Long = 0L, var override: Long = 0L) : RecorderEnvironment {
        private val runtime = policy?.let { T.runtime(it) }

        override fun runtime(): PolicyRuntime? = runtime

        override fun calendar(): QuotaCalendar = runtime?.calendar ?: QuotaCalendar(ZoneId.of("America/Fortaleza"), 0)

        override fun localOverrideUntilMs(): Long = override

        override fun recordFromMs(): Long = recordFrom

        override fun entry(appId: String): CatalogEntry {
            val untracked = appId == "launcher"
            return CatalogEntry(appId, appId, appId, system = untracked, launchable = true, essential = untracked, tracked = !untracked, category = "other")
        }
    }

    private val policy =
        Policy(
            dailyLimit = DailyLimit(enabled = true, minutes = 60, resetMinutes = 4 * 60),
            apps = AppsPolicy(rules = mapOf("chat" to AppRule(AppState.EXCEPTION))),
        )

    @Test
    fun creditoEDivididoNaViradaDeHoraENaViradaDoDiaDaCota() {
        val writer = FakeWriter()
        val recorder = UsageRecorder(writer, writer, Env(policy))
        // Reinício às 04:00: de 03:50 a 04:10 atravessa a hora e o dia da cota.
        recorder.onUsage(setOf("jogo"), T.at("2026-11-18", "03:50"), T.at("2026-11-18", "04:10"))
        assertEquals(2, writer.credits.size)
        assertEquals("2026-11-17", writer.credits[0].day)
        assertEquals(3, writer.credits[0].hour)
        assertEquals(10 * T.MIN, writer.credits[0].ms)
        assertEquals("2026-11-18", writer.credits[1].day)
        assertEquals(4, writer.credits[1].hour)
        assertEquals(10 * T.MIN, writer.credits[1].ms)
        assertTrue(writer.credits.all { it.quota })
    }

    @Test
    fun excecaoNaoConsomeCotaETelaDivididaConsomeSeAlgumAppConsome() {
        val writer = FakeWriter()
        val recorder = UsageRecorder(writer, writer, Env(policy))
        val t = T.at("2026-11-17", "10:00")
        recorder.onUsage(setOf("chat"), t, t + T.MIN)
        recorder.onUsage(setOf("chat", "jogo"), t + T.MIN, t + 2 * T.MIN)
        recorder.onUsage(setOf("launcher"), t + 2 * T.MIN, t + 3 * T.MIN)
        recorder.onUsage(setOf("launcher", "jogo"), t + 3 * T.MIN, t + 4 * T.MIN)
        assertEquals(listOf(false, true, true), writer.credits.map { it.quota })
        assertEquals(listOf("chat", "jogo"), writer.credits[1].apps)
        assertEquals("app não rastreado fica fora", listOf("jogo"), writer.credits[2].apps)
    }

    @Test
    fun tempoDuranteSuspensaoOuLiberacaoLocalNaoConsomeCota() {
        val t = T.at("2026-11-17", "10:00")
        val suspended = policy.copy(overrides = Overrides(suspension = Suspension(t + 30 * T.MIN, setOf(SuspensionScope.DAILY_LIMIT))))
        val writer = FakeWriter()
        UsageRecorder(writer, writer, Env(suspended)).onUsage(setOf("jogo"), t, t + T.MIN)
        assertFalse(writer.credits.single().quota)

        val writer2 = FakeWriter()
        UsageRecorder(writer2, writer2, Env(policy, override = t + 10 * T.MIN)).onUsage(setOf("jogo"), t, t + T.MIN)
        assertFalse(writer2.credits.single().quota)
        assertEquals("o tempo continua nos relatórios", T.MIN, writer2.credits.single().ms)
    }

    @Test
    fun antesDoInicioDeGravacaoNadaEGravado() {
        val start = T.at("2026-11-17", "04:00")
        val writer = FakeWriter()
        val recorder = UsageRecorder(writer, writer, Env(policy, recordFrom = start))
        recorder.onUsage(setOf("jogo"), start - 30 * T.MIN, start - 10 * T.MIN)
        recorder.onOpen("jogo", start - T.MIN)
        recorder.onSession("jogo", start - 30 * T.MIN, start - 10 * T.MIN)
        assertTrue(writer.credits.isEmpty() && writer.opens.isEmpty() && writer.sessions.isEmpty())

        // Intervalo que atravessa o início: só a parte de depois conta, e a sessão é aparada.
        recorder.onUsage(setOf("jogo"), start - 5 * T.MIN, start + 5 * T.MIN)
        recorder.onSession("jogo", start - 5 * T.MIN, start + 5 * T.MIN)
        recorder.onOpen("jogo", start)
        assertEquals(5 * T.MIN, writer.credits.sumOf { it.ms })
        assertEquals(start, writer.sessions.single().startMs)
        assertEquals("2026-11-17", writer.sessions.single().day)
        assertEquals(-180, writer.sessions.single().tzOffsetMin)
        assertEquals(listOf("2026-11-17" to "jogo"), writer.opens)
    }

    @Test
    fun semPoliticaOTempoAindaEGravado() {
        val writer = FakeWriter()
        val t = T.at("2026-11-17", "10:00")
        UsageRecorder(writer, writer, Env(null)).onUsage(setOf("jogo"), t, t + T.MIN)
        assertEquals(T.MIN, writer.credits.single().ms)
        assertTrue(writer.credits.single().quota)
    }

    // Textos

    @Test
    fun textosDeDuracaoEDeLiberacao() {
        assertEquals("0 min", TimeText.duration(0))
        assertEquals("menos de 1 min", TimeText.duration(59_000))
        assertEquals("1 min", TimeText.duration(60_000))
        assertEquals("45 min", TimeText.duration(44 * T.MIN + 1))
        assertEquals("2 h", TimeText.duration(2 * T.HOUR))
        assertEquals("2 h 30 min", TimeText.duration(150 * T.MIN))
        val now = T.at("2026-11-17", "15:00")
        assertEquals("hoje às 21:00", TimeText.release(T.at("2026-11-17", "21:00"), now, T.FORTALEZA))
        assertEquals("amanhã às 07:00", TimeText.release(T.at("2026-11-18", "07:00"), now, T.FORTALEZA))
        assertEquals("dia 23/11 às 07:00", TimeText.release(T.at("2026-11-23", "07:00"), now, T.FORTALEZA))
        assertEquals("07:05", TimeText.clock(T.at("2026-11-17", "07:05"), T.FORTALEZA))
    }
}
