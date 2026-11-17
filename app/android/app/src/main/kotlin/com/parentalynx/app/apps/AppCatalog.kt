package com.parentalynx.app.apps

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Telephony
import android.telecom.TelecomManager
import android.view.inputmethod.InputMethodManager
import com.parentalynx.app.BrowserActivity
import com.parentalynx.app.R
import com.parentalynx.app.core.AppLog
import com.parentalynx.app.core.Hashing
import com.parentalynx.app.policy.AppFacts
import java.util.concurrent.ConcurrentHashMap

/** O que o agente sabe de um app instalado. */
data class CatalogEntry(
    val appId: String,
    val pkg: String,
    val label: String,
    val system: Boolean,
    val launchable: Boolean,
    val essential: Boolean,
    val tracked: Boolean,
    val category: String,
) {
    fun toFacts(): AppFacts = AppFacts(appId = appId, essential = essential, system = system, tracked = tracked)
}

/** Linha do inventário enviado ao servidor (`InventoryApp` do protocolo). */
data class InventoryItem(
    val entry: CatalogEntry,
    val versionName: String?,
    val installedAtMs: Long,
    val updatedAtMs: Long,
    val iconHash: String?,
)

/**
 * Catálogo de apps do aparelho: classificação (essencial, rastreado), rótulo, categoria e
 * inventário. Tudo vem direto do sistema operacional.
 */
class AppCatalog(context: Context) {
    private val context = context.applicationContext
    private val pm: PackageManager = this.context.packageManager
    private val ownPackage: String = this.context.packageName
    private val browserActivityClass: String = BrowserActivity::class.java.name
    private val cache = ConcurrentHashMap<String, CatalogEntry>()
    private val activityCache = ConcurrentHashMap<String, Boolean>()

    @Volatile
    private var sets = SystemPackageSets(ownPackage)

    @Volatile
    private var browserPackages: Set<String> = emptySet()

    @Volatile
    private var communicationPackages: Set<String> = emptySet()

    @Volatile
    private var initialized = false

    /** Identificador usado na política: o pacote, ou o pacote virtual do navegador gerenciado. */
    fun appIdFor(pkg: String, cls: String?): String =
        if (pkg == ownPackage && cls == browserActivityClass) PackageClassifier.BROWSER_APP_ID else pkg

    /** Pacote real a que um identificador de app corresponde. */
    fun packageOf(appId: String): String = if (appId == PackageClassifier.BROWSER_APP_ID) ownPackage else appId

    fun entry(appId: String): CatalogEntry {
        ensureInitialized()
        return cache.getOrPut(appId) { build(appId) }
    }

    fun facts(appId: String): AppFacts = entry(appId).toFacts()

    /** Relê do sistema os conjuntos de pacotes especiais e esvazia o cache. */
    @Synchronized
    fun refresh() {
        sets = readSets()
        browserPackages = readBrowserPackages()
        communicationPackages = readCommunicationPackages()
        cache.clear()
        initialized = true
    }

    /** Verdadeiro se (pacote, classe) é uma atividade. Usado para filtrar eventos de janela. */
    fun isActivity(pkg: String, cls: String?): Boolean {
        if (cls.isNullOrEmpty()) return false
        return activityCache.getOrPut("$pkg/$cls") {
            try {
                pm.getActivityInfo(ComponentName(pkg, cls), 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    /** Apps que entram no inventário: com ícone no launcher ou instalados pelo usuário. */
    fun inventory(): List<InventoryItem> {
        ensureInitialized()
        val out = ArrayList<InventoryItem>()
        val installed =
            try {
                pm.getInstalledApplications(0)
            } catch (e: RuntimeException) {
                AppLog.w(TAG, "falha ao listar apps instalados", e)
                emptyList()
            }
        for (info in installed) {
            val pkg = info.packageName
            if (pkg == ownPackage) continue
            val entry = entry(pkg)
            if (!entry.launchable && entry.system) continue
            var versionName: String? = null
            var installedAt = 0L
            var updatedAt = 0L
            var versionCode = 0L
            try {
                val pi = pm.getPackageInfo(pkg, 0)
                versionName = pi.versionName
                installedAt = pi.firstInstallTime
                updatedAt = pi.lastUpdateTime
                versionCode = pi.longVersionCode
            } catch (e: PackageManager.NameNotFoundException) {
                continue
            }
            out.add(
                InventoryItem(
                    entry = entry,
                    versionName = versionName,
                    installedAtMs = installedAt,
                    updatedAtMs = updatedAt,
                    iconHash = Hashing.sha256Hex("$pkg|$versionCode|$updatedAt").take(16),
                ),
            )
        }
        // O navegador gerenciado aparece para o responsável como um app próprio.
        val self = runCatching { pm.getPackageInfo(ownPackage, 0) }.getOrNull()
        out.add(
            InventoryItem(
                entry = entry(PackageClassifier.BROWSER_APP_ID),
                versionName = self?.versionName,
                installedAtMs = self?.firstInstallTime ?: 0L,
                updatedAtMs = self?.lastUpdateTime ?: 0L,
                iconHash = Hashing.sha256Hex("${PackageClassifier.BROWSER_APP_ID}|${self?.longVersionCode ?: 0}").take(16),
            ),
        )
        return out
    }

    /** Pacotes com ícone no launcher. */
    fun launchablePackages(): Set<String> {
        ensureInitialized()
        return sets.launchablePackages
    }

    private fun ensureInitialized() {
        if (!initialized) refresh()
    }

    private fun build(appId: String): CatalogEntry {
        if (appId == PackageClassifier.BROWSER_APP_ID) {
            return CatalogEntry(
                appId = appId,
                pkg = ownPackage,
                label = context.getString(R.string.browser_label),
                system = false,
                launchable = true,
                essential = false,
                tracked = true,
                category = CATEGORY_BROWSER,
            )
        }
        val info =
            try {
                pm.getApplicationInfo(appId, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                // Pacote que não conseguimos identificar: não bloqueia e não contabiliza.
                return CatalogEntry(appId, appId, appId, system = true, launchable = false, essential = true, tracked = false, category = CATEGORY_SYSTEM)
            }
        val system = isSystem(info)
        val cls = PackageClassifier.classify(appId, system, sets)
        val label = runCatching { pm.getApplicationLabel(info).toString() }.getOrDefault(appId).ifBlank { appId }
        return CatalogEntry(
            appId = appId,
            pkg = appId,
            label = label,
            system = system,
            launchable = cls.launchable,
            essential = cls.essential,
            tracked = cls.tracked,
            category = categoryOf(info, system),
        )
    }

    private fun isSystem(info: ApplicationInfo): Boolean =
        (info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0

    private fun categoryOf(info: ApplicationInfo, system: Boolean): String {
        val pkg = info.packageName
        if (pkg in communicationPackages || pkg in sets.dialerPackages) return CATEGORY_COMMUNICATION
        if (pkg in browserPackages) return CATEGORY_BROWSER
        @Suppress("DEPRECATION")
        val isGameFlag = (info.flags and ApplicationInfo.FLAG_IS_GAME) != 0
        return when (info.category) {
            ApplicationInfo.CATEGORY_GAME -> "games"
            ApplicationInfo.CATEGORY_AUDIO -> "audio"
            ApplicationInfo.CATEGORY_VIDEO -> "video"
            ApplicationInfo.CATEGORY_IMAGE -> "image"
            ApplicationInfo.CATEGORY_SOCIAL -> "social"
            ApplicationInfo.CATEGORY_NEWS -> "news"
            ApplicationInfo.CATEGORY_MAPS -> "maps"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
            else ->
                when {
                    isGameFlag -> "games"
                    system -> CATEGORY_SYSTEM
                    else -> "other"
                }
        }
    }

    private fun readSets(): SystemPackageSets {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val homes = HashSet<String>()
        val candidates = runCatching { pm.queryIntentActivities(homeIntent, 0) }.getOrDefault(emptyList())
        val defaultHome =
            runCatching { pm.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName }.getOrNull()
        if (defaultHome != null && defaultHome != "android" && defaultHome !in NOT_A_LAUNCHER) {
            homes.add(defaultHome)
        }
        for (resolved in candidates) {
            val activity = resolved.activityInfo ?: continue
            val pkg = activity.packageName
            // As Configurações declaram uma tela inicial de reserva com prioridade negativa.
            // Ela não é um launcher: as Configurações seguem as regras gerais.
            if (pkg in NOT_A_LAUNCHER || resolved.priority < 0) continue
            // Launchers de sistema, e qualquer launcher quando o usuário ainda não escolheu o padrão.
            if (isSystem(activity.applicationInfo) || defaultHome == null || defaultHome == "android") homes.add(pkg)
        }

        val dialers = HashSet<String>()
        runCatching {
            val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            telecom?.defaultDialerPackage?.let(dialers::add)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) telecom?.systemDialerPackage?.let(dialers::add)
        }

        val imes = HashSet<String>()
        runCatching {
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.enabledInputMethodList?.forEach { imes.add(it.packageName) }
        }

        val launchable = HashSet<String>()
        runCatching {
            val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            for (resolved in pm.queryIntentActivities(launcherIntent, 0)) {
                resolved.activityInfo?.packageName?.let(launchable::add)
            }
        }
        return SystemPackageSets(
            ownPackage = ownPackage,
            homePackages = homes,
            dialerPackages = dialers,
            imePackages = imes,
            launchablePackages = launchable,
        )
    }

    private fun readBrowserPackages(): Set<String> {
        val out = HashSet<String>()
        runCatching {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://www.example.com")).addCategory(Intent.CATEGORY_BROWSABLE)
            for (resolved in pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)) {
                resolved.activityInfo?.packageName?.let { if (it != ownPackage) out.add(it) }
            }
        }
        return out
    }

    private fun readCommunicationPackages(): Set<String> {
        val out = HashSet<String>()
        runCatching { Telephony.Sms.getDefaultSmsPackage(context)?.let(out::add) }
        runCatching {
            val contacts = Intent(Intent.ACTION_VIEW, ContactsContract.Contacts.CONTENT_URI)
            pm.resolveActivity(contacts, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName?.let {
                if (it != "android") out.add(it)
            }
        }
        return out
    }

    companion object {
        const val CATEGORY_BROWSER = "browser"
        const val CATEGORY_COMMUNICATION = "communication"
        const val CATEGORY_SYSTEM = "system"
        private const val TAG = "AppCatalog"

        /** Pacotes que declaram uma tela inicial só como reserva do sistema. */
        private val NOT_A_LAUNCHER = setOf("com.android.settings")
    }
}
