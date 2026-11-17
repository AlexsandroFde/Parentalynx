package com.parentalynx.app.data

import com.parentalynx.app.policy.PolicyParseException
import com.parentalynx.app.policy.PolicyParser
import com.parentalynx.app.policy.PolicyRuntime
import java.time.ZoneId

/**
 * Política em vigor no aparelho: o documento JSON recebido do servidor, a versão e o instante em
 * que foi aplicada. Mantém também a forma pronta para avaliação.
 */
class PolicyStore(private val kv: KeyValueStore) {
    private val lock = Any()
    private var loaded = false
    private var cachedJson: String? = null
    private var cachedVersion: Long = 0L
    private var cachedAppliedAt: Long? = null
    private var cachedRuntime: PolicyRuntime? = null

    val version: Long
        get() = synchronized(lock) { ensureLoaded(); cachedVersion }

    val appliedAtMs: Long?
        get() = synchronized(lock) { ensureLoaded(); cachedAppliedAt }

    val json: String?
        get() = synchronized(lock) { ensureLoaded(); cachedJson }

    /** Política pronta para avaliação, ou nulo se não há política válida. */
    fun runtime(): PolicyRuntime? = synchronized(lock) { ensureLoaded(); cachedRuntime }

    /**
     * Valida e grava uma nova política.
     *
     * @throws PolicyParseException se o documento não puder ser lido. Nesse caso a política
     *   anterior continua em vigor.
     */
    fun save(version: Long, json: String, appliedAtMs: Long): PolicyRuntime =
        synchronized(lock) {
            val runtime = PolicyRuntime(PolicyParser.parse(json), ZoneId.systemDefault())
            kv.putString(KeyValueStore.POLICY_JSON, json)
            kv.putLong(KeyValueStore.POLICY_VERSION, version)
            kv.putLong(KeyValueStore.POLICY_APPLIED_AT, appliedAtMs)
            cachedJson = json
            cachedVersion = version
            cachedAppliedAt = appliedAtMs
            cachedRuntime = runtime
            loaded = true
            runtime
        }

    /** Esquece a política em memória (depois de apagar o banco na desvinculação). */
    fun reset() {
        synchronized(lock) {
            loaded = false
            cachedJson = null
            cachedVersion = 0L
            cachedAppliedAt = null
            cachedRuntime = null
        }
    }

    private fun ensureLoaded() {
        if (loaded) return
        loaded = true
        cachedJson = kv.getString(KeyValueStore.POLICY_JSON)
        cachedVersion = kv.getLong(KeyValueStore.POLICY_VERSION) ?: 0L
        cachedAppliedAt = kv.getLong(KeyValueStore.POLICY_APPLIED_AT)
        cachedRuntime =
            cachedJson?.let { json ->
                try {
                    PolicyRuntime(PolicyParser.parse(json), ZoneId.systemDefault())
                } catch (e: PolicyParseException) {
                    null
                }
            }
    }
}
