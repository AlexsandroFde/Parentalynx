package com.parentalynx.app.policy

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PolicyEngineTest {
    private val noon = T.at("2026-11-17", "12:00") // terça-feira
    private val game = T.app("com.exemplo.jogo")
    private val chat = T.app("com.exemplo.chat")
    private val allDays = setOf(1, 2, 3, 4, 5, 6, 7)

    private fun limit(minutes: Int, perWeekday: Map<Int, Int> = emptyMap(), reset: Int = 0) =
        DailyLimit(enabled = true, minutes = minutes, perWeekday = perWeekday, resetMinutes = reset)

    private fun decide(
        policy: Policy?,
        app: AppFacts = game,
        usage: UsageView = T.usage(),
        now: Long = noon,
        tampered: Boolean = false,
        localOverrideUntil: Long = 0,
    ): Decision =
        PolicyEngine.evaluate(
            policy?.let { T.runtime(it) },
            app,
            usage,
            EvalContext(now, tampered, localOverrideUntil),
        )

    private fun reasonOf(decision: Decision): BlockReason? = (decision as? Decision.Blocked)?.reason

    private val bedtime = WeeklyBlockPeriod("p1", "Hora de dormir", true, allDays, 21 * 60, 7 * 60)

    // 1 e 2: essenciais e ausência de política

    @Test
    fun pacoteEssencialNuncaEBloqueado() {
        val policy =
            Policy(
                dailyLimit = limit(0),
                blockPeriods = listOf(bedtime),
                apps = AppsPolicy(rules = mapOf("com.android.phone" to AppRule(AppState.BLOCKED))),
                protection = ProtectionPolicy(lockOnTamper = true),
                overrides = Overrides(manualLock = ManualLock(active = true)),
            )
        val dialer = T.app("com.android.phone", essential = true, system = true)
        assertEquals(Decision.Allowed, decide(policy, dialer, now = T.at("2026-11-17", "23:00"), tampered = true))
    }

    @Test
    fun semPoliticaTudoEPermitido() {
        assertEquals(Decision.Allowed, decide(null))
        assertEquals(LockKind.NONE, PolicyEngine.deviceLock(null, T.usage(), EvalContext(noon)).kind)
    }

    // 4: bloqueio manual

    @Test
    fun bloqueioManualAtingeAppsComunsMasNaoExcecoes() {
        val policy =
            Policy(
                apps = AppsPolicy(rules = mapOf(chat.appId to AppRule(AppState.EXCEPTION))),
                overrides = Overrides(manualLock = ManualLock(active = true)),
            )
        val blocked = decide(policy) as Decision.Blocked
        assertEquals(BlockReason.MANUAL_LOCK, blocked.reason)
        assertNull(blocked.releaseAtMs)
        assertEquals(Decision.Allowed, decide(policy, chat))
    }

    @Test
    fun bloqueioManualComPrazoTerminaSozinho() {
        val until = noon + 30 * T.MIN
        val policy = Policy(overrides = Overrides(manualLock = ManualLock(active = true, untilMs = until)))
        assertEquals(until, (decide(policy) as Decision.Blocked).releaseAtMs)
        assertEquals(Decision.Allowed, decide(policy, now = until))
        assertEquals(Decision.Allowed, decide(Policy(overrides = Overrides(manualLock = ManualLock(active = false, untilMs = until)))))
    }

    // 5: adulteração

    @Test
    fun bloqueioPorAdulteracaoSoComAOpcaoLigadaEControleDegradado() {
        val on = Policy(protection = ProtectionPolicy(lockOnTamper = true))
        assertEquals(BlockReason.TAMPER_LOCK, reasonOf(decide(on, tampered = true)))
        assertEquals(Decision.Allowed, decide(on, tampered = false))
        assertEquals(Decision.Allowed, decide(Policy(), tampered = true))
        val withException = on.copy(apps = AppsPolicy(rules = mapOf(chat.appId to AppRule(AppState.EXCEPTION))))
        assertEquals(Decision.Allowed, decide(withException, chat, tampered = true))
    }

    // 6: app bloqueado e app novo

    @Test
    fun appBloqueadoERespeitaSuspensaoDeBloqueios() {
        val rules = mapOf(game.appId to AppRule(AppState.BLOCKED))
        assertEquals(BlockReason.APP_BLOCKED, reasonOf(decide(Policy(apps = AppsPolicy(rules = rules)))))

        val suspended =
            Policy(
                apps = AppsPolicy(rules = rules),
                overrides = Overrides(suspension = Suspension(noon + T.HOUR, setOf(SuspensionScope.APP_BLOCKS))),
            )
        assertEquals(Decision.Allowed, decide(suspended))
        assertEquals("suspensão vencida", BlockReason.APP_BLOCKED, reasonOf(decide(suspended, now = noon + T.HOUR)))

        val otherScope =
            suspended.copy(overrides = Overrides(suspension = Suspension(noon + T.HOUR, setOf(SuspensionScope.DAILY_LIMIT))))
        assertEquals(BlockReason.APP_BLOCKED, reasonOf(decide(otherScope)))
    }

    @Test
    fun appNovoFicaBloqueadoQuandoOPadraoEBloquear() {
        val policy = Policy(apps = AppsPolicy(blockNewApps = true, rules = mapOf(chat.appId to AppRule(AppState.ALLOWED))))
        assertEquals(BlockReason.NEW_APP, reasonOf(decide(policy, game)))
        assertEquals("app com regra explícita", Decision.Allowed, decide(policy, chat))
        assertEquals("app de sistema sem regra", Decision.Allowed, decide(policy, T.app("com.android.settings", system = true)))
        assertEquals(Decision.Allowed, decide(Policy(apps = AppsPolicy(blockNewApps = false)), game))
    }

    // 7: limite próprio do app

    @Test
    fun limiteProprioDoAppBloqueiaNoMinutoExato() {
        val policy = Policy(apps = AppsPolicy(rules = mapOf(game.appId to AppRule(AppState.ALLOWED, dailyLimitMinutes = 45))))
        assertEquals(Decision.Allowed, decide(policy, usage = T.usage(apps = mapOf(game.appId to 45 * T.MIN - 1))))
        val blocked = decide(policy, usage = T.usage(apps = mapOf(game.appId to 45 * T.MIN))) as Decision.Blocked
        assertEquals(BlockReason.APP_LIMIT, blocked.reason)
        assertEquals(T.at("2026-11-18", "00:00"), blocked.releaseAtMs)
        assertEquals("outro app não é afetado", Decision.Allowed, decide(policy, chat, T.usage(apps = mapOf(game.appId to 45 * T.MIN))))
    }

    @Test
    fun limiteProprioValeTambemParaExcecaoESuspendeComOLimiteDiario() {
        val rules = mapOf(chat.appId to AppRule(AppState.EXCEPTION, dailyLimitMinutes = 10))
        val usage = T.usage(apps = mapOf(chat.appId to 10 * T.MIN))
        assertEquals(BlockReason.APP_LIMIT, reasonOf(decide(Policy(apps = AppsPolicy(rules = rules)), chat, usage)))
        val suspended =
            Policy(
                apps = AppsPolicy(rules = rules),
                overrides = Overrides(suspension = Suspension(noon + T.HOUR, setOf(SuspensionScope.DAILY_LIMIT))),
            )
        assertEquals(Decision.Allowed, decide(suspended, chat, usage))
    }

    // 8: exceção

    @Test
    fun excecaoContinuaDisponivelComLimiteAtingidoEForaDoHorario() {
        val policy =
            Policy(
                dailyLimit = limit(60),
                blockPeriods = listOf(bedtime),
                apps = AppsPolicy(rules = mapOf(chat.appId to AppRule(AppState.EXCEPTION))),
            )
        val night = T.at("2026-11-17", "23:00")
        val usage = T.usage(quotaUsedMs = 5 * T.HOUR)
        assertEquals(Decision.Allowed, decide(policy, chat, usage, night))
        assertEquals(BlockReason.SCHEDULE, reasonOf(decide(policy, game, usage, night)))
    }

    // 9: horários

    @Test
    fun bloqueioPorHorarioInformaNomeELiberacao() {
        val policy = Policy(blockPeriods = listOf(bedtime))
        val blocked = decide(policy, now = T.at("2026-11-17", "22:00")) as Decision.Blocked
        assertEquals(BlockReason.SCHEDULE, blocked.reason)
        assertEquals("Hora de dormir", blocked.label)
        assertEquals(T.at("2026-11-18", "07:00"), blocked.releaseAtMs)
        assertEquals(Decision.Allowed, decide(policy, now = T.at("2026-11-17", "20:00")))
    }

    @Test
    fun suspensaoDeHorariosLiberaMasADeLimiteNao() {
        val night = T.at("2026-11-17", "22:00")
        val base = Policy(blockPeriods = listOf(bedtime))
        val schedulesOff =
            base.copy(overrides = Overrides(suspension = Suspension(night + T.HOUR, setOf(SuspensionScope.SCHEDULES))))
        assertEquals(Decision.Allowed, decide(schedulesOff, now = night))
        val limitOff =
            base.copy(overrides = Overrides(suspension = Suspension(night + T.HOUR, setOf(SuspensionScope.DAILY_LIMIT))))
        assertEquals(BlockReason.SCHEDULE, reasonOf(decide(limitOff, now = night)))
    }

    // 10: limite diário

    @Test
    fun limiteDiarioBloqueiaExatamenteAoAtingirOConfigurado() {
        val policy = Policy(dailyLimit = limit(150)) // 2h30
        val limitMs = 150 * T.MIN
        assertEquals(Decision.Allowed, decide(policy, usage = T.usage(quotaUsedMs = limitMs - 1)))
        val blocked = decide(policy, usage = T.usage(quotaUsedMs = limitMs)) as Decision.Blocked
        assertEquals(BlockReason.DAILY_LIMIT, blocked.reason)
        assertEquals(T.at("2026-11-18", "00:00"), blocked.releaseAtMs)
        assertEquals(BlockReason.DAILY_LIMIT, reasonOf(decide(policy, usage = T.usage(quotaUsedMs = limitMs + 5_000))))
    }

    @Test
    fun limiteDesligadoOuSuspensoNaoBloqueia() {
        val used = T.usage(quotaUsedMs = 10 * T.HOUR)
        assertEquals(Decision.Allowed, decide(Policy(dailyLimit = DailyLimit(enabled = false, minutes = 60)), usage = used))
        val suspended =
            Policy(
                dailyLimit = limit(60),
                overrides = Overrides(suspension = Suspension(noon + 1, setOf(SuspensionScope.DAILY_LIMIT))),
            )
        assertEquals(Decision.Allowed, decide(suspended, usage = used))
        assertEquals(BlockReason.DAILY_LIMIT, reasonOf(decide(suspended, usage = used, now = noon + 1)))
    }

    @Test
    fun limiteZeroSoDeixaExcecoes() {
        val policy =
            Policy(dailyLimit = limit(0), apps = AppsPolicy(rules = mapOf(chat.appId to AppRule(AppState.EXCEPTION))))
        assertEquals(BlockReason.DAILY_LIMIT, reasonOf(decide(policy)))
        assertEquals(Decision.Allowed, decide(policy, chat))
    }

    @Test
    fun tempoExtraValeSoParaODiaIndicado() {
        val extraToday = ExtraTime("e1", "2026-11-17", 30, noon)
        val extraOtherDay = ExtraTime("e2", "2026-11-16", 120, noon)
        val policy = Policy(dailyLimit = limit(60), overrides = Overrides(extraTime = listOf(extraToday, extraOtherDay)))
        val runtime = T.runtime(policy)
        assertEquals(90 * T.MIN, runtime.limitMs(LocalDate.parse("2026-11-17")))
        assertEquals(30 * T.MIN, runtime.extraMs(LocalDate.parse("2026-11-17")))
        assertEquals(60 * T.MIN, runtime.limitMs(LocalDate.parse("2026-11-18")))
        assertEquals(Decision.Allowed, decide(policy, usage = T.usage(quotaUsedMs = 90 * T.MIN - 1)))
        assertEquals(BlockReason.DAILY_LIMIT, reasonOf(decide(policy, usage = T.usage(quotaUsedMs = 90 * T.MIN))))
    }

    @Test
    fun variosTemposExtrasNoMesmoDiaSomam() {
        val extras = listOf(ExtraTime("a", "2026-11-17", 15, 0), ExtraTime("b", "2026-11-17", 30, 0))
        val runtime = T.runtime(Policy(dailyLimit = limit(60), overrides = Overrides(extraTime = extras)))
        assertEquals(105 * T.MIN, runtime.limitMs(LocalDate.parse("2026-11-17")))
    }

    @Test
    fun limitePorDiaDaSemanaUsaODiaDaCota() {
        // Sábado (6) e domingo (7) com 4 horas, demais dias 2 horas. Reinício às 04:00.
        val policy = Policy(dailyLimit = limit(120, mapOf(6 to 240, 7 to 240), reset = 4 * 60))
        val used3h = T.usage(quotaUsedMs = 3 * T.HOUR)
        // Sábado 21/11 ao meio-dia: limite de 4 h.
        assertEquals(Decision.Allowed, decide(policy, usage = used3h, now = T.at("2026-11-21", "12:00")))
        // Segunda 23/11 às 02:00 ainda é o dia da cota de domingo: 4 h.
        assertEquals(Decision.Allowed, decide(policy, usage = used3h, now = T.at("2026-11-23", "02:00")))
        // Segunda 23/11 às 05:00 já é o dia da cota de segunda: 2 h.
        val blocked = decide(policy, usage = used3h, now = T.at("2026-11-23", "05:00")) as Decision.Blocked
        assertEquals(BlockReason.DAILY_LIMIT, blocked.reason)
        assertEquals(T.at("2026-11-24", "04:00"), blocked.releaseAtMs)
    }

    @Test
    fun liberacaoDoLimiteConsideraBloqueioPorHorarioNoReinicio() {
        // A cota reinicia à meia-noite, mas o período de dormir vai até as 07:00.
        val policy = Policy(dailyLimit = limit(60), blockPeriods = listOf(bedtime))
        val blocked = decide(policy, usage = T.usage(quotaUsedMs = T.HOUR), now = T.at("2026-11-17", "15:00")) as Decision.Blocked
        assertEquals(BlockReason.DAILY_LIMIT, blocked.reason)
        assertEquals(T.at("2026-11-18", "07:00"), blocked.releaseAtMs)
    }

    // Precedência entre motivos

    @Test
    fun ordemDePrecedenciaDosMotivos() {
        val night = T.at("2026-11-17", "23:00")
        val everything =
            Policy(
                dailyLimit = limit(60),
                blockPeriods = listOf(bedtime),
                apps = AppsPolicy(rules = mapOf(game.appId to AppRule(AppState.BLOCKED, dailyLimitMinutes = 1))),
                protection = ProtectionPolicy(lockOnTamper = true),
                overrides = Overrides(manualLock = ManualLock(active = true)),
            )
        val usage = T.usage(quotaUsedMs = 5 * T.HOUR, apps = mapOf(game.appId to T.HOUR))
        assertEquals(BlockReason.MANUAL_LOCK, reasonOf(decide(everything, usage = usage, now = night, tampered = true)))

        val noManual = everything.copy(overrides = Overrides())
        assertEquals(BlockReason.TAMPER_LOCK, reasonOf(decide(noManual, usage = usage, now = night, tampered = true)))
        assertEquals(BlockReason.APP_BLOCKED, reasonOf(decide(noManual, usage = usage, now = night)))

        val limited = noManual.copy(apps = AppsPolicy(rules = mapOf(game.appId to AppRule(AppState.ALLOWED, dailyLimitMinutes = 1))))
        assertEquals(BlockReason.APP_LIMIT, reasonOf(decide(limited, usage = usage, now = night)))

        val plain = noManual.copy(apps = AppsPolicy())
        assertEquals(BlockReason.SCHEDULE, reasonOf(decide(plain, usage = usage, now = night)))
        assertEquals(BlockReason.DAILY_LIMIT, reasonOf(decide(plain, usage = usage, now = noon)))
    }

    // Estado geral do aparelho

    @Test
    fun estadoGeralDoAparelho() {
        fun lock(policy: Policy, usage: UsageView = T.usage(), now: Long = noon, tampered: Boolean = false) =
            PolicyEngine.deviceLock(T.runtime(policy), usage, EvalContext(now, tampered))

        assertEquals(LockKind.NONE, lock(Policy(dailyLimit = limit(60))).kind)

        val daily = lock(Policy(dailyLimit = limit(60)), T.usage(quotaUsedMs = T.HOUR))
        assertEquals(LockKind.DAILY_LIMIT, daily.kind)
        assertEquals(T.at("2026-11-18", "00:00"), daily.releaseAtMs)

        val schedule = lock(Policy(blockPeriods = listOf(bedtime)), now = T.at("2026-11-17", "22:00"))
        assertEquals(LockKind.SCHEDULE, schedule.kind)
        assertEquals("Hora de dormir", schedule.label)

        assertEquals(LockKind.MANUAL_LOCK, lock(Policy(overrides = Overrides(manualLock = ManualLock(true)))).kind)
        assertEquals(
            LockKind.TAMPER_LOCK,
            lock(Policy(protection = ProtectionPolicy(lockOnTamper = true)), tampered = true).kind,
        )
        // Um app bloqueado não é bloqueio geral do aparelho.
        val onlyAppBlocked = Policy(apps = AppsPolicy(rules = mapOf(game.appId to AppRule(AppState.BLOCKED))))
        assertEquals(LockKind.NONE, lock(onlyAppBlocked).kind)
        // Bloquear apps novos também não trava o aparelho.
        assertEquals(LockKind.NONE, lock(Policy(apps = AppsPolicy(blockNewApps = true))).kind)
    }

    // Consumo de cota

    @Test
    fun consumoDeCotaPorTipoDeRegra() {
        val policy =
            Policy(
                dailyLimit = limit(60),
                apps =
                    AppsPolicy(
                        rules =
                            mapOf(
                                "exc" to AppRule(AppState.EXCEPTION),
                                "excConta" to AppRule(AppState.EXCEPTION, countsTowardLimit = true),
                                "bloq" to AppRule(AppState.BLOCKED),
                            ),
                    ),
            )
        val runtime = T.runtime(policy)
        val ctx = EvalContext(noon)
        assertTrue(PolicyEngine.consumesQuota(runtime, game, ctx))
        assertFalse(PolicyEngine.consumesQuota(runtime, T.app("exc"), ctx))
        assertTrue(PolicyEngine.consumesQuota(runtime, T.app("excConta"), ctx))
        assertTrue("app bloqueado em uso durante suspensão consome cota", PolicyEngine.consumesQuota(runtime, T.app("bloq"), ctx))
        assertFalse(PolicyEngine.consumesQuota(runtime, T.app("x", essential = true), ctx))
        assertFalse(PolicyEngine.consumesQuota(runtime, T.app("x", tracked = false), ctx))
        assertTrue("sem política o tempo ainda é acumulado", PolicyEngine.consumesQuota(null, game, ctx))
    }

    @Test
    fun tempoDuranteSuspensaoDoLimiteNaoConsomeCota() {
        val policy =
            Policy(
                dailyLimit = limit(60),
                overrides = Overrides(suspension = Suspension(noon + T.HOUR, setOf(SuspensionScope.DAILY_LIMIT))),
            )
        val runtime = T.runtime(policy)
        assertFalse(PolicyEngine.consumesQuota(runtime, game, EvalContext(noon)))
        assertTrue(PolicyEngine.consumesQuota(runtime, game, EvalContext(noon + T.HOUR)))
        // Suspender só os horários não muda o consumo.
        val schedulesOnly =
            T.runtime(policy.copy(overrides = Overrides(suspension = Suspension(noon + T.HOUR, setOf(SuspensionScope.SCHEDULES)))))
        assertTrue(PolicyEngine.consumesQuota(schedulesOnly, game, EvalContext(noon)))
    }

    // Liberação local pelo responsável no aparelho

    @Test
    fun liberacaoLocalPassaPorLimiteHorarioEBloqueioManualMasNaoPorAppBloqueado() {
        val night = T.at("2026-11-17", "23:00")
        val policy =
            Policy(
                dailyLimit = limit(60),
                blockPeriods = listOf(bedtime),
                apps = AppsPolicy(rules = mapOf("bloq" to AppRule(AppState.BLOCKED))),
                protection = ProtectionPolicy(lockOnTamper = true),
                overrides = Overrides(manualLock = ManualLock(active = true)),
            )
        val usage = T.usage(quotaUsedMs = 5 * T.HOUR)
        val until = night + 15 * T.MIN
        assertEquals(Decision.Allowed, decide(policy, usage = usage, now = night, tampered = true, localOverrideUntil = until))
        assertEquals(BlockReason.APP_BLOCKED, reasonOf(decide(policy, T.app("bloq"), usage, night, localOverrideUntil = until)))
        assertEquals("liberação vencida", BlockReason.MANUAL_LOCK, reasonOf(decide(policy, usage = usage, now = until, localOverrideUntil = until)))
        assertFalse(PolicyEngine.consumesQuota(T.runtime(policy), game, EvalContext(night, localOverrideUntilMs = until)))
    }

    // Saldo e fronteiras

    @Test
    fun saldoRestanteDaCota() {
        val runtime = T.runtime(Policy(dailyLimit = limit(150)))
        val day = LocalDate.parse("2026-11-17")
        assertEquals(150 * T.MIN, PolicyEngine.remainingQuotaMs(runtime, day, 0))
        assertEquals(30 * T.MIN, PolicyEngine.remainingQuotaMs(runtime, day, 120 * T.MIN))
        assertEquals(0L, PolicyEngine.remainingQuotaMs(runtime, day, 500 * T.MIN))
        assertNull(PolicyEngine.remainingQuotaMs(T.runtime(Policy()), day, 0))
        assertNull(PolicyEngine.remainingQuotaMs(null, day, 0))
    }

    @Test
    fun proximaFronteiraDeTempo() {
        val reset = T.at("2026-11-18", "00:00")
        assertEquals(reset, PolicyEngine.nextTimeBoundaryMs(T.runtime(Policy()), EvalContext(noon)))

        val withBedtime = T.runtime(Policy(blockPeriods = listOf(bedtime)))
        assertEquals(T.at("2026-11-17", "21:00"), PolicyEngine.nextTimeBoundaryMs(withBedtime, EvalContext(noon)))

        val suspension = Suspension(noon + 10 * T.MIN, setOf(SuspensionScope.DAILY_LIMIT))
        val withSuspension = T.runtime(Policy(overrides = Overrides(suspension = suspension)))
        assertEquals(noon + 10 * T.MIN, PolicyEngine.nextTimeBoundaryMs(withSuspension, EvalContext(noon)))

        val manual = T.runtime(Policy(overrides = Overrides(manualLock = ManualLock(true, noon + 5 * T.MIN))))
        assertEquals(noon + 5 * T.MIN, PolicyEngine.nextTimeBoundaryMs(manual, EvalContext(noon)))

        assertEquals(
            noon + T.MIN,
            PolicyEngine.nextTimeBoundaryMs(T.runtime(Policy()), EvalContext(noon, localOverrideUntilMs = noon + T.MIN)),
        )
        assertNull(PolicyEngine.nextTimeBoundaryMs(null, EvalContext(noon)))
    }

    @Test
    fun fusoInvalidoCaiNoFusoDeReserva() {
        val runtime = PolicyRuntime(Policy(timezone = "Marte/Olympus"), T.FORTALEZA)
        assertEquals(T.FORTALEZA, runtime.zone)
        assertEquals(T.FORTALEZA, PolicyRuntime(Policy(timezone = ""), T.FORTALEZA).zone)
    }
}
