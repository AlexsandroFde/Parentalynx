package com.parentalynx.app.enforcement

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.UserManager
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.data.KeyValueStore
import com.parentalynx.app.policy.ProtectionPolicy
import com.parentalynx.app.service.AdminReceiver
import com.parentalynx.app.web.DohSafeDnsChecker
import org.json.JSONArray

/**
 * Controle imposto pelo sistema quando o ParentaLynx é o dono do dispositivo (Device Owner).
 *
 * Tudo aqui é inofensivo fora desse modo: cada método confere antes e não faz nada. Ver
 * `docs/01-capacidades-android.md`, seção 2.3, e `docs/05-device-owner.md`.
 */
class DeviceOwnerController(context: Context, private val kv: KeyValueStore) {
    private val context = context.applicationContext
    private val dpm = this.context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val admin = ComponentName(this.context, AdminReceiver::class.java)
    private val ownPackage = this.context.packageName

    fun isDeviceOwner(): Boolean = dpm.isDeviceOwnerApp(ownPackage)

    /**
     * Aplica as proteções escolhidas pelo responsável e o DNS privado filtrado.
     *
     * Chamar fora da thread principal: a definição do DNS privado testa a conexão com o resolvedor.
     *
     * @return falso se alguma proteção pedida não pôde ser aplicada.
     */
    fun applyProtection(protection: ProtectionPolicy, safeDns: Boolean): Boolean {
        if (!isDeviceOwner()) return true
        var ok = true
        ok = attempt("bloqueio de desinstalação") { dpm.setUninstallBlocked(admin, ownPackage, protection.blockUninstall) } && ok
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Impede forçar parada e limpar dados do ParentaLynx.
            ok =
                attempt("proteção contra parada forçada") {
                    dpm.setUserControlDisabledPackages(admin, if (protection.blockUninstall) listOf(ownPackage) else emptyList())
                } && ok
        }
        ok = restriction(UserManager.DISALLOW_SAFE_BOOT, protection.blockSafeBoot) && ok
        ok = restriction(UserManager.DISALLOW_FACTORY_RESET, protection.blockFactoryReset) && ok
        ok = restriction(UserManager.DISALLOW_ADD_USER, protection.blockAddUser) && ok
        ok = restriction(UserManager.DISALLOW_CONFIG_DATE_TIME, protection.blockDateTimeChange) && ok
        if (protection.blockDateTimeChange) {
            ok =
                attempt("hora automática") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        dpm.setAutoTimeEnabled(admin, true)
                    } else {
                        @Suppress("DEPRECATION")
                        dpm.setAutoTimeRequired(admin, true)
                    }
                } && ok
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            attempt("hora automática") {
                @Suppress("DEPRECATION")
                dpm.setAutoTimeRequired(admin, false)
            }
        }
        ok = restriction(UserManager.DISALLOW_INSTALL_UNKNOWN_SOURCES, protection.blockUnknownSources) && ok
        ok = restriction(UserManager.DISALLOW_DEBUGGING_FEATURES, protection.blockUsbDebugging) && ok
        ok = applyPrivateDns(safeDns) && ok
        attempt("mensagem de suporte") {
            dpm.setShortSupportMessage(admin, context.getString(R.string.owner_support_short))
            dpm.setLongSupportMessage(admin, context.getString(R.string.owner_support_long))
        }
        return ok
    }

    /**
     * Ajusta o conjunto de pacotes suspensos pelo sistema para [desired]. Só mexe nos pacotes que
     * este app suspendeu.
     *
     * @return pacotes que o sistema se recusou a suspender (para eles vale a interceptação).
     */
    fun syncSuspended(desired: Set<String>): Set<String> {
        if (!isDeviceOwner()) return emptySet()
        val current = loadSuspended()
        val toRelease = current - desired
        val toSuspend = desired - current
        if (toRelease.isEmpty() && toSuspend.isEmpty()) return emptySet()
        var failed: Set<String> = emptySet()
        try {
            if (toRelease.isNotEmpty()) dpm.setPackagesSuspended(admin, toRelease.toTypedArray(), false)
            if (toSuspend.isNotEmpty()) {
                failed = dpm.setPackagesSuspended(admin, toSuspend.toTypedArray(), true).toSet()
            }
        } catch (e: RuntimeException) {
            AppLog.w(TAG, "falha ao suspender pacotes", e)
            failed = toSuspend
        }
        saveSuspended((current - toRelease) + (toSuspend - failed))
        return failed
    }

    /** Pacotes suspensos por este app no momento. */
    fun suspendedPackages(): Set<String> = loadSuspended()

    /** Remove todas as suspensões e restrições, mantendo o papel de dono do dispositivo. */
    fun clearAll() {
        if (!isDeviceOwner()) return
        syncSuspended(emptySet())
        attempt("liberar desinstalação") { dpm.setUninstallBlocked(admin, ownPackage, false) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            attempt("liberar parada forçada") { dpm.setUserControlDisabledPackages(admin, emptyList()) }
        }
        for (key in MANAGED_RESTRICTIONS) restriction(key, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            restriction(UserManager.DISALLOW_CONFIG_PRIVATE_DNS, false)
            if (kv.getString(KV_PRIVATE_DNS) == "1") {
                attempt("DNS privado automático") { dpm.setGlobalPrivateDnsModeOpportunistic(admin) }
                kv.remove(KV_PRIVATE_DNS)
            }
        }
        attempt("mensagem de suporte") {
            dpm.setShortSupportMessage(admin, null)
            dpm.setLongSupportMessage(admin, null)
        }
    }

    /**
     * Abre mão do modo Device Owner: remove restrições e suspensões e devolve o aparelho ao estado
     * comum, em que o app pode ser desinstalado.
     *
     * @return verdadeiro se o app deixou de ser o dono do dispositivo.
     */
    fun release(): Boolean {
        if (!isDeviceOwner()) return true
        clearAll()
        attempt("abrir mão do dispositivo") {
            @Suppress("DEPRECATION")
            dpm.clearDeviceOwnerApp(ownPackage)
        }
        attempt("desativar administrador") { dpm.removeActiveAdmin(admin) }
        return !isDeviceOwner()
    }

    /** Desativa o administrador do dispositivo (modo padrão com administrador ativo). */
    fun removeActiveAdmin() {
        attempt("desativar administrador") { dpm.removeActiveAdmin(admin) }
    }

    private fun applyPrivateDns(enabled: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        val host = DohSafeDnsChecker.PRIVATE_DNS_HOST
        return try {
            if (enabled) {
                val alreadySet =
                    dpm.getGlobalPrivateDnsMode(admin) == DevicePolicyManager.PRIVATE_DNS_MODE_PROVIDER_HOSTNAME &&
                        dpm.getGlobalPrivateDnsHost(admin) == host
                val applied =
                    alreadySet ||
                        dpm.setGlobalPrivateDnsModeSpecifiedHost(admin, host) == DevicePolicyManager.PRIVATE_DNS_SET_NO_ERROR
                if (applied) {
                    kv.putString(KV_PRIVATE_DNS, "1")
                    restriction(UserManager.DISALLOW_CONFIG_PRIVATE_DNS, true)
                }
                // Sem rede o sistema recusa o resolvedor: fica para a próxima aplicação.
                applied
            } else {
                restriction(UserManager.DISALLOW_CONFIG_PRIVATE_DNS, false)
                if (kv.getString(KV_PRIVATE_DNS) == "1") {
                    dpm.setGlobalPrivateDnsModeOpportunistic(admin)
                    kv.remove(KV_PRIVATE_DNS)
                }
                true
            }
        } catch (e: RuntimeException) {
            AppLog.w(TAG, "falha ao definir DNS privado", e)
            false
        }
    }

    private fun restriction(key: String, enabled: Boolean): Boolean =
        attempt("restrição $key") {
            if (enabled) dpm.addUserRestriction(admin, key) else dpm.clearUserRestriction(admin, key)
        }

    private inline fun attempt(what: String, block: () -> Unit): Boolean =
        try {
            block()
            true
        } catch (e: RuntimeException) {
            AppLog.w(TAG, "não foi possível aplicar: $what", e)
            false
        }

    private fun loadSuspended(): Set<String> {
        val json = kv.getString(KeyValueStore.SUSPENDED_PACKAGES) ?: return emptySet()
        val array = runCatching { JSONArray(json) }.getOrNull() ?: return emptySet()
        val out = HashSet<String>(array.length())
        for (i in 0 until array.length()) array.optString(i).takeIf { it.isNotEmpty() }?.let(out::add)
        return out
    }

    private fun saveSuspended(packages: Set<String>) {
        kv.putString(KeyValueStore.SUSPENDED_PACKAGES, JSONArray(packages.toList()).toString())
    }

    private companion object {
        const val TAG = "DeviceOwner"
        const val KV_PRIVATE_DNS = "owner.private_dns"

        val MANAGED_RESTRICTIONS =
            listOf(
                UserManager.DISALLOW_SAFE_BOOT,
                UserManager.DISALLOW_FACTORY_RESET,
                UserManager.DISALLOW_ADD_USER,
                UserManager.DISALLOW_CONFIG_DATE_TIME,
                UserManager.DISALLOW_INSTALL_UNKNOWN_SOURCES,
                UserManager.DISALLOW_DEBUGGING_FEATURES,
            )
    }
}
