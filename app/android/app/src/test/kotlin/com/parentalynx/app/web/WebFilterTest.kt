package com.parentalynx.app.web

import com.parentalynx.app.policy.WebPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WebFilterTest {
    private val dnsQueries = ArrayList<String>()
    private val filter =
        WebFilter { host ->
            dnsQueries.add(host)
            host == "adulto-desconhecido.example"
        }
    private val open = WebPolicy()

    @Test
    fun dominioBloqueadoCobreSubdominiosMasNaoNomesParecidos() {
        val policy = WebPolicy(blockedDomains = listOf("exemplo.com"))
        assertEquals(WebDecision.REASON_DOMAIN_BLOCKED, filter.evaluate(policy, "https://exemplo.com/").reason)
        assertFalse(filter.evaluate(policy, "https://www.exemplo.com/pagina?x=1").allowed)
        assertFalse(filter.evaluate(policy, "http://a.b.exemplo.com").allowed)
        assertFalse(filter.evaluate(policy, "https://EXEMPLO.com.").allowed)
        assertTrue(filter.evaluate(policy, "https://meuexemplo.com/").allowed)
        assertTrue(filter.evaluate(policy, "https://exemplo.com.br/").allowed)
    }

    @Test
    fun modoAllowlistSoAbreOQueEstaNaLista() {
        val policy = WebPolicy(allowlistMode = true, allowedDomains = listOf("wikipedia.org"), blockedCategories = setOf("video"))
        assertTrue(filter.evaluate(policy, "https://pt.wikipedia.org/wiki/Lince").allowed)
        val denied = filter.evaluate(policy, "https://exemplo.com/")
        assertFalse(denied.allowed)
        assertEquals(WebDecision.REASON_NOT_IN_ALLOWLIST, denied.reason)
        assertEquals("exemplo.com", denied.host)
    }

    @Test
    fun categoriaBloqueadaUsaAListaBasica() {
        val policy = WebPolicy(blockedCategories = setOf("social", "gambling"))
        val social = filter.evaluate(policy, "https://www.instagram.com/alguem")
        assertFalse(social.allowed)
        assertEquals(WebDecision.REASON_CATEGORY, social.reason)
        assertEquals("social", social.category)
        assertEquals("gambling", filter.evaluate(policy, "https://m.bet365.com/").category)
        assertTrue("categoria não bloqueada", filter.evaluate(policy, "https://www.youtube.com/watch?v=1").allowed)
        assertTrue("fora da lista básica", filter.evaluate(policy, "https://rede-nova.example/").allowed)
    }

    @Test
    fun dominioAutorizadoPassaPorCimaDeCategoriaEDeDns() {
        val policy = WebPolicy(blockedCategories = setOf("video"), allowedDomains = listOf("youtube.com"), safeDns = true)
        assertTrue(filter.evaluate(policy, "https://www.youtube.com/").allowed)
        assertTrue(dnsQueries.isEmpty())
        val both = policy.copy(blockedDomains = listOf("youtube.com"))
        assertFalse("a lista de proibidos vence", filter.evaluate(both, "https://www.youtube.com/").allowed)
    }

    @Test
    fun dnsFiltradoSoEConsultadoQuandoLigado() {
        assertTrue(filter.evaluate(open, "https://adulto-desconhecido.example/").allowed)
        assertTrue(dnsQueries.isEmpty())
        val safe = WebPolicy(safeDns = true)
        val blocked = filter.evaluate(safe, "https://adulto-desconhecido.example/x")
        assertFalse(blocked.allowed)
        assertEquals(WebDecision.REASON_SAFE_DNS, blocked.reason)
        assertTrue(filter.evaluate(safe, "https://escola.example/").allowed)
        assertEquals(listOf("adulto-desconhecido.example", "escola.example"), dnsQueries)
    }

    @Test
    fun esquemasInternosPassamEOsQueSaemDaWebNao() {
        assertTrue(filter.evaluate(open, "about:blank").allowed)
        assertTrue(filter.evaluate(open, "data:text/html,oi").allowed)
        for (bad in listOf("file:///sdcard/a.html", "intent://x#Intent;end", "javascript:alert(1)", "content://x/y", "sem esquema", "https:///sem-host")) {
            assertFalse(bad, filter.evaluate(open, bad).allowed)
        }
    }

    @Test
    fun enderecoComCaracteresForaDoPadraoNaoEBloqueadoPorEngano() {
        val decision = filter.evaluate(open, "https://exemplo.com/busca?q=a|b {c}&x=\"y\"")
        assertTrue(decision.allowed)
        assertEquals("exemplo.com", decision.host)
    }

    @Test
    fun separacaoDoEndereco() {
        val parts = UrlParts.parse("HTTPS://usuario:senha@Sub.Exemplo.com:8443/a/b?q=1&r=2#topo")!!
        assertEquals("https", parts.scheme)
        assertEquals("sub.exemplo.com", parts.host)
        assertEquals("/a/b", parts.path)
        assertEquals("q=1&r=2", parts.query)
        assertEquals("topo", parts.fragment)
        assertEquals("2001:db8::1", UrlParts.parse("http://[2001:db8::1]:8080/x")!!.host)
        assertEquals("exemplo.com", filter.hostOf("http://exemplo.com"))
        assertNull(UrlParts.parse("nada"))
        assertNull(filter.hostOf("about:blank"))
    }

    @Test
    fun buscaSeguraAcrescentaOParametroDeCadaBuscador() {
        val policy = WebPolicy(safeSearch = true)
        assertEquals(
            "https://www.google.com/search?q=lince&safe=active",
            filter.evaluate(policy, "https://www.google.com/search?q=lince").rewrittenUrl,
        )
        assertEquals(
            "https://www.google.com.br/search?q=lince&hl=pt&safe=active#x",
            filter.evaluate(policy, "https://www.google.com.br/search?q=lince&safe=off&hl=pt#x").rewrittenUrl,
        )
        assertEquals("https://www.bing.com/search?q=a&adlt=strict", filter.evaluate(policy, "https://www.bing.com/search?q=a").rewrittenUrl)
        assertEquals("https://duckduckgo.com/?q=a&kp=1", filter.evaluate(policy, "https://duckduckgo.com/?q=a").rewrittenUrl)
        assertEquals(
            "https://br.search.yahoo.com/search?p=a&vm=r",
            filter.evaluate(policy, "https://br.search.yahoo.com/search?p=a").rewrittenUrl,
        )
    }

    @Test
    fun buscaSeguraNaoMexeNoQueNaoEBuscaNemNoQueJaEstaSeguro() {
        val policy = WebPolicy(safeSearch = true)
        assertNull(filter.evaluate(policy, "https://www.google.com/search?q=a&safe=active").rewrittenUrl)
        assertNull(filter.evaluate(policy, "https://www.google.com/").rewrittenUrl)
        assertNull(filter.evaluate(policy, "https://mail.google.com/mail/u/0/").rewrittenUrl)
        assertNull(filter.evaluate(policy, "https://notgoogle.com/search?q=a").rewrittenUrl)
        assertNull(filter.evaluate(policy, "https://exemplo.com/search?q=a").rewrittenUrl)
        assertNull("desligada", filter.evaluate(open, "https://www.google.com/search?q=a").rewrittenUrl)
    }

    @Test
    fun respostaDoResolvedorFamiliar() {
        val blocked = """{"Status":0,"Answer":[{"name":"x.example","type":1,"TTL":60,"data":"0.0.0.0"}]}"""
        val allowed = """{"Status":0,"Answer":[{"name":"x.example","type":5,"data":"y.example."},{"name":"y.example","type":1,"data":"93.184.216.34"}]}"""
        assertEquals(true, DohSafeDnsChecker.parseBlocked(blocked))
        assertEquals(false, DohSafeDnsChecker.parseBlocked(allowed))
        assertEquals(false, DohSafeDnsChecker.parseBlocked("""{"Status":3}"""))
        assertNull(DohSafeDnsChecker.parseBlocked("não é json"))
    }

    @Test
    fun listaBasicaDeCategorias() {
        assertEquals(DomainCategories.VIDEO, DomainCategories.categoryOf("m.youtube.com"))
        assertEquals(DomainCategories.GAMES, DomainCategories.categoryOf("www.roblox.com"))
        assertEquals(DomainCategories.ADULT, DomainCategories.categoryOf("pornhub.com"))
        assertNull(DomainCategories.categoryOf("wikipedia.org"))
        assertEquals(setOf("adult", "gambling", "social", "video", "games"), DomainCategories.categories)
    }
}
