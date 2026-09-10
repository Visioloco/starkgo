package com.starkgo.net.cardenCode.vpn

import android.content.Context
import android.content.SharedPreferences

/**
 * Estado persistente del túnel compartido entre el lado Dart, el servicio en
 * primer plano, el receptor de acciones y el Tile de Ajustes Rápidos.
 *
 * Se guarda en SharedPreferences porque el servicio y el tile pueden ejecutarse
 * (o reactivarse) cuando el motor de Flutter ya no está en memoria.
 */
object VpnState {
    private const val PREFS = "starkgo_vpn"
    private const val KEY_ACTIVE = "tunnel_active"
    private const val KEY_PENDING_ACTION = "pending_action"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isTunnelActive(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ACTIVE, false)

    fun setTunnelActive(context: Context, active: Boolean) {
        prefs(context).edit().putBoolean(KEY_ACTIVE, active).apply()
    }

    /** Acción diferida (stop_vpn / open_vpn) que se entrega al motor de
     *  Flutter cuando éste vuelva a suscribirse. */
    fun pendingAction(context: Context): String? =
        prefs(context).getString(KEY_PENDING_ACTION, null)

    fun setPendingAction(context: Context, action: String?) {
        prefs(context).edit().putString(KEY_PENDING_ACTION, action).apply()
    }
}
