package com.starkgo.net.cardenCode.vpn

import android.app.Service
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * Acceso de emergencia al VpnService del backend `wireguard-android`.
 *
 * El plugin `wireguard_flutter` arranca `com.wireguard.android.backend.
 * GoBackend$VpnService` mediante `Context.startService()` y expone la instancia
 * en el campo estático `GoBackend.vpnService` (un CompletableFuture). Ese
 * servicio NO publica notificaciones ni corre como foreground.
 *
 * Cuando el motor de Flutter ya no existe (usuario deslizó la app de Recientes
 * pero el proceso sigue vivo gracias al foreground service) no hay forma de
 * llegar a Dart; para "Apagar VPN" reflejamos ese campo y pedimos `stopSelf()`:
 * al destruirse el VpnService se cierra el descriptor TUN y la interfaz
 * WireGuard cae inmediatamente (equivalente a `GoBackend.setState(DOWN)`).
 */
object VpnNative {
    private const val TAG = "VpnNative"
    private const val GO_BACKEND_CLASS =
        "com.wireguard.android.backend.GoBackend"
    private const val VPN_SERVICE_FIELD = "vpnService"

    private fun vpnServiceOrNull(): Service? {
        return try {
            val klass = Class.forName(GO_BACKEND_CLASS)
            val field = klass.getDeclaredField(VPN_SERVICE_FIELD)
            field.isAccessible = true
            val future = field.get(null) ?: return null
            val get = future.javaClass.getMethod(
                "get",
                Long::class.javaPrimitiveType,
                TimeUnit::class.java,
            )
            get.invoke(future, 0L, TimeUnit.NANOSECONDS) as? Service
        } catch (e: Throwable) {
            Log.w(TAG, "No se pudo consultar el VpnService de WireGuard: ${e.message}")
            null
        }
    }

    /** true si el VpnService del backend sigue vivo (túnel potencialmente up). */
    fun isVpnServiceRunning(): Boolean = vpnServiceOrNull() != null

    /** Detiene el VpnService de WireGuard (cierra el túnel) sin pasar por Dart. */
    fun forceStopTunnel(): Boolean {
        val service = vpnServiceOrNull() ?: return false
        return try {
            service.stopSelf()
            Log.i(TAG, "VpnService detenido por fallback nativo (stopSelf).")
            true
        } catch (e: Throwable) {
            Log.w(TAG, "Error al detener el VpnService: ${e.message}")
            false
        }
    }
}
