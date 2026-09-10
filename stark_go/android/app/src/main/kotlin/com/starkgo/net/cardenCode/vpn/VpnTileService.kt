package com.starkgo.net.cardenCode.vpn

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.starkgo.net.cardenCode.R

/**
 * Tile de Ajustes Rápidos para gestionar el túnel WireGuard.
 *
 *  - Tile activo  → la VPN está conectada. Un tap pide desconectar.
 *  - Tile inactivo → la VPN está apagada. Un tap abre la app en la pantalla
 *    VPN para iniciar la conexión (hace falta la config + consentimiento del
 *    sistema, que solo puede pedir la Activity).
 */
class VpnTileService : TileService() {

    override fun onTileAdded() {
        refreshTile()
    }

    override fun onStartListening() {
        refreshTile()
    }

    override fun onClick() {
        if (!VpnState.isTunnelActive(this)) {
            VpnActions.startRequested(this)
        } else {
            VpnActions.stopRequested(this)
        }
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val active = VpnState.isTunnelActive(this)
        tile.state =
            if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label =
            if (active) getString(R.string.vpn_tile_on)
            else getString(R.string.vpn_tile_off)
        if (android.os.Build.VERSION.SDK_INT >=
            android.os.Build.VERSION_CODES.Q
        ) {
            tile.subtitle =
                if (active) getString(R.string.vpn_tile_sub_on)
                else getString(R.string.vpn_tile_sub_off)
        }
        tile.updateTile()
    }

    companion object {
        /**
         * Pide al sistema que refresque el tile (si está visible) tras cambiar
         * el estado del túnel. Se invoca desde el servicio en primer plano.
         */
        fun refresh(context: Context) {
            // La variante de dos argumentos de requestListeningState existe
            // desde Android 13 (TIRAMISU); en versiones anteriores el tile se
            // refresca igual en onStartListening al abrir Ajustes Rápidos.
            if (android.os.Build.VERSION.SDK_INT <
                android.os.Build.VERSION_CODES.TIRAMISU
            ) {
                return
            }
            try {
                TileService.requestListeningState(
                    context,
                    ComponentName(context, VpnTileService::class.java),
                )
            } catch (_: Throwable) {
                // El tile puede no estar agregado todavía; se ignora.
            }
        }
    }
}
