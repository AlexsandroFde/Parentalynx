package com.parentalynx.app.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Banco local do agente (SQLite na área privada do app, protegida pela criptografia de arquivos
 * do Android). Guarda o uso por dia e por app, as filas de saída, os pedidos de tempo e o estado
 * do motor. Segredos não ficam aqui: vão para o [com.parentalynx.app.core.SecureStore].
 */
class AgentDatabase(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {
    override fun onConfigure(db: SQLiteDatabase) {
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE kv (k TEXT PRIMARY KEY NOT NULL, v TEXT NOT NULL)")
        db.execSQL(
            """
            CREATE TABLE usage_day (
                day TEXT PRIMARY KEY NOT NULL,
                quota_ms INTEGER NOT NULL DEFAULT 0,
                total_ms INTEGER NOT NULL DEFAULT 0,
                limit_ms INTEGER,
                extra_ms INTEGER NOT NULL DEFAULT 0,
                limit_reached_at INTEGER,
                first_use_at INTEGER,
                last_use_at INTEGER,
                hourly TEXT NOT NULL DEFAULT '',
                flags TEXT NOT NULL DEFAULT '{}',
                rev INTEGER NOT NULL DEFAULT 0,
                synced_rev INTEGER NOT NULL DEFAULT -1
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE usage_app (
                day TEXT NOT NULL,
                package TEXT NOT NULL,
                ms INTEGER NOT NULL DEFAULT 0,
                opens INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (day, package)
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE outbox_session (
                seq INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT NOT NULL UNIQUE,
                package TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                day TEXT NOT NULL,
                tz_offset_min INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE outbox_event (
                seq INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT NOT NULL UNIQUE,
                type TEXT NOT NULL,
                ts INTEGER NOT NULL,
                package TEXT,
                data TEXT NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE outbox_browsing (
                seq INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT NOT NULL UNIQUE,
                ts INTEGER NOT NULL,
                url TEXT NOT NULL,
                domain TEXT NOT NULL,
                title TEXT,
                blocked INTEGER NOT NULL,
                reason TEXT
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE time_request (
                id TEXT PRIMARY KEY NOT NULL,
                created_at INTEGER NOT NULL,
                minutes INTEGER,
                message TEXT,
                status TEXT NOT NULL,
                granted_minutes INTEGER,
                resolved_at INTEGER,
                delivered INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent(),
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Versão 1: ainda não há migrações.
    }

    /** Executa o bloco em uma transação. */
    inline fun <T> transaction(block: (SQLiteDatabase) -> T): T {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val result = block(db)
            db.setTransactionSuccessful()
            return result
        } finally {
            db.endTransaction()
        }
    }

    /** Apaga todos os dados do agente (desvinculação). */
    fun wipe() {
        transaction { db ->
            for (table in TABLES) db.delete(table, null, null)
        }
    }

    companion object {
        private const val DB_NAME = "agent.db"
        private const val DB_VERSION = 1
        private val TABLES =
            listOf("kv", "usage_day", "usage_app", "outbox_session", "outbox_event", "outbox_browsing", "time_request")
    }
}
