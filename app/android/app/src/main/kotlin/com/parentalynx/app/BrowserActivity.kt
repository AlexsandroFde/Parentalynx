package com.parentalynx.app

import android.content.Intent
import android.os.Bundle
import com.parentalynx.app.bridge.Bridges
import com.parentalynx.app.bridge.DeviceBridge
import com.parentalynx.app.bridge.NativeEventsApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Navegador gerenciado. É uma atividade separada, com motor Flutter próprio e ponto de entrada
 * Dart `browserMain`, para que o agente a trate como um app à parte: o tempo nela conta como o
 * pacote virtual `com.parentalynx.app.browser` e ela pode ser bloqueada como qualquer app.
 *
 * O ícone no launcher e os filtros de link ficam no `activity-alias` `BrowserLauncher`, ligado só
 * em aparelho vinculado com o navegador habilitado na política.
 */
class BrowserActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingUrl: String? = null
    private var events: NativeEventsApi? = null
    private var deviceBridge: DeviceBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingUrl = urlOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun getDartEntrypointFunctionName(): String = DART_ENTRYPOINT

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        deviceBridge =
            Bridges.register(
                messenger = messenger,
                graph = AgentGraph.get(this),
                activity = this,
                consumeAction = { null },
                consumeUrl = { pendingUrl.also { pendingUrl = null } },
            )
        events = NativeEventsApi(messenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val url = urlOf(intent) ?: return
        val api = events
        if (api == null) {
            pendingUrl = url
            return
        }
        scope.launch {
            try {
                api.onOpenUrl(url)
            } catch (e: Throwable) {
                pendingUrl = url
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        deviceBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    /** Endereço pedido: link http ou https tocado em outro app, ou o extra de `openManagedBrowser`. */
    private fun urlOf(intent: Intent?): String? {
        if (intent == null) return null
        intent.getStringExtra(EXTRA_URL)?.takeIf { it.isNotBlank() }?.let { return it }
        val data = intent.data ?: return null
        val scheme = data.scheme?.lowercase()
        return if (scheme == "http" || scheme == "https") data.toString() else null
    }

    companion object {
        const val EXTRA_URL = "plx.browser.url"
        private const val DART_ENTRYPOINT = "browserMain"
    }
}
