package com.starkgo.net.cardenCode.vpn

import android.content.Context
import android.content.Intent
import android.util.Log
import com.starkgo.net.cardenCode.MainActivity

/**
 * Reparte las acciones originadas en la notificación o en el Tile hacia el
 * lado Dart (MethodChannel) cuando el motor de Flutter está vivo; si no lo
 * está, ejecuta el equivalente de forma 100% nativa.
 */
object VpnActions {
    private const val TAG = "VpnActions"

    /**
     * Entrega la acción a Dart. Devuelve true si quedó "gestionada" (entregada
     * ahora o encolada para cuando Dart se suscriba).
     */
    fun deliver(context: Context, action: String): Boolean {
        if (!VpnForegroundPlugin.engineAttached) {
            Log.i(TAG, "Acción '$action': motor Flutter no adjunto; " +
                "se resolverá de forma nativa.")
            return false
        }
        val sink = VpnForegroundPlugin.eventSink
        if (sink != null) {
            Log.i(TAG, "Acción '$action' entregada al motor Flutter.")
            sink.success(action)
            return true
        }
        // Motor adjunto pero Dart aún no escucha: se reenvía al suscribirse.
        Log.i(TAG, "Acción '$action': Dart aún no escucha; se encola.")
        VpnState.setPendingAction(context, action)
        return true
    }

    /** "Apagar VPN". Ahora es un apagado con doble vía:
     *  1) Avisa a Dart para que sincronice su estado/UI (si el motor existe).
     *  2) Detiene SIEMPRE el VpnService real del backend por la vía nativa:
     *     así funciona aunque el motor actual no sea el dueño del túnel
     *     (p. ej. app reabierta con túnel conectado de una sesión anterior).
     *  3) Detiene el FGS (oculta la notificación) y actualiza el tile.
     */
    fun stopRequested(context: Context) {
        deliver(context, VpnForegroundPlugin.ACTION_STOP_VPN)

        val stopped = VpnNative.forceStopTunnel()
        Log.i(TAG, "Apagado solicitado desde notificación/tile. " +
            "Túnel detenido nativamente: $stopped")

        VpnForegroundService.stop(context)
        VpnState.setTunnelActive(context, false)
        VpnTileService.refresh(context)
    }

    /** Abrir la app (notificación / tile cuando está desconectada). */
    fun openRequested(context: Context) {
        if (deliver(context, VpnForegroundPlugin.ACTION_OPEN_VPN)) return
        launchApp(context, VpnForegroundPlugin.ACTION_OPEN_VPN)
    }

    /** El tile pide conectar la VPN: abre la app en la sección VPN. */
    fun startRequested(context: Context) {
        if (deliver(context, VpnForegroundPlugin.ACTION_TOGGLE_VPN)) return
        launchApp(context, VpnForegroundPlugin.ACTION_OPEN_VPN)
    }

    private fun launchApp(context: Context, action: String) {
        val intent =
            context.packageManager.getLaunchIntentForPackage(
                context.packageName,
            ) ?: Intent(context, MainActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
        )
        intent.putExtra(VpnForegroundPlugin.EXTRA_VPN_ACTION, action)
        context.startActivity(intent)
    }
}
