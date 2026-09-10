package com.starkgo.net.cardenCode.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.starkgo.net.cardenCode.MainActivity
import com.starkgo.net.cardenCode.R

/**
 * Servicio en primer plano "acompañante" del túnel WireGuard.
 *
 * El VpnService real lo gestiona el backend wireguard-android (arrancado por el
 * plugin wireguard_flutter con `startService`) y NO publica ninguna
 * notificación. Este servicio:
 *
 *  1. Sube la prioridad del proceso mientras el túnel está activo (evita que
 *     el sistema mate el proceso y con él la interfaz wg0).
 *  2. Publica la notificación persistente "StarkGo · VPN Activa / Conectado a
 *     MikroTik" con la acción "Apagar VPN".
 *  3. Al tocar el cuerpo de la notificación abre la MainActivity.
 *
 * Se inicia desde Dart (MethodChannel) en cuanto el túnel pasa a `connected` y
 * se detiene cuando pasa a `disconnected` / `error` (la notificación
 * desaparece sola al detenerse el servicio).
 */
class VpnForegroundService : Service() {

    companion object {
        private const val TAG = "VpnForegroundService"

        const val ACTION_START =
            "com.starkgo.net.cardenCode.vpn.action.START"
        const val ACTION_STOP =
            "com.starkgo.net.cardenCode.vpn.action.STOP"
        const val ACTION_STOP_VPN =
            "com.starkgo.net.cardenCode.vpn.action.STOP_VPN"

        const val NOTIFICATION_CHANNEL_ID = "tunel_vpn_estado"
        const val NOTIFICATION_ID = 4107

        /** Arranca el servicio en primer plano (o lo refresca si ya corre). */
        fun start(context: Context) {
            val intent =
                Intent(context, VpnForegroundService::class.java)
                    .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Detiene el servicio (y por lo tanto oculta la notificación). */
        fun stop(context: Context) {
            context.stopService(
                Intent(context, VpnForegroundService::class.java),
            )
        }

        /** Crea el canal de notificación (Android 8+). IMPORTANCE_LOW para no
         *  emitir pitidos repetidos: es una notificación de estado ongoing. */
        fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                context.getSystemService(NotificationManager::class.java)
                    ?: return
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Estado del túnel VPN",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description =
                    "Notificación persistente mientras la VPN WireGuard está activa"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }

        /** Construye la notificación persistente con acción "Apagar VPN". */
        fun buildNotification(context: Context): Notification {
            ensureNotificationChannel(context)

            val contentIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val stopPendingIntent = PendingIntent.getBroadcast(
                context,
                1,
                // Componente explícito: el receiver es exported=false y no
                // tiene intent-filter, por lo que no se resolvería por acción.
                Intent(context, VpnActionReceiver::class.java)
                    .setAction(VpnForegroundPlugin.ACTION_STOP_VPN),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val builder =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
                } else {
                    @Suppress("DEPRECATION")
                    Notification.Builder(context)
                }

            val stopAction = Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(
                    context,
                    R.drawable.ic_stop_vpn,
                ),
                "Apagar VPN",
                stopPendingIntent,
            ).build()

            return builder
                .setSmallIcon(R.drawable.ic_stat_vpn)
                .setContentTitle(context.getString(R.string.app_name) + " · VPN Activa")
                .setContentText("Conectado a MikroTik")
                .setStyle(
                    Notification.BigTextStyle().bigText(
                        "Túnel WireGuard activo y conectado a MikroTik.\n" +
                            "Tocá esta notificación para abrir StarkGo.",
                    ),
                )
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setCategory(Notification.CATEGORY_SERVICE)
                .setColor(0xFF00C6AE.toInt())
                .addAction(stopAction)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel(this)
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        when (intent?.action) {
            ACTION_START -> {
                startAsForeground()
                return START_STICKY
            }

            ACTION_STOP_VPN -> {
                // Botón "Apagar VPN" enviado a través del servicio.
                VpnActions.stopRequested(this)
                return START_STICKY
            }

            ACTION_STOP -> {
                stopSelf()
                return START_STICKY
            }

            else -> {
                // Re-arranque del sistema (START_STICKY tras muerte del proceso)
                // o arranque directo. Solo mostramos la notificación si el
                // VpnService de WireGuard sigue vivo; si no, el túnel ya cayó.
                if (VpnState.isTunnelActive(this) &&
                    VpnNative.isVpnServiceRunning()
                ) {
                    startAsForeground()
                    return START_STICKY
                }
                VpnState.setTunnelActive(this, false)
                VpnTileService.refresh(this)
                return START_NOT_STICKY
            }
        }
    }

    private fun startAsForeground() {
        try {
            val notification = buildNotification(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+: tipo especialUse explícito en startForeground.
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            VpnState.setTunnelActive(this, true)
            VpnTileService.refresh(this)
            Log.i(TAG, "Notificación del túnel publicada (id=$NOTIFICATION_ID).")
        } catch (e: Throwable) {
            Log.e(TAG, "No se pudo iniciar el FGS: ${e.message}", e)
            stopSelf()
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "Servicio en primer plano detenido; notificación oculta.")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        VpnState.setTunnelActive(this, false)
        VpnTileService.refresh(this)
        super.onDestroy()
    }
}

