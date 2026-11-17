package com.parentalynx.app.sync

import com.parentalynx.app.apps.InventoryItem
import com.parentalynx.app.core.putNullable
import com.parentalynx.app.data.BrowsingRow
import com.parentalynx.app.data.DaySnapshot
import com.parentalynx.app.data.EventRow
import com.parentalynx.app.data.SessionRow
import com.parentalynx.app.enforcement.EngineSnapshot
import com.parentalynx.app.permissions.PermissionState
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/** Dados do aparelho que entram em `SyncRequest.status` além do retrato do motor. */
data class DeviceStatusInfo(
    val batteryPercent: Int?,
    val appVersion: String,
    val sdkInt: Int,
    val timezone: String,
    val tzOffsetMin: Int,
)

/**
 * Monta os corpos JSON das rotas do aparelho no formato de `docs/03-protocolo.md`, seção 5. Puro:
 * recebe os dados já lidos e devolve JSON, para ser testado na JVM.
 */
object SyncPayloads {
    const val MAX_SESSIONS = 500
    const val MAX_EVENTS = 500
    const val MAX_BROWSING = 500
    const val MAX_DAYS = 8

    fun syncRequest(
        sentAtMs: Long,
        policyVersion: Long,
        policyAppliedAtMs: Long?,
        snapshot: EngineSnapshot,
        permissions: PermissionState,
        device: DeviceStatusInfo,
        days: List<DaySnapshot>,
        sessions: List<SessionRow>,
        events: List<EventRow>,
        browsing: List<BrowsingRow>,
    ): JSONObject {
        val body = JSONObject()
        body.put("sentAt", sentAtMs)
        body.put("policyVersion", policyVersion)
        body.putNullable("policyAppliedAt", policyAppliedAtMs)
        body.put("status", status(snapshot, permissions, device))
        body.put("days", JSONArray().also { array -> days.forEach { array.put(it.json) } })
        body.put("sessions", JSONArray().also { array -> sessions.forEach { array.put(session(it)) } })
        body.put("events", JSONArray().also { array -> events.forEach { array.put(event(it)) } })
        body.put("browsing", JSONArray().also { array -> browsing.forEach { array.put(browsingEntry(it)) } })
        return body
    }

    fun status(snapshot: EngineSnapshot, permissions: PermissionState, device: DeviceStatusInfo): JSONObject {
        val perms =
            JSONObject()
                .put("usageAccess", permissions.usageAccess)
                .put("accessibility", permissions.accessibility)
                .put("overlay", permissions.overlay)
                .put("notifications", permissions.notifications)
                .put("batteryOptimizationIgnored", permissions.batteryOptimizationIgnored)
                .put("deviceAdmin", permissions.deviceAdmin)
                .put("exactAlarms", permissions.exactAlarms)
        val enforcement =
            JSONObject()
                .put("active", snapshot.active && permissions.canDetect && permissions.canBlock)
                .put("issues", JSONArray(snapshot.issues))
        val lock =
            JSONObject()
                .put("state", snapshot.lock.kind.wire)
                .putNullable("releaseAt", snapshot.lock.releaseAtMs)
        return JSONObject()
            .put("managementMode", permissions.managementMode)
            .put("permissions", perms)
            .put("enforcement", enforcement)
            .put("lock", lock)
            .putNullable("foregroundApp", snapshot.foregroundApp)
            .put("screenOn", snapshot.screenOn)
            .putNullable("batteryPercent", device.batteryPercent)
            .put("appVersion", device.appVersion)
            .put("sdkInt", device.sdkInt)
            .put("timezone", device.timezone)
            .put("tzOffsetMin", device.tzOffsetMin)
            .put("clockTrusted", snapshot.clockTrusted)
    }

    fun session(row: SessionRow): JSONObject =
        JSONObject()
            .put("id", row.id)
            .put("package", row.appId)
            .put("start", row.startMs)
            .put("end", row.endMs)
            .put("day", row.day)
            .put("tzOffsetMin", row.tzOffsetMin)

    fun event(row: EventRow): JSONObject {
        val data =
            try {
                JSONObject(row.dataJson)
            } catch (e: JSONException) {
                JSONObject()
            }
        val json = JSONObject().put("id", row.id).put("type", row.type).put("ts", row.tsMs)
        if (row.appId != null) json.put("package", row.appId)
        return json.put("data", data)
    }

    fun browsingEntry(row: BrowsingRow): JSONObject =
        JSONObject()
            .put("id", row.id)
            .put("ts", row.tsMs)
            .put("url", row.url)
            .put("domain", row.domain)
            .putNullable("title", row.title)
            .put("blocked", row.blocked)
            .putNullable("reason", row.reason)

    fun inventory(items: List<InventoryItem>): JSONObject {
        val apps = JSONArray()
        for (item in items) {
            val entry = item.entry
            apps.put(
                JSONObject()
                    .put("package", entry.appId)
                    .put("label", entry.label)
                    .put("category", entry.category)
                    .put("system", entry.system)
                    .put("launchable", entry.launchable)
                    .put("essential", entry.essential)
                    .putNullable("versionName", item.versionName)
                    .put("installedAt", item.installedAtMs)
                    .put("updatedAt", item.updatedAtMs)
                    .putNullable("iconHash", item.iconHash),
            )
        }
        return JSONObject().put("full", true).put("apps", apps)
    }
}
