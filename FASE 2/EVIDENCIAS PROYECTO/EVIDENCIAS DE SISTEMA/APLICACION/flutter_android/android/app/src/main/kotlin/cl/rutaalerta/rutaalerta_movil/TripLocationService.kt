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
import android.net.Uri
import org.json.JSONObject
import java.time.Instant

/** Ubicación local en memoria. No envía recorridos, no lee Waze y no calcula riesgo. */
class TripLocationService : Service(), LocationListener {
    companion object {
        @Volatile var running = false
        @Volatile var lastLocation: Location? = null
        @Volatile var error: String? = null
        @Volatile var noticeCount=0
        @Volatile var cacheUntil=0L
        @Volatile var voiceState = "off"
        @Volatile var grouped = false
        const val CHANNEL = "rutaalerta_trayecto"
        private const val ALERT_CHANNEL = "rutaalerta_antecedentes"
        private const val SPOKEN_CHANNEL = "rutaalerta_antecedentes_voz"
    }
    private var notices=emptyList<TerritorialNotice>()
    private val alerted=mutableMapOf<String,Long>()
    private var lastAny=0L
    private var manager: LocationManager? = null
    private var voice: TripVoice? = null
    private var voiceEnabled = false
    private var ensayo = false
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_TRIP") { stopSelf(); return START_NOT_STICKY }
        if (running) return START_NOT_STICKY
        loadNotices(intent?.getStringExtra("alerts") ?: "{}")
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Trayecto de RutaAlerta", NotificationManager.IMPORTANCE_LOW))
        notifications.createNotificationChannel(NotificationChannel(ALERT_CHANNEL, "Antecedentes territoriales", NotificationManager.IMPORTANCE_DEFAULT))
        notifications.createNotificationChannel(NotificationChannel(SPOKEN_CHANNEL, "Avisos acompañados por voz", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, TripLocationService::class.java).setAction("STOP_TRIP"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = Notification.Builder(this, CHANNEL)
            .setContentTitle("RutaAlerta · Trayecto activo")
            .setContentText("Ubicación local activa. Avisos sólo con antecedentes revisados vigentes.")
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
            } else {
                error = null
                running = true
                if (voiceEnabled && grouped) {
                    voice = runCatching { TripVoice(this) { voiceState = it } }
                        .getOrElse { voiceState = "unavailable"; null }
                }
            }
        } catch (_: Exception) {
            error = "No se pudo mantener la ubicación. Revisa los permisos y vuelve a iniciar el trayecto."
            stopSelf()
        }
        return START_NOT_STICKY
    }
    override fun onLocationChanged(location: Location) {
        if (!running) return
        lastLocation=Location(location)
        val now=System.currentTimeMillis()
        if (!location.hasAccuracy()) return
        for(n in notices){
            if(ProximityRules.eligible(n,location.latitude,location.longitude,location.accuracy.toDouble(),location.time,now,cacheUntil,alerted[n.id] ?: 0L,lastAny)){
                val manager=getSystemService(NotificationManager::class.java)
                val id=(n.id.hashCode() and 0x7fffffff)%100000+2000
                val destination = if (grouped) Intent(this, MainActivity::class.java)
                    else Intent(Intent.ACTION_VIEW,Uri.parse(n.url))
                val open=PendingIntent.getActivity(this,id,destination,PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                val prefix = if (ensayo) "Ensayo · " else "RutaAlerta · "
                val title = if (n.encerronas > 0) "Zona con antecedentes de encerronas" else "Antecedentes históricos cerca"
                val text = if (grouped) "${n.zone}: ${n.total} antecedentes revisados."
                    else "Antecedente publicado en ${n.zone}. Fuente: ${n.source}, ${n.published}."
                val speech = n.speech(ensayo)
                val voiceQueued = speech != null && runCatching { voice?.say(speech) == true }.getOrDefault(false)
                val channel = if (voiceQueued) SPOKEN_CHANNEL else ALERT_CHANNEL
                val notification=Notification.Builder(this,channel).setContentTitle(prefix + title)
                    .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text+" Revisa este aviso cuando estés estacionado."))
                    .setSmallIcon(R.drawable.ic_notification).setContentIntent(open).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build()
                runCatching { manager.notify(id,notification) }
                alerted[n.id] = now
                lastAny = now
                break
            }
        }
    }
    private fun loadNotices(raw:String){
        notices=emptyList();noticeCount=0;cacheUntil=0
        try {
            if(raw.length>250000)return
            val data=JSONObject(raw)
            cacheUntil=data.optLong("cacheUntil",0).coerceAtMost(System.currentTimeMillis()+7200000L)
            voiceEnabled = data.optBoolean("voz")
            ensayo = data.optBoolean("ensayo")
            val areas = data.optJSONArray("zonas")
            grouped = areas != null
            val array = areas ?: data.optJSONArray("avisos") ?: return
            val values=mutableListOf<TerritorialNotice>()
            for(i in 0 until minOf(array.length(),200)){
                val n = array.optJSONObject(i) ?: continue
                runCatching { parseNotice(n) }.getOrNull()?.let(values::add)
            }
            notices=values;noticeCount=values.size
        }catch(_:Exception){notices=emptyList();noticeCount=0;cacheUntil=0}
    }
    private fun parseNotice(n: JSONObject): TerritorialNotice? {
        val lat = n.getDouble("latitud")
        val lon = n.getDouble("longitud")
        val radius = n.getDouble("radio_m")
        if (lat !in -90.0..90.0 || lon !in -180.0..180.0 || radius !in 100.0..15000.0) return null
        val field = if (grouped) "vigente_hasta" else "vence_en"
        val expiry = Instant.parse(n.getString(field).replace("+00:00", "Z")).toEpochMilli()
        if (grouped) {
            val total = n.getInt("antecedentes")
            val encerronas = n.getInt("encerronas")
            if (total < 2 || encerronas !in 0..total) return null
            return TerritorialNotice(n.getString("id_zona"), lat, lon, radius, expiry,
                n.getString("sector").take(120), total = total, encerronas = encerronas)
        }
        val uri = Uri.parse(n.getString("url_fuente"))
        if (uri.scheme != "https" || uri.host.isNullOrEmpty() || uri.userInfo != null) return null
        return TerritorialNotice(n.getString("id_antecedente"), lat, lon, radius, expiry,
            n.getString("zona").take(120), n.getString("nombre_fuente").take(100),
            uri.toString(), n.getString("fecha_publicacion").take(10))
    }
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
        voice?.close()
        voice = null
        voiceState = "off"
        grouped = false
        running = false; lastLocation = null;notices=emptyList();noticeCount=0;cacheUntil=0;alerted.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
