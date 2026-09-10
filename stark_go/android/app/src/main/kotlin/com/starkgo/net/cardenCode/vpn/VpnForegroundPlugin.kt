package com.starkgo.net.cardenCode.vpn

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Plugin Flutter registrado en [com.starkgo.net.cardenCode.MainActivity].
 *
 * Canales:
 *  - MethodChannel `com.starkgo.net.cardenCode/vpn_foreground`
 *      · start()                  → arranca el servicio en primer plano
 *      · stop()                   → detiene el servicio (oculta notificación)
 *      · setTunnelActive(bool)    → sincroniza el Tile con el estado real
 *  - EventChannel `.../vpn_foreground/events`
 *      Emite `stop_vpn`, `open_vpn` o `toggle_vpn` cuando el usuario pulsa el
 *      botón "Apagar VPN" de la notificación o toca el Tile.
 */
class VpnForegroundPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {

    companion object {
        const val CHANNEL = "com.starkgo.net.cardenCode/vpn_foreground"
        const val EVENTS = "com.starkgo.net.cardenCode/vpn_foreground/events"
        private const val TAG = "VpnForegroundPlugin"

        /** Extra usado al abrir la app desde el tile/notificación. */
        const val EXTRA_VPN_ACTION = "extra_vpn_action"
        const val ACTION_STOP_VPN = "stop_vpn"
        const val ACTION_OPEN_VPN = "open_vpn"
        const val ACTION_TOGGLE_VPN = "toggle_vpn"

        @Volatile
        var engineAttached: Boolean = false

        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var activityBinding: ActivityPluginBinding? = null

    // ── FlutterPlugin ──────────────────────────────────────────────
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENTS)
        eventChannel?.setStreamHandler(this)
        engineAttached = true
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
        engineAttached = false
        eventSink = null
    }

    // ── MethodCallHandler ──────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: Result) {
        val ctx = context
        if (ctx == null) {
            result.success(null)
            return
        }
        when (call.method) {
            "start" -> {
                try {
                    Log.i(TAG, "Dart solicita arrancar el FGS del túnel.")
                    VpnForegroundService.start(ctx)
                    result.success(true)
                } catch (e: Throwable) {
                    Log.e(TAG, "Error arrancando FGS: ${e.message}", e)
                    result.error("fgs_start_error", e.message, null)
                }
            }

            "stop" -> {
                // Asegura que el túnel real (VpnService del backend) baje y
                // detiene el servicio en primer plano (oculta la notificación).
                try {
                    Log.i(TAG, "Dart solicita detener el FGS del túnel.")
                    VpnNative.forceStopTunnel()
                    VpnForegroundService.stop(ctx)
                    result.success(true)
                } catch (e: Throwable) {
                    Log.e(TAG, "Error deteniendo FGS: ${e.message}", e)
                    result.error("fgs_stop_error", e.message, null)
                }
            }

            "setTunnelActive" -> {
                val active = call.arguments as? Boolean ?: false
                VpnState.setTunnelActive(ctx, active)
                VpnTileService.refresh(ctx)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // ── EventChannel.StreamHandler ─────────────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Reprocesa acciones pendientes: ej. "Desconectar" pulsado cuando la
        // app estaba cerrada y se reabrió para ejecutarla.
        val ctx = context ?: return
        val pending = VpnState.pendingAction(ctx)
        if (pending != null) {
            VpnState.setPendingAction(ctx, null)
            events?.success(pending)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ── ActivityAware ──────────────────────────────────────────────
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        // Si la app se lanzó desde el tile/notificación con una acción, se
        // encola para que Dart la reciba al suscribirse al EventChannel.
        val ctx = context
        val action =
            binding.activity.intent?.getStringExtra(EXTRA_VPN_ACTION)
        if (action != null && ctx != null) {
            VpnState.setPendingAction(ctx, action)
        }
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }
}
