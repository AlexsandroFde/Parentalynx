package com.parentalynx.app.sync

import com.parentalynx.app.apps.CatalogEntry
import com.parentalynx.app.apps.InventoryItem
import com.parentalynx.app.data.BrowsingRow
import com.parentalynx.app.data.DaySnapshot
import com.parentalynx.app.data.EventRow
import com.parentalynx.app.data.SessionRow
import com.parentalynx.app.enforcement.EngineSnapshot
import com.parentalynx.app.permissions.PermissionState
import com.parentalynx.app.policy.DeviceLock
import com.parentalynx.app.policy.LockKind
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Nomes dos campos de um objeto JSON (a classe do Android não tem keySet). */
private fun JSONObject.fieldNames(): Set<String> = keys().asSequence().toSet()

/** Formato dos corpos enviados ao servidor (`docs/03-protocolo.md`, seção 5) e cliente HTTP. */
class SyncPayloadsTest {
    private val permissions =
        PermissionState(
            usageAccess = true, accessibility = true, overlay = false, notifications = true,
            batteryOptimizationIgnored = true, deviceAdmin = false, deviceOwner = false, exactAlarms = true,
        )
    private val snapshot =
        EngineSnapshot.INACTIVE.copy(
            active = true,
            day = "2026-11-17",
            lock = DeviceLock(LockKind.DAILY_LIMIT, releaseAtMs = 123L),
            issues = listOf("overlay_missing"),
            foregroundApp = "com.whatsapp",
            screenOn = true,
            clockTrusted = true,
        )
    private val device = DeviceStatusInfo(batteryPercent = 80, appVersion = "1.0.0", sdkInt = 34, timezone = "America/Fortaleza", tzOffsetMin = -180)

    @Test
    fun corpoDaSincronizacaoSegueOProtocolo() {
        val day = DaySnapshot("2026-11-17", 3, JSONObject().put("day", "2026-11-17").put("quotaUsedMs", 10))
        val body =
            SyncPayloads.syncRequest(
                sentAtMs = 1000,
                policyVersion = 12,
                policyAppliedAtMs = null,
                snapshot = snapshot,
                permissions = permissions,
                device = device,
                days = listOf(day),
                sessions = listOf(SessionRow("s1", "com.whatsapp", 1, 2, "2026-11-17", -180)),
                events = listOf(EventRow("e1", "blocked_attempt", 5, "com.exemplo.jogo", """{"reason":"app_blocked"}"""), EventRow("e2", "device_boot", 6, null, "inválido")),
                browsing = listOf(BrowsingRow("b1", 7, "https://exemplo.com/a", "exemplo.com", null, true, "category")),
            )
        assertEquals(1000L, body.getLong("sentAt"))
        assertEquals(12L, body.getLong("policyVersion"))
        assertTrue(body.isNull("policyAppliedAt"))

        val status = body.getJSONObject("status")
        assertEquals("standard", status.getString("managementMode"))
        assertEquals(setOf("usageAccess", "accessibility", "overlay", "notifications", "batteryOptimizationIgnored", "deviceAdmin", "exactAlarms"), status.getJSONObject("permissions").fieldNames())
        assertTrue(status.getJSONObject("enforcement").getBoolean("active"))
        assertEquals("overlay_missing", status.getJSONObject("enforcement").getJSONArray("issues").getString(0))
        assertEquals("daily_limit", status.getJSONObject("lock").getString("state"))
        assertEquals(123L, status.getJSONObject("lock").getLong("releaseAt"))
        assertEquals("com.whatsapp", status.getString("foregroundApp"))
        assertEquals(80, status.getInt("batteryPercent"))
        assertEquals(-180, status.getInt("tzOffsetMin"))
        assertTrue(status.getBoolean("clockTrusted"))

        assertEquals("2026-11-17", body.getJSONArray("days").getJSONObject(0).getString("day"))
        val session = body.getJSONArray("sessions").getJSONObject(0)
        assertEquals(setOf("id", "package", "start", "end", "day", "tzOffsetMin"), session.fieldNames())
        val events = body.getJSONArray("events")
        assertEquals("app_blocked", events.getJSONObject(0).getJSONObject("data").getString("reason"))
        assertEquals("com.exemplo.jogo", events.getJSONObject(0).getString("package"))
        assertFalse("evento sem app não leva o campo", events.getJSONObject(1).has("package"))
        assertEquals("dados ilegíveis viram objeto vazio", 0, events.getJSONObject(1).getJSONObject("data").length())
        val visit = body.getJSONArray("browsing").getJSONObject(0)
        assertTrue(visit.isNull("title"))
        assertTrue(visit.getBoolean("blocked"))
        assertEquals("category", visit.getString("reason"))
    }

    @Test
    fun aplicacaoNaoEstaAtivaSemMeioDeDetectarOuDeBloquear() {
        val blind = permissions.copy(usageAccess = false, accessibility = false)
        assertFalse(SyncPayloads.status(snapshot, blind, device).getJSONObject("enforcement").getBoolean("active"))
        val owner = blind.copy(usageAccess = true, deviceOwner = true)
        val status = SyncPayloads.status(snapshot, owner, device)
        assertTrue(status.getJSONObject("enforcement").getBoolean("active"))
        assertEquals("device_owner", status.getString("managementMode"))
        assertEquals("device_admin", SyncPayloads.status(snapshot, permissions.copy(deviceAdmin = true), device).getString("managementMode"))
    }

    @Test
    fun inventarioSegueOProtocolo() {
        val entry = CatalogEntry("com.whatsapp", "com.whatsapp", "WhatsApp", system = false, launchable = true, essential = false, tracked = true, category = "communication")
        val body = SyncPayloads.inventory(listOf(InventoryItem(entry, "2.24", 10, 20, "abcdef0123456789")))
        assertTrue(body.getBoolean("full"))
        val app = body.getJSONArray("apps").getJSONObject(0)
        assertEquals(
            setOf("package", "label", "category", "system", "launchable", "essential", "versionName", "installedAt", "updatedAt", "iconHash"),
            app.fieldNames(),
        )
        assertEquals("communication", app.getString("category"))
    }

    @Test
    fun clienteHttpTraduzSucessoErroDoProtocoloEFalhaDeRede() {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody("""{"serverTime":5}"""))
        server.enqueue(MockResponse().setResponseCode(204))
        server.enqueue(
            MockResponse().setResponseCode(423).setBody("""{"error":{"code":"account_locked","message":"Bloqueado.","details":{"retryAfterSec":60}}}"""),
        )
        server.enqueue(MockResponse().setResponseCode(401).setBody("""{"error":{"code":"device_revoked","message":"Revogado."}}"""))
        server.start()
        val base = server.url("/api/").toString()
        val client = ApiClient(ApiClient.newHttpClient())

        val ok = client.postJson(base, "/v1/device/sync", "dv_token", JSONObject().put("a", 1)) as ApiResult.Ok
        assertEquals(5L, ok.body.getLong("serverTime"))
        val request = server.takeRequest()
        assertEquals("/api/v1/device/sync", request.path)
        assertEquals("Bearer dv_token", request.getHeader("Authorization"))
        assertEquals("""{"a":1}""", request.body.readUtf8())

        val empty = client.putBytes(base, "/v1/device/apps/icon", mapOf("package" to "com.a b", "hash" to "h"), "t", "image/png", byteArrayOf(1, 2)) as ApiResult.Ok
        assertEquals(0, empty.body.length())
        assertEquals("/api/v1/device/apps/icon?package=com.a%20b&hash=h", server.takeRequest().path)

        val locked = client.postJson(base, "/v1/device/admin-verify", "t", JSONObject()) as ApiResult.Error
        assertFalse(locked.network)
        assertEquals(423, locked.status)
        assertEquals("account_locked", locked.code)
        assertEquals(60L, locked.retryAfterSec)

        val revoked = client.get(base, "/v1/guardian/alerts", emptyMap(), "t") as ApiResult.Error
        assertEquals(ApiResult.CODE_DEVICE_REVOKED, revoked.wireCode)

        server.shutdown()
        val offline = client.get(base, "/v1/meta", emptyMap(), null) as ApiResult.Error
        assertTrue(offline.network)
        assertEquals("network", offline.wireCode)
        assertTrue((client.get("isto não é url", "/x", emptyMap(), null) as ApiResult.Error).network)
    }
}
