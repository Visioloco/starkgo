package com.starkgo.net.cardenCode

import com.starkgo.net.cardenCode.vpn.VpnForegroundPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Puente nativo para la notificación del servicio en primer plano y el
        // Tile de Ajustes Rápidos del túnel WireGuard.
        flutterEngine.plugins.add(VpnForegroundPlugin())
    }
}

