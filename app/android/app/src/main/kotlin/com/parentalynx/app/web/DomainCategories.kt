package com.parentalynx.app.web

/**
 * Lista básica embutida de domínios conhecidos por categoria.
 *
 * Não é exaustiva: serve para os atalhos de categoria do navegador gerenciado. A cobertura ampla
 * de conteúdo adulto e de malware vem do DNS filtrado (`safeDns`). Domínios são comparados por
 * sufixo, então `youtube.com` cobre `m.youtube.com`.
 */
object DomainCategories {
    const val ADULT = "adult"
    const val GAMBLING = "gambling"
    const val SOCIAL = "social"
    const val VIDEO = "video"
    const val GAMES = "games"

    private val byCategory: Map<String, Set<String>> =
        mapOf(
            ADULT to
                setOf(
                    "pornhub.com", "xvideos.com", "xnxx.com", "xhamster.com", "redtube.com",
                    "youporn.com", "spankbang.com", "tube8.com", "brazzers.com", "chaturbate.com",
                    "stripchat.com", "livejasmin.com", "bongacams.com", "cam4.com", "onlyfans.com",
                    "privacy.com.br", "eporner.com", "hclips.com", "beeg.com", "txxx.com",
                    "rule34.xxx", "e-hentai.org", "nhentai.net", "hentaihaven.xxx", "motherless.com",
                ),
            GAMBLING to
                setOf(
                    "bet365.com", "betano.com", "betano.bet.br", "sportingbet.com", "sportingbet.bet.br",
                    "betfair.com", "betfair.bet.br", "pixbet.com", "blaze.com", "blaze.bet.br",
                    "stake.com", "1xbet.com", "22bet.com", "betway.com", "bwin.com", "pokerstars.com",
                    "888casino.com", "888poker.com", "novibet.bet.br", "kto.bet.br", "estrelabet.bet.br",
                    "superbet.bet.br", "f12.bet.br", "betnacional.bet.br", "casadeapostas.bet.br",
                    "esportesdasorte.bet.br", "vaidebet.bet.br", "bet7k.bet.br", "galera.bet.br",
                ),
            SOCIAL to
                setOf(
                    "facebook.com", "fb.com", "instagram.com", "threads.net", "threads.com",
                    "tiktok.com", "twitter.com", "x.com", "snapchat.com", "reddit.com",
                    "pinterest.com", "tumblr.com", "kwai.com", "discord.com", "discord.gg",
                    "vk.com", "bsky.app", "mastodon.social", "telegram.org", "web.telegram.org",
                    "web.whatsapp.com", "messenger.com", "bereal.com", "ask.fm", "omegle.com",
                ),
            VIDEO to
                setOf(
                    "youtube.com", "youtu.be", "youtube-nocookie.com", "netflix.com", "twitch.tv",
                    "vimeo.com", "dailymotion.com", "primevideo.com", "disneyplus.com", "max.com",
                    "hbomax.com", "globoplay.globo.com", "paramountplus.com", "crunchyroll.com",
                    "pluto.tv", "kick.com", "rumble.com", "bilibili.com", "tv.apple.com",
                ),
            GAMES to
                setOf(
                    "roblox.com", "poki.com", "friv.com", "miniclip.com", "crazygames.com",
                    "crazygames.com.br", "y8.com", "kizi.com", "clickjogos.com.br", "jogos360.com.br",
                    "epicgames.com", "steampowered.com", "steamcommunity.com", "minecraft.net",
                    "itch.io", "newgrounds.com", "armorgames.com", "kongregate.com", "1001jogos.com.br",
                    "coolmathgames.com", "agar.io", "slither.io", "krunker.io",
                ),
        )

    val categories: Set<String> = byCategory.keys

    /** Categoria do host, ou nulo se o domínio não está na lista básica. */
    fun categoryOf(host: String): String? {
        for ((category, domains) in byCategory) {
            if (DomainMatcher.matchesAny(host, domains)) return category
        }
        return null
    }
}

object DomainMatcher {
    /** Normaliza um host: minúsculas, sem ponto final e sem espaços. */
    fun normalize(host: String): String = host.trim().lowercase().trimEnd('.')

    /** Verdadeiro se [host] é o domínio ou um subdomínio dele (`exemplo.com` cobre `www.exemplo.com`). */
    fun matches(host: String, domain: String): Boolean {
        if (domain.isEmpty()) return false
        return host == domain || host.endsWith(".$domain")
    }

    fun matchesAny(host: String, domains: Collection<String>): Boolean = domains.any { matches(host, it) }
}
