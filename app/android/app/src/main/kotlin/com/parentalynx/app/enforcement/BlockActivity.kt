package com.parentalynx.app.enforcement

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import android.window.OnBackInvokedDispatcher
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.parentalynx.app.AgentGraph
import com.parentalynx.app.MainActivity
import com.parentalynx.app.R
import com.parentalynx.app.policy.BlockReason
import com.parentalynx.app.policy.Decision

/**
 * Tela de bloqueio nativa. Explica por que o app não pode ser usado agora, informa a liberação e
 * oferece os caminhos que continuam disponíveis: apps liberados, pedido de tempo, emergência e
 * área do responsável.
 *
 * Não é ela que bloqueia: o bloqueio é a suspensão pelo sistema ou o envio do app para o segundo
 * plano, feitos pelo [BlockController]. Esta tela só informa. Ela se fecha sozinha quando o
 * motivo deixa de valer (tempo extra concedido, fim do período).
 */
class BlockActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var graph: AgentGraph
    private var appId: String = ""
    private var appLabel: String = ""
    private var reason: BlockReason = BlockReason.APP_BLOCKED
    private var releaseAtMs: Long? = null
    private var scheduleLabel: String? = null
    private val poll =
        object : Runnable {
            override fun run() {
                refresh()
                handler.postDelayed(this, POLL_MS)
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        graph = AgentGraph.get(this)
        setContentView(R.layout.activity_block)
        val root = findViewById<View>(R.id.block_root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { goHome() }
        }
        findViewById<Button>(R.id.block_request).setOnClickListener { askForTime() }
        findViewById<Button>(R.id.block_emergency).setOnClickListener { openEmergencyDialer() }
        findViewById<Button>(R.id.block_guardian).setOnClickListener { openGuardianArea() }
        findViewById<Button>(R.id.block_home).setOnClickListener { goHome() }
        bind(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        bind(intent)
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
        handler.removeCallbacks(poll)
        handler.postDelayed(poll, POLL_MS)
    }

    override fun onPause() {
        isInForeground = false
        handler.removeCallbacks(poll)
        super.onPause()
    }

    // Até o Android 12 o retorno chega por aqui. Do 13 em diante vale o registrado em onCreate.
    @SuppressLint("GestureBackNavigation")
    @Deprecated("Substituído pelo retorno registrado em onCreate a partir do Android 13.")
    override fun onBackPressed() {
        goHome()
    }

    private fun bind(intent: Intent) {
        appId = intent.getStringExtra(EXTRA_APP_ID).orEmpty()
        appLabel = intent.getStringExtra(EXTRA_LABEL).orEmpty().ifEmpty { appId }
        reason = BlockReason.fromWire(intent.getStringExtra(EXTRA_REASON)) ?: BlockReason.APP_BLOCKED
        releaseAtMs = intent.getLongExtra(EXTRA_RELEASE_AT, 0L).takeIf { it > 0L }
        scheduleLabel = intent.getStringExtra(EXTRA_SCHEDULE_LABEL)?.takeIf { it.isNotBlank() }
        render()
    }

    private fun render() {
        val icon = findViewById<ImageView>(R.id.block_icon)
        val title = findViewById<TextView>(R.id.block_title)
        val message = findViewById<TextView>(R.id.block_message)
        val request = findViewById<Button>(R.id.block_request)
        when (reason) {
            BlockReason.DAILY_LIMIT -> {
                icon.setImageResource(R.drawable.ic_block_time)
                title.setText(R.string.block_title_daily_limit)
                message.setText(R.string.block_message_daily_limit)
            }
            BlockReason.SCHEDULE -> {
                icon.setImageResource(R.drawable.ic_block_moon)
                title.text = scheduleLabel ?: getString(R.string.block_title_schedule)
                message.setText(R.string.block_message_schedule)
            }
            BlockReason.APP_BLOCKED -> {
                icon.setImageResource(R.drawable.ic_block_lock)
                title.setText(R.string.block_title_app_blocked)
                message.text = getString(R.string.block_message_app_blocked, appLabel)
            }
            BlockReason.NEW_APP -> {
                icon.setImageResource(R.drawable.ic_block_lock)
                title.setText(R.string.block_title_new_app)
                message.text = getString(R.string.block_message_new_app, appLabel)
            }
            BlockReason.APP_LIMIT -> {
                icon.setImageResource(R.drawable.ic_block_time)
                title.setText(R.string.block_title_app_limit)
                message.text = getString(R.string.block_message_app_limit, appLabel)
            }
            BlockReason.MANUAL_LOCK -> {
                icon.setImageResource(R.drawable.ic_block_lock)
                title.setText(R.string.block_title_manual_lock)
                message.setText(R.string.block_message_manual_lock)
            }
            BlockReason.TAMPER_LOCK -> {
                icon.setImageResource(R.drawable.ic_block_shield)
                title.setText(R.string.block_title_tamper)
                message.setText(R.string.block_message_tamper)
            }
        }
        request.visibility = if (reason == BlockReason.TAMPER_LOCK) View.GONE else View.VISIBLE
        request.setText(
            if (reason == BlockReason.APP_BLOCKED || reason == BlockReason.NEW_APP) R.string.block_request_release else R.string.block_request_time,
        )
        renderRelease()
        renderAllowedApps()
        val guardian = graph.prefs.guardianName
        findViewById<TextView>(R.id.block_footer).text =
            if (guardian.isEmpty()) getString(R.string.block_footer) else getString(R.string.block_footer_guardian, guardian)
    }

    private fun renderRelease() {
        val view = findViewById<TextView>(R.id.block_release)
        val release = releaseAtMs
        if (release == null) {
            view.visibility = View.GONE
            return
        }
        val zone = graph.engine.calendar().zone
        view.visibility = View.VISIBLE
        view.text = getString(R.string.block_release, TimeText.release(release, graph.clock.nowMs(), zone))
    }

    /** Lista os apps que continuam disponíveis durante o bloqueio. Tocar abre o app. */
    private fun renderAllowedApps() {
        val list = findViewById<LinearLayout>(R.id.block_allowed_list)
        val empty = findViewById<TextView>(R.id.block_allowed_empty)
        list.removeAllViews()
        val entries = graph.engine.exceptionEntries().take(MAX_ALLOWED_APPS)
        empty.visibility = if (entries.isEmpty()) View.VISIBLE else View.GONE
        val inflater = LayoutInflater.from(this)
        for (entry in entries) {
            val row = inflater.inflate(R.layout.item_allowed_app, list, false)
            row.findViewById<TextView>(R.id.allowed_label).text = entry.label
            val icon = row.findViewById<ImageView>(R.id.allowed_icon)
            runCatching { icon.setImageDrawable(packageManager.getApplicationIcon(entry.pkg)) }
            row.setOnClickListener {
                if (graph.childOps.launchApp(entry.appId)) finish()
            }
            list.addView(row)
        }
    }

    /** Confere com o motor se o bloqueio ainda vale. Se não vale mais, fecha a tela. */
    private fun refresh() {
        if (!graph.agent.isActive() || appId.isEmpty()) {
            finish()
            return
        }
        graph.engine.evaluateAsync(appId) { decision ->
            if (isFinishing || isDestroyed) return@evaluateAsync
            when (decision) {
                is Decision.Allowed -> {
                    Toast.makeText(this, R.string.block_released, Toast.LENGTH_SHORT).show()
                    finish()
                }
                is Decision.Blocked -> {
                    if (decision.reason != reason || decision.releaseAtMs != releaseAtMs || decision.label != scheduleLabel) {
                        reason = decision.reason
                        releaseAtMs = decision.releaseAtMs
                        scheduleLabel = decision.label
                        render()
                    }
                }
            }
        }
    }

    private fun askForTime() {
        val status = findViewById<TextView>(R.id.block_request_status)
        if (reason == BlockReason.APP_BLOCKED || reason == BlockReason.NEW_APP) {
            graph.childOps.submitTimeRequest(null, getString(R.string.request_release_message, appLabel))
            status.setText(R.string.block_request_sent)
            status.visibility = View.VISIBLE
            return
        }
        val minutes = intArrayOf(15, 30, 60)
        val labels = arrayOf(getString(R.string.request_15), getString(R.string.request_30), getString(R.string.request_60))
        AlertDialog
            .Builder(this)
            .setTitle(R.string.request_dialog_title)
            .setItems(labels) { _, which ->
                graph.childOps.submitTimeRequest(minutes[which], null)
                status.setText(R.string.block_request_sent)
                status.visibility = View.VISIBLE
            }.setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    /** Chamadas de emergência nunca são bloqueadas: abre o discador de emergência do sistema. */
    private fun openEmergencyDialer() {
        val emergency = Intent(ACTION_EMERGENCY_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(emergency)
        } catch (e: ActivityNotFoundException) {
            runCatching { startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        } catch (e: SecurityException) {
            runCatching { startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        }
    }

    private fun openGuardianArea() {
        startActivity(
            Intent(this, MainActivity::class.java)
                .putExtra(AgentNotifier.EXTRA_LAUNCH_ACTION, AgentNotifier.ACTION_GUARDIAN_AREA)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
        finish()
    }

    private fun goHome() {
        runCatching {
            startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        finish()
    }

    companion object {
        private const val EXTRA_APP_ID = "plx.block.app"
        private const val EXTRA_LABEL = "plx.block.label"
        private const val EXTRA_REASON = "plx.block.reason"
        private const val EXTRA_RELEASE_AT = "plx.block.release"
        private const val EXTRA_SCHEDULE_LABEL = "plx.block.schedule"
        private const val ACTION_EMERGENCY_DIAL = "com.android.phone.EmergencyDialer.DIAL"
        private const val POLL_MS = 1000L
        private const val MAX_ALLOWED_APPS = 12

        /** Verdadeiro enquanto a tela de bloqueio está visível e em primeiro plano. */
        @Volatile
        var isInForeground: Boolean = false
            private set

        // NO_USER_ACTION evita que o app coberto receba o aviso de "usuário saindo", que faria
        // players de vídeo entrarem em janela flutuante e continuarem tocando.
        fun intent(context: Context, request: BlockRequest): Intent =
            Intent(context, BlockActivity::class.java)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION or
                        Intent.FLAG_ACTIVITY_NO_USER_ACTION,
                )
                .putExtra(EXTRA_APP_ID, request.appId)
                .putExtra(EXTRA_LABEL, request.label)
                .putExtra(EXTRA_REASON, request.reason.wire)
                .putExtra(EXTRA_RELEASE_AT, request.releaseAtMs ?: 0L)
                .putExtra(EXTRA_SCHEDULE_LABEL, request.scheduleLabel)
    }
}
