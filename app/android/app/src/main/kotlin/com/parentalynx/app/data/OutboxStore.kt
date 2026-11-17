package com.parentalynx.app.data

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase

class SessionRow(
    val id: String,
    val appId: String,
    val startMs: Long,
    val endMs: Long,
    val day: String,
    val tzOffsetMin: Int,
)

class EventRow(val id: String, val type: String, val tsMs: Long, val appId: String?, val dataJson: String)

class BrowsingRow(
    val id: String,
    val tsMs: Long,
    val url: String,
    val domain: String,
    val title: String?,
    val blocked: Boolean,
    val reason: String?,
)

/** Destino das sessões de uso encerradas. Separado para testar o gravador na JVM. */
fun interface SessionWriter {
    fun addSession(row: SessionRow)
}

/**
 * Filas de saída: sessões de uso, eventos e histórico do navegador gerenciado. Um item só sai da
 * fila quando o servidor confirma o recebimento (`ack`), então nada se perde sem conexão.
 */
class OutboxStore(private val database: AgentDatabase) : SessionWriter {
    override fun addSession(row: SessionRow) {
        val values =
            ContentValues().apply {
                put("id", row.id)
                put("package", row.appId)
                put("start_ms", row.startMs)
                put("end_ms", row.endMs)
                put("day", row.day)
                put("tz_offset_min", row.tzOffsetMin)
            }
        database.writableDatabase.insertWithOnConflict("outbox_session", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun addEvent(row: EventRow) {
        val values =
            ContentValues().apply {
                put("id", row.id)
                put("type", row.type)
                put("ts", row.tsMs)
                if (row.appId == null) putNull("package") else put("package", row.appId)
                put("data", row.dataJson)
            }
        database.writableDatabase.insertWithOnConflict("outbox_event", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun addBrowsing(row: BrowsingRow) {
        val values =
            ContentValues().apply {
                put("id", row.id)
                put("ts", row.tsMs)
                put("url", row.url)
                put("domain", row.domain)
                if (row.title == null) putNull("title") else put("title", row.title)
                put("blocked", if (row.blocked) 1 else 0)
                if (row.reason == null) putNull("reason") else put("reason", row.reason)
            }
        database.writableDatabase.insertWithOnConflict("outbox_browsing", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun sessions(limit: Int): List<SessionRow> =
        database.readableDatabase
            .rawQuery(
                "SELECT id, package, start_ms, end_ms, day, tz_offset_min FROM outbox_session ORDER BY seq LIMIT ?",
                arrayOf(limit.toString()),
            ).use { c ->
                val out = ArrayList<SessionRow>(c.count)
                while (c.moveToNext()) {
                    out.add(SessionRow(c.getString(0), c.getString(1), c.getLong(2), c.getLong(3), c.getString(4), c.getInt(5)))
                }
                out
            }

    fun events(limit: Int): List<EventRow> =
        database.readableDatabase
            .rawQuery("SELECT id, type, ts, package, data FROM outbox_event ORDER BY seq LIMIT ?", arrayOf(limit.toString()))
            .use { c ->
                val out = ArrayList<EventRow>(c.count)
                while (c.moveToNext()) {
                    out.add(
                        EventRow(c.getString(0), c.getString(1), c.getLong(2), if (c.isNull(3)) null else c.getString(3), c.getString(4)),
                    )
                }
                out
            }

    fun browsing(limit: Int): List<BrowsingRow> =
        database.readableDatabase
            .rawQuery(
                "SELECT id, ts, url, domain, title, blocked, reason FROM outbox_browsing ORDER BY seq LIMIT ?",
                arrayOf(limit.toString()),
            ).use { c ->
                val out = ArrayList<BrowsingRow>(c.count)
                while (c.moveToNext()) {
                    out.add(
                        BrowsingRow(
                            id = c.getString(0),
                            tsMs = c.getLong(1),
                            url = c.getString(2),
                            domain = c.getString(3),
                            title = if (c.isNull(4)) null else c.getString(4),
                            blocked = c.getInt(5) != 0,
                            reason = if (c.isNull(6)) null else c.getString(6),
                        ),
                    )
                }
                out
            }

    fun ackSessions(ids: Collection<String>) = deleteByIds("outbox_session", ids)

    fun ackEvents(ids: Collection<String>) = deleteByIds("outbox_event", ids)

    fun ackBrowsing(ids: Collection<String>) = deleteByIds("outbox_browsing", ids)

    fun pendingCount(): Int =
        count("outbox_session") + count("outbox_event") + count("outbox_browsing")

    /**
     * Limita o tamanho das filas quando o aparelho passa muito tempo sem sincronizar: descarta os
     * itens mais antigos além de [maxRows] por fila.
     */
    fun trim(maxRows: Int) {
        val db = database.writableDatabase
        for (table in TABLES) {
            db.execSQL(
                "DELETE FROM $table WHERE seq IN (SELECT seq FROM $table ORDER BY seq DESC LIMIT -1 OFFSET ?)",
                arrayOf(maxRows),
            )
        }
    }

    private fun count(table: String): Int =
        database.readableDatabase.rawQuery("SELECT COUNT(*) FROM $table", null).use { c ->
            if (c.moveToFirst()) c.getInt(0) else 0
        }

    private fun deleteByIds(table: String, ids: Collection<String>) {
        if (ids.isEmpty()) return
        database.transaction { db ->
            for (id in ids) db.delete(table, "id = ?", arrayOf(id))
        }
    }

    private companion object {
        val TABLES = listOf("outbox_session", "outbox_event", "outbox_browsing")
    }
}
