package com.parentalynx.app.core

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Armazenamento de segredos: valores cifrados com AES-256-GCM e chave não exportável do Android
 * Keystore. O nome da chave lógica entra como dado autenticado, então um valor cifrado não pode
 * ser movido para outra entrada.
 *
 * Guarda o token do aparelho, o segredo do código offline e o token de sessão do responsável.
 */
class SecureStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val lock = Any()

    fun get(key: String): String? =
        synchronized(lock) {
            val stored = prefs.getString(key, null) ?: return null
            try {
                val raw = Base64.decode(stored, Base64.NO_WRAP)
                if (raw.size <= IV_BYTES) return null
                val cipher = Cipher.getInstance(TRANSFORMATION)
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    secretKey(),
                    GCMParameterSpec(TAG_BITS, raw, 0, IV_BYTES),
                )
                cipher.updateAAD(key.toByteArray(Charsets.UTF_8))
                String(cipher.doFinal(raw, IV_BYTES, raw.size - IV_BYTES), Charsets.UTF_8)
            } catch (e: GeneralSecurityException) {
                // Chave do Keystore perdida ou valor corrompido: o segredo não é recuperável.
                AppLog.w(TAG, "valor seguro ilegível, descartado: $key", e)
                prefs.edit().remove(key).apply()
                null
            } catch (e: IllegalArgumentException) {
                prefs.edit().remove(key).apply()
                null
            }
        }

    fun put(key: String, value: String) {
        synchronized(lock) {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            cipher.updateAAD(key.toByteArray(Charsets.UTF_8))
            val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val payload = cipher.iv + encrypted
            prefs.edit().putString(key, Base64.encodeToString(payload, Base64.NO_WRAP)).commit()
        }
    }

    fun remove(key: String) {
        synchronized(lock) { prefs.edit().remove(key).commit() }
    }

    fun removeByPrefix(prefix: String) {
        synchronized(lock) {
            val editor = prefs.edit()
            prefs.all.keys.filter { it.startsWith(prefix) }.forEach { editor.remove(it) }
            editor.commit()
        }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec
                .Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        /** Prefixo reservado ao agente nativo. A ponte com o Dart recusa essas chaves. */
        const val AGENT_PREFIX = "agent."
        const val KEY_DEVICE_TOKEN = "agent.device_token"
        const val KEY_OFFLINE_SECRET = "agent.offline_secret"

        /** Chave em que o Dart grava o token de sessão do responsável. */
        const val KEY_GUARDIAN_SESSION_TOKEN = "guardian.session_token"

        private const val TAG = "SecureStore"
        private const val PREFS_NAME = "plx_secure"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "plx_secure_v1"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_BYTES = 12
        private const val TAG_BITS = 128
    }
}
