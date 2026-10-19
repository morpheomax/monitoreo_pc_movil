package com.innextsolutions.pcmonitor

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPairing: String? = null
    private var pairingChannel: MethodChannel? = null

    private fun receivePairing(source: Intent?) {
        val url = source?.getStringExtra("pcmonitor_pairing") ?: return
        source.removeExtra("pcmonitor_pairing")
        // Solo conservar en memoria. Flutter valida también esquema, host y ruta.
        if (url.length > 256) return
        pendingPairing = url
        pairingChannel?.invokeMethod("available", null)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receivePairing(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        receivePairing(intent)
        pairingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pcmonitor/pairing")
        pairingChannel?.setMethodCallHandler { call, result ->
            if (call.method == "consume") {
                val value = pendingPairing
                pendingPairing = null
                result.success(value)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pcmonitor/panel")
            .setMethodCallHandler { call, result ->
                if (call.method == "keepScreenOn") {
                    // La bandera solo mantiene despierta esta ventana mientras está visible.
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                } else if (call.method == "getThemeMode") {
                    result.success(getPreferences(MODE_PRIVATE).getString("themeMode", "system"))
                } else if (call.method == "setThemeMode") {
                    val mode = call.arguments as? String
                    if (mode in setOf("system", "light", "dark")) {
                        getPreferences(MODE_PRIVATE).edit().putString("themeMode", mode).apply()
                        result.success(null)
                    } else {
                        result.error("invalid_theme", "Unknown theme mode", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
