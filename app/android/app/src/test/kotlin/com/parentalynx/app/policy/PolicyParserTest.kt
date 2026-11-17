package com.parentalynx.app.policy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class PolicyParserTest {
    /** Documento de exemplo de `docs/03-protocolo.md`, seção 4.2. */
    private val protocolExample =
        """
        {
          "schema": 1,
          "timezone": "America/Fortaleza",
          "dailyLimit": {
            "enabled": true,
            "minutes": 150,
            "perWeekday": { "6": 240, "7": 240 },
            "resetTime": "00:00",
            "warnAtMinutes": [15, 5]
          },
          "allowedHours": {
            "enabled": false,
            "windows": [ { "days": [1, 2, 3, 4, 5], "start": "07:00", "end": "20:30" } ]
          },
          "blockPeriods": [
            { "id": "a", "label": "Hora de dormir", "enabled": true, "kind": "weekly",
              "days": [1, 2, 3, 4, 5, 6, 7], "start": "21:00", "end": "07:00" },
            { "id": "b", "label": "Estudo para a prova", "enabled": true, "kind": "once",
              "startAt": 1000, "endAt": 2000 }
          ],
          "apps": {
            "defaultForNewApps": "allowed",
            "rules": {
              "com.whatsapp": { "state": "exception", "countsTowardLimit": false, "dailyLimitMinutes": null },
              "com.example.jogo": { "state": "blocked" },
              "com.google.android.youtube": { "state": "allowed", "dailyLimitMinutes": 45 }
            }
          },
          "web": {
            "managedBrowser": true, "logHistory": true, "safeDns": true, "safeSearch": true,
            "mode": "blocklist",
            "blockedDomains": ["Exemplo.com", "*.ruim.net."], "allowedDomains": [],
            "blockedCategories": ["adult", "gambling"]
          },
          "protection": {
            "lockOnTamper": false,
            "blockUninstall": true, "blockSafeBoot": true, "blockFactoryReset": true,
            "blockDateTimeChange": true, "blockAddUser": true,
            "blockUnknownSources": false, "blockUsbDebugging": false
          },
          "overrides": {
            "extraTime": [ { "id": "x", "day": "2026-11-17", "minutes": 30, "grantedAt": 5 } ],
            "manualLock": { "active": false, "until": null, "setAt": null },
            "suspension": { "until": 0, "scopes": [], "setAt": null }
          }
        }
        """.trimIndent()

    @Test
    fun leOExemploCompletoDoProtocolo() {
        val p = PolicyParser.parse(protocolExample)
        assertEquals(1, p.schema)
        assertEquals("America/Fortaleza", p.timezone)

        assertTrue(p.dailyLimit.enabled)
        assertEquals(150, p.dailyLimit.minutes)
        assertEquals(mapOf(6 to 240, 7 to 240), p.dailyLimit.perWeekday)
        assertEquals(240, p.dailyLimit.minutesFor(6))
        assertEquals(150, p.dailyLimit.minutesFor(2))
        assertEquals(0, p.dailyLimit.resetMinutes)
        assertEquals(listOf(15, 5), p.dailyLimit.warnAtMinutes)

        assertFalse(p.allowedHours.enabled)
        assertEquals(TimeWindow(setOf(1, 2, 3, 4, 5), 420, 1230), p.allowedHours.windows.single())

        assertEquals(2, p.blockPeriods.size)
        val weekly = p.blockPeriods[0] as WeeklyBlockPeriod
        assertEquals("Hora de dormir", weekly.label)
        assertEquals(21 * 60, weekly.startMinutes)
        assertEquals(7 * 60, weekly.endMinutes)
        assertEquals(7, weekly.days.size)
        val once = p.blockPeriods[1] as OnceBlockPeriod
        assertEquals(1000L, once.startAtMs)
        assertEquals(2000L, once.endAtMs)

        assertFalse(p.apps.blockNewApps)
        assertEquals(AppRule(AppState.EXCEPTION, false, null), p.apps.rules["com.whatsapp"])
        assertEquals(AppState.BLOCKED, p.apps.rules["com.example.jogo"]!!.state)
        assertEquals(45, p.apps.rules["com.google.android.youtube"]!!.dailyLimitMinutes)

        assertTrue(p.web.managedBrowser && p.web.logHistory && p.web.safeDns && p.web.safeSearch)
        assertFalse(p.web.allowlistMode)
        assertEquals(listOf("exemplo.com", "ruim.net"), p.web.blockedDomains)
        assertEquals(setOf("adult", "gambling"), p.web.blockedCategories)

        assertFalse(p.protection.lockOnTamper)
        assertTrue(p.protection.blockUninstall)
        assertFalse(p.protection.blockUsbDebugging)

        assertEquals(ExtraTime("x", "2026-11-17", 30, 5), p.overrides.extraTime.single())
        assertFalse(p.overrides.manualLock.active)
        assertNull(p.overrides.manualLock.untilMs)
        assertEquals(0L, p.overrides.suspension.untilMs)
    }

    @Test
    fun documentoVazioRecebePadroesSeguros() {
        val p = PolicyParser.parse("{}")
        assertFalse(p.dailyLimit.enabled)
        assertFalse(p.allowedHours.enabled)
        assertTrue(p.blockPeriods.isEmpty())
        assertTrue(p.apps.rules.isEmpty())
        assertFalse(p.apps.blockNewApps)
        assertTrue(p.web.managedBrowser)
        assertFalse(p.overrides.manualLock.active)
        assertTrue(p.overrides.extraTime.isEmpty())
    }

    @Test
    fun entradasInvalidasSaoDescartadasSemDerrubarODocumento() {
        val json =
            """
            {
              "dailyLimit": { "enabled": true, "minutes": 99999, "resetTime": "25:99",
                "perWeekday": { "0": 10, "8": 10, "x": 10, "3": -5, "4": 90 },
                "warnAtMinutes": [0, 5, 5, 500, 10, 20, 30, 40] },
              "allowedHours": { "enabled": true, "windows": [
                { "days": [1], "start": "10:00", "end": "09:00" },
                { "days": [], "start": "08:00", "end": "09:00" },
                { "days": [2, 9], "start": "08:00", "end": "24:00" } ] },
              "blockPeriods": [
                { "label": "sem id", "kind": "weekly", "days": [1], "start": "01:00", "end": "02:00" },
                { "id": "k", "kind": "desconhecido" },
                { "id": "w", "kind": "weekly", "days": [1], "start": "xx", "end": "02:00" },
                { "id": "o", "kind": "once", "startAt": 20, "endAt": 10 },
                { "id": "ok", "kind": "weekly", "days": [1], "start": "01:00", "end": "02:00" } ],
              "apps": { "defaultForNewApps": "blocked", "rules": {
                "a": { "state": "talvez" }, "b": "texto", "c": { "state": "allowed", "dailyLimitMinutes": 0 } } },
              "overrides": { "extraTime": [ { "day": "2026-11-17", "minutes": -3 }, { "minutes": 5 } ],
                "manualLock": { "active": true, "until": 123 },
                "suspension": { "until": 999, "scopes": ["dailyLimit", "inventado", "schedules"] } }
            }
            """.trimIndent()
        val p = PolicyParser.parse(json)
        assertEquals(1440, p.dailyLimit.minutes)
        assertEquals(0, p.dailyLimit.resetMinutes)
        assertEquals(mapOf(3 to 0, 4 to 90), p.dailyLimit.perWeekday)
        assertEquals(listOf(5, 10, 20, 30), p.dailyLimit.warnAtMinutes)
        assertEquals(listOf(TimeWindow(setOf(2), 480, 1440)), p.allowedHours.windows)
        assertEquals(listOf("ok"), p.blockPeriods.map { it.id })
        assertTrue(p.apps.blockNewApps)
        assertEquals(setOf("c"), p.apps.rules.keys)
        assertNull(p.apps.rules["c"]!!.dailyLimitMinutes)
        assertTrue(p.overrides.extraTime.isEmpty())
        assertTrue(p.overrides.manualLock.active)
        assertEquals(123L, p.overrides.manualLock.untilMs)
        assertEquals(setOf(SuspensionScope.DAILY_LIMIT, SuspensionScope.SCHEDULES), p.overrides.suspension.scopes)
    }

    @Test
    fun modoAllowlistEReconhecido() {
        val p = PolicyParser.parse("""{ "web": { "mode": "allowlist", "allowedDomains": ["wikipedia.org"] } }""")
        assertTrue(p.web.allowlistMode)
        assertEquals(listOf("wikipedia.org"), p.web.allowedDomains)
    }

    @Test
    fun textoQueNaoEJsonFalha() {
        for (bad in listOf("", "não é json", "[1, 2]", "null")) {
            try {
                PolicyParser.parse(bad)
                fail("deveria falhar: $bad")
            } catch (expected: PolicyParseException) {
                // esperado
            }
        }
    }

    @Test
    fun schemaMaisNovoERecusado() {
        try {
            PolicyParser.parse("""{ "schema": 2 }""")
            fail("deveria recusar schema desconhecido")
        } catch (expected: PolicyParseException) {
            assertTrue(expected.message!!.contains("schema"))
        }
    }

    @Test
    fun horarioDoDia() {
        assertEquals(0, PolicyParser.parseTimeOfDay("00:00"))
        assertEquals(23 * 60 + 59, PolicyParser.parseTimeOfDay("23:59"))
        assertEquals(7 * 60 + 5, PolicyParser.parseTimeOfDay("7:05"))
        assertNull(PolicyParser.parseTimeOfDay("24:00"))
        assertEquals(1440, PolicyParser.parseTimeOfDay("24:00", allow24 = true))
        assertNull(PolicyParser.parseTimeOfDay("24:01", allow24 = true))
        assertNull(PolicyParser.parseTimeOfDay("12:60"))
        assertNull(PolicyParser.parseTimeOfDay("meio-dia"))
        assertNull(PolicyParser.parseTimeOfDay(null))
    }
}
