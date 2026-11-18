package com.parentalynx.app.bridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.fail
import org.junit.Test

class BridgeValidationTest {
    private fun assertInvalid(block: () -> Unit) {
        try {
            block()
            fail("Era esperada a recusa com invalid_argument")
        } catch (e: FlutterError) {
            assertEquals(BridgeValidation.CODE_INVALID_ARGUMENT, e.code)
        }
    }

    @Test
    fun pedidoDeTempoAceitaNuloEIntervaloDoContrato() {
        assertNull(BridgeValidation.requestMinutes(null))
        assertEquals(30, BridgeValidation.requestMinutes(30))
        assertEquals(720, BridgeValidation.requestMinutes(720))
        assertInvalid { BridgeValidation.requestMinutes(0) }
        assertInvalid { BridgeValidation.requestMinutes(-5) }
        assertInvalid { BridgeValidation.requestMinutes(721) }
    }

    @Test
    fun liberacaoLocalTemLimiteDeQuatroHoras() {
        assertEquals(1, BridgeValidation.overrideMinutes(1))
        assertEquals(240, BridgeValidation.overrideMinutes(240))
        assertInvalid { BridgeValidation.overrideMinutes(0) }
        assertInvalid { BridgeValidation.overrideMinutes(241) }
    }

    @Test
    fun nomeDePacoteSegueOFormatoDoAndroid() {
        assertEquals("com.whatsapp", BridgeValidation.packageName("com.whatsapp"))
        assertEquals("com.parentalynx.app.browser", BridgeValidation.packageName("com.parentalynx.app.browser"))
        assertInvalid { BridgeValidation.packageName("") }
        assertInvalid { BridgeValidation.packageName("semponto") }
        assertInvalid { BridgeValidation.packageName("com..duplo") }
        assertInvalid { BridgeValidation.packageName("com.exemplo/../outro") }
    }

    @Test
    fun chaveDeArmazenamentoNaoPodeSerVazia() {
        assertEquals("guardian.email", BridgeValidation.storageKey("guardian.email"))
        assertInvalid { BridgeValidation.storageKey("  ") }
    }
}
