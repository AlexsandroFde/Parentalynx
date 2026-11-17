package com.parentalynx.app.data

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

class TimeRequestRow(
    val id: String,
    val createdAtMs: Long,
    val minutes: Int?,
    val message: String?,
    val status: String,
    val grantedMinutes: Int?,
    val resolvedAtMs: Long?,
    val delivered: Boolean,
)

/** Pedidos de tempo adicional feitos pela criança. O identificador é o do evento `time_request`. */
class TimeRequestStore(private val database: AgentDatabase) {
    fun add(id: String, createdAtMs: Long, minutes: Int?, message: String?) {
        val values =
            ContentValues().apply {
                put("id", id)
                put("created_at", createdAtMs)
                if (minutes == null) putNull("minutes") else put("minutes", minutes)
                if (message == null) putNull("message") else put("message", message)
                put("status", STATUS_PENDING)
                put("delivered", 0)
            }
        database.writableDatabase.insertWithOnConflict("time_request", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun recent(limit: Int): List<TimeRequestRow> =
        database.readableDatabase
            .rawQuery(
                "SELECT id, created_at, minutes, message, status, granted_minutes, resolved_at, delivered " +
                    "FROM time_request ORDER BY created_at DESC LIMIT ?",
                arrayOf(limit.toString()),
            ).use { c ->
                val out = ArrayList<TimeRequestRow>(c.count)
                while (c.moveToNext()) {
                    out.add(
                        TimeRequestRow(
                            id = c.getString(0),
                            createdAtMs = c.getLong(1),
                            minutes = if (c.isNull(2)) null else c.getInt(2),
                            message = if (c.isNull(3)) null else c.getString(3),
                            status = c.getString(4),
                            grantedMinutes = if (c.isNull(5)) null else c.getInt(5),
                            resolvedAtMs = if (c.isNull(6)) null else c.getLong(6),
                            delivered = c.getInt(7) != 0,
                        ),
                    )
                }
                out
            }

    /** Marca como entregues os pedidos cujos eventos o servidor confirmou. */
    fun markDelivered(ids: Collection<String>) {
        if (ids.isEmpty()) return
        val values = ContentValues().apply { put("delivered", 1) }
        database.transaction { db ->
            for (id in ids) db.update("time_request", values, "id = ?", arrayOf(id))
        }
    }

    /**
     * Atualiza a resposta do responsável.
     *
     * @return verdadeiro se o estado mudou (para avisar a criança uma única vez).
     */
    fun updateStatus(id: String, status: String, grantedMinutes: Int?, resolvedAtMs: Long?): Boolean {
        val current =
            database.readableDatabase
                .rawQuery("SELECT status FROM time_request WHERE id = ?", arrayOf(id))
                .use { c -> if (c.moveToFirst()) c.getString(0) else null }
                ?: return false
        if (current == status) return false
        val values =
            ContentValues().apply {
                put("status", status)
                put("delivered", 1)
                if (grantedMinutes == null) putNull("granted_minutes") else put("granted_minutes", grantedMinutes)
                if (resolvedAtMs == null) putNull("resolved_at") else put("resolved_at", resolvedAtMs)
            }
        database.writableDatabase.update("time_request", values, "id = ?", arrayOf(id))
        return true
    }

    /** Há pedido pendente criado depois de [sinceMs]? Evita pedidos repetidos em sequência. */
    fun hasPendingSince(sinceMs: Long): Boolean =
        database.readableDatabase
            .rawQuery(
                "SELECT COUNT(*) FROM time_request WHERE status = ? AND created_at >= ?",
                arrayOf(STATUS_PENDING, sinceMs.toString()),
            ).use { c -> c.moveToFirst() && c.getInt(0) > 0 }

    fun prune(olderThanMs: Long) {
        database.writableDatabase.delete("time_request", "created_at < ?", arrayOf(olderThanMs.toString()))
    }

    companion object {
        const val STATUS_PENDING = "pending"
        const val STATUS_APPROVED = "approved"
        const val STATUS_DENIED = "denied"
        const val STATUS_EXPIRED = "expired"
    }
}
