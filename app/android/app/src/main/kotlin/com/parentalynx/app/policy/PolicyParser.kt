package com.parentalynx.app.policy

import com.parentalynx.app.core.arrayOrEmpty
import com.parentalynx.app.core.booleanOr
import com.parentalynx.app.core.intOrNull
import com.parentalynx.app.core.ints
import com.parentalynx.app.core.longOrNull
import com.parentalynx.app.core.objectOrNull
import com.parentalynx.app.core.objects
import com.parentalynx.app.core.stringOrNull
import com.parentalynx.app.core.strings
import org.json.JSONException
import org.json.JSONObject

class PolicyParseException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Leitor tolerante da política.
 *
 * Campos ausentes recebem o padrão, valores fora da faixa são limitados e entradas individuais
 * inválidas (um período ou uma regra) são descartadas sem derrubar o documento. Só falha quando o
 * texto não é um objeto JSON ou quando o `schema` é mais novo do que este app entende.
 */
object PolicyParser {
    const val SUPPORTED_SCHEMA = 1
    private const val MINUTES_PER_DAY = 1440

    fun parse(json: String): Policy {
        val root =
            try {
                JSONObject(json)
            } catch (e: JSONException) {
                throw PolicyParseException("política não é um objeto JSON", e)
            }
        val schema = root.intOrNull("schema") ?: SUPPORTED_SCHEMA
        if (schema > SUPPORTED_SCHEMA) {
            throw PolicyParseException("schema $schema não suportado por esta versão do app")
        }
        return Policy(
            schema = schema,
            timezone = root.stringOrNull("timezone").orEmpty(),
            dailyLimit = parseDailyLimit(root.objectOrNull("dailyLimit")),
            allowedHours = parseAllowedHours(root.objectOrNull("allowedHours")),
            blockPeriods = root.arrayOrEmpty("blockPeriods").objects().mapNotNull(::parseBlockPeriod),
            apps = parseApps(root.objectOrNull("apps")),
            web = parseWeb(root.objectOrNull("web")),
            protection = parseProtection(root.objectOrNull("protection")),
            overrides = parseOverrides(root.objectOrNull("overrides")),
        )
    }

    /** Converte `HH:mm` em minutos desde a meia-noite. Aceita `24:00` quando [allow24] é verdadeiro. */
    fun parseTimeOfDay(text: String?, allow24: Boolean = false): Int? {
        if (text == null) return null
        val parts = text.trim().split(":")
        if (parts.size != 2) return null
        val hours = parts[0].toIntOrNull() ?: return null
        val minutes = parts[1].toIntOrNull() ?: return null
        if (hours == 24 && minutes == 0 && allow24) return MINUTES_PER_DAY
        if (hours !in 0..23 || minutes !in 0..59) return null
        return hours * 60 + minutes
    }

    private fun parseDailyLimit(obj: JSONObject?): DailyLimit {
        if (obj == null) return DailyLimit()
        val perWeekday = HashMap<Int, Int>()
        obj.objectOrNull("perWeekday")?.let { map ->
            for (key in map.keys()) {
                val day = key.toIntOrNull() ?: continue
                val minutes = map.intOrNull(key) ?: continue
                if (day in 1..7) perWeekday[day] = minutes.coerceIn(0, MINUTES_PER_DAY)
            }
        }
        return DailyLimit(
            enabled = obj.booleanOr("enabled", false),
            minutes = (obj.intOrNull("minutes") ?: 0).coerceIn(0, MINUTES_PER_DAY),
            perWeekday = perWeekday,
            resetMinutes = parseTimeOfDay(obj.stringOrNull("resetTime")) ?: 0,
            warnAtMinutes =
                obj.arrayOrEmpty("warnAtMinutes").ints().filter { it in 1..120 }.distinct().take(4),
        )
    }

    private fun parseDays(obj: JSONObject): Set<Int> =
        obj.arrayOrEmpty("days").ints().filter { it in 1..7 }.toSet()

    private fun parseAllowedHours(obj: JSONObject?): AllowedHours {
        if (obj == null) return AllowedHours()
        val windows =
            obj.arrayOrEmpty("windows").objects().mapNotNull { w ->
                val start = parseTimeOfDay(w.stringOrNull("start")) ?: return@mapNotNull null
                val end = parseTimeOfDay(w.stringOrNull("end"), allow24 = true) ?: return@mapNotNull null
                val days = parseDays(w)
                if (days.isEmpty() || start >= end) null else TimeWindow(days, start, end)
            }
        return AllowedHours(enabled = obj.booleanOr("enabled", false), windows = windows)
    }

    private fun parseBlockPeriod(obj: JSONObject): BlockPeriod? {
        val id = obj.stringOrNull("id") ?: return null
        val label = obj.stringOrNull("label").orEmpty()
        val enabled = obj.booleanOr("enabled", true)
        return when (obj.stringOrNull("kind")) {
            "weekly" -> {
                val start = parseTimeOfDay(obj.stringOrNull("start")) ?: return null
                val end = parseTimeOfDay(obj.stringOrNull("end"), allow24 = true) ?: return null
                val days = parseDays(obj)
                if (days.isEmpty()) null else WeeklyBlockPeriod(id, label, enabled, days, start, end)
            }
            "once" -> {
                val startAt = obj.longOrNull("startAt") ?: return null
                val endAt = obj.longOrNull("endAt") ?: return null
                if (endAt <= startAt) null else OnceBlockPeriod(id, label, enabled, startAt, endAt)
            }
            else -> null
        }
    }

    private fun parseApps(obj: JSONObject?): AppsPolicy {
        if (obj == null) return AppsPolicy()
        val rules = HashMap<String, AppRule>()
        obj.objectOrNull("rules")?.let { map ->
            for (pkg in map.keys()) {
                val rule = map.optJSONObject(pkg) ?: continue
                val state = AppState.fromWire(rule.stringOrNull("state")) ?: continue
                rules[pkg] =
                    AppRule(
                        state = state,
                        countsTowardLimit = rule.booleanOr("countsTowardLimit", false),
                        dailyLimitMinutes =
                            rule.intOrNull("dailyLimitMinutes")?.takeIf { it in 1..MINUTES_PER_DAY },
                    )
            }
        }
        return AppsPolicy(
            blockNewApps = obj.stringOrNull("defaultForNewApps") == AppState.BLOCKED.wire,
            rules = rules,
        )
    }

    private fun normalizeDomains(obj: JSONObject, key: String): List<String> =
        obj.arrayOrEmpty(key)
            .strings()
            .map { it.trim().lowercase().removePrefix("*.").trimEnd('.') }
            .filter { it.isNotEmpty() }
            .distinct()

    private fun parseWeb(obj: JSONObject?): WebPolicy {
        if (obj == null) return WebPolicy()
        return WebPolicy(
            managedBrowser = obj.booleanOr("managedBrowser", true),
            logHistory = obj.booleanOr("logHistory", true),
            safeDns = obj.booleanOr("safeDns", false),
            safeSearch = obj.booleanOr("safeSearch", false),
            allowlistMode = obj.stringOrNull("mode") == "allowlist",
            blockedDomains = normalizeDomains(obj, "blockedDomains"),
            allowedDomains = normalizeDomains(obj, "allowedDomains"),
            blockedCategories = obj.arrayOrEmpty("blockedCategories").strings().toSet(),
        )
    }

    private fun parseProtection(obj: JSONObject?): ProtectionPolicy {
        if (obj == null) return ProtectionPolicy()
        val defaults = ProtectionPolicy()
        return ProtectionPolicy(
            lockOnTamper = obj.booleanOr("lockOnTamper", defaults.lockOnTamper),
            blockUninstall = obj.booleanOr("blockUninstall", defaults.blockUninstall),
            blockSafeBoot = obj.booleanOr("blockSafeBoot", defaults.blockSafeBoot),
            blockFactoryReset = obj.booleanOr("blockFactoryReset", defaults.blockFactoryReset),
            blockDateTimeChange = obj.booleanOr("blockDateTimeChange", defaults.blockDateTimeChange),
            blockAddUser = obj.booleanOr("blockAddUser", defaults.blockAddUser),
            blockUnknownSources = obj.booleanOr("blockUnknownSources", defaults.blockUnknownSources),
            blockUsbDebugging = obj.booleanOr("blockUsbDebugging", defaults.blockUsbDebugging),
        )
    }

    private fun parseOverrides(obj: JSONObject?): Overrides {
        if (obj == null) return Overrides()
        val extra =
            obj.arrayOrEmpty("extraTime").objects().mapNotNull { e ->
                val day = e.stringOrNull("day") ?: return@mapNotNull null
                val minutes = e.intOrNull("minutes") ?: return@mapNotNull null
                if (minutes <= 0) return@mapNotNull null
                ExtraTime(
                    id = e.stringOrNull("id").orEmpty(),
                    day = day,
                    minutes = minutes,
                    grantedAtMs = e.longOrNull("grantedAt") ?: 0L,
                )
            }
        val lock = obj.objectOrNull("manualLock")
        val suspension = obj.objectOrNull("suspension")
        return Overrides(
            extraTime = extra,
            manualLock =
                ManualLock(
                    active = lock?.booleanOr("active", false) ?: false,
                    untilMs = lock?.longOrNull("until"),
                ),
            suspension =
                Suspension(
                    untilMs = suspension?.longOrNull("until") ?: 0L,
                    scopes =
                        suspension
                            ?.arrayOrEmpty("scopes")
                            ?.strings()
                            ?.mapNotNull { SuspensionScope.fromWire(it) }
                            ?.toSet()
                            ?: emptySet(),
                ),
        )
    }
}
