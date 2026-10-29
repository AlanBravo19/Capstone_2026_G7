package cl.rutaalerta.rutaalerta_movil

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper

/** Ubicación local en memoria. No envía recorridos, no lee Waze y no calcula riesgo. */
class TripLocationService : Service(), LocationListener {
    companion object {
        @Volatile var running = false
        @Volatile var lastLocation: Location? = null
        @Volatile var error: String? = null
        const val CHANNEL = "rutaalerta_trayecto"
    }
    private var manager: LocationManager? = null
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_TRIP") { stopSelf(); return START_NOT_STICKY }
        if (running) return START_NOT_STICKY
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Trayecto de RutaAlerta", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, TripLocationService::class.java).setAction("STOP_TRIP"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = Notification.Builder(this, CHANNEL)
            .setContentTitle("RutaAlerta · Trayecto activo")
            .setContentText("Ubicación local activa. Sin avisos territoriales en esta versión.")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(null, "Detener", stop).build()).build()
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(731, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            else startForeground(731, notification)
            manager = getSystemService(LocationManager::class.java)
            val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!fine && !coarse) throw SecurityException()
            var registered = false
            if (fine && manager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) {
                manager?.requestLocationUpdates(LocationManager.GPS_PROVIDER, 10000L, 20f, this, Looper.getMainLooper())
                registered = true
            }
            if (manager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                manager?.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 10000L, 20f, this, Looper.getMainLooper())
                registered = true
            }
            if (!registered) {
                error = "Activa la ubicación del teléfono e inicia nuevamente el trayecto."
                stopSelf()
            } else { error = null; running = true }
        } catch (_: Exception) {
            error = "No se pudo mantener la ubicación. Revisa los permisos y vuelve a iniciar el trayecto."
            stopSelf()
        }
        return START_NOT_STICKY
    }
    override fun onLocationChanged(location: Location) { if (running) lastLocation = Location(location) }
    override fun onProviderDisabled(provider: String) {
        // Nunca conservar indefinidamente una ubicación vieja como si fuera actual.
        lastLocation = null
        error = "Proveedor de ubicación desactivado. Revisa el GPS."
    }
    override fun onProviderEnabled(provider: String) { error = null }
    @Deprecated("Necesario para compatibilidad Android 8")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) { }
    override fun onDestroy() {
        manager?.removeUpdates(this)
        running = false; lastLocation = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
