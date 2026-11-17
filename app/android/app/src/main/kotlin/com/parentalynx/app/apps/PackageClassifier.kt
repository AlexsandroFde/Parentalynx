package com.parentalynx.app.apps

/**
 * Conjuntos de pacotes lidos do sistema que entram na classificação.
 *
 * @property homePackages launcher padrão e launchers de sistema.
 * @property dialerPackages discador padrão e discador de sistema.
 * @property imePackages teclados habilitados.
 * @property launchablePackages pacotes com ícone no launcher.
 */
data class SystemPackageSets(
    val ownPackage: String,
    val homePackages: Set<String> = emptySet(),
    val dialerPackages: Set<String> = emptySet(),
    val imePackages: Set<String> = emptySet(),
    val launchablePackages: Set<String> = emptySet(),
)

/**
 * @property essential nunca é bloqueado e nunca consome cota.
 * @property tracked o tempo aparece nos relatórios.
 */
data class PackageClass(val essential: Boolean, val tracked: Boolean, val launchable: Boolean)

/**
 * Classificação de pacotes de `docs/02-arquitetura.md`, seção 4.1. Pura: recebe os conjuntos já
 * lidos do sistema.
 */
object PackageClassifier {
    /** Pacote virtual do navegador gerenciado (a atividade do navegador dentro do próprio app). */
    const val BROWSER_APP_ID = "com.parentalynx.app.browser"

    /**
     * Pacotes que nunca são bloqueados em nenhum aparelho: interface do sistema, telefonia e
     * emergência, alertas de emergência, controlador de permissões e instalador de pacotes.
     */
    val ALWAYS_ESSENTIAL: Set<String> =
        setOf(
            // Interface do sistema.
            "android",
            "com.android.systemui",
            "com.android.intentresolver",
            // Telefonia e chamadas.
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.incallui",
            "com.android.dialer",
            "com.google.android.dialer",
            "com.samsung.android.dialer",
            "com.samsung.android.incallui",
            // Emergência e segurança pessoal.
            "com.android.emergency",
            "com.google.android.apps.safetyhub",
            "com.sec.android.app.safetyassurance",
            // Alertas de emergência por difusão celular.
            "com.android.cellbroadcastreceiver",
            "com.android.cellbroadcastreceiver.module",
            "com.google.android.cellbroadcastreceiver",
            // Permissões e instalação.
            "com.android.permissioncontroller",
            "com.google.android.permissioncontroller",
            "com.samsung.android.permissioncontroller",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
        )

    fun classify(pkg: String, isSystem: Boolean, sets: SystemPackageSets): PackageClass {
        val launchable = pkg in sets.launchablePackages
        val isHome = pkg in sets.homePackages
        val isOwn = pkg == sets.ownPackage
        val essential =
            isOwn ||
                isHome ||
                pkg in ALWAYS_ESSENTIAL ||
                pkg in sets.dialerPackages ||
                pkg in sets.imePackages ||
                // Componentes de sistema sem ícone (seletor de arquivos, login de conta,
                // compartilhamento): sem isso, apps liberados como exceção quebrariam.
                (isSystem && !launchable)
        // Rastreados: com ícone no launcher ou instalados pelo usuário, menos os launchers e a
        // interface do próprio ParentaLynx.
        val tracked = !isOwn && !isHome && (launchable || !isSystem)
        return PackageClass(essential = essential, tracked = tracked, launchable = launchable)
    }
}
