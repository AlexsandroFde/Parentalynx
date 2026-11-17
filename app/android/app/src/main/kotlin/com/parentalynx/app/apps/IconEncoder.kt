package com.parentalynx.app.apps

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import com.parentalynx.app.R
import java.io.ByteArrayOutputStream

/** Converte o ícone de um app em PNG pequeno, para o painel do responsável e a tela da criança. */
class IconEncoder(context: Context) {
    private val context = context.applicationContext
    private val lock = Any()
    private val cache =
        object : LinkedHashMap<String, ByteArray>(32, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, ByteArray>?): Boolean = size > CACHE_SIZE
        }

    /** PNG do ícone, com no máximo [MAX_BYTES], ou nulo se o app não existe. */
    fun pngFor(appId: String): ByteArray? {
        synchronized(lock) { cache[appId]?.let { return it } }
        val drawable = loadDrawable(appId) ?: return null
        var bytes = encode(drawable, ICON_PX)
        // Ícones muito detalhados podem passar do limite do protocolo: reduz até caber.
        var size = ICON_PX
        while (bytes.size > MAX_BYTES && size > MIN_PX) {
            size -= 24
            bytes = encode(drawable, size)
        }
        if (bytes.size > MAX_BYTES) return null
        synchronized(lock) { cache[appId] = bytes }
        return bytes
    }

    private fun loadDrawable(appId: String): Drawable? =
        try {
            if (appId == PackageClassifier.BROWSER_APP_ID) {
                context.getDrawable(R.mipmap.ic_browser)
            } else {
                context.packageManager.getApplicationIcon(appId)
            }
        } catch (e: PackageManager.NameNotFoundException) {
            null
        } catch (e: RuntimeException) {
            null
        }

    private fun encode(drawable: Drawable, sizePx: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, sizePx, sizePx)
            drawable.draw(canvas)
            val out = ByteArrayOutputStream(8 * 1024)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            return out.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    private companion object {
        const val ICON_PX = 96
        const val MIN_PX = 48

        /** Limite de `PUT /v1/device/apps/icon` no protocolo: 64 KiB. */
        const val MAX_BYTES = 64 * 1024
        const val CACHE_SIZE = 64
    }
}
