package com.parentalynx.app.core

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TotpTest {
    private val sha1Seed = "12345678901234567890".toByteArray(Charsets.US_ASCII)
    private val sha256Seed = "12345678901234567890123456789012".toByteArray(Charsets.US_ASCII)
    private val sha512Seed =
        "1234567890123456789012345678901234567890123456789012345678901234".toByteArray(Charsets.US_ASCII)

    private fun rfc(seed: ByteArray, seconds: Long, algorithm: String): String =
        Totp.generate(seed, seconds * 1000L, stepSeconds = 30, digits = 8, algorithm = algorithm)

    @Test
    fun vetoresDaRfc6238ComSha1() {
        assertEquals("94287082", rfc(sha1Seed, 59, "HmacSHA1"))
        assertEquals("07081804", rfc(sha1Seed, 1111111109, "HmacSHA1"))
        assertEquals("14050471", rfc(sha1Seed, 1111111111, "HmacSHA1"))
        assertEquals("89005924", rfc(sha1Seed, 1234567890, "HmacSHA1"))
        assertEquals("69279037", rfc(sha1Seed, 2000000000, "HmacSHA1"))
        assertEquals("65353130", rfc(sha1Seed, 20000000000, "HmacSHA1"))
    }

    @Test
    fun vetoresDaRfc6238ComSha256() {
        assertEquals("46119246", rfc(sha256Seed, 59, "HmacSHA256"))
        assertEquals("68084774", rfc(sha256Seed, 1111111109, "HmacSHA256"))
        assertEquals("67062674", rfc(sha256Seed, 1111111111, "HmacSHA256"))
        assertEquals("91819424", rfc(sha256Seed, 1234567890, "HmacSHA256"))
        assertEquals("90698825", rfc(sha256Seed, 2000000000, "HmacSHA256"))
        assertEquals("77737706", rfc(sha256Seed, 20000000000, "HmacSHA256"))
    }

    @Test
    fun vetoresDaRfc6238ComSha512() {
        assertEquals("90693936", rfc(sha512Seed, 59, "HmacSHA512"))
        assertEquals("25091201", rfc(sha512Seed, 1111111109, "HmacSHA512"))
        assertEquals("47863826", rfc(sha512Seed, 20000000000, "HmacSHA512"))
    }

    @Test
    fun padraoDoProtocoloTemOitoDigitosEPassoDeSessentaSegundos() {
        val secret = Base32.decode("JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP")
        val t = 1_790_000_000_000L
        val code = Totp.generate(secret, t)
        assertEquals(8, code.length)
        // Mesmo passo de 60 s: mesmo código.
        val stepStart = t - (t % 60_000L)
        assertEquals(Totp.generate(secret, stepStart), Totp.generate(secret, stepStart + 59_999L))
    }

    @Test
    fun verificacaoAceitaDoisPassosParaCadaLado() {
        val secret = Base32.decode("JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP")
        val t = 1_790_000_000_000L
        val code = Totp.generate(secret, t)
        assertTrue(Totp.verify(secret, code, t))
        assertTrue(Totp.verify(secret, code, t + 2 * 60_000L))
        assertTrue(Totp.verify(secret, code, t - 2 * 60_000L))
        assertFalse(Totp.verify(secret, code, t + 3 * 60_000L))
        assertFalse(Totp.verify(secret, code, t - 3 * 60_000L))
    }

    @Test
    fun verificacaoRecusaFormatoErradoEAceitaSeparadores() {
        val secret = Base32.decode("JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP")
        val t = 1_790_000_000_000L
        val code = Totp.generate(secret, t)
        assertFalse(Totp.verify(secret, code.dropLast(1), t))
        assertFalse(Totp.verify(secret, "", t))
        assertFalse(Totp.verify(secret, "abcdefgh", t))
        assertTrue(Totp.verify(secret, code.substring(0, 4) + " " + code.substring(4), t))
        val wrong = if (code == "00000000") "00000001" else "00000000"
        assertFalse(Totp.verify(secret, wrong, t))
    }

    @Test
    fun base32SegueARfc4648() {
        assertEquals("MZXW6YTBOI", Base32.encode("foobar".toByteArray(Charsets.US_ASCII)))
        assertEquals("MZXW6", Base32.encode("foo".toByteArray(Charsets.US_ASCII)))
        assertArrayEquals("foobar".toByteArray(Charsets.US_ASCII), Base32.decode("MZXW6YTBOI"))
        assertArrayEquals("foobar".toByteArray(Charsets.US_ASCII), Base32.decode("mzxw6ytboi======"))
        val random = ByteArray(20) { (it * 37 + 11).toByte() }
        assertArrayEquals(random, Base32.decode(Base32.encode(random)))
    }

    @Test(expected = IllegalArgumentException::class)
    fun base32RecusaCaractereInvalido() {
        Base32.decode("MZXW6!")
    }
}
