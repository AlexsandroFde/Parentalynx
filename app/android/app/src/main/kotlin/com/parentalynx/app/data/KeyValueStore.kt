package com.parentalynx.app.data

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

/** Estado do motor em pares de chave e valor, na mesma base (e transação) dos contadores de uso. */
class KeyValueStore(private val database: AgentDatabase) {
    fun getString(key: String): String? =
        database.readableDatabase
            .rawQuery("SELECT v FROM kv WHERE k = ?", arrayOf(key))
            .use { c -> if (c.moveToFirst()) c.getString(0) else null }

    fun getLong(key: String): Long? = getString(key)?.toLongOrNull()

    fun putString(key: String, value: String) {
        put(database.writableDatabase, key, value)
    }

    fun putLong(key: String, value: Long) {
        putString(key, value.toString())
    }

    fun remove(key: String) {
        database.writableDatabase.delete("kv", "k = ?", arrayOf(key))
    }

    /** Grava dentro de uma transação já aberta. */
    fun put(db: SQLiteDatabase, key: String, value: String) {
        val values =
            ContentValues().apply {
                put("k", key)
                put("v", value)
            }
        db.insertWithOnConflict("kv", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    companion object {
        const val TRACKER_STATE = "tracker.state"
        const val CURSOR_TS = "source.cursor_ts"
        const val CURSOR_SEEN = "source.cursor_seen"
        const val HEARTBEAT = "engine.heartbeat"
        const val BOOT_ID = "engine.boot_id"
        const val POLL_WALL = "engine.poll_wall"
        const val POLL_ELAPSED = "engine.poll_elapsed"
        const val RECORD_FROM = "engine.record_from"
        const val LOCK_KIND = "engine.lock_kind"
        const val LOCK_SINCE = "engine.lock_since"
        const val PERMISSIONS = "engine.permissions"
        const val MANAGEMENT_MODE = "engine.management_mode"
        const val KNOWN_PACKAGES = "engine.known_packages"
        const val SUSPENDED_PACKAGES = "owner.suspended"
        const val POLICY_JSON = "policy.json"
        const val POLICY_VERSION = "policy.version"
        const val POLICY_APPLIED_AT = "policy.applied_at"
        const val CLOCK_STATE = "clock.state"
    }
}
