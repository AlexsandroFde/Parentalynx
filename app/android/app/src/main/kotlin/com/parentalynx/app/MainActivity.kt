package com.parentalynx.app

import android.content.Intent
import android.os.Bundle
import com.parentalynx.app.bridge.Bridges
import com.parentalynx.app.bridge.DeviceBridge
import com.parentalynx.app.bridge.NativeEventsApi
import com.parentalynx.app.enforcement.AgentNotifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** Atividade principal: hospeda a interface Flutter dos modos responsável e criança. */
class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingAction: String? = null
    private var events: NativeEventsApi? = null
    private var deviceBridge: DeviceBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingAction = intent?.getStringExtra(AgentNotifier.EXTRA_LAUNCH_ACTION)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        deviceBridge =
            Bridges.register(
                messenger = messenger,
                graph = AgentGraph.get(this),
                activity = this,
                consumeAction = { pendingAction.also { pendingAction = null } },
                consumeUrl = { null },
            )
        events = NativeEventsApi(messenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra(AgentNotifier.EXTRA_LAUNCH_ACTION) ?: return
        val api = events
        if (api == null) {
            pendingAction = action
            return
        }
        scope.launch {
            try {
                api.onLaunchAction(action)
            } catch (e: Throwable) {
                // Interface ainda não registrou o receptor: fica para consumeLaunchAction.
                pendingAction = action
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val graph = AgentGraph.get(this)
        graph.agent.ensureRunning("app_open")
        graph.engine.requestPermissionCheck()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        deviceBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
