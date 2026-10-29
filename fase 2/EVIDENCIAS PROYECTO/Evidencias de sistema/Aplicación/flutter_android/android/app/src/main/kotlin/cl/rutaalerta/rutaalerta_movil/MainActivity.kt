package cl.rutaalerta.rutaalerta_movil

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cl.rutaalerta/trayecto").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (pending != null) result.error("busy", "Ya hay una solicitud en curso.", null)
                    else {
                        val permissions = mutableListOf<String>()
                        if (!hasLocation()) {
                            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
                            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
                        }
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                        if (permissions.isNotEmpty()) {
                            pending = result
                            requestPermissions(permissions.toTypedArray(), 731)
                        } else launchTrip(result)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, TripLocationService::class.java))
                    TripLocationService.running = false
                    TripLocationService.lastLocation = null
                    TripLocationService.error = null
                    result.success(null)
                }
                "status" -> {
                    val loc = TripLocationService.lastLocation
                    result.success(mapOf("running" to TripLocationService.running, "lat" to loc?.latitude, "lng" to loc?.longitude, "accuracy" to loc?.accuracy?.toInt(), "error" to TripLocationService.error))
                }
                "openAttribution" -> {
                    try { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.openstreetmap.org/copyright"))); result.success(null) }
                    catch (_: Exception) { result.error("browser", "No hay un navegador disponible.", null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun hasLocation() = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    private fun launchTrip(result: MethodChannel.Result) {
        if (!hasLocation()) { result.error("location", "Necesitas autorizar la ubicación para iniciar el trayecto.", null); return }
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            result.error("notifications", "Autoriza las notificaciones para mantener visible el trayecto.", null); return
        }
        try { startForegroundService(Intent(this, TripLocationService::class.java)); result.success(null) }
        catch (_: Exception) { result.error("service", "No se pudo iniciar el trayecto. Abre RutaAlerta e inténtalo de nuevo.", null) }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 731) { val result = pending; pending = null; if (result != null) launchTrip(result) }
    }
    override fun onDestroy() {
        pending?.error("cancelled", "Solicitud cancelada. Vuelve a iniciar el trayecto.", null)
        pending = null
        super.onDestroy()
    }
}
