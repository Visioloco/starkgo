package com.starkgo.net.cardenCode.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Recibe las acciones PendingIntent de la notificación del servicio en primer
 * plano ("Apagar VPN") y las reparte a Dart o al fallback nativo.
 */
class VpnActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "Acción de notificación recibida: ${intent.action}")
        when (intent.action) {
            VpnForegroundPlugin.ACTION_STOP_VPN -> VpnActions.stopRequested(context)

            VpnForegroundPlugin.ACTION_OPEN_VPN -> VpnActions.openRequested(context)

            VpnForegroundPlugin.ACTION_TOGGLE_VPN -> VpnActions.startRequested(context)

            else -> Unit
        }
    }

    private companion object {
        const val TAG = "VpnActionReceiver"
    }
}
