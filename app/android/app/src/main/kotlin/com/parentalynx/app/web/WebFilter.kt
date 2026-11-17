package com.parentalynx.app.web

import com.parentalynx.app.policy.WebPolicy

/** Decisão sobre uma navegação de página principal no navegador gerenciado. */
data class WebDecision(
    val allowed: Boolean,
    val reason: String? = null,
    val category: String? = null,
    val rewrittenUrl: String? = null,
    val host: String? = null,
) {
    companion object {
        const val REASON_DOMAIN_BLOCKED = "domain_blocked"
        const val REASON_CATEGORY = "category"
        const val REASON_SAFE_DNS = "safe_dns"
        const val REASON_NOT_IN_ALLOWLIST = "not_in_allowlist"
    }
}

/** Consulta a um resolvedor DNS familiar. Verdadeiro quando o resolvedor recusa o domínio. */
fun interface SafeDnsChecker {
    fun isBlocked(host: String): Boolean
}

/**
 * Partes de um endereço. A separação é tolerante de propósito: endereços reais trazem caracteres
 * que um analisador estrito de URI recusa, e recusar a página por isso seria um bloqueio indevido.
 */
data class UrlParts(
    val scheme: String,
    val authority: String,
    val host: String,
    val path: String,
    val query: String,
    val fragment: String?,
) {
    companion object {
        fun parse(url: String): UrlParts? {
            val text = url.trim()
            val colon = text.indexOf(':')
            if (colon <= 0) return null
            val scheme = text.substring(0, colon).lowercase()
            if (!scheme.all { it.isLetterOrDigit() || it == '+' || it == '-' || it == '.' }) return null
            var rest = text.substring(colon + 1)
            var fragment: String? = null
            val hash = rest.indexOf('#')
            if (hash >= 0) {
                fragment = rest.substring(hash + 1)
                rest = rest.substring(0, hash)
            }
            var query = ""
            val mark = rest.indexOf('?')
            if (mark >= 0) {
                query = rest.substring(mark + 1)
                rest = rest.substring(0, mark)
            }
            var authority = ""
            var path = rest
            if (rest.startsWith("//")) {
                val slash = rest.indexOf('/', 2)
                authority = if (slash >= 0) rest.substring(2, slash) else rest.substring(2)
                path = if (slash >= 0) rest.substring(slash) else ""
            }
            return UrlParts(scheme, authority, hostOf(authority), path, query, fragment)
        }

        private fun hostOf(authority: String): String {
            var host = authority.substringAfterLast('@')
            if (host.startsWith("[")) {
                // Endereço IPv6 literal.
                val end = host.indexOf(']')
                host = if (end > 0) host.substring(1, end) else host
            } else {
                val portAt = host.lastIndexOf(':')
                if (portAt >= 0) host = host.substring(0, portAt)
            }
            return DomainMatcher.normalize(host)
        }
    }
}

/**
 * Filtro do navegador gerenciado. Decide por domínio, nesta ordem:
 *
 * - modo `allowlist`: só o que está em `allowedDomains`;
 * - modo `blocklist`: `blockedDomains` bloqueia, `allowedDomains` libera explicitamente (passa por
 *   cima de categoria e de DNS), depois `blockedCategories` e por fim o DNS filtrado.
 *
 * O filtro enxerga só o endereço da página principal aberta neste navegador. Não inspeciona
 * conteúdo, formulários nem o tráfego de outros apps.
 */
class WebFilter(private val safeDns: SafeDnsChecker?) {
    fun evaluate(policy: WebPolicy, url: String): WebDecision {
        val parts = UrlParts.parse(url) ?: return WebDecision(allowed = false, reason = WebDecision.REASON_DOMAIN_BLOCKED)
        if (parts.scheme in INTERNAL_SCHEMES) return WebDecision(allowed = true)
        if (parts.scheme != "http" && parts.scheme != "https") {
            // Esquemas que saem da web (arquivos locais, intents, scripts) não são abertos aqui.
            return WebDecision(allowed = false, reason = WebDecision.REASON_DOMAIN_BLOCKED)
        }
        val host = parts.host
        if (host.isEmpty()) return WebDecision(allowed = false, reason = WebDecision.REASON_DOMAIN_BLOCKED)

        val rewritten = if (policy.safeSearch) SafeSearch.rewrite(parts) else null

        if (policy.allowlistMode) {
            return if (DomainMatcher.matchesAny(host, policy.allowedDomains)) {
                WebDecision(allowed = true, rewrittenUrl = rewritten, host = host)
            } else {
                WebDecision(allowed = false, reason = WebDecision.REASON_NOT_IN_ALLOWLIST, host = host)
            }
        }

        if (DomainMatcher.matchesAny(host, policy.blockedDomains)) {
            return WebDecision(allowed = false, reason = WebDecision.REASON_DOMAIN_BLOCKED, host = host)
        }
        if (DomainMatcher.matchesAny(host, policy.allowedDomains)) {
            return WebDecision(allowed = true, rewrittenUrl = rewritten, host = host)
        }
        val category = DomainCategories.categoryOf(host)
        if (category != null && category in policy.blockedCategories) {
            return WebDecision(allowed = false, reason = WebDecision.REASON_CATEGORY, category = category, host = host)
        }
        if (policy.safeDns && safeDns != null && safeDns.isBlocked(host)) {
            return WebDecision(allowed = false, reason = WebDecision.REASON_SAFE_DNS, host = host)
        }
        return WebDecision(allowed = true, rewrittenUrl = rewritten, host = host)
    }

    /** Host normalizado de um endereço http ou https, ou nulo. */
    fun hostOf(url: String): String? = UrlParts.parse(url)?.host?.takeIf { it.isNotEmpty() }

    private companion object {
        val INTERNAL_SCHEMES = setOf("about", "data", "blob")
    }
}

/** Força a busca segura nos buscadores conhecidos, acrescentando o parâmetro de cada um. */
object SafeSearch {
    private class Rule(val hostMatches: (String) -> Boolean, val pathPrefix: String, val param: String, val value: String)

    private val rules =
        listOf(
            Rule({ it == "google.com" || it.startsWith("google.") || it.contains(".google.") }, "/search", "safe", "active"),
            Rule({ DomainMatcher.matches(it, "bing.com") }, "/", "adlt", "strict"),
            Rule({ DomainMatcher.matches(it, "duckduckgo.com") }, "/", "kp", "1"),
            Rule({ DomainMatcher.matches(it, "search.yahoo.com") }, "/search", "vm", "r"),
        )

    /** Endereço com o parâmetro de busca segura, ou nulo se não se aplica ou já está presente. */
    fun rewrite(parts: UrlParts): String? {
        val bare = parts.host.removePrefix("www.")
        val rule = rules.firstOrNull { it.hostMatches(bare) } ?: return null
        val path = parts.path.ifEmpty { "/" }
        if (!path.startsWith(rule.pathPrefix)) return null
        val params = parts.query.split("&").filter { it.isNotEmpty() }
        // Só mexe em páginas de busca: sem termo de consulta não há o que proteger.
        if (params.none { it.startsWith("q=") || it.startsWith("p=") }) return null
        val expected = "${rule.param}=${rule.value}"
        if (expected in params) return null
        val newQuery = (params.filterNot { it.startsWith("${rule.param}=") } + expected).joinToString("&")
        val sb = StringBuilder()
        sb.append(parts.scheme).append("://").append(parts.authority).append(path).append('?').append(newQuery)
        parts.fragment?.let { sb.append('#').append(it) }
        return sb.toString()
    }
}
