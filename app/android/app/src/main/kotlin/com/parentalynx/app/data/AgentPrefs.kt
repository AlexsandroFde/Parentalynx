package com.parentalynx.app.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Preferências não secretas do app: modo escolhido, dados do vínculo que não são credenciais,
 * estado da última sincronização e contadores de tentativas. Tokens e segredos ficam no
 * [com.parentalynx.app.core.SecureStore].
 */
class AgentPrefs(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Modo do app: `unset`, `guardian` ou `child`. */
    var mode: String
        get() = prefs.getString(KEY_MODE, MODE_UNSET) ?: MODE_UNSET
        set(value) = prefs.edit().putString(KEY_MODE, value).apply()

    /** Verdadeiro enquanto o aparelho está vinculado e o controle parental está ligado. */
    var active: Boolean
        get() = prefs.getBoolean(KEY_ACTIVE, false)
        set(value) {
            prefs.edit().putBoolean(KEY_ACTIVE, value).commit()
        }

    var serverUrl: String
        get() = prefs.getString(KEY_SERVER_URL, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_SERVER_URL, value).apply()

    var deviceId: String
        get() = prefs.getString(KEY_DEVICE_ID, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_DEVICE_ID, value).apply()

    var childName: String
        get() = prefs.getString(KEY_CHILD_NAME, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_CHILD_NAME, value).apply()

    var guardianName: String
        get() = prefs.getString(KEY_GUARDIAN_NAME, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_GUARDIAN_NAME, value).apply()

    /** Minutos restantes que disparam o evento `low_time` para o responsável. */
    var lowTimeMinutes: Int
        get() = prefs.getInt(KEY_LOW_TIME, 10)
        set(value) = prefs.edit().putInt(KEY_LOW_TIME, value).apply()

    var lastSyncAtMs: Long
        get() = prefs.getLong(KEY_LAST_SYNC_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_SYNC_AT, value).apply()

    var lastSyncOk: Boolean
        get() = prefs.getBoolean(KEY_LAST_SYNC_OK, false)
        set(value) = prefs.edit().putBoolean(KEY_LAST_SYNC_OK, value).apply()

    var lastSyncError: String?
        get() = prefs.getString(KEY_LAST_SYNC_ERROR, null)
        set(value) = prefs.edit().putString(KEY_LAST_SYNC_ERROR, value).apply()

    /** Instante do último envio de inventário de apps aceito pelo servidor. */
    var lastInventoryAtMs: Long
        get() = prefs.getLong(KEY_LAST_INVENTORY_AT, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_INVENTORY_AT, value).apply()

    /** Inventário mudou (app instalado ou removido) e precisa ser reenviado. */
    var inventoryDirty: Boolean
        get() = prefs.getBoolean(KEY_INVENTORY_DIRTY, true)
        set(value) = prefs.edit().putBoolean(KEY_INVENTORY_DIRTY, value).apply()

    /**
     * Verdadeiro depois que as permissões essenciais foram vistas concedidas ao mesmo tempo. A
     * partir daí, a falta de uma delas conta como adulteração.
     */
    var setupCompleted: Boolean
        get() = prefs.getBoolean(KEY_SETUP_COMPLETED, false)
        set(value) = prefs.edit().putBoolean(KEY_SETUP_COMPLETED, value).apply()

    /** Liberação local concedida pelo responsável no aparelho (hora confiável). Zero se não há. */
    var localOverrideUntilMs: Long
        get() = prefs.getLong(KEY_LOCAL_OVERRIDE, 0L)
        set(value) {
            prefs.edit().putLong(KEY_LOCAL_OVERRIDE, value).commit()
        }

    var offlineCodeFailures: Int
        get() = prefs.getInt(KEY_OFFLINE_FAILURES, 0)
        set(value) {
            prefs.edit().putInt(KEY_OFFLINE_FAILURES, value).commit()
        }

    /** Fim do bloqueio de tentativas do código offline (hora confiável). */
    var offlineCodeLockedUntilMs: Long
        get() = prefs.getLong(KEY_OFFLINE_LOCKED_UNTIL, 0L)
        set(value) {
            prefs.edit().putLong(KEY_OFFLINE_LOCKED_UNTIL, value).commit()
        }

    /** Motivo da última desativação do controle (`revoked` ou `unlinked`), para avisar na tela. */
    var lastDeactivationReason: String?
        get() = prefs.getString(KEY_DEACTIVATION_REASON, null)
        set(value) = prefs.edit().putString(KEY_DEACTIVATION_REASON, value).apply()

    // Modo responsável: busca de alertas em segundo plano.

    var guardianServerUrl: String
        get() = prefs.getString(KEY_GUARDIAN_SERVER_URL, "").orEmpty()
        set(value) = prefs.edit().putString(KEY_GUARDIAN_SERVER_URL, value).apply()

    /** Maior identificador de alerta já mostrado. -1 enquanto nunca foi definido. */
    var guardianLastSeenAlertId: Long
        get() = prefs.getLong(KEY_GUARDIAN_LAST_ALERT, -1L)
        set(value) = prefs.edit().putLong(KEY_GUARDIAN_LAST_ALERT, value).apply()

    /** Apaga os dados do vínculo do modo criança, preservando o modo escolhido. */
    fun clearChildLink() {
        prefs.edit()
            .remove(KEY_ACTIVE)
            .remove(KEY_SERVER_URL)
            .remove(KEY_DEVICE_ID)
            .remove(KEY_CHILD_NAME)
            .remove(KEY_GUARDIAN_NAME)
            .remove(KEY_LOW_TIME)
            .remove(KEY_LAST_SYNC_AT)
            .remove(KEY_LAST_SYNC_OK)
            .remove(KEY_LAST_SYNC_ERROR)
            .remove(KEY_LAST_INVENTORY_AT)
            .remove(KEY_INVENTORY_DIRTY)
            .remove(KEY_SETUP_COMPLETED)
            .remove(KEY_LOCAL_OVERRIDE)
            .remove(KEY_OFFLINE_FAILURES)
            .remove(KEY_OFFLINE_LOCKED_UNTIL)
            .commit()
    }

    companion object {
        const val MODE_UNSET = "unset"
        const val MODE_GUARDIAN = "guardian"
        const val MODE_CHILD = "child"

        private const val PREFS_NAME = "plx_agent"
        private const val KEY_MODE = "mode"
        private const val KEY_ACTIVE = "active"
        private const val KEY_SERVER_URL = "server_url"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_CHILD_NAME = "child_name"
        private const val KEY_GUARDIAN_NAME = "guardian_name"
        private const val KEY_LOW_TIME = "low_time_minutes"
        private const val KEY_LAST_SYNC_AT = "last_sync_at"
        private const val KEY_LAST_SYNC_OK = "last_sync_ok"
        private const val KEY_LAST_SYNC_ERROR = "last_sync_error"
        private const val KEY_LAST_INVENTORY_AT = "last_inventory_at"
        private const val KEY_INVENTORY_DIRTY = "inventory_dirty"
        private const val KEY_SETUP_COMPLETED = "setup_completed"
        private const val KEY_LOCAL_OVERRIDE = "local_override_until"
        private const val KEY_OFFLINE_FAILURES = "offline_failures"
        private const val KEY_OFFLINE_LOCKED_UNTIL = "offline_locked_until"
        private const val KEY_DEACTIVATION_REASON = "deactivation_reason"
        private const val KEY_GUARDIAN_SERVER_URL = "guardian_server_url"
        private const val KEY_GUARDIAN_LAST_ALERT = "guardian_last_alert"
    }
}
